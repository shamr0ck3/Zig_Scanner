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

clear
echo -e "${BLU}┌──────────────────────────────────────────────────────────┐${RST}"
echo -e "${BLU}│${RST} ${CYN}LOXS-OMNI v5.4${RST} ${BLU}│${RST} ${YLW}OPERATOR: LOXS${RST}           ${BLU}│${RST}"
echo -e "${BLU}├──────────────────────────────────────────────────────────┤${RST}"
echo -e "${BLU}│${RST} ${YLW}SHIELD STATUS: [ $SHIELD_STATUS ]${RST}"
echo -e "${BLU}└──────────────────────────────────────────────────────────┘${RST}"

echo -e "\n${CYN}Select Mission Profile:${RST}"
echo -e "  ${GRN}1)${RST} ${YLW}LEGACY RECON${RST}  (v3.1: Nmap, Geo-IP, NSE, Headers)"
echo -e "  ${GRN}2)${RST} ${YLW}MODERN FUZZ${RST}   (v4.3: PATT, Kernel LPE, Anti-Cloak)"
echo -e "  ${GRN}3)${RST} ${YLW}HERMES AUDIT${RST}  (Env Check, Hygiene, Sync Status)"
echo -e "  ${GRN}4)${RST} ${YLW}PDF SCANNER${RST}   (v3.1: ClamAV, Web Crawler, Flask)"
echo -e "  ${GRN}5)${RST} ${YLW}RECON ADVISOR${RST} (Pre‑scan intelligence & payload suggestions)"
echo -e "  ${GRN}Q)${RST} ${RED}EXIT${RST}"

echo -ne "\n${CYN}LOXS@JDT-Mobile:${RST} "
read choice

