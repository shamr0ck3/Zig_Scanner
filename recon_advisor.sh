#!/data/data/com.termux/files/usr/bin/bash
# recon_advisor.sh - Enhanced Pre‑Scan Intelligence (v2.4)
# Optional: whatweb, subfinder, dnsrecon, gospider, httpx, jq, dig

# Colors
RED='\033[1;31m'; GRN='\033[1;32m'; YLW='\033[1;33m'
BLU='\033[1;34m'; CYN='\033[1;36m'; RST='\033[0m'

# ====== HELPER FUNCTIONS ======

# Check for required tools
if ! command -v curl &>/dev/null; then
    echo -e "${RED}[!] curl is not installed. Please install curl and try again.${RST}"
    exit 1
fi
if ! command -v jq &>/dev/null; then
    echo -e "${YLW}[!] jq not found – JSON output will be less reliable. Install jq for proper escaping.${RST}"
fi

random_ua() {
    local ua_list=(
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/115.0.0.0 Safari/537.36"
        "Mozilla/5.0 (Android 14; Mobile; rv:109.0) Gecko/113.0 Firefox/113.0"
        "Mozilla/5.0 (iPhone; CPU iPhone OS 16_6 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.6 Mobile/15E148 Safari/604.1"
        "curl/8.4.0"
    )
    echo "${ua_list[$RANDOM % ${#ua_list[@]}]}"
}

# Random IP generator for anti-ban
random_ip() {
    echo "$((RANDOM%223+1)).$((RANDOM%255)).$((RANDOM%255)).$((RANDOM%255))"
}

# Check if a host is reachable (HTTP/HTTPS) and returns 2xx/3xx
check_target() {
    local target="$1"
    local http_target="http://$target"
    local https_target="https://$target"

    # Try HTTP first
    local status
    status=$(curl -s -o /dev/null -w "%{http_code}" --max-redirs 3 --connect-timeout 3 "$http_target" 2>/dev/null)
    if [[ $status -ge 200 && $status -lt 400 ]]; then
        echo "$http_target"
        return 0
    fi
    # Fallback to HTTPS
    status=$(curl -s -o /dev/null -w "%{http_code}" --max-redirs 3 --connect-timeout 3 "$https_target" 2>/dev/null)
    if [[ $status -ge 200 && $status -lt 400 ]]; then
        echo "$https_target"
        return 0
    fi
    return 1
}

fast_port_scan() {
    local host="$1"
    local ports="$2"
    local open_ports=()
    local t_cmd="timeout"
    command -v timeout >/dev/null || t_cmd="busybox timeout"
    IFS=',' read -ra port_list <<< "$ports"
    for port in "${port_list[@]}"; do
        $t_cmd 7 bash -c "echo >/dev/tcp/$host/$port" 2>/dev/null && open_ports+=("$port")
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
        local headers=$(curl -sfI -A "$ua" --connect-timeout 5 "http://$site/" 2>/dev/null)
        local waf=$(echo "$headers" | grep -iE "server|waf|cloudflare|cf-ray|akamai" | tr '\n' ' ')
        echo "  $code → $site" | tee -a "$ADVICE_TXT"
        if [ -n "$waf" ]; then
            echo "     Headers: $waf" | tee -a "$ADVICE_TXT"
        fi
    done
    echo -e "${GRN}[+] Test site check complete.${RST}"
}

