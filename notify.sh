#!/bin/sh

if [ -z "$TEXT" ]; then
  echo "TEXT environment variable is not set"
  exit 1
fi

if [ -z "$BOT_TOKEN" ] || [ -z "$CHAT_ID" ]; then
  echo "BOT_TOKEN or CHAT_ID environment variable is not set"
  exit 1
fi

# argument for message_thread_id
if [ -n "$THREAD_ID" ]; then
  THREAD_ARG="-d message_thread_id=${THREAD_ID}"
else
  THREAD_ARG=""
fi

response=$(curl -s -w "%{http_code}" -o /tmp/telegram_response.txt \
  "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
  -d chat_id="${CHAT_ID}" \
  $THREAD_ARG \
  -d text="${TEXT}" \
  -d parse_mode="Markdown")

if [ "$response" -eq 200 ]; then
  echo "Message sent successfully!"
else
  echo "Failed to send message. HTTP code: $response"
  echo "Response:"
  cat /tmp/telegram_response.txt
  exit 1
fi
