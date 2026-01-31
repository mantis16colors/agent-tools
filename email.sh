#!/bin/bash
# email.sh - AgentMail CLI
# Set AGENTMAIL_INBOX and AGENTMAIL_API_KEY environment variables

INBOX="${AGENTMAIL_INBOX:-}"
API_KEY="${AGENTMAIL_API_KEY:-}"
BASE_URL="https://api.agentmail.to/v0"

if [ -z "$INBOX" ] || [ -z "$API_KEY" ]; then
    echo "Error: Set AGENTMAIL_INBOX and AGENTMAIL_API_KEY environment variables"
    echo ""
    echo "Example:"
    echo "  export AGENTMAIL_INBOX=you@agentmail.to"
    echo "  export AGENTMAIL_API_KEY=am_xxx"
    exit 1
fi

usage() {
    echo "Usage: email.sh <command> [args]"
    echo "Commands:"
    echo "  list [limit]           - List messages (default: 10)"
    echo "  read <message_id>      - Read a specific message"
    echo "  send <to> <subject>    - Send email (reads body from stdin)"
    echo "  unread                 - List unread messages"
    exit 1
}

auth_header() {
    echo "Authorization: Bearer $API_KEY"
}

case "$1" in
    list)
        limit="${2:-10}"
        curl -s -H "$(auth_header)" \
            "$BASE_URL/inboxes/$INBOX/messages?limit=$limit" | jq -r '.messages[] | "\(.timestamp) | \(.from) | \(.subject)"'
        ;;
    unread)
        curl -s -H "$(auth_header)" \
            "$BASE_URL/inboxes/$INBOX/messages" | jq -r '.messages[] | select(.labels | contains(["unread"])) | "\(.timestamp) | \(.from) | \(.subject)"'
        ;;
    read)
        [ -z "$2" ] && usage
        curl -s -H "$(auth_header)" \
            "$BASE_URL/inboxes/$INBOX/messages/$2" | jq .
        ;;
    send)
        [ -z "$2" ] || [ -z "$3" ] && usage
        to="$2"
        subject="$3"
        body=$(cat)
        curl -s -X POST \
            -H "$(auth_header)" \
            -H "Content-Type: application/json" \
            -d "{\"to\": \"$to\", \"subject\": \"$subject\", \"text\": \"$body\"}" \
            "$BASE_URL/inboxes/$INBOX/messages/send" | jq .
        ;;
    *)
        usage
        ;;
esac
