#!/bin/bash

# Log file location
LOG_FILE="/var/log/network_scan.log"
sudo chmod 777 /var/log
# Function to check and install missing packages
check_install() {
    if ! dpkg -l | grep -q "$1"; then
        echo "$1 not found. Installing..."
        sudo apt-get install -y "$1"
    else
        echo "$1 is Installed."
    fi
}

# Ensure required packages are installed
REQUIRED_PKGS=("sshpass" "nmap" "whois" "jq" "curl" "perl" "cpanm" "tor")
for pkg in "${REQUIRED_PKGS[@]}"; do
    check_install "$pkg"
done

# Locate Nipe directory dynamically and install Nipe and its dependencies if not found.
NIPE_PATH=$(find / -type d -name "nipe" 2>/dev/null | head -n 1)
if [ -z "$NIPE_PATH" ]; then
    echo "Nipe directory not found. Cloning and installing..."
    git clone https://github.com/htrgouvea/nipe.git "$HOME/nipe"
    NIPE_PATH="$HOME/nipe"
    cd "$NIPE_PATH" || exit
    sudo cpan install Try::Tiny Config::Simple JSON
    sudo perl nipe.pl install
else
    echo "Nipe Installed"
    cd "$NIPE_PATH" || exit
fi

echo "Connecting anonymously..."
# Start and check Nipe for anonymity
# Nipe routes all traffic through the Tor network for anonymity
# Re-attempt to connect anonymously
RETRIES=3
while [ $RETRIES -gt 0 ]; do 
    sudo perl nipe.pl start
    ANON_STATUS=$(sudo perl nipe.pl status | grep 'Status' | awk '{print $3}')
    if [ "$ANON_STATUS" == "true" ]; then
        break
    fi
    RETRIES=$((RETRIES - 1))
    sudo perl nipe.pl stop
    echo "Retrying Nipe connection... Attempts left: $RETRIES"
done
#Exit if still fails after retries
if [ "$ANON_STATUS" != "true" ]; then 
	sudo perl nipe.pl stop
    echo "[ERROR] Not anonymous! Exiting..."
    exit 1
fi

