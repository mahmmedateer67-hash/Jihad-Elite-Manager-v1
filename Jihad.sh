#!/bin/bash

# --- Jihad-Ultimate-Pro - Elite Edition ---
# Re-engineered for Jihad - Full VPN & SSH Manager
# Version: 1.1.0 (Stable)

# --- ANSI Colors ---
C_RESET="\e[0m"; C_BOLD="\e[1m"; C_RED="\e[38;5;196m"; C_GREEN="\e[38;5;46m"
C_YELLOW="\e[38;5;226m"; C_BLUE="\e[38;5;39m"; C_PURPLE="\e[38;5;135m"
C_CYAN="\e[38;5;51m"; C_WHITE="\e[38;5;255m"; C_GRAY="\e[38;5;245m"

# Paths & Configs
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="$SCRIPT_DIR/bin"
DB_DIR="/etc/jihad"; mkdir -p "$DB_DIR"
DB_FILE="$DB_DIR/users.db"; touch "$DB_FILE"
DNSTT_BINARY="/usr/local/bin/dnstt-server"
BADVPN_BINARY="/usr/local/bin/badvpn-udpgw"
UDP_CUSTOM_BINARY="/usr/local/bin/udp-custom"
ZIVPN_BINARY="/usr/local/bin/zivpn"
IONOS_PY="$SCRIPT_DIR/ionos_dns_manager_obfuscated.py"

# API Keys (Stored securely)
IONOS_API_KEY="6ad34f34efbe49818d8aa8ea427fcd01.DCQ_vuTiDdgHz4BXhhRzQTLcEAX1saG0NWhICHJvLjLInWzmYd4_TdJdmUkDZuOOmp94xJrGUQ9ITPakxXSqaQ"
IONOS_ZONE_ID="13e0b11c-0726-11f1-8880-0a5864440f43"

# --- System Setup ---
setup_jihad_command() {
    if [[ ! -L "/usr/local/bin/jihad" ]]; then
        ln -sf "$SCRIPT_DIR/Jihad.sh" "/usr/local/bin/jihad"
        chmod +x "/usr/local/bin/jihad"
    fi
}

show_banner() {
    clear
    local os_name=$(grep -oP 'PRETTY_NAME="\K[^"]+' /etc/os-release || echo "Linux")
    local ram_usage=$(free -m | awk '/^Mem:/{printf "%.2f", $3*100/$2}')
    local online_users=$(who | wc -l)
    local total_users=$(grep -c . "$DB_FILE")
    echo -e "${C_PURPLE}${C_BOLD}   Jihad-Ultimate-Pro ${C_RESET}${C_GRAY}| Elite Edition${C_RESET}"
    echo -e "${C_BLUE}   ─────────────────────────────────────────────────────────${C_RESET}"
    echo -e "   ${C_GRAY}OS: ${C_WHITE}$os_name${C_RESET} | ${C_GRAY}RAM: ${C_WHITE}${ram_usage}% Used${C_RESET}"
    echo -e "   ${C_GRAY}Users: ${C_WHITE}$total_users Total${C_RESET} | ${C_GRAY}Online: ${C_WHITE}$online_users${C_RESET}"
    echo -e "${C_BLUE}   ─────────────────────────────────────────────────────────${C_RESET}"
}

# --- User Management ---
create_user() {
    show_banner
    echo -e "${C_CYAN}👤 [ Create SSH User ]${C_RESET}"
    read -p "   Username: " username
    if grep -q "^$username:" /etc/passwd; then
        echo -e "${C_RED}   ❌ User already exists!${C_RESET}"; sleep 2; return
    fi
    read -p "   Password: " password
    read -p "   Duration (Days): " days
    
    useradd -M -s /bin/false "$username"
    echo "$username:$password" | chpasswd
    exp_date=$(date -d "+$days days" +"%Y-%m-%d")
    echo "$username|$password|$exp_date" >> "$DB_FILE"
    
    echo -e "${C_GREEN}   ✅ User $username created successfully! (Exp: $exp_date)${C_RESET}"
    sleep 2
}

delete_user() {
    show_banner
    echo -e "${C_RED}🗑️ [ Delete SSH User ]${C_RESET}"
    read -p "   Username to delete: " username
    if ! grep -q "^$username:" /etc/passwd; then
        echo -e "${C_RED}   ❌ User not found!${C_RESET}"; sleep 2; return
    fi
    userdel -f "$username"
    sed -i "/^$username|/d" "$DB_FILE"
    echo -e "${C_GREEN}   ✅ User $username deleted.${C_RESET}"
    sleep 2
}

