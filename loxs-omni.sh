#!/bin/bash

# LOXS-Omni v5.4 - Integrated JDT-Mobile Security Suite
# Tool    : LOXS-Omni (Recon Advisor + Menu)
# Version : 5.4
# Author  : shamr0ck3 / LOXS

# Colors
RED='\033[1;31m'; GRN='\033[1;32m'; YLW='\033[1;33m'
BLU='\033[1;34m'; CYN='\033[1;36m'; RST='\033[0m'

# Service Checks
CRON_PID=$(pgrep crond)
if [ -z "$CRON_PID" ]; then
    SHIELD_STATUS="${RED}OFFLINE${RST}"
else
    SHIELD_STATUS="${GRN}ACTIVE (PID: $CRON_PID)${RST}"
fi
echo -e "${CYN}██╗      ██████╗ ██╗  ██╗███████╗${RST}"
echo -e "${CYN}██║     ██╔═══██╗╚██╗██╔╝██╔════╝${RST}"
echo -e "${CYN}██║     ██║   ██║ ╚███╔╝ ███████╗${RST}"
echo -e "${CYN}██║     ██║   ██║ ██╔██╗ ╚════██║${RST}"
echo -e "${CYN}███████╗╚██████╔╝██╔╝ ██╗███████║${RST}"
echo -e "${CYN}╚══════╝ ╚═════╝ ╚═╝  ╚═╝╚══════╝${RST}"
echo -e "${YLW}[ SHIELD: $SHIELD_STATUS ]${RST}"
echo -e "\n${CYN}Select Mission Profile:${RST}"
echo -e "  1) LEGACY RECON"
echo -e "  2) MODERN FUZZ"
echo -e "  3) PDF SCANNER"
echo -e "  4) RECON ADVISOR"
echo -e "  5) WEGRAB"
echo -e "  Q) EXIT"
echo -ne "\n${CYN}LOXS@JDT-Mobile:${RST} "
read choice
case $choice in
    1)
        echo -e "\n${GRN}[+] Launching Legacy Recon (v3.1)..."
        bash "$(cd "$(dirname "$0")" && pwd)/intelijen_v3.sh.bak"
        sleep 2 && bash "$0"
        ;;
    2)
        bash "$(cd "$(dirname "$0")" && pwd)/intelijen_v3.sh"
        sleep 2 && bash "$0"
        ;;
    3)
        echo -e "\n${CYN}[+] Initializing PDF_SCAN.EXE v3.1...${RST}"
        if [ ! -f "$(cd "$(dirname "$0")" && pwd)/pdf_scan.py" ]; then
            echo -e "${RED}[!] pdf_scan.py not found.${RST}"
            sleep 2 && bash "$(cd "$(dirname "$0")" && pwd)/loxs-omni.sh"
        fi
        if ! pgrep -f "pdf_scan.py" > /dev/null; then
            echo -e "${GRN}[*] Starting Background Engine...${RST}"
            python3 "$(cd "$(dirname "$0")" && pwd)/pdf_scan.py" > /dev/null 2>&1 &
            sleep 2
        fi
        termux-open-url http://127.0.0.1:5000
        echo -e "${GRN}[+] Dashboard deployed to browser.${RST}"
        sleep 1 && bash "$(cd "$(dirname "$0")" && pwd)/loxs-omni.sh"
        ;;
    4)
        bash "$(cd "$(dirname "$0")" && pwd)/recon_advisor.sh"
        bash "$(cd "$(dirname "$0")" && pwd)/loxs-omni.sh"
        ;;
    5)
        echo -e "\n${CYN}[+] Starting WebGrab Pro...${RST}"
        if ! pgrep -f "wegrab.py" > /dev/null; then
            python3 "$(cd "$(dirname "$0")" && pwd)/wegrab.py" > /dev/null 2>&1 &
            sleep 2
        fi
        termux-open-url http://127.0.0.1:5000
        sleep 1 && bash "$(cd "$(dirname "$0")" && pwd)/loxs-omni.sh"
        ;;
    [Qq])
        echo -e "\n${YLW}Cleaning up background tasks...${RST}"
        pkill -f "pdf_scan.py"
        echo -e "${RED}Session Terminated.${RST}"
        exit 0
        ;;
    *)
        echo -e "\n${RED}[!] Invalid choice.${RST}"
        sleep 1 && bash "$(cd "$(dirname "$0")" && pwd)/loxs-omni.sh"
        ;;
esac