# Fetches the current spoofed IP address using Tor's check service
SPOOFED_IP=$(curl -s https://check.torproject.org/api/ip | jq -r '.IP')
SPOOFED_COUNTRY=$(whois "$SPOOFED_IP" | grep -i country | awk '{print $2}')
echo "Connected anonymously with IP: $SPOOFED_IP ($SPOOFED_COUNTRY)"

# Prompt user for domain to scan
#DOMAIN='scanme.nmap.org'
read -p "Enter the domain or URL to scan (e.g., scanme.nmap.org): " DOMAIN

while true; do
    read -p "Use default remote server? (y/n): " USE_DEFAULT
    if [[ "$USE_DEFAULT" =~ ^[YyNn]$ ]]; then
        break
    else
        echo "Invalid input. Please enter 'y' or 'n'."
    fi
done

if [[ "$USE_DEFAULT" =~ ^[Yy]$ ]]; then
    REMOTE_USER="ec2-user"
    REMOTE_HOST="18.234.142.187"
    SSHPASS='ilovecfc'
else
    read -p "Enter remote server username: " REMOTE_USER
    read -p "Enter remote server IP address: " REMOTE_HOST
    read -s -p "Enter SSH password for $REMOTE_USER@$REMOTE_HOST: " SSHPASS
    echo ""
fi

export SSHPASS

SILENT_MODE=false
while true; do
    read -p "Silent Mode? (y/n): " USE_MODE
    if [[ "$USE_MODE" =~ ^[YyNn]$ ]]; then
        break
    else
        echo "Invalid input. Please enter 'y' or 'n'."
    fi
done

if [[ "$USE_MODE" =~ ^[Yy]$ ]]; then
    SILENT_MODE=true
else
    SILENT_MODE=false
fi

echo "Scaning..."
# Run scans on remote server
# Run scans silently.
if [ "$SILENT_MODE" = true ]; then 
	sshpass -e ssh $REMOTE_USER@$REMOTE_HOST << EOF > /dev/null 2>&1
     # Detect OS and set package manager
    if [ -f /etc/debian_version ]; then
        PKG_MANAGER="apt-get install -y"
    elif grep -qi "Amazon Linux" /etc/os-release; then
        PKG_MANAGER="yum install -y"
    elif [ -f /etc/redhat-release ]; then
        PKG_MANAGER="yum install -y"
    else
        exit 1
    fi
    
    # Function to check and install missing packages on remote server
    check_remote_install() {
        if ! command -v "\$1" &> /dev/null; then
            echo "$SSHPASS" | sudo -S \$PKG_MANAGER "\$1"
        fi
    }
    
    # Ensure required packages are installed on the remote server
    REMOTE_REQUIRED_PKGS=("nmap" "whois")
    for pkg in "\${REMOTE_REQUIRED_PKGS[@]}"; do
        check_remote_install "\$pkg"
    done
    
    # Perform an Nmap service version detection scan on the specified domain
    # -sV: Detects service versions running on open ports
    # -oN: Saves output in a normal readable format to the specified file
    nmap -sV "$DOMAIN" -oN /tmp/scan_results.txt
    
    # Perform a Whois lookup to gather registration information about the domain
    whois "$DOMAIN" > /tmp/whois_results.txt
EOF
else
	# Runs normally
	sshpass -e ssh -q -t $REMOTE_USER@$REMOTE_HOST << EOF
     # Detect OS and set package manager
    if [ -f /etc/debian_version ]; then
        PKG_MANAGER="apt-get install -y"
    elif grep -qi "Amazon Linux" /etc/os-release; then
        PKG_MANAGER="yum install -y"
    elif [ -f /etc/redhat-release ]; then
        PKG_MANAGER="yum install -y"
    else
        echo "Unsupported OS. Exiting..."
        exit 1
    fi
    
    # Function to check and install missing packages on remote server
    check_remote_install() {
        if ! command -v "\$1" &> /dev/null; then
            echo "\$1 not found on remote server. Installing..."
            echo "$SSHPASS" | sudo -S \$PKG_MANAGER "\$1"
        else
            echo "\$1 is already installed on remote server."
        fi
    }
    
    # Ensure required packages are installed on the remote server
    REMOTE_REQUIRED_PKGS=("nmap" "whois")
    for pkg in "\${REMOTE_REQUIRED_PKGS[@]}"; do
        check_remote_install "\$pkg"
    done    
    
    
    # Perform an Nmap service version detection scan on the specified domain
    # -sV: Detects service versions running on open ports
    # -oN: Saves output in a normal readable format to the specified file
    nmap -sV "$DOMAIN" -oN /tmp/scan_results.txt
    
    # Perform a Whois lookup to gather registration information about the domain
    whois "$DOMAIN" > /tmp/whois_results.txt
EOF
fi

# Define the custom directory path
LOCAL_DIR="$HOME/Data_Collected"

# Check if the directory exists, create it if it doesn't
if [ ! -d "$LOCAL_DIR" ]; then
    mkdir -p "$LOCAL_DIR"
    #echo "Created directory: $LOCAL_DIR"
fi

# Retrieve scan results securely using SCP
# scp: Securely copies files from the remote server to the local machine
# -o StrictHostKeyChecking=no: Disables host key checking to allow automation
# -o UserKnownHostsFile=/dev/null: Prevents storing host key to known_hosts
sshpass -e scp $REMOTE_USER@$REMOTE_HOST:/tmp/scan_results.txt "$LOCAL_DIR"
sshpass -e scp $REMOTE_USER@$REMOTE_HOST:/tmp/whois_results.txt "$LOCAL_DIR"


# Log activity
echo "$sudo $(date) - Scanned $DOMAIN | Nmap | Spoofed IP: $SPOOFED_IP ($SPOOFED_COUNTRY)" >> "$LOG_FILE"
echo "$sudo $(date) - Scanned $DOMAIN | Whois | Spoofed IP: $SPOOFED_IP ($SPOOFED_COUNTRY)" >> "$LOG_FILE"
echo "Logs are saved in $LOG_FILE"
sudo chmod 755 /var/log
sudo perl nipe.pl stop
cd ..
echo "Scan complete. Results saved in $LOCAL_DIR/scan_results.txt"
echo "Scan complete. Results saved in $LOCAL_DIR/whois_results.txt"