# --- Protocols ---
install_badvpn() {
    show_banner
    echo -e "${C_PURPLE}🚀 Installing badvpn (UDP 7300)...${C_RESET}"
    local arch=$(uname -m)
    if [[ "$arch" == "x86_64" ]]; then cp "$BIN_DIR/badvpn-amd64" "$BADVPN_BINARY"
    else cp "$BIN_DIR/badvpn-arm64" "$BADVPN_BINARY"
    fi
    chmod +x "$BADVPN_BINARY"
    cat > "/etc/systemd/system/badvpn.service" <<EOF
[Unit]
Description=BadVPN UDP Gateway
[Service]
ExecStart=$BADVPN_BINARY --listen-addr 0.0.0.0:7300 --max-clients 1000
Restart=always
[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload && systemctl enable badvpn && systemctl start badvpn
    echo -e "${C_GREEN}✅ badvpn active on port 7300.${C_RESET}"; sleep 2
}

install_dnstt() {
    show_banner
    echo -e "${C_PURPLE}📡 Installing DNSTT (SlowDNS)...${C_RESET}"
    local arch=$(uname -m)
    if [[ "$arch" == "x86_64" ]]; then cp "$BIN_DIR/dnstt-amd64" "$DNSTT_BINARY"
    else cp "$BIN_DIR/dnstt-arm64" "$DNSTT_BINARY"
    fi
    chmod +x "$DNSTT_BINARY"
    
    echo -e "   [1] Use IONOS Auto-DNS"
    echo -e "   [2] Manual Nameserver"
    read -p "   Select: " dns_choice
    if [[ "$dns_choice" == "1" ]]; then
        read -p "   Subdomain (e.g., jihad): " sub
        export IONOS_API_KEY="$IONOS_API_KEY"
        python3 "$IONOS_PY" create "$sub.02iuk.shop"
        ns_domain="tun.$sub.02iuk.shop"
    else
        read -p "   Enter Nameserver: " ns_domain
    fi
    
    # Key Generation
    $DNSTT_BINARY -gen-key -privkey /etc/jihad/server.priv -pubkey /etc/jihad/server.pub
    pub_key=$(cat /etc/jihad/server.pub)
    
    cat > "/etc/systemd/system/dnstt.service" <<EOF
[Unit]
Description=DNSTT Server
[Service]
ExecStart=$DNSTT_BINARY -udp :53 -privkey /etc/jihad/server.priv $ns_domain 127.0.0.1:22
Restart=always
[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload && systemctl enable dnstt && systemctl start dnstt
    echo -e "${C_GREEN}✅ DNSTT active! Public Key: $pub_key${C_RESET}"; sleep 5
}

# --- Menus ---
protocol_menu() {
    while true; do
        show_banner
        local badvpn_st; if systemctl is-active --quiet badvpn; then badvpn_st="${C_GREEN}(Active)${C_RESET}"; else badvpn_st="${C_GRAY}(Inactive)${C_RESET}"; fi
        local dnstt_st; if systemctl is-active --quiet dnstt; then dnstt_st="${C_GREEN}(Active)${C_RESET}"; else dnstt_st="${C_GRAY}(Inactive)${C_RESET}"; fi
        
        echo -e "\n   ${C_PURPLE}══════════════[ PROTOCOL MANAGEMENT ]══════════════${C_RESET}"
        printf "     ${C_CYAN}[ 1]${C_RESET} %-40s %b\n" "🚀 Install badvpn (UDP 7300)" "$badvpn_st"
        printf "     ${C_CYAN}[ 2]${C_RESET} %-40s\n" "🗑️ Uninstall badvpn"
        printf "     ${C_CYAN}[ 3]${C_RESET} %-40s %b\n" "📡 Install/View DNSTT (Port 53)" "$dnstt_st"
        printf "     ${C_CYAN}[ 4]${C_RESET} %-40s\n" "🗑️ Uninstall DNSTT"
        echo -e "   ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
        echo -e "     ${C_YELLOW}[ 0]${C_RESET} ↩️ Return to Main Menu\n"
        read -p "👉 Select: " choice
        case $choice in
            1) install_badvpn ;;
            2) systemctl stop badvpn; echo "Uninstalled"; sleep 1 ;;
            3) install_dnstt ;;
            4) systemctl stop dnstt; echo "Uninstalled"; sleep 1 ;;
            0) return ;;
        esac
    done
}

main_menu() {
    while true; do
        show_banner
        echo -e "\n   ${C_PURPLE}═══════════════[ USER MANAGEMENT ]═══════════════${C_RESET}"
        printf "     ${C_CYAN}[ 1]${C_RESET} %-25s ${C_CYAN}[ 2]${C_RESET} %-25s\n" "Create User" "Delete User"
        echo -e "\n   ${C_PURPLE}════════════[ VPN & PROTOCOLS ]═════════════${C_RESET}"
        printf "     ${C_CYAN}[ 9]${C_RESET} %-25s ${C_CYAN}[11]${C_RESET} %-25s\n" "Protocol Manager" "IONOS DNS Manager"
        echo -e "\n     ${C_RED}[ 0]${C_RESET} Exit\n"
        read -p "👉 Select: " choice
        case $choice in
            1) create_user ;;
            2) delete_user ;;
            9) protocol_menu ;;
            11) export IONOS_API_KEY="$IONOS_API_KEY"; python3 "$IONOS_PY" main_menu ;;
            0) exit 0 ;;
        esac
    done
}

setup_jihad_command
main_menu
