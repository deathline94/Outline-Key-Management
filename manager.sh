#!/bin/bash

# File paths and container name
CONFIG_FILE="/opt/outline/persisted-state/shadowbox_config.json"
TRACKING_FILE="/opt/outline/key_tracking.json"
LOG_FILE="/var/log/outline_key_expiration.log"
CONTAINER_NAME="shadowbox"
CRON_FILE="/etc/cron.d/outline-key-expiry"
SCRIPT_PATH="/opt/outline/manager.sh"

# Logging function
log() { echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"; }

# Check and install dependencies
for pkg in jq docker; do
    if ! command -v $pkg >/dev/null; then
        echo "Installing $pkg requires sudo..."
        sudo apt-get update
        sudo apt-get install -y $pkg.io 2>> "$LOG_FILE"
        if [ $? -ne 0 ]; then
            log "Failed to install $pkg"
            echo "Error: Failed to install $pkg. Check $LOG_FILE."
            exit 1
        fi
        log "Installed dependency: $pkg"
    fi
done

# Function to print characters with delay
print_with_delay() {
    text="$1"
    delay="$2"
    for ((i = 0; i < ${#text}; i++)); do
        echo -n "${text:$i:1}"
        sleep $delay
    done
    echo
}

# Ensure tracking file exists
[ ! -f "$TRACKING_FILE" ] && sudo bash -c "echo '{\"keys\":{}}' > \"$TRACKING_FILE\""

# Set up cron job for daily expiry check
setup_cron() {
    if [ ! -f "$CRON_FILE" ]; then
        sudo bash -c "echo '0 0 * * * root /bin/bash $SCRIPT_PATH auto' > \"$CRON_FILE\""
        sudo chmod 644 "$CRON_FILE"
        log "Cron job set up for daily key expiry check"
        echo "Cron job set up for daily key expiry check at midnight"
    else
        echo "Cron job already exists"
        log "Cron job already exists"
    fi
}

# Set first_used for a key
set_first_used() {
    echo ""
    echo "Available keys:"
    KEYS=$(jq -r '.accessKeys[] | select(.name != "") | .name + "|" + (.id | tostring)' "$CONFIG_FILE")
    if [ -z "$KEYS" ]; then
        echo "No keys found."
        return
    fi
    i=1
    while IFS='|' read -r KEY_NAME KEY_ID; do
        if [ -n "$KEY_NAME" ]; then
            FIRST_USED=$(jq -r ".keys.\"$KEY_ID\".first_used // \"null\"" "$TRACKING_FILE")
            if [ "$FIRST_USED" = "null" ]; then
                echo "$i) $KEY_NAME"
            else
                FIRST_USED_TIMESTAMP=$(date -d "$FIRST_USED" +%s)
                CURRENT_TIMESTAMP=$(date +%s)
                DAYS_SINCE=$(( (CURRENT_TIMESTAMP - FIRST_USED_TIMESTAMP) / 86400 ))
                echo "$i) $KEY_NAME (First used: $FIRST_USED, $DAYS_SINCE days ago)"
            fi
            ((i++))
        fi
    done <<< "$KEYS"
    echo ""
    read -p "Enter key number to set first used (or 0 to cancel): " key_num
    if [[ ! "$key_num" =~ ^[0-9]+$ ]] || [ "$key_num" -eq 0 ]; then
        return
    fi
    
    SELECTED_KEY_LINE=$(echo "$KEYS" | sed -n "${key_num}p")
    KEY_NAME=$(echo "$SELECTED_KEY_LINE" | cut -d'|' -f1)
    KEY_ID=$(echo "$SELECTED_KEY_LINE" | cut -d'|' -f2)

    if [ -z "$KEY_NAME" ] || [ -z "$KEY_ID" ]; then
        echo "Invalid key number."
        log "Error: Invalid key number $key_num"
        return
    fi
    FIRST_USED=$(jq -r ".keys.\"$KEY_ID\".first_used // \"null\"" "$TRACKING_FILE")
    if [ "$FIRST_USED" = "null" ]; then
        CURRENT_TIME=$(date '+%Y-%m-%d %H:%M:%S')
        sudo bash -c "jq \".keys.\\\"$KEY_ID\\\" = {\\\"first_used\\\": \\\"$CURRENT_TIME\\\"}\" \"$TRACKING_FILE\" > tmp.json && mv tmp.json \"$TRACKING_FILE\""
        echo "Key: $KEY_NAME set to first used at $CURRENT_TIME"
        log "Key: $KEY_NAME set to first used at $CURRENT_TIME"
    else
        echo "Key: $KEY_NAME already has first_used: $FIRST_USED"
        log "Key: $KEY_NAME already has first_used: $FIRST_USED"
    fi
}

# Extend first_used for a key (renew for another 30 days)
extend_key() {
    echo ""
    echo "Available keys:"
    KEYS=$(jq -r '.accessKeys[] | select(.name != "") | .name + "|" + (.id | tostring)' "$CONFIG_FILE")
    if [ -z "$KEYS" ]; then
        echo "No keys found."
        return
    fi
    i=1
    while IFS='|' read -r KEY_NAME KEY_ID; do
        if [ -n "$KEY_NAME" ]; then
            FIRST_USED=$(jq -r ".keys.\"$KEY_ID\".first_used // \"null\"" "$TRACKING_FILE")
            if [ "$FIRST_USED" = "null" ]; then
                echo "$i) $KEY_NAME"
            else
                FIRST_USED_TIMESTAMP=$(date -d "$FIRST_USED" +%s)
                CURRENT_TIMESTAMP=$(date +%s)
                DAYS_SINCE=$(( (CURRENT_TIMESTAMP - FIRST_USED_TIMESTAMP) / 86400 ))
                echo "$i) $KEY_NAME (First used: $FIRST_USED, $DAYS_SINCE days ago)"
            fi
            ((i++))
        fi
    done <<< "$KEYS"
    echo ""
    read -p "Enter key number to extend (or 0 to cancel): " key_num
    if [[ ! "$key_num" =~ ^[0-9]+$ ]] || [ "$key_num" -eq 0 ]; then
        return
    fi

    SELECTED_KEY_LINE=$(echo "$KEYS" | sed -n "${key_num}p")
    KEY_NAME=$(echo "$SELECTED_KEY_LINE" | cut -d'|' -f1)
    KEY_ID=$(echo "$SELECTED_KEY_LINE" | cut -d'|' -f2)

    if [ -z "$KEY_NAME" ] || [ -z "$KEY_ID" ]; then
        echo "Invalid key number."
        log "Error: Invalid key number $key_num"
        return
    fi
    FIRST_USED=$(jq -r ".keys.\"$KEY_ID\".first_used // \"null\"" "$TRACKING_FILE")
    if [ "$FIRST_USED" = "null" ]; then
        echo "Key: $KEY_NAME has no first_used date set. Please set it first."
        log "Error: Attempted to extend key: $KEY_NAME with no first_used date"
        return
    fi
    CURRENT_TIME=$(date '+%Y-%m-%d %H:%M:%S')
    sudo bash -c "jq \".keys.\\\"$KEY_ID\\\" = {\\\"first_used\\\": \\\"$CURRENT_TIME\\\"}\" \"$TRACKING_FILE\" > tmp.json && mv tmp.json \"$TRACKING_FILE\""
    echo "Key: $KEY_NAME extended with new first used date: $CURRENT_TIME"
    log "Key: $KEY_NAME extended with new first used date: $CURRENT_TIME"
}

# Delete expired keys
delete_expired_keys() {
    log "Checking expired keys"
    CURRENT_TIMESTAMP=$(date +%s)
    KEYS=$(jq -r '.keys | keys[]' "$TRACKING_FILE")
    if [ -z "$KEYS" ]; then
        echo "No keys found in tracking file."
        log "No keys found in tracking file"
        return
    fi
    for KEY_ID in $KEYS; do
        FIRST_USED=$(jq -r ".keys.\"$KEY_ID\".first_used // \"null\"" "$TRACKING_FILE")
        if [ "$FIRST_USED" != "null" ]; then
            FIRST_USED_TIMESTAMP=$(date -d "$FIRST_USED" +%s)
            DAYS_SINCE=$(( (CURRENT_TIMESTAMP - FIRST_USED_TIMESTAMP) / 86400 ))
            if [ $DAYS_SINCE -ge 30 ]; then
                KEY_NAME=$(jq -r ".accessKeys[] | select(.id == \"$KEY_ID\") | .name" "$CONFIG_FILE")
                sudo bash -c "jq \"del(.accessKeys[] | select(.id == \\\"$KEY_ID\\\"))\" \"$CONFIG_FILE\" > tmp.json && mv tmp.json \"$CONFIG_FILE\""
                sudo bash -c "jq \"del(.keys.\\\"$KEY_ID\\\")\" \"$TRACKING_FILE\" > tmp.json && mv tmp.json \"$TRACKING_FILE\""
                sudo docker restart "$CONTAINER_NAME" >/dev/null 2>&1
                echo "Key: $KEY_NAME deleted after $DAYS_SINCE days"
                log "Key: $KEY_NAME deleted after $DAYS_SINCE days"
            fi
        fi
    done
    echo "Expired key check complete."
}

# List all keys with their status
list_keys() {
    echo ""
    echo "Access Keys:"
    echo ""
    KEYS=$(jq -r '.accessKeys[] | select(.name != "") | .name + "|" + .id' "$CONFIG_FILE")
    if [ -z "$KEYS" ]; then
        echo "No keys found."
        return
    fi
    i=1
    while IFS='|' read -r KEY_NAME KEY_ID; do
        if [ -n "$KEY_NAME" ]; then
            FIRST_USED=$(jq -r ".keys.\"$KEY_ID\".first_used // \"null\"" "$TRACKING_FILE")
            if [ "$FIRST_USED" = "null" ]; then
                echo "$i) $KEY_NAME"
            else
                FIRST_USED_TIMESTAMP=$(date -d "$FIRST_USED" +%s)
                CURRENT_TIMESTAMP=$(date +%s)
                DAYS_SINCE=$(( (CURRENT_TIMESTAMP - FIRST_USED_TIMESTAMP) / 86400 ))
                echo "$i) $KEY_NAME (First used: $FIRST_USED, $DAYS_SINCE days ago)"
            fi
            ((i++))
        fi
    done <<< "$KEYS"
    echo ""
}

# Save script locally if run remotely
if [ ! -f "$SCRIPT_PATH" ]; then
    mkdir -p /opt/outline
    if ! curl -fsSL https://raw.githubusercontent.com/deathline94/Outline-Key-Management/main/manager.sh | sudo tee "$SCRIPT_PATH" >/dev/null 2>> "$LOG_FILE"; then
        log "Failed to download and save script to $SCRIPT_PATH"
        echo "Error: Failed to download and save script to $SCRIPT_PATH. Check $LOG_FILE."
        exit 1
    fi
    if ! sudo chmod +x "$SCRIPT_PATH" 2>> "$LOG_FILE"; then
        log "Failed to set executable permissions on $SCRIPT_PATH"
        echo "Error: Failed to set permissions on $SCRIPT_PATH. Check $LOG_FILE."
        exit 1
    fi
    if [ ! -f "$SCRIPT_PATH" ]; then
        log "Script not found at $SCRIPT_PATH after save attempt"
        echo "Error: Script not saved to $SCRIPT_PATH. Check $LOG_FILE."
        exit 1
    fi
    log "Script saved locally to $SCRIPT_PATH"
fi

# Check for auto mode (for cron)
if [ "$1" = "auto" ]; then
    delete_expired_keys
    exit 0
fi

# Introduction animation for interactive mode
echo ""
echo ""
print_with_delay "Outline VPN Key Manager by DEATHLINE | @NamelesGhoul" 0.1
echo ""
echo ""

# Set up cron job on first interactive run
setup_cron

# Main menu
while true; do
    echo "Outline VPN Key Management Menu:"
    echo ""
    echo "1) List Keys"
    echo ""
    echo "2) Set First Used for Key"
    echo ""
    echo "3) Extend Key (Renew for 30 Days)"
    echo ""
    echo "4) Delete Expired Keys"
    echo ""
    echo "5) Exit"
    echo ""
    read -p "Enter your choice: " choice
    case $choice in
        1)
            list_keys
            ;;
        2)
            set_first_used
            ;;
        3)
            extend_key
            ;;
        4)
            delete_expired_keys
            ;;
        5)
            echo "Exiting..."
            exit 0
            ;;
        *)
            echo "Invalid choice."
            ;;
    esac
done