# ====== CURL RECON FUNCTION ======
curl_recon() {
    local target="$1"
    local ua
    ua=$(random_ua)
    local ip
    ip=$(random_ip)

    echo -e "\n${CYN}[+] CURL RECON PHASE: $target${RST}"

    # Phase 1 — Fingerprinting
    echo -e "\n${YLW}[*] Phase 1: Fingerprinting${RST}"
    local baseline
    baseline=$(curl -s -A "$ua" --fail --max-redirs 3 --connect-timeout 10 "$target" | wc -c)
    echo -e "    [*] Baseline size: ${baseline}B"

    local server
    server=$(curl -sI -A "$ua" --fail --max-redirs 3 "$target" 2>/dev/null | grep -i "^Server:" | cut -d' ' -f2-)
    local powered
    powered=$(curl -sI -A "$ua" --fail --max-redirs 3 "$target" 2>/dev/null | grep -i "X-Powered-By:" | cut -d' ' -f2-)
    [[ -n "$server" ]]  && echo -e "    [*] Server: $server"
    [[ -n "$powered" ]] && echo -e "    [*] Powered-By: $powered"

    local stack
    stack=$(curl -s -A "$ua" --fail --max-redirs 3 "$target" 2>/dev/null | grep -ioE "jsp|php|asp\.net|django|laravel|node\.js|tomcat|java" | sort -u | tr '\n' ',' | sed 's/,$//')
    [[ -n "$stack" ]] && echo -e "    [*] Tech hints: $stack" || echo -e "    [*] Tech hints: none detected"

    # Phase 2 — Endpoint Discovery
    echo -e "\n${YLW}[*] Phase 2: Endpoint Discovery${RST}"
    local html
    html=$(curl -sL -A "$ua" -H "X-Forwarded-For: $ip" --fail --max-redirs 3 "$target" 2>/dev/null)

    local endpoints
    endpoints=$(echo "$html" | grep -oE 'href="[^"]*"' | tr -d '"' | sed 's/href=//' | grep -v "^#\|^http\|^mailto\|^javascript" | sort -u)
    if [[ -n "$endpoints" ]]; then
        echo -e "    [+] Endpoints found:"
        echo "$endpoints" | sed 's/^/        /' | head -20
    fi

    local params
    params=$(echo "$html" | grep -oE 'href="[^"]*\?[^"]*"' | grep -oE '\?[^"#]*' | tr '&' '\n' | grep -oE '^[?]?[a-zA-Z_][a-zA-Z0-9_]*' | tr -d '?' | sort -u)
    if [[ -n "$params" ]]; then
        echo -e "    [+] Params found: $(echo "$params" | tr '\n' ',' | sed 's/,$//')"
    fi

    # Phase 3 — Reflection Testing
    echo -e "\n${YLW}[*] Phase 3: Reflection Testing${RST}"
    local marker="JDT_MARKER_$$"
    local test_params=("query" "q" "search" "id" "page" "content" "url" "path" "name" "input")

    for param in "${test_params[@]}"; do
        local reflect
        reflect=$(curl -s -A "$ua" -H "X-Forwarded-For: $ip" \
            --max-redirs 3 --connect-timeout 5 "${target}?${param}=${marker}" 2>/dev/null | grep -c "$marker")
        if [[ "$reflect" -gt 0 ]]; then
            echo -e "    ${RED}[!!!] REFLECTS: $param — potential XSS/SQLi injection point${RST}"
        fi
    done

    # Phase 4 — XSS Quick Test
    echo -e "\n${YLW}[*] Phase 4: XSS Quick Test${RST}"
    local xss_params
    xss_params=$(echo "$params" | tr ',' '\n')
    for param in $xss_params; do
        local xss_result
        xss_result=$(curl -s -A "$ua" -H "X-Forwarded-For: $ip" \
            --max-redirs 3 --connect-timeout 5 \
            "${target}?${param}=%22%3E%3Cscript%3Ealert(1)%3C%2Fscript%3E" 2>/dev/null \
            | grep -i "<script>alert(1)</script>")
        if [[ -n "$xss_result" ]]; then
            echo -e "    ${RED}[!!!] XSS CONFIRMED: ${target}?${param}=<script>alert(1)</script>${RST}"
        fi
    done

    # Phase 5 — LFI Quick Test
    echo -e "\n${YLW}[*] Phase 5: LFI Quick Test${RST}"
    local lfi_params=("content" "page" "file" "path" "include" "load" "view" "doc")
    for param in "${lfi_params[@]}"; do
        local normal_size
        normal_size=$(curl -s -A "$ua" --max-redirs 3 --connect-timeout 5 \
            "${target}?${param}=index" 2>/dev/null | wc -c)
        local lfi_size
        lfi_size=$(curl -s -A "$ua" --max-redirs 3 --connect-timeout 5 \
            "${target}?${param}=../../../etc/passwd" 2>/dev/null | wc -c)
        local diff=$(( lfi_size - normal_size ))
        diff="${diff#-}"
        if [[ $diff -gt 200 ]]; then
            echo -e "    ${RED}[!!!] LFI ANOMALY: $param (diff=${diff}B)${RST}"
        fi
    done

    # Phase 6 — Infrastructure
    echo -e "\n${YLW}[*] Phase 6: Infrastructure Checks${RST}"

    # AJP Ghostcat check (FIXED)
    local base_host=$(echo "$target" | sed -E 's|^(https?://)([^:/]+).*$|\1\2|')
    local ajp
    ajp=$(curl -s -o /dev/null -w "%{http_code}" --max-redirs 3 --connect-timeout 3 "${base_host}:8009/" 2>/dev/null)
    if [[ "$ajp" != "000" ]]; then
        echo -e "    ${RED}[!] AJP port 8009 OPEN — check Ghostcat CVE-2020-1938${RST}"
    else
        echo -e "    ${GRN}    [✓] AJP port 8009 closed${RST}"
    fi

    # Swagger/API exposure
    local swagger
    swagger=$(curl -s -o /dev/null -w "%{http_code}" --max-redirs 3 --connect-timeout 5 \
        "${target%/}/swagger/index.html" 2>/dev/null)
    if [[ "$swagger" == "200" ]]; then
        echo -e "    ${RED}[!] Swagger UI exposed: ${target}/swagger/index.html${RST}"
    fi

    # CGI RCE check (CVE-2019-0232)
    local cgi
    cgi=$(curl -s -A "$ua" --max-redirs 3 --connect-timeout 5 "${target%/}/cgi.exe?&dir" 2>/dev/null | wc -c)
    if [[ "$cgi" -gt 100 ]]; then
        echo -e "    ${RED}[!] cgi.exe responds (${cgi}B) — test CVE-2019-0232 RCE${RST}"
    fi

    # Login endpoint
    local login
    login=$(curl -s -o /dev/null -w "%{http_code}" --max-redirs 3 --connect-timeout 5 \
        "${target%/}/login.jsp" 2>/dev/null)
    [[ "$login" == "200" ]] && echo -e "    ${YLW}[*] Login page found: ${target}/login.jsp — try SQLi bypass${RST}"

    echo -e "\n${GRN}[+] Curl Recon Complete.${RST}"
}

