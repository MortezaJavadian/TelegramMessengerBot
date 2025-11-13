#!/bin/sh

# Set default notification target if not set
if [ -z "$NOTIFICATION_TARGET" ]; then
  echo "NOTIFICATION_TARGET not set, defaulting to 'telegram'."
  NOTIFICATION_TARGET="telegram"
fi

# Check if at least one action variable is set
if [ -z "$FILE" ] && [ -z "$TEXT" ] && [ -z "$PUSH" ] && [ -z "$FOLDER" ]; then
  echo "Error: One of the environment variables TEXT, FILE, FOLDER, or PUSH must be set."
  exit 1
fi

# Ensure mutual exclusivity between action variables
if [ -n "$PUSH" ]; then
  if [ -n "$TEXT" ] || [ -n "$FILE" ] || [ -n "$FOLDER" ]; then
    echo "Error: PUSH cannot be used with TEXT, FILE, or FOLDER."
    exit 1
  fi
fi
if [ -n "$FILE" ] && [ -n "$FOLDER" ]; then
  echo "Error: Both FILE and FOLDER variables are set. Please use only one."
  exit 1
fi

if [ "$NOTIFICATION_TARGET" = "telegram" ]; then
  if [ -z "$TELEGRAM_BOT_TOKEN" ] || [ -z "$TELEGRAM_CHAT_ID" ]; then
    echo "Error: TELEGRAM_BOT_TOKEN or TELEGRAM_CHAT_ID environment variable is not set"
    exit 1
  fi
  # Argument for message_thread_id
  if [ -n "$TELEGRAM_THREAD_ID" ]; then
    TELEGRAM_THREAD_ARG_TEXT="-d message_thread_id=${TELEGRAM_THREAD_ID}"
    TELEGRAM_THREAD_ARG_FILE="-F message_thread_id=${TELEGRAM_THREAD_ID}"
  else
    TELEGRAM_THREAD_ARG_TEXT=""
    TELEGRAM_THREAD_ARG_FILE=""
  fi
elif [ "$NOTIFICATION_TARGET" = "mattermost" ]; then
  if [ -z "$MATTERMOST_URL" ] || [ -z "$MATTERMOST_TOKEN" ] || [ -z "$MATTERMOST_TEAM_NAME" ] || [ -z "$MATTERMOST_CHANNEL_NAME" ]; then
    echo "Error: MATTERMOST_URL, MATTERMOST_TOKEN, MATTERMOST_TEAM_NAME, and MATTERMOST_CHANNEL_NAME must be set."
    exit 1
  fi
fi

# Argument for reply_to_message_id
if [ -n "$TELEGRAM_REPLY_ID" ]; then
  TELEGRAM_REPLY_ARG_TEXT="-d reply_to_message_id=${TELEGRAM_REPLY_ID}"
  TELEGRAM_REPLY_ARG_FILE="-F reply_to_message_id=${TELEGRAM_REPLY_ID}"
else
  TELEGRAM_REPLY_ARG_TEXT=""
  TELEGRAM_REPLY_ARG_FILE=""
fi

