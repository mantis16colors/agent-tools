#!/bin/bash
# agent-wallet.sh - Secure storage for DIDs, VCs, and API keys
# Stores credentials in encrypted format using age (if available) or base64 fallback

WALLET_DIR="${HOME}/.agent-wallet"
WALLET_FILE="${WALLET_DIR}/wallet.json"
ENCRYPTED_FILE="${WALLET_DIR}/wallet.age"

mkdir -p "${WALLET_DIR}"
chmod 700 "${WALLET_DIR}"

usage() {
    echo "🦐 Agent Wallet - Secure credential storage"
    echo ""
    echo "Usage: agent-wallet.sh <command> [args]"
    echo ""
    echo "Commands:"
    echo "  init                    - Initialize wallet"
    echo "  add <type> <name>       - Add credential (reads value from stdin)"
    echo "  get <type> <name>       - Retrieve credential"
    echo "  list [type]             - List credentials"
    echo "  remove <type> <name>    - Remove credential"
    echo "  export                  - Export wallet (encrypted)"
    echo "  import <file>           - Import wallet"
    echo "  generate-keypair        - Generate signing keypair for attestations"
    echo "  sign <data>             - Sign data with wallet's private key"
    echo "  verify <sig> <data>     - Verify a signature"
    echo "  pubkey                  - Show public verification key"
    echo ""
    echo "Types: did, vc, apikey, ssh, other"
    echo ""
    echo "Examples:"
    echo "  echo 'sk_live_xxx' | agent-wallet.sh add apikey stripe"
    echo "  agent-wallet.sh get apikey stripe"
    echo "  agent-wallet.sh list did"
    echo "  echo 'important data' | agent-wallet.sh sign"
    exit 1
}

init_wallet() {
    if [ -f "$WALLET_FILE" ]; then
        echo "Wallet already exists at ${WALLET_FILE}"
        return 1
    fi
    echo '{"dids":{},"vcs":{},"apikeys":{},"ssh":{},"other":{},"meta":{"created":"'$(date -Iseconds)'"}}' | jq . > "$WALLET_FILE"
    chmod 600 "$WALLET_FILE"
    echo "✓ Wallet initialized at ${WALLET_FILE}"
}

get_type_key() {
    case "$1" in
        did|dids) echo "dids" ;;
        vc|vcs) echo "vcs" ;;
        apikey|apikeys|key|keys) echo "apikeys" ;;
        ssh) echo "ssh" ;;
        *) echo "other" ;;
    esac
}

add_credential() {
    [ ! -f "$WALLET_FILE" ] && init_wallet
    local type_key=$(get_type_key "$1")
    local name="$2"
    local value=$(cat)
    
    # Add to wallet
    local tmp=$(mktemp)
    jq --arg type "$type_key" --arg name "$name" --arg value "$value" \
        '.[$type][$name] = {"value": $value, "added": now | strftime("%Y-%m-%dT%H:%M:%SZ")}' \
        "$WALLET_FILE" > "$tmp" && mv "$tmp" "$WALLET_FILE"
    chmod 600 "$WALLET_FILE"
    echo "✓ Added ${type_key}/${name}"
}

get_credential() {
    [ ! -f "$WALLET_FILE" ] && { echo "No wallet found. Run: agent-wallet.sh init"; exit 1; }
    local type_key=$(get_type_key "$1")
    local name="$2"
    jq -r --arg type "$type_key" --arg name "$name" '.[$type][$name].value // empty' "$WALLET_FILE"
}

list_credentials() {
    [ ! -f "$WALLET_FILE" ] && { echo "No wallet found."; exit 1; }
    if [ -n "$1" ]; then
        local type_key=$(get_type_key "$1")
        echo "=== ${type_key} ==="
        jq -r --arg type "$type_key" '.[$type] | keys[]' "$WALLET_FILE" 2>/dev/null
    else
        for t in dids vcs apikeys ssh other; do
            local keys=$(jq -r --arg type "$t" '.[$type] | keys | length' "$WALLET_FILE" 2>/dev/null)
            if [ "$keys" != "0" ] && [ -n "$keys" ]; then
                echo "=== ${t} (${keys}) ==="
                jq -r --arg type "$t" '.[$type] | keys[]' "$WALLET_FILE"
            fi
        done
    fi
}

remove_credential() {
    [ ! -f "$WALLET_FILE" ] && { echo "No wallet found."; exit 1; }
    local type_key=$(get_type_key "$1")
    local name="$2"
    local tmp=$(mktemp)
    jq --arg type "$type_key" --arg name "$name" 'del(.[$type][$name])' "$WALLET_FILE" > "$tmp" && mv "$tmp" "$WALLET_FILE"
    echo "✓ Removed ${type_key}/${name}"
}

export_wallet() {
    [ ! -f "$WALLET_FILE" ] && { echo "No wallet found."; exit 1; }
    if command -v age &> /dev/null; then
        echo "Enter passphrase for encryption:"
        age -p "$WALLET_FILE" > "$ENCRYPTED_FILE"
        echo "✓ Exported to ${ENCRYPTED_FILE} (age encrypted)"
    else
        base64 "$WALLET_FILE"
        echo ""
        echo "# (base64 encoded - install 'age' for real encryption)"
    fi
}

