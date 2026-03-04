#!/bin/bash

# --- Jihad-Ultimate-Pro - Elite Edition (Re-Engineered) ---
# Version: 1.2.0 (Stable & Tested)

# --- ANSI Colors (Simplified & Stable) ---
C_RESET="\e[0m"; C_BOLD="\e[1m"; C_RED="\e[31m"; C_GREEN="\e[32m"
C_YELLOW="\e[33m"; C_BLUE="\e[34m"; C_PURPLE="\e[35m"; C_CYAN="\e[36m"
C_WHITE="\e[37m"; C_GRAY="\e[90m"

# Paths & Configs
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="$SCRIPT_DIR/bin"
DB_DIR="/etc/jihad"; mkdir -p "$DB_DIR"
DB_FILE="$DB_DIR/users.db"; touch "$DB_FILE"
DNSTT_BINARY="/usr/local/bin/dnstt-server"
BADVPN_BINARY="/usr/local/bin/badvpn-udpgw"
IONOS_PY="$SCRIPT_DIR/ionos_dns_manager_obfuscated.py"

# --- System Check ---
setup_jihad_command() {
    if [[ ! -L "/usr/local/bin/jihad" ]]; then
        ln -sf "$SCRIPT_DIR/Jihad.sh" "/usr/local/bin/jihad"
        chmod +x "/usr/local/bin/jihad"
    fi
}

show_banner() {
    clear
    local os_name=$(grep -oP 'PRETTY_NAME="\K[^"]+' /etc/os-release || echo "Linux")
    local ram_usage=$(free -m | awk '/^Mem:/{printf "%.1f", $3*100/$2}')
    local online_users=$(who | wc -l)
    local total_users=$(grep -c . "$DB_FILE")
    echo -e "${C_PURPLE}${C_BOLD}   Jihad-Ultimate-Pro ${C_RESET}${C_GRAY}| Elite Edition${C_RESET}"
    echo -e "${C_BLUE}   ─────────────────────────────────────────────────────────${C_RESET}"
    echo -e "   ${C_GRAY}OS: ${C_WHITE}$os_name${C_RESET} | ${C_GRAY}RAM: ${C_WHITE}${ram_usage}% Used${C_RESET}"
    echo -e "   ${C_GRAY}Users: ${C_WHITE}$total_users Total${C_RESET} | ${C_GRAY}Online: ${C_WHITE}$online_users${C_RESET}"
    echo -e "${C_BLUE}   ─────────────────────────────────────────────────────────${C_RESET}"
}

# --- User Management (Real SSH Logic) ---
create_user() {
    show_banner
    echo -e "${C_CYAN}👤 [ Create SSH User ]${C_RESET}"
    read -p "   Username: " username
    [[ -z "$username" ]] && return
    if id "$username" &>/dev/null; then
        echo -e "${C_RED}   ❌ User already exists!${C_RESET}"; sleep 2; return
    fi
    read -p "   Password: " password
    read -p "   Duration (Days): " days
    [[ -z "$days" ]] && days=30
    
    useradd -M -s /bin/false "$username"
    echo "$username:$password" | chpasswd
    exp_date=$(date -d "+$days days" +"%Y-%m-%d")
    echo "$username|$password|$exp_date" >> "$DB_FILE"
    
    echo -e "${C_GREEN}   ✅ User $username created! (Exp: $exp_date)${C_RESET}"
    sleep 2
}

delete_user() {
    show_banner
    echo -e "${C_RED}🗑️ [ Delete SSH User ]${C_RESET}"
    read -p "   Username to delete: " username
    [[ -z "$username" ]] && return
    if ! id "$username" &>/dev/null; then
        echo -e "${C_RED}   ❌ User not found!${C_RESET}"; sleep 2; return
    fi
    userdel -f "$username"
    sed -i "/^$username|/d" "$DB_FILE"
    echo -e "${C_GREEN}   ✅ User $username deleted.${C_RESET}"
    sleep 2
}