# ====== RECON ADVISOR (FULL ENHANCED VERSION) ======
recon_advisor() {
    local target
    echo -e "\n${CYN}┌──────────────────────────────────────────┐${RST}"
    echo -e "${CYN}│   Recon Advisor v2.3 - Deep Intelligence│${RST}"
    echo -e "${CYN}└──────────────────────────────────────────┘${RST}"
    read -rp "Enter target URL (e.g., http://example.com): " target
    [[ "$target" != http* ]] && target="http://$target"

    echo -e "\n${YLW}[*] Analyzing $target ...${RST}"

    mkdir -p "$(cd "$(dirname "$0")" && pwd)/scan_logs"
    local TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    local REPORT_JSON="$(cd "$(dirname "$0")" && pwd)/scan_logs/report_$TIMESTAMP.json"
    local ADVICE_TXT="$(cd "$(dirname "$0")" && pwd)/scan_logs/advice_$TIMESTAMP.txt"

    # --- Helper functions inside the advisor (local to this function) ---
    random_ua() {
        local ua_list=(
            "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/115.0.0.0 Safari/537.36"
            "Mozilla/5.0 (Android 14; Mobile; rv:109.0) Gecko/113.0 Firefox/113.0"
            "Mozilla/5.0 (iPhone; CPU iPhone OS 16_6 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.6 Mobile/15E148 Safari/604.1"
            "curl/8.4.0"
        )
        echo "${ua_list[$RANDOM % ${#ua_list[@]}]}"
    }

    random_ip() {
        echo "$((RANDOM%223+1)).$((RANDOM%255)).$((RANDOM%255)).$((RANDOM%255))"
    }

    fast_port_scan() {
        local host="$1"
        local ports="$2"
        local open_ports=()
        IFS=',' read -ra port_list <<< "$ports"
        for port in "${port_list[@]}"; do
            timeout 2 bash -c "echo >/dev/tcp/$host/$port" 2>/dev/null && open_ports+=("$port")
        done
        echo "${open_ports[@]}"
    }

    check_test_sites() {
        local sites=(
            "testasp.vulnweb.com"
            "zero.webappsecurity.com"
            "demo.testfire.net"
            "juice-shop.herokuapp.com"
        )
        echo -e "\n${YLW}[*] Checking known test sites availability & WAF headers:${RST}"
        for site in "${sites[@]}"; do
            local ua=$(random_ua)
            local code=$(curl -s -o /dev/null -w "%{http_code}" -A "$ua" --connect-timeout 5 "http://$site/" 2>/dev/null)
            local headers=$(curl -sI -A "$ua" --connect-timeout 5 "http://$site/" 2>/dev/null)
            local waf=$(echo "$headers" | grep -iE "server|waf|cloudflare|cf-ray|akamai" | tr '\n' ' ')
            echo "  $code → $site" | tee -a "$ADVICE_TXT"
            if [ -n "$waf" ]; then
                echo "     Headers: $waf" | tee -a "$ADVICE_TXT"
            fi
        done
        echo -e "${GRN}[+] Test site check complete.${RST}"
    }

    # --- 1. Basic HTTP analysis ---
    local headers=$(curl -sI -H "X-Forwarded-For: $(random_ip)" -A "$(random_ua)" "$target" 2>/dev/null)
    local html=$(curl -sL -H "X-Forwarded-For: $(random_ip)" -A "$(random_ua)" "$target" 2>/dev/null)

    # WAF detection
    local waf="false"
    if echo "$headers" | grep -qiE "cf-ray|x-waf|cloudflare|akamai|incapsula|mod_security|sucuri"; then
        waf="true"
    fi
    echo -e "${YLW}[*] WAF detected: ${waf}${RST}"

    # Technology detection (httpx if available)
    local tech="unknown"
    if command -v httpx &>/dev/null; then
        httpx -u "$target" -silent -status-code -title -tech-detect -json -o /tmp/httpx_$$.json 2>/dev/null
        if [ -f /tmp/httpx_$$.json ] && jq -e . /tmp/httpx_$$.json &>/dev/null; then
            tech=$(jq -r '.["tech"] | join(",")' /tmp/httpx_$$.json)
        fi
        rm -f /tmp/httpx_$$.json
    fi

    # Guess technology from HTML
    local guess_tech=""
    if echo "$headers" | grep -qi "X-Powered-By: PHP"; then guess_tech="${guess_tech}PHP,"; fi
    if echo "$headers" | grep -qi "X-Powered-By: ASP.NET"; then guess_tech="${guess_tech}ASP.NET,"; fi
    if echo "$html" | grep -qi "sqlite"; then guess_tech="${guess_tech}SQLite,"; fi
    if echo "$html" | grep -qi "mysql"; then guess_tech="${guess_tech}MySQL,"; fi
    if echo "$html" | grep -qi "postgresql"; then guess_tech="${guess_tech}PostgreSQL,"; fi
    if echo "$html" | grep -qi "node\.js"; then guess_tech="${guess_tech}Node.js,"; fi
    if echo "$html" | grep -qi "django"; then guess_tech="${guess_tech}Django,"; fi
    guess_tech=${guess_tech%,}
    [ -z "$guess_tech" ] && guess_tech="unknown"
    local full_tech=$(echo "${tech},${guess_tech}" | sed 's/^,//;s/,$//')

    # Extract parameters from HTML
    local params=$(echo "$html" | grep -oE '(name|id)="[^"]*"' | sed -E 's/.*="([^"]+)"/\1/' | sort -u)
    params+=$'\n'"$(echo "$html" | grep -oE 'href="[^"]*\?[^"]*"' | grep -oE '\?[^"#]*' | tr '&' '\n' | grep -oE '^[?]?[a-zA-Z_][a-zA-Z0-9_]*' | tr -d '?' | sort -u)"
    local param_list=$(echo "$params" | sort -u | grep -v '^$' | tr '\n' ',' | sed 's/,$//')

    # --- 2. Port scanning ---
    local domain=$(echo "$target" | awk -F/ '{print $3}' | cut -d: -f1)
    local ports_to_scan="80,443,8080,8443,22,21,25,3306,5432,27017"
    echo -e "${YLW}[*] Scanning ports: $ports_to_scan${RST}"
    local open_ports=$(fast_port_scan "$domain" "$ports_to_scan")
    echo -e "${YLW}[*] Open ports: ${open_ports:-none}${RST}"

    # --- 3. whatweb (optional) ---
    local whatweb_tech=""
    if command -v whatweb &>/dev/null; then
        echo -e "${YLW}[*] Running whatweb...${RST}"
        local ww_out=$(whatweb --color=never --quiet "$target" 2>/dev/null)
        whatweb_tech=$(echo "$ww_out" | grep -oE '\[[^]]+\]' | tr -d '[]' | sort -u | tr '\n' ',' | sed 's/,$//')
    fi

    # --- 4. subfinder (optional) ---
    local subdomains=""
    if command -v subfinder &>/dev/null; then
        echo -e "${YLW}[*] Running subfinder...${RST}"
        subdomains=$(subfinder -d "$domain" -silent 2>/dev/null | head -20 | tr '\n' ',')
        subdomains=${subdomains%,}
    fi

    # --- 5. Origin IP discovery from subdomains ---
    local origin_ips=""
    if [ -n "$subdomains" ]; then
        echo -e "${YLW}[*] Checking subdomains for origin IPs...${RST}"
        IFS=',' read -ra sub_arr <<< "$subdomains"
        for sub in "${sub_arr[@]}"; do
            ip=$(dig +short "$sub" | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' | head -1)
            if [ -n "$ip" ]; then
                if ! echo "$ip" | grep -qE '^(104\.16|104\.17|104\.18|104\.19|104\.20)'; then
                    origin_ips="${origin_ips}${ip} "
                fi
            fi
        done
        origin_ips=$(echo "$origin_ips" | sed 's/ $//')
        echo -e "${YLW}[*] Potential origin IPs: ${origin_ips:-none}${RST}"
    fi

    # --- 6. Recommendations ---
    local delay="1 second"
    [ "$waf" = "true" ] && delay="3-5 seconds"

    local attack_suggestions=""
    [[ "$full_tech" == *"PHP"* ]] && attack_suggestions="${attack_suggestions} LFI/RCE,"
    [[ "$full_tech" == *"SQL"* ]] && attack_suggestions="${attack_suggestions} SQLi,"
    [[ "$full_tech" == *"Node.js"* ]] && attack_suggestions="${attack_suggestions} SSTI,"
    [[ "$full_tech" == *"ASP"* ]] && attack_suggestions="${attack_suggestions} XSS,"
    [ -z "$attack_suggestions" ] && attack_suggestions=" XSS, SQLi, LFI (generic)"
    attack_suggestions=${attack_suggestions%,}

    local payload_suggestions="Generic: ' OR '1'='1, <script>alert(1)</script>, ../../etc/passwd, {{7*7}}"
    [[ "$full_tech" == *"PHP"* ]] && payload_suggestions="LFI: ../../../../etc/passwd\nRCE: ;id, | whoami"
    [[ "$full_tech" == *"SQL"* ]] && payload_suggestions="SQLi: ' OR '1'='1, ' UNION SELECT 1,2,3--"
    [[ "$full_tech" == *"Node.js"* ]] && payload_suggestions="SSTI: {{7*7}}, #{7*7}"

    # --- 7. Write JSON report ---
    cat > "$REPORT_JSON" <<EOF
{
  "target": "$target",
  "timestamp": "$TIMESTAMP",
  "waf_detected": $waf,
  "technologies": "$full_tech",
  "whatweb_tech": "$whatweb_tech",
  "parameters": "$param_list",
  "open_ports": "$open_ports",
  "subdomains": "$subdomains",
  "origin_ips": "$origin_ips",
  "recommended_delay": "$delay",
  "recommended_attacks": "$attack_suggestions",
  "sample_payloads": "$(echo "$payload_suggestions" | tr '\n' ' ' | sed 's/ $//')"
}
EOF

    # --- 8. Write plain text advice ---
    {
        echo -e "\n${CYN}========== RECOMMENDATIONS ==========${RST}"
        echo "1. Delay between requests: $delay"
        echo "2. Attack types to focus on: $attack_suggestions"
        echo "3. Sample payloads to try:"
        echo -e "$payload_suggestions" | sed 's/^/     /'
        echo "4. Parameters to test: $param_list"
        echo "5. Open ports: $open_ports"
        [ -n "$subdomains" ] && {
            echo "6. Subdomains found:"
            echo "$subdomains" | sed 's/^/     /'
        }
        [ -n "$origin_ips" ] && {
            echo "7. Potential origin IPs:"
            echo "$origin_ips" | sed 's/^/     /'
        }
        echo "8. Use User-Agent rotation and random IP headers (X-Forwarded-For)."
        echo -e "${CYN}=====================================${RST}"
        echo "Full report (JSON): $REPORT_JSON"
        echo "Advice (text): $ADVICE_TXT"
    } | tee "$ADVICE_TXT"

    ln -sf "$REPORT_JSON" "$(cd "$(dirname "$0")" && pwd)/scan_logs/latest_report.json"
    echo -e "\n${GRN}[+] Advice saved. Latest report: $(cd "$(dirname "$0")" && pwd)/scan_logs/latest_report.json${RST}"

    # --- 9. Optional: check test sites ---
    read -p "Do you want to check known test sites? (y/N): " check_opt
    if [[ "$check_opt" =~ ^[Yy]$ ]]; then
        check_test_sites
        cat "$ADVICE_TXT" | tail -n 20
    fi

    # --- 10. Launch modern fuzzer with collected intel ---
    read -p "Do you want to launch the modern fuzzer with these settings? (y/N): " launch_opt
    if [[ "$launch_opt" =~ ^[Yy]$ ]]; then
        local delay_num
        delay_num=$(echo "$delay" | sed -E 's/^([0-9]+).*$/\1/')
        [[ -z "$delay_num" ]] && delay_num=3
        echo -e "\n${GRN}[+] Launching Zig_Scanner v5.1 with target=$target and delay=${delay_num}s${RST}"
        export ZIG_TARGET="$target"
        export ZIG_DELAY="$delay_num"
        bash "$(cd "$(dirname "$0")" && pwd)/intelijen_v3.sh"
    else
        echo -e "${YLW}[*] You can later run the fuzzer manually with:${RST}"
        echo -e "    ZIG_TARGET=\"$target\" ZIG_DELAY=\"$delay_num\" ~/intelijen_v3.sh"
    fi
}

# ====== CASE HANDLING ======
case $choice in
    1)
        echo -e "\n${GRN}[+] Launching Legacy Recon (v3.1)...${RST}"
        bash "$(cd "$(dirname "$0")" && pwd)/intelijen_v3.sh.bak"
        ;;
    2)
        echo -e "\n${GRN}[+] Launching Modern Fuzzer (v4.3)...${RST}"
        bash "$(cd "$(dirname "$0")" && pwd)/intelijen_v3.sh"
        ;;
    3)
        echo -e "\n${CYN}[+] Running Hermes Audit Pipeline...${RST}"
        bash "$(cd "$(dirname "$0")" && pwd)/hermes_check.sh"
        ;;
    4)
        echo -e "\n${CYN}[+] Initializing PDF_SCAN.EXE v3.1...${RST}"
        if [ ! -f "$(cd "$(dirname "$0")" && pwd)/pdf_scan.py" ]; then
            echo -e "${RED}[!] pdf_scan.py not found.${RST}"
            sleep 2 && bash "$(cd "$(dirname "$0")" && pwd)/loxs-omni.sh"
        fi
        if ! pgrep -f "pdf_scan.py" > /dev/null; then
            echo -e "${GRN}[*] Starting Background Engine...${RST}"
            python "$(cd "$(dirname "$0")" && pwd)/pdf_scan.py" > /dev/null 2>&1 &
            sleep 2
        fi
        termux-open-url http://127.0.0.1:5000
        echo -e "${GRN}[+] Dashboard deployed to browser.${RST}"
        sleep 1 && bash "$(cd "$(dirname "$0")" && pwd)/loxs-omni.sh"
        ;;
    5)
        recon_advisor
        bash "$(cd "$(dirname "$0")" && pwd)/loxs-omni.sh"
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