# Set standard text push for commits and tags
if [ "$PUSH" = "TRUE" ]; then
  apk add --no-cache coreutils tzdata
  COMMIT_TIME=$(TZ='Asia/Tehran' date -d "$CI_COMMIT_TIMESTAMP" '+%H:%M:%S %Y-%m-%d')

  if [ -n "$CI_COMMIT_TAG" ]; then
    TEXT=$(cat <<-EOF
👨‍💻 *Push by $GITLAB_USER_NAME*
🏷️ **New Tag**

📂 *Project:* \`$CI_PROJECT_PATH\`
🌿 *Branch:* \`$CI_COMMIT_BRANCH\`
🔖 *Tag:* \`$CI_COMMIT_TAG\`
⏰ *Time:* \`$COMMIT_TIME\`

💬 *Commit Message:*
\`$CI_COMMIT_MESSAGE\`

🔍 *Details:*
  🔗 *Commit:* [$CI_COMMIT_SHORT_SHA]($CI_PROJECT_URL/-/commit/$CI_COMMIT_SHA)
  ⚙️ *Pipeline:* [#$CI_PIPELINE_ID]($CI_PIPELINE_URL)
  🏷️ *Tag Page:* [$CI_COMMIT_TAG]($CI_PROJECT_URL/-/tags/$CI_COMMIT_TAG)
EOF
)
  else
    TEXT=$(cat <<-EOF
👨‍💻 *Push by $GITLAB_USER_NAME*

📂 *Project:* \`$CI_PROJECT_PATH\`
🌿 *Branch:* \`$CI_COMMIT_BRANCH\`
⏰ *Time:* \`$COMMIT_TIME\`

💬 *Commit Message:*
\`$CI_COMMIT_MESSAGE\`

🔍 *Details:*
  🔗 *Commit:* [$CI_COMMIT_SHORT_SHA]($CI_PROJECT_URL/-/commit/$CI_COMMIT_SHA)
  ⚙️ *Pipeline:* [#$CI_PIPELINE_ID]($CI_PIPELINE_URL)
EOF
)
  fi
fi

# Handle message sending based on notification target
if [ "$NOTIFICATION_TARGET" = "telegram" ]; then
  # ============================================
  # TELEGRAM MESSAGE SENDING
  # ============================================
  
  # Handle file sending
  if [ -n "$FILE" ]; then
    if [ ! -f "$FILE" ]; then
      echo "File not found: $FILE"
      exit 1
    fi
    
    # Send document
    response=$(curl -s -w "%{http_code}" -o /tmp/telegram_response.txt \
      "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendDocument" \
      -F chat_id="${TELEGRAM_CHAT_ID}" \
      $TELEGRAM_THREAD_ARG_FILE \
      $TELEGRAM_REPLY_ARG_FILE \
      -F document=@"${FILE}" \
      -F caption="${TEXT}")

  elif [ -n "$FOLDER" ]; then
    if [ ! -d "$FOLDER" ]; then
      echo "Directory not found: $FOLDER"
      exit 1
    fi

    # Install zip utility
    apk add --no-cache zip

    # Create a temporary zip file
    ZIP_FILE="/tmp/$(basename "$FOLDER").zip"
    echo "Zipping folder: $FOLDER to $ZIP_FILE"
    zip -r "$ZIP_FILE" "$FOLDER"

    # Send the zipped folder
    response=$(curl -s -w "%{http_code}" -o /tmp/telegram_response.txt \
      "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendDocument" \
      -F chat_id="${TELEGRAM_CHAT_ID}" \
      $TELEGRAM_THREAD_ARG_FILE \
      $TELEGRAM_REPLY_ARG_FILE \
      -F document=@"${ZIP_FILE}" \
      -F caption="${TEXT}")
    
  else
    # Send text message
    response=$(curl -s -w "%{http_code}" -o /tmp/telegram_response.txt \
      "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
      -d chat_id="${TELEGRAM_CHAT_ID}" \
      $TELEGRAM_THREAD_ARG_TEXT \
      $TELEGRAM_REPLY_ARG_TEXT \
      -d text="${TEXT}" \
      -d parse_mode="Markdown")
  fi

  # Check Telegram response
  http_code=$(echo "$response" | cut -c1-3)

  if [ "$http_code" -ge 200 ] && [ "$http_code" -lt 300 ]; then
    echo "Telegram message sent successfully!"
  else
    echo "Failed to send Telegram message. HTTP code: $http_code"
    echo "Response:"
    cat /tmp/telegram_response.txt
    exit 1
  fi

elif [ "$NOTIFICATION_TARGET" = "mattermost" ]; then
  # ============================================
  # MATTERMOST MESSAGE SENDING
  # ============================================
  
  # Get team and channel IDs
  echo "Fetching Mattermost team and channel information..."
  
  # Get team ID
  team_response=$(curl -s -X GET \
    "${MATTERMOST_URL}/api/v4/teams/name/${MATTERMOST_TEAM_NAME}" \
    -H "Authorization: Bearer ${MATTERMOST_TOKEN}")
  
  MATTERMOST_TEAM_ID=$(echo "$team_response" | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)
  
  if [ -z "$MATTERMOST_TEAM_ID" ]; then
    echo "Error: Could not retrieve team ID for team: $MATTERMOST_TEAM_NAME"
    echo "Response: $team_response"
    exit 1
  fi
  
  # Get channel ID
  channel_response=$(curl -s -X GET \
    "${MATTERMOST_URL}/api/v4/teams/${MATTERMOST_TEAM_ID}/channels/name/${MATTERMOST_CHANNEL_NAME}" \
    -H "Authorization: Bearer ${MATTERMOST_TOKEN}")
  
  MATTERMOST_CHANNEL_ID=$(echo "$channel_response" | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)
  
  if [ -z "$MATTERMOST_CHANNEL_ID" ]; then
    echo "Error: Could not retrieve channel ID for channel: $MATTERMOST_CHANNEL_NAME"
    echo "Response: $channel_response"
    exit 1
  fi
  
  echo "Team ID: $MATTERMOST_TEAM_ID"
  echo "Channel ID: $MATTERMOST_CHANNEL_ID"
  
  # Handle file sending
  if [ -n "$FILE" ]; then
    if [ ! -f "$FILE" ]; then
      echo "File not found: $FILE"
      exit 1
    fi
    
    # Upload file to Mattermost
    echo "Uploading file to Mattermost..."
    upload_response=$(curl -s -X POST \
      "${MATTERMOST_URL}/api/v4/files" \
      -H "Authorization: Bearer ${MATTERMOST_TOKEN}" \
      -F "files=@${FILE}" \
      -F "channel_id=${MATTERMOST_CHANNEL_ID}")
    
    # Extract file_id from response
    file_id=$(echo "$upload_response" | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)
    
    if [ -z "$file_id" ]; then
      echo "Error: Failed to upload file to Mattermost"
      echo "Response: $upload_response"
      exit 1
    fi
    
    echo "File uploaded successfully. File ID: $file_id"
    
    # Send message with file attached
    if [ -n "$TEXT" ]; then
      message_payload="{\"channel_id\":\"${MATTERMOST_CHANNEL_ID}\",\"message\":\"${TEXT}\",\"file_ids\":[\"${file_id}\"]}"
    else
      message_payload="{\"channel_id\":\"${MATTERMOST_CHANNEL_ID}\",\"message\":\"\",\"file_ids\":[\"${file_id}\"]}"
    fi
    
    response=$(curl -s -w "\n%{http_code}" -X POST \
      "${MATTERMOST_URL}/api/v4/posts" \
      -H "Authorization: Bearer ${MATTERMOST_TOKEN}" \
      -H "Content-Type: application/json" \
      -d "$message_payload")

  elif [ -n "$FOLDER" ]; then
    if [ ! -d "$FOLDER" ]; then
      echo "Directory not found: $FOLDER"
      exit 1
    fi

    # Install zip utility
    apk add --no-cache zip

    # Create a temporary zip file
    ZIP_FILE="/tmp/$(basename "$FOLDER").zip"
    echo "Zipping folder: $FOLDER to $ZIP_FILE"
    zip -r "$ZIP_FILE" "$FOLDER"
    
    # Upload zip file to Mattermost
    echo "Uploading zip file to Mattermost..."
    upload_response=$(curl -s -X POST \
      "${MATTERMOST_URL}/api/v4/files" \
      -H "Authorization: Bearer ${MATTERMOST_TOKEN}" \
      -F "files=@${ZIP_FILE}" \
      -F "channel_id=${MATTERMOST_CHANNEL_ID}")
    
    # Extract file_id from response
    file_id=$(echo "$upload_response" | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)
    
    if [ -z "$file_id" ]; then
      echo "Error: Failed to upload zip file to Mattermost"
      echo "Response: $upload_response"
      exit 1
    fi
    
    echo "Zip file uploaded successfully. File ID: $file_id"
    
    # Send message with zip file attached
    if [ -n "$TEXT" ]; then
      message_payload="{\"channel_id\":\"${MATTERMOST_CHANNEL_ID}\",\"message\":\"${TEXT}\",\"file_ids\":[\"${file_id}\"]}"
    else
      message_payload="{\"channel_id\":\"${MATTERMOST_CHANNEL_ID}\",\"message\":\"\",\"file_ids\":[\"${file_id}\"]}"
    fi
    
    response=$(curl -s -w "\n%{http_code}" -X POST \
      "${MATTERMOST_URL}/api/v4/posts" \
      -H "Authorization: Bearer ${MATTERMOST_TOKEN}" \
      -H "Content-Type: application/json" \
      -d "$message_payload")
    
  else
    # Send text message only
    message_payload="{\"channel_id\":\"${MATTERMOST_CHANNEL_ID}\",\"message\":\"${TEXT}\"}"
    
    response=$(curl -s -w "\n%{http_code}" -X POST \
      "${MATTERMOST_URL}/api/v4/posts" \
      -H "Authorization: Bearer ${MATTERMOST_TOKEN}" \
      -H "Content-Type: application/json" \
      -d "$message_payload")
  fi

  # Check Mattermost response
  http_code=$(echo "$response" | tail -n1)
  response_body=$(echo "$response" | sed '$d')

  if [ "$http_code" -ge 200 ] && [ "$http_code" -lt 300 ]; then
    echo "Mattermost message sent successfully!"
  else
    echo "Failed to send Mattermost message. HTTP code: $http_code"
    echo "Response: $response_body"
    exit 1
  fi

fi