# --- Protocol Installation (Real Binaries Logic) ---
install_badvpn() {
    show_banner
    echo -e "${C_PURPLE}🚀 Installing badvpn (UDP 7300)...${C_RESET}"
    local arch=$(uname -m)
    local bin_src=""
    [[ "$arch" == "x86_64" ]] && bin_src="$BIN_DIR/badvpn-amd64" || bin_src="$BIN_DIR/badvpn-arm64"
    
    if [[ ! -f "$bin_src" ]]; then
        echo -e "${C_RED}   ❌ Binary not found in $bin_src!${C_RESET}"; sleep 3; return
    fi
    
    cp "$bin_src" "$BADVPN_BINARY" && chmod +x "$BADVPN_BINARY"
    
    # Systemd Service
    cat > "/etc/systemd/system/badvpn.service" <<EOF
[Unit]
Description=BadVPN UDP Gateway
After=network.target
[Service]
ExecStart=$BADVPN_BINARY --listen-addr 0.0.0.0:7300 --max-clients 1000
Restart=always
[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload && systemctl enable badvpn && systemctl start badvpn
    echo -e "${C_GREEN}   ✅ badvpn active on port 7300.${C_RESET}"; sleep 2
}

install_dnstt() {
    show_banner
    echo -e "${C_PURPLE}📡 Installing DNSTT (SlowDNS)...${C_RESET}"
    local arch=$(uname -m)
    local bin_src=""
    [[ "$arch" == "x86_64" ]] && bin_src="$BIN_DIR/dnstt-amd64" || bin_src="$BIN_DIR/dnstt-arm64"
    
    if [[ ! -f "$bin_src" ]]; then
        echo -e "${C_RED}   ❌ Binary not found in $bin_src!${C_RESET}"; sleep 3; return
    fi
    
    cp "$bin_src" "$DNSTT_BINARY" && chmod +x "$DNSTT_BINARY"
    
    echo -e "   [1] Use IONOS Auto-DNS (Subdomain)"
    echo -e "   [2] Manual Nameserver Input"
    read -p "   Select [1-2]: " dns_choice
    
    local ns_domain=""
    if [[ "$dns_choice" == "1" ]]; then
        read -p "   Subdomain (e.g. jihad): " sub
        [[ -z "$sub" ]] && return
        # Call IONOS Manager
        export IONOS_API_KEY="6ad34f34efbe49818d8aa8ea427fcd01.DCQ_vuTiDdgHz4BXhhRzQTLcEAX1saG0NWhICHJvLjLInWzmYd4_TdJdmUkDZuOOmp94xJrGUQ9ITPakxXSqaQ"
        python3 "$IONOS_PY" create "$sub.02iuk.shop"
        ns_domain="tun.$sub.02iuk.shop"
    else
        read -p "   Enter Nameserver (FQDN): " ns_domain
    fi
    
    # Key Gen
    mkdir -p /etc/jihad/keys
    $DNSTT_BINARY -gen-key -privkey /etc/jihad/keys/server.priv -pubkey /etc/jihad/keys/server.pub
    pub_key=$(cat /etc/jihad/keys/server.pub)
    
    # Systemd Service
    cat > "/etc/systemd/system/dnstt.service" <<EOF
[Unit]
Description=DNSTT Server
After=network.target
[Service]
ExecStart=$DNSTT_BINARY -udp :53 -privkey /etc/jihad/keys/server.priv $ns_domain 127.0.0.1:22
Restart=always
[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload && systemctl enable dnstt && systemctl start dnstt
    echo -e "${C_GREEN}   ✅ DNSTT active! Public Key: $pub_key${C_RESET}"; sleep 5
}

# --- Menus Logic (The Fixed Part) ---
protocol_menu() {
    while true; do
        show_banner
        local badvpn_st; systemctl is-active --quiet badvpn && badvpn_st="${C_GREEN}(Active)${C_RESET}" || badvpn_st="${C_GRAY}(Inactive)${C_RESET}"
        local dnstt_st; systemctl is-active --quiet dnstt && dnstt_st="${C_GREEN}(Active)${C_RESET}" || dnstt_st="${C_GRAY}(Inactive)${C_RESET}"
        
        echo -e "\n   ${C_PURPLE}══════════════[ PROTOCOL MANAGEMENT ]══════════════${C_RESET}"
        echo -e "     ${C_CYAN}[ 1]${C_RESET} 🚀 Install badvpn (UDP 7300)     $badvpn_st"
        echo -e "     ${C_CYAN}[ 2]${C_RESET} 🗑️ Uninstall badvpn"
        echo -e "     ${C_CYAN}[ 3]${C_RESET} 📡 Install/View DNSTT (Port 53)  $dnstt_st"
        echo -e "     ${C_CYAN}[ 4]${C_RESET} 🗑️ Uninstall DNSTT"
        echo -e "   ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
        echo -e "     ${C_YELLOW}[ 0]${C_RESET} ↩️ Return to Main Menu\n"
        read -p "👉 Select: " p_choice
        case $p_choice in
            1) install_badvpn ;;
            2) systemctl stop badvpn; systemctl disable badvpn; echo -e "${C_GREEN}Uninstalled.${C_RESET}"; sleep 1 ;;
            3) install_dnstt ;;
            4) systemctl stop dnstt; systemctl disable dnstt; echo -e "${C_GREEN}Uninstalled.${C_RESET}"; sleep 1 ;;
            0) break ;;
            *) echo -e "${C_RED}Invalid option!${C_RESET}"; sleep 1 ;;
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
        read -p "👉 Select: " m_choice
        case $m_choice in
            1) create_user ;;
            2) delete_user ;;
            9) protocol_menu ;;
            11) export IONOS_API_KEY="6ad34f34efbe49818d8aa8ea427fcd01.DCQ_vuTiDdgHz4BXhhRzQTLcEAX1saG0NWhICHJvLjLInWzmYd4_TdJdmUkDZuOOmp94xJrGUQ9ITPakxXSqaQ"
                python3 "$IONOS_PY" main_menu ;;
            0) exit 0 ;;
            *) echo -e "${C_RED}Invalid option!${C_RESET}"; sleep 1 ;;
        esac
    done
}

# --- Initialization ---
if [[ $EUID -ne 0 ]]; then
   echo -e "${C_RED}❌ Error: This script requires root privileges.${C_RESET}"
   exit 1
fi
setup_jihad_command
main_menu