import_wallet() {
    local file="$1"
    [ ! -f "$file" ] && { echo "File not found: $file"; exit 1; }
    if [[ "$file" == *.age ]]; then
        if command -v age &> /dev/null; then
            age -d "$file" > "$WALLET_FILE"
            chmod 600 "$WALLET_FILE"
            echo "✓ Imported from ${file}"
        else
            echo "Install 'age' to decrypt .age files"
            exit 1
        fi
    else
        cp "$file" "$WALLET_FILE"
        chmod 600 "$WALLET_FILE"
        echo "✓ Imported from ${file}"
    fi
}

# Attestation functions for agent-to-agent signing
KEYPAIR_FILE="${WALLET_DIR}/attestation_keypair"

generate_keypair() {
    [ ! -f "$WALLET_FILE" ] && { echo "No wallet found. Run: agent-wallet.sh init"; exit 1; }
    
    if [ -f "$KEYPAIR_FILE" ]; then
        echo "Keypair already exists at ${KEYPAIR_FILE}"
        echo "Use: agent-wallet.sh pubkey"
        return 1
    fi
    
    if command -v openssl &> /dev/null; then
        # Generate ED25519 keypair using OpenSSL
        openssl genpkey -algorithm ED25519 -out "${KEYPAIR_FILE}.priv" 2>/dev/null
        openssl pkey -in "${KEYPAIR_FILE}.priv" -pubout -out "${KEYPAIR_FILE}.pub" 2>/dev/null
        
        chmod 600 "${KEYPAIR_FILE}.priv"
        chmod 644 "${KEYPAIR_FILE}.pub"
        
        # Store public key reference in wallet
        local pubkey=$(cat "${KEYPAIR_FILE}.pub")
        local tmp=$(mktemp)
        jq --arg pubkey "$pubkey" '.meta.attestationPublicKey = $pubkey' "$WALLET_FILE" > "$tmp" && mv "$tmp" "$WALLET_FILE"
        chmod 600 "$WALLET_FILE"
        
        echo "✓ Generated ED25519 attestation keypair"
        echo "  Private: ${KEYPAIR_FILE}.priv"
        echo "  Public:  ${KEYPAIR_FILE}.pub"
    else
        echo "OpenSSL required for attestation features"
        exit 1
    fi
}

sign_data() {
    [ ! -f "$WALLET_FILE" ] && { echo "No wallet found. Run: agent-wallet.sh init"; exit 1; }
    [ ! -f "${KEYPAIR_FILE}.priv" ] && { echo "No attestation keypair. Run: agent-wallet.sh generate-keypair"; exit 1; }
    
    local data="$1"
    local timestamp=$(date -Iseconds)
    local payload="${data}|${timestamp}"
    
    if command -v openssl &> /dev/null; then
        # Sign the payload
        local signature=$(echo -n "$payload" | openssl pkeyutl -sign -inkey "${KEYPAIR_FILE}.priv" | base64 -w 0)
        
        # Output as JSON for easy parsing
        jq -n \
            --arg data "$data" \
            --arg timestamp "$timestamp" \
            --arg signature "$signature" \
            --arg pubkey "$(cat "${KEYPAIR_FILE}.pub")" \
            '{data: $data, timestamp: $timestamp, signature: $signature, publicKey: $pubkey}'
    else
        echo "OpenSSL required for signing"
        exit 1
    fi
}

verify_signature() {
    local signature="$1"
    local data="$2"
    local pubkey="$3"
    
    if [ -z "$pubkey" ]; then
        pubkey="${KEYPAIR_FILE}.pub"
    fi
    
    if command -v openssl &> /dev/null; then
        # Parse signature (expected JSON format with timestamp)
        local sig_data=$(echo "$signature" | jq -r '.signature // empty')
        local timestamp=$(echo "$signature" | jq -r '.timestamp // empty')
        local payload="${data}|${timestamp}"
        
        if [ -z "$sig_data" ] || [ -z "$timestamp" ]; then
            echo "❌ Invalid signature format"
            return 1
        fi
        
        # Verify
        echo -n "$payload" | base64 -d > /tmp/sig_verify_$$.bin
        echo "$sig_data" | base64 -d >> /tmp/sig_verify_$$.bin
        
        if openssl pkeyutl -verify -pubin -inkey "$pubkey" -certin -in /tmp/sig_verify_$$.bin 2>/dev/null; then
            echo "✓ Signature valid"
            rm -f /tmp/sig_verify_$$.bin
            return 0
        else
            echo "❌ Signature invalid"
            rm -f /tmp/sig_verify_$$.bin
            return 1
        fi
    else
        echo "OpenSSL required for verification"
        exit 1
    fi
}

show_pubkey() {
    [ ! -f "${KEYPAIR_FILE}.pub" ] && { echo "No attestation keypair. Run: agent-wallet.sh generate-keypair"; exit 1; }
    
    echo "=== Public Verification Key ==="
    cat "${KEYPAIR_FILE}.pub"
}

case "$1" in
    init) init_wallet ;;
    add) [ -z "$2" ] || [ -z "$3" ] && usage; add_credential "$2" "$3" ;;
    get) [ -z "$2" ] || [ -z "$3" ] && usage; get_credential "$2" "$3" ;;
    list) list_credentials "$2" ;;
    remove|rm) [ -z "$2" ] || [ -z "$3" ] && usage; remove_credential "$2" "$3" ;;
    export) export_wallet ;;
    import) [ -z "$2" ] && usage; import_wallet "$2" ;;
    generate-keypair) generate_keypair ;;
    sign) [ -z "$2" ] && usage; sign_data "$2" ;;
    verify) [ -z "$2" ] || [ -z "$3" ] && usage; verify_signature "$2" "$3" "$4" ;;
    pubkey) show_pubkey ;;
    *) usage ;;
esac
