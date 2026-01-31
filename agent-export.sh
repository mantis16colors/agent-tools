#!/bin/bash
# agent-export.sh - Full state export for migration
# Creates a tarball of everything needed to recreate an agent

EXPORT_DIR="${1:-/tmp}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
AGENT_NAME="${AGENT_NAME:-agent}"
EXPORT_NAME="${AGENT_NAME}_export_${TIMESTAMP}"
EXPORT_PATH="${EXPORT_DIR}/${EXPORT_NAME}.tar.gz"

echo "🤖 Agent State Export"
echo "====================="

# Create temp directory for export
TEMP_DIR=$(mktemp -d)
mkdir -p "${TEMP_DIR}/${EXPORT_NAME}"

echo "Gathering files..."

# Workspace files
cp -r ~/.openclaw/workspace/* "${TEMP_DIR}/${EXPORT_NAME}/" 2>/dev/null

# SSH keys (public only for safety)
mkdir -p "${TEMP_DIR}/${EXPORT_NAME}/.ssh"
cp ~/.ssh/*.pub "${TEMP_DIR}/${EXPORT_NAME}/.ssh/" 2>/dev/null
cp ~/.ssh/config "${TEMP_DIR}/${EXPORT_NAME}/.ssh/" 2>/dev/null

# Git config
cp ~/.gitconfig "${TEMP_DIR}/${EXPORT_NAME}/" 2>/dev/null

# Tools (excluding .env files with secrets)
mkdir -p "${TEMP_DIR}/${EXPORT_NAME}/tools"
find ~/tools -maxdepth 1 -type f ! -name "*.env" ! -name ".env*" -exec cp {} "${TEMP_DIR}/${EXPORT_NAME}/tools/" \; 2>/dev/null

# Create manifest
cat > "${TEMP_DIR}/${EXPORT_NAME}/MANIFEST.md" << EOF
# Agent Export
**Exported:** $(date -Iseconds)
**Host:** $(hostname)

## Contents
- Workspace files (SOUL.md, USER.md, MEMORY.md, etc.)
- Memory directory
- Tools directory (secrets excluded)
- SSH public keys and config
- Git configuration

## To Restore
1. Extract to new workspace
2. Recreate SSH private keys
3. Set up environment variables for tools
4. Update any platform-specific paths
EOF

# Create tarball
cd "${TEMP_DIR}"
tar -czf "${EXPORT_PATH}" "${EXPORT_NAME}"
rm -rf "${TEMP_DIR}"

echo "✓ Export created: ${EXPORT_PATH}"
echo "  Size: $(du -h "${EXPORT_PATH}" | cut -f1)"