# ====== MAIN ======
main() {
    local target
    echo -e "${CYN}┌──────────────────────────────────────────┐${RST}"
    echo -e "${CYN}│   Recon Advisor v2.4 - Deep Intelligence│${RST}"
    echo -e "${CYN}└──────────────────────────────────────────┘${RST}"
    read -rp "Enter target URL or domain (e.g., example.com or http://example.com): " target

    # If user didn't include scheme, try to detect HTTP/HTTPS
    if [[ "$target" != http* ]]; then
        local detected
        detected=$(check_target "$target")
        if [[ -n "$detected" ]]; then
            target="$detected"
        else
            echo -e "${RED}[!] Could not reach $target with HTTP or HTTPS (or target returned error).${RST}"
            exit 1
        fi
    else
        # Validate the target with a quick status check
        local status
        status=$(curl -s -o /dev/null -w "%{http_code}" --max-redirs 3 --connect-timeout 10 "$target" 2>/dev/null)
        if [[ $status -lt 200 || $status -ge 400 ]]; then
            echo -e "${RED}[!] Target returned HTTP $status. Not proceeding.${RST}"
            exit 1
        fi
    fi

    echo -e "\n${YLW}[*] Analyzing $target ...${RST}"

    mkdir -p "$(cd "$(dirname "$0")" && pwd)/scan_logs"
    local TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    local REPORT_JSON="$(cd "$(dirname "$0")" && pwd)/scan_logs/report_$TIMESTAMP.json"
    local ADVICE_TXT="$(cd "$(dirname "$0")" && pwd)/scan_logs/advice_$TIMESTAMP.txt"

    # ------------------------------------------------------------------
    # 1. Basic HTTP analysis
    # ------------------------------------------------------------------
    local headers=$(curl -sfI -H "X-Forwarded-For: $(random_ip)" -A "$(random_ua)" --fail --max-redirs 3 "$target" 2>/dev/null)
    local html=$(curl -sL -H "X-Forwarded-For: $(random_ip)" -A "$(random_ua)" --fail --max-redirs 3 "$target" 2>/dev/null)
    curl_recon "$target"

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
    local full_tech
    full_tech=$(echo "${tech},${guess_tech}" | sed 's/^,//;s/,$//')

    # Extract parameters from HTML
    local params=$(echo "$html" | grep -oE '(name|id)="[^"]*"' | sed -E 's/.*="([^"]+)"/\1/' | sort -u)
    params+=$'\n'"$(echo "$html" | grep -oE 'href="[^"]*\?[^"]*"' | grep -oE '\?[^"#]*' | tr '&' '\n' | grep -oE '^[?]?[a-zA-Z_][a-zA-Z0-9_]*' | tr -d '?' | sort -u)"
    local param_list=$(echo "$params" | sort -u | grep -v '^$' | head -n 20 | tr '\n' ',' | sed 's/,$//')

    # ------------------------------------------------------------------
    # 2. Port scanning
    # ------------------------------------------------------------------
    local domain=$(echo "$target" | awk -F/ '{print $3}' | cut -d: -f1)
    local ports_to_scan="80,443,8080,8443,22,21,25,3306,5432,27017"
    echo -e "${YLW}[*] Scanning ports: $ports_to_scan${RST}"
    local open_ports=$(fast_port_scan "$domain" "$ports_to_scan")
    echo -e "${YLW}[*] Open ports: ${open_ports:-none}${RST}"

    # ------------------------------------------------------------------
    # 3. whatweb (optional)
    # ------------------------------------------------------------------
    local whatweb_tech=""
    if command -v whatweb &>/dev/null; then
        echo -e "${YLW}[*] Running whatweb...${RST}"
        local ww_out=$(whatweb --color=never --quiet "$target" 2>/dev/null)
        whatweb_tech=$(echo "$ww_out" | grep -oE '\[[^]]+\]' | tr -d '[]' | sort -u | tr '\n' ',' | sed 's/,$//')
    fi

    # ------------------------------------------------------------------
    # 4. subfinder (optional)
    # ------------------------------------------------------------------
    local subdomains=""
    if command -v subfinder &>/dev/null; then
        echo -e "${YLW}[*] Running subfinder...${RST}"
        subdomains=$(subfinder -d "$domain" -silent 2>/dev/null | head -20 | tr '\n' ',')
        subdomains=${subdomains%,}
    fi

    # ------------------------------------------------------------------
    # 5. Origin IP discovery from subdomains
    # ------------------------------------------------------------------
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

    # ------------------------------------------------------------------
    # 6. Recommendations
    # ------------------------------------------------------------------
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

    # ------------------------------------------------------------------
    # 7. Write JSON report (with jq for proper escaping)
    # ------------------------------------------------------------------
    if command -v jq &>/dev/null; then
        jq -n \
            --arg target "$target" \
            --arg timestamp "$TIMESTAMP" \
            --argjson waf "$waf" \
            --arg technologies "$full_tech" \
            --arg whatweb_tech "$whatweb_tech" \
            --arg parameters "$param_list" \
            --arg open_ports "$open_ports" \
            --arg subdomains "$subdomains" \
            --arg origin_ips "$origin_ips" \
            --arg recommended_delay "$delay" \
            --arg recommended_attacks "$attack_suggestions" \
            --arg sample_payloads "$(echo "$payload_suggestions" | tr '\n' ' ' | sed 's/ $//')" \
            '{
                target: $target,
                timestamp: $timestamp,
                waf_detected: $waf,
                technologies: $technologies,
                whatweb_tech: $whatweb_tech,
                parameters: $parameters,
                open_ports: $open_ports,
                subdomains: $subdomains,
                origin_ips: $origin_ips,
                recommended_delay: $recommended_delay,
                recommended_attacks: $recommended_attacks,
                sample_payloads: $sample_payloads
            }' > "$REPORT_JSON"
    else
        # Fallback to heredoc (may break if parameters contain quotes)
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
    fi

    # ------------------------------------------------------------------
    # 8. Write plain text advice
    # ------------------------------------------------------------------
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
    echo -e "\n${GRN}[+] Advice saved. Latest report: ~/scan_logs/latest_report.json${RST}"

    # ------------------------------------------------------------------
    # 9. Optional: check test sites (ask user)
    # ------------------------------------------------------------------
    read -p "Do you want to check known test sites? (y/N): " check_opt
    if [[ "$check_opt" =~ ^[Yy]$ ]]; then
        check_test_sites
        cat "$ADVICE_TXT" | tail -n 20
    fi

    # ------------------------------------------------------------------
    # 10. Launch modern fuzzer with collected intel
    # ------------------------------------------------------------------
    read -p "Do you want to launch the modern fuzzer with these settings? (y/N): " launch_opt
    if [[ "$launch_opt" =~ ^[Yy]$ ]]; then
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

main "$@"

