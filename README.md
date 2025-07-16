# OVERKILL - Raspberry Pi 5 Media Center Setup

This repository contains the `overkill-install.sh` script, a tool designed for setting up a maximum-performance media center on a **Raspberry Pi 5 running Armbian with NVMe storage**.

## ⚠️ Disclaimer ⚠️

This script is designed for advanced users. It is highly aggressive and performs actions that can carry risk.

-   **Data Loss:** The script modifies system files. **BACKUP YOUR DATA** before running.
-   **Overclocking:** The script applies extreme overclock settings that require an **active cooler**. Insufficient cooling can cause instability or permanent hardware damage.
-   **No Warranty:** You use this script entirely at your own risk. The author is not responsible for any damage or data loss.

By running this script, you acknowledge these risks and agree to take full responsibility for the outcome.

---

## Quick Install

To run the default installation, execute the following command in your terminal. This will download the script and run it with root privileges.

```bash
curl -sSL https://raw.githubusercontent.com/flashingcursor/overkill-pi-setup/main/overkill-install.sh | sudo bash
```
---

## Installation with Options

You can include optional addon packages by adding flags to the command.

### Install Umbrella Addon Repository

To include the repository for the **Umbrella** addon, use the `--umbrella` flag:

```bash
curl -sSL https://raw.githubusercontent.com/flashingcursor/overkill-pi-setup/main/overkill-install.sh | sudo bash -s -- --umbrella
```

### Install Adult Addon Repository

To include the repository for adult addons (like **Cumination**), use the `--fap` flag:

```bash
curl -sSL https://raw.githubusercontent.com/flashingcursor/overkill-pi-setup/main/overkill-install.sh | sudo bash -s -- --fap
```
### Install Both

You can combine flags:

```bash
curl -sSL https://raw.githubusercontent.com/flashingcursor/overkill-pi-setup/main/overkill-install.sh | sudo bash -s -- --umbrella --fap
```
