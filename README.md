# Outline VPN Key Management Script

A simple and automated script for managing Outline VPN access keys, featuring an interactive menu and daily expiry checks for seamless key management on your Linux server.

## Installation

To install and run the Outline VPN Key Management script, execute the following command as root:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/deathline94/Outline-Key-Management/main/manager.sh)
```

This will:
* Save the script to `/opt/outline/manager.sh`.
* Set up a daily cron job for automatic key expiry checks at `/etc/cron.d/outline-key-expiry`.
* Launch an interactive menu for key management.
* Install required dependencies (`jq`, `docker.io`) if not already present.

## Features

* **List Keys**: Displays all access keys from `shadowbox_config.json` with their `first_used` timestamp and days since first use.
* **Set First Used**: Assigns a `first_used` timestamp to a key to start its 30-day expiry countdown.
* **Extend Key**: Resets a key’s `first_used` timestamp to extend its validity for another 30 days.
* **Delete Expired Keys**: Removes keys older than 30 days from `shadowbox_config.json` and `key_tracking.json`, restarting the `shadowbox` container.
* **Automated Expiry Checks**: Daily cron job removes expired keys automatically.
* **Logging**: Tracks all actions in `/var/log/outline_key_expiration.log`.
* **Minimal Dependencies**: Uses only `jq` and `docker.io`, with no unnecessary bloat.

## Usage

1. **Run the Script**:
   ```bash
   bash <(curl -fsSL https://raw.githubusercontent.com/deathline94/Outline-Key-Management/main/manager.sh)
   ```

2. **Main Menu**:
   * **List Keys**: View all keys and their status (timestamp and days since first use).
   * **Set First Used**: Set a key’s initial timestamp to begin tracking.
   * **Extend Key**: Renew a key for another 30 days.
   * **Delete Expired Keys**: Manually remove keys older than 30 days.
   * **Exit**: Close the script.

3. **Auto Mode** (for cron):
   ```bash
   sudo /opt/outline/manager.sh auto
   ```
   Checks and deletes expired keys without user interaction.

4. **Logs**:
   * Check `/var/log/outline_key_expiration.log` for detailed action logs.

5. **Verify Cron Job**:
   ```bash
   cat /etc/cron.d/outline-key-expiry
   ```
   Ensures the daily expiry check is scheduled.

6. **Notes**:
   * Ensure the Outline VPN container is named `shadowbox` or update `CONTAINER_NAME` in the script.
   * Verify file paths:
     * Configuration: `/opt/outline/persisted-state/shadowbox_config.json`
     * Tracking: `/opt/outline/key_tracking.json`
     * Log: `/var/log/outline_key_expiration.log`
   * Install dependencies if needed:
     ```bash
     sudo apt-get update
     sudo apt-get install -y jq docker.io
     ```

## Credits

* **Outline VPN**: This script is designed for use with the **[Outline VPN](https://getoutline.org/)** project. Thanks to the Outline team for their awesome work!
* **Developed by**: **[@deathline94](https://github.com/deathline94)**

---

Enjoy seamless Outline VPN key management with this script! If you find it useful, please give it a **⭐** on GitHub.