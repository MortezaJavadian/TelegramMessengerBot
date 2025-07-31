# Telegram Messenger Bot

A simple Docker-based Telegram bot for sending automated messages. Perfect for CI/CD notifications and any automated messaging needs.

## Features

- **Dockerized**: Lightweight Alpine-based container
- **CI/CD Ready**: Easy integration with GitLab CI/CD
- **Thread Support**: Send messages to specific threads
- **Secure**: Environment variable-based configuration

## Prerequisites

1. **Create a Telegram Bot**
   - Open Telegram and search for `@BotFather`
   - Send `/newbot` command
   - Follow the instructions to create your bot
   - Save the `BOT_TOKEN` provided by BotFather

2. **Get Chat ID**
   - Add your bot to the desired group chat
   - Make the bot an admin with the necessary access
   - Send a messege in group or a tapic that you want bot can send messege on that
   - `curl https://api.telegram.org/bot<YOUR_BOT_TOKEN>/getUpdates`
   - Find your `chat_id` in the json response
   - Also if you want, Find your `message_thread_id` in that json response

3. **Build Docker Image**
   ```bash
   sudo docker build -t telegram-messenger .
   ```

## Usage Methods

### Method 1: GitLab CI/CD Integration

1. **Set Environment Variables in GitLab**
   - Go to your GitLab project → Settings → CI/CD → Variables
   - Add the following variables:
     - `BOT_TOKEN`: Your Telegram bot token
     - `CHAT_ID`: Your chat/channel ID
     - `DEPLOY_ID`: If you want send a messege in a specific thread like me set that with every name of you want

2. **Add `.gitlab-ci.yml`** in you project
3. Now everyone push the project, send messege in your group

### Method 2: Manual Docker Execution

1. **Usage without Thread**
   ```bash
   docker run --rm \
     -e BOT_TOKEN="your_bot_token_here" \
     -e CHAT_ID="your_chat_id_here" \
     -e TEXT="Hello!" \
     telegram-messenger
   ```

2. **Usage with Thread**
   ```bash
   docker run --rm \
     -e BOT_TOKEN="your_bot_token_here" \
     -e CHAT_ID="your_chat_id_here" \
     -e THREAD_ID="your_message_thread_id" \
     -e TEXT="Hello!" \
     telegram-messenger
   ```
