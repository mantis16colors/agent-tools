#!/bin/bash
# soul-hash.sh - Identity hash tracking
# Computes a hash of core identity files to detect changes

WORKSPACE="${HOME}/.openclaw/workspace"
HASH_FILE="${WORKSPACE}/.soul-hash"

# Core identity files (order matters for consistency)
IDENTITY_FILES=(
    "SOUL.md"
    "IDENTITY.md"
    "USER.md"
    "AGENTS.md"
)

compute_hash() {
    local combined=""
    for file in "${IDENTITY_FILES[@]}"; do
        if [ -f "${WORKSPACE}/${file}" ]; then
            combined+=$(cat "${WORKSPACE}/${file}")
        fi
    done
    echo -n "$combined" | sha256sum | cut -d' ' -f1
}

current_hash=$(compute_hash)

case "$1" in
    check)
        if [ -f "$HASH_FILE" ]; then
            stored_hash=$(cat "$HASH_FILE")
            if [ "$current_hash" = "$stored_hash" ]; then
                echo "✓ Identity unchanged"
                exit 0
            else
                echo "⚠ Identity changed since last check"
                echo "  Previous: ${stored_hash:0:16}..."
                echo "  Current:  ${current_hash:0:16}..."
                exit 1
            fi
        else
            echo "No previous hash found"
            exit 2
        fi
        ;;
    update)
        echo "$current_hash" > "$HASH_FILE"
        echo "✓ Hash updated: ${current_hash:0:16}..."
        ;;
    show)
        echo "Current hash: ${current_hash:0:16}..."
        if [ -f "$HASH_FILE" ]; then
            echo "Stored hash:  $(cat "$HASH_FILE" | cut -c1-16)..."
        fi
        ;;
    *)
        echo "Usage: soul-hash.sh [check|update|show]"
        echo "  check  - Compare current identity to stored hash"
        echo "  update - Store current identity hash"
        echo "  show   - Display hashes"
        exit 1
        ;;
esac
