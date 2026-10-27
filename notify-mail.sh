#!/bin/bash
# Usage: notify-mail.sh <subject> [body-file]   (body from stdin if no file)
# Sends a mail through the SMTP account Nextcloud uses (credentials in .env.mail).
set -euo pipefail
cd "$(dirname "$0")"
set -a; . ./.env.mail; set +a
subject=$1
body=$(cat "${2:-/dev/stdin}")
msg=$(mktemp); trap 'rm -f "$msg"' EXIT
{
  printf 'From: mdserv <%s>\r\nTo: %s\r\nSubject: %s\r\nDate: %s\r\nContent-Type: text/plain; charset=UTF-8\r\n\r\n' \
    "$SMTP_USER" "$MAIL_TO" "$subject" "$(date -R)"
  printf '%s\r\n' "$body"
} > "$msg"
curl -sS --fail --ssl-reqd -m 30 --url "$SMTP_URL" --user "$SMTP_USER:$SMTP_PASSWORD" \
  --mail-from "$SMTP_USER" --mail-rcpt "$MAIL_TO" -T "$msg"
