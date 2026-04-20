#!/bin/sh
TO="$1"
SUBJECT="$2"
MESSAGE="$3"

# BOT_TOKEN берётся из env контейнера
: "${BOT_TOKEN:?BOT_TOKEN is not set}"

TEXT="${SUBJECT}
${MESSAGE}"

curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
  -d "chat_id=${TO}" \
  --data-urlencode "text=${TEXT}" \
  -d "parse_mode=HTML" > /dev/null 2>&1
