#!/bin/bash
# agent-backup.sh - Periodic backup with cleanup
# Keeps last N backups, removes older ones

BACKUP_DIR="${HOME}/.openclaw/backups"
WORKSPACE="${HOME}/.openclaw/workspace"
MAX_BACKUPS=7
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
AGENT_NAME="${AGENT_NAME:-agent}"
BACKUP_NAME="${AGENT_NAME}_backup_${TIMESTAMP}.tar.gz"

mkdir -p "${BACKUP_DIR}"

echo "🤖 Agent Backup"
echo "==============="

# Create backup
tar -czf "${BACKUP_DIR}/${BACKUP_NAME}" \
    -C "${WORKSPACE}" . \
    -C "${HOME}" tools 2>/dev/null

echo "✓ Created: ${BACKUP_NAME}"

# Cleanup old backups
BACKUP_COUNT=$(ls -1 "${BACKUP_DIR}"/${AGENT_NAME}_backup_*.tar.gz 2>/dev/null | wc -l)
if [ "$BACKUP_COUNT" -gt "$MAX_BACKUPS" ]; then
    REMOVE_COUNT=$((BACKUP_COUNT - MAX_BACKUPS))
    echo "Cleaning up ${REMOVE_COUNT} old backup(s)..."
    ls -1t "${BACKUP_DIR}"/${AGENT_NAME}_backup_*.tar.gz | tail -n "${REMOVE_COUNT}" | xargs rm -f
fi

echo "✓ Backups retained: $(ls -1 "${BACKUP_DIR}"/${AGENT_NAME}_backup_*.tar.gz 2>/dev/null | wc -l)/${MAX_BACKUPS}"
echo "  Location: ${BACKUP_DIR}"
