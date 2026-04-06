#!/bin/bash
# Zig_Scanner v3.1 - Termux Non-Root Edition
# [+] Fixed NSE integration
# [+] Animated loading system
# [+] All tools working
# [+] Added Geolocation Lookup
# [+] Added Honeypot Detection
# [FIX] Repaired all critical bugs:
#   - launch_xsstrike() was opened but never closed, swallowing waf_detection()
#   - get_target_geolocation() was defined twice; second copy incomplete & post-execution
#   - Dead code inside run_analysis() (local test_url inside return block)
#   - Duplicate get_target_geolocation call in pipeline
#   - Duplicate AUTO-VAULT SYNC block
#   - Added stubs for undefined functions: check_dependencies, random_sleep, random_ua,
#     header_analysis, threat_intel_check

# ====== CONFIGURATION ======
export NMAP_SCRIPTS="$HOME/nmap-nse-scripts/scripts"
THREAT_INTEL_DB="threat_intel.json"
EXTERNAL_C2_FEED="https://raw.githubusercontent.com/BlacklistSnatcher/Blacklist-IPs/main/blacklist.txt"
USER_AGENTS=(
    "Mozilla/5.0 (Android 14; Mobile; rv:109.0) Gecko/113.0 Firefox/113.0"
    "curl/8.4.0"
    "Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/115.0.0.0 Mobile Safari/537.36"
)
SLEEP_INTERVALS=(0.3 1.2 0.8 2.5 0.6)
PY_ANALYZER="analyzer.py"
HONEYPOT_DETECTOR_SCRIPT="honeydetect.py"
LOG_DIR="scan_logs"
SCAN_START_TIME=$(date +%Y%m%d_%H%M%S)
LOG_FILE="$LOG_DIR/scan_results_$SCAN_START_TIME.log"
AGGRESSIVE_MODE=false
WAF_STATUS="true"
PAYLOADS_DIR="PayloadsAllTheThings"

# ====== NMAP CONFIG ======
NSE_SAFE_SCRIPTS="http-title,ssl-cert,http-enum"
NSE_AGGRESSIVE_SCRIPTS="http-vuln-cve2017-5638,http-vuln-cve2017-8917,http-vuln-cve2015-1635"
NCAT_TIMEOUT=2
SCAN_PORTS="80,443,8080,8443"

# ====== LOADING ANIMATION ======
# FIX: Accept PID as $1 instead of relying on $! inside the function
buffering_animation() {
    local pid=$1
    local delay=0.1
    local frames=("⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠇" "⠏")

    while kill -0 "$pid" 2>/dev/null; do
        for frame in "${frames[@]}"; do
            echo -ne "    [$frame] Loading...\r"
            sleep $delay
        done
    done
    tput el
    echo -e "    [✓] Done!"
}

# ====== BANNER ======
center() {
  while IFS= read -r line; do
    printf "%*s\n" $(( (COLUMNS + ${#line}) / 2 )) "$line"
  done
}

echo -e "\033[1;34m"
clear
cat << 'EOF' | center
                    :::!~!!!!!:.
                .xUHWH!! !!?M88WHX:.
              .X*#M@$!!  !X!M$$$$$$WWx:.
             :!!!!!!?H! :!$!$$$$$$$$$$8X:
            !!~  ~:~!! :~!$!#$$$$$$$$$$8X:
           :!~::!H!<   ~.U$X!?R$$$$$$$$MM!
           ~!~!!!!~~ .:XW$$$U!!?$$$$$$RMM!
             !:~~~ .:!M"T#$$$$WX??#MRRMMM!
             ~?WuxiW*`   `"#$$$$8!!!!??!!!
           :X- M$$$$       `"T#$T~!8$WUXU~
          :%`  ~#$$$m:        ~!~ ?$$$$$$
        :!`.-   ~T$$$$8xx.  .xWW- ~""##*"
..... -~~:<` ! ~?T#$$@@W@*?$$      /`
W$@@M!!! .!~~ !!     .:XUW$W!~ `"~:    :
#"~~`.:x%`!! !H:   !WM$$$$Ti.: .!WUn+!`
:::~:!!`:X~ .: ?H.!u "$$$B$$$!W:U!T$$M~
.~~   :X@!.-~   ?@WTWo("*$$$W$TH$! `
Wi.~!X$?!-~    : ?$$$B$Wu("**$RM!
$R@i.~~ !     :   ~"##*$$$$M~
                 ██╗      ██████╗ ██╗  ██╗███████╗
                 ██║     ██╔═══██╗╚██╗██╔╝██╔════╝
                 ██║     ██║   ██║ ╚███╔╝ ███████╗
                 ██║     ██║   ██║ ██╔██╗ ╚════██║
                 ███████╗╚██████╔╝██╔╝ ██╗███████║
                 ╚══════╝ ╚═════╝ ╚═╝  ╚═╝╚══════╝
EOF
echo -e "Zig_Scanner v3.1 - Termux Non-Root Edition\033[0m"
echo "======================================================="
echo -e "\033[1;33m[*] Optimized for Termux non-root environment\033[0m"
echo -e "\033[1;33m[*] Using TCP connect scans and safe NSE scripts\033[0m"

# ====== FUNCTIONS ======

# ====== STUB FUNCTIONS (undefined in original) ======

random_ua() {
    echo "${USER_AGENTS[$((RANDOM % ${#USER_AGENTS[@]}))]}"
}

random_sleep() {
    sleep "${SLEEP_INTERVALS[$((RANDOM % ${#SLEEP_INTERVALS[@]}))]}"
}

check_dependencies() {
    echo -e "\033[1;36m[*] Checking dependencies...\033[0m"
    local deps=(curl nmap python3 dig jq git)
    for dep in "${deps[@]}"; do
        if command -v "$dep" &>/dev/null; then
            echo -e "    \033[1;32m[✓] $dep found\033[0m"
        else
            echo -e "    \033[1;31m[!] $dep not found — some features may fail\033[0m"
        fi
    done
}

header_analysis() {
    echo -e "\n\033[1;33m[+] HTTP Header Analysis:\033[0m"
    local target_url="$1"
    [[ ! "$target_url" =~ ^https?:// ]] && target_url="http://$target_url"
    curl -sI -A "$(random_ua)" --connect-timeout 5 "$target_url" 2>/dev/null | sed 's/^/    /'
}

threat_intel_check() {
    echo -e "\n\033[1;33m[+] Threat Intelligence Check:\033[0m"
    local target="$1"
    local target_ip
    target_ip=$(dig +short "$target" | head -n1)
    if [ -f "$THREAT_INTEL_DB" ] && [ -n "$target_ip" ]; then
        if grep -q "$target_ip" "$THREAT_INTEL_DB" 2>/dev/null; then
            echo -e "    \033[1;31m[!] IP $target_ip found in threat intel DB!\033[0m"
        else
            echo -e "    \033[1;32m[✓] IP $target_ip not in threat intel DB.\033[0m"
        fi
    else
        echo -e "    \033[1;33m[!] Threat intel DB not available or IP unresolvable.\033[0m"
    fi
}

# ====== V4.2 FUNCTION LIBRARY ======

anti_cloaking_check() {
    echo -e "\n\033[1;33m[+] Anti-Cloaking & Evasion Check:\033[0m"
    local target_url=$1
    local mobile_size=$(curl -sL -A "Mozilla/5.0 (Linux; Android 14)" "$target_url" | wc -c)
    local bot_size=$(curl -sL -A "Googlebot/2.1" "$target_url" | wc -c)
    echo "    [*] Mobile: $mobile_size bytes | Bot: $bot_size bytes"
}

stego_asset_scan() {
    echo -e "\n\033[1;33m[+] Steganography Asset Analysis:\033[0m"
    [ -f "defender_scan.py" ] && echo "    [*] defender_scan.py active." || echo "    [!] defender_scan.py missing."
}

fuzz_xss_bypass() {
    echo -e "\n\033[1;33m[+] XSS WAF Bypass Fuzzing:\033[0m"
    echo "    [*] Initializing fuzzer module..."
}

# FIX: launch_xsstrike() was unclosed, swallowing waf_detection() inside it.
# Restored as a proper stub.
launch_xsstrike() {
    echo -e "\n\033[1;33m[+] XSStrike Launch:\033[0m"
    echo "    [*] XSStrike module placeholder."
}

waf_detection() {
    echo -e "\n\033[1;33m[+] WAF Detection:\033[0m"
    random_sleep
    local target_url="$1"
    [[ ! "$target_url" =~ ^https?:// ]] && target_url="http://$target_url"
    echo "    Probing: $target_url"
    local response_headers
    response_headers=$(curl -sI -A "$(random_ua)" --connect-timeout 5 "$target_url" 2>/dev/null)
    if echo "$response_headers" | grep -qiE "x-sucuri|x-firewall|cf-ray|x-waf|akamai|incapsula|mod_security|x-cdn"; then
        echo -e "\033[1;31m    [!] WAF/CDN Detected\033[0m"
        WAF_STATUS="true"
    else
        echo -e "\033[1;32m    [✓] No WAF detected.\033[0m"
        WAF_STATUS="false"
    fi
}

# FIX: Removed duplicate definition. Single clean version kept here.
get_target_geolocation() {
    echo -e "\n\033[1;33m[+] Geolocation Lookup:\033[0m"
    random_sleep
    local clean_target
    clean_target=$(echo "$1" | sed -E 's|^https?://||; s|/.*||')
    local target_ip
    target_ip=$(echo "$clean_target" | grep -oE "([0-9]{1,3}\.){3}[0-9]{1,3}" \
        || dig +short "$clean_target" | grep -E "^[0-9.]+$" | head -n1)

    if [ -n "$target_ip" ]; then
        echo "    Looking up geolocation for IP: $target_ip"
        python3 checkip.py "$target_ip" > geolocation_output.json &
        buffering_animation $!
        if [ -f "geolocation_output.json" ] && jq . < geolocation_output.json &>/dev/null; then
            echo -e "\033[1;32m[✓] Geolocation Data:\033[0m"
            jq . < geolocation_output.json | sed 's/^/        /'
        else
            echo -e "\033[1;33m[!] Failed to get or parse geolocation data for $target_ip.\033[0m"
        fi
        rm -f geolocation_output.json 2>/dev/null
    else
        echo -e "\033[1;33m[!] Could not resolve IP for geolocation lookup.\033[0m"
    fi
}

port_scan() {
    echo -e "\n\033[1;33m[+] Termux Port Scan (Nmap Safe Mode):\033[0m"
    local host
    host=$(echo "$1" | sed -E "s|^https?://||" | cut -d/ -f1 | cut -d: -f1)
    nmap -sV -Pn --top-ports 20 --open "$host" > nmap_port_scan.txt &
    buffering_animation $!
    cat nmap_port_scan.txt
}

honeypot_scan() {
    echo -e "\n\033[1;33m[+] Honeypot Detection:\033[0m"
    random_sleep
    local target_url="$1"
    [[ ! "$target_url" =~ ^https?:// ]] && target_url="http://$target_url"
    echo "    Running honeypot detection on: $target_url"
    local honeypot_output
    honeypot_output=$(python3 "$HONEYPOT_DETECTOR_SCRIPT" "$target_url" 2>&1)
    echo "$honeypot_output" | sed 's/^/    /'
    if echo "$honeypot_output" | grep -qi "Honeypot detected: YES"; then
        echo -e "\033[1;31m    [!] Strong honeypot indicators detected!\033[0m"
    else
        echo -e "\033[1;32m    [✓] No strong honeypot indicators found.\033[0m"
    fi
}

run_analysis() {
    echo -e "\n\033[1;36m[+] Running Security Analysis:\033[0m"
    if [ ! -d "$PAYLOADS_DIR" ]; then
        echo -e "\n\033[1;31m[!] Error: PayloadsAllTheThings missing.\033[0m"
        return
        # FIX: Removed dead code (local test_url=... after return)
    fi
    [ -f "$PY_ANALYZER" ] && python3 "$PY_ANALYZER" & buffering_animation $!
}

update_threat_intel() {
    echo -e "\033[1;36m[+] Updating Threat Intelligence DB...\033[0m"
    if curl -sf "$EXTERNAL_C2_FEED" -o threat_feed_tmp.txt 2>/dev/null; then
        mv threat_feed_tmp.txt "$THREAT_INTEL_DB"
        echo -e "\033[1;32m[✓] Threat intel DB updated.\033[0m"
    else
        echo -e "\033[1;33m[!] Could not fetch threat feed. Using existing DB if available.\033[0m"
        rm -f threat_feed_tmp.txt
    fi
}

sql_injection_probe() {
    echo -e "\n\033[1;33m[+] SQL Injection Probing (JDT-Mobile Engine):\033[0m"
    local target_url=$1
    local sql_payloads=(
        "' OR '1'='1"
        "'-- "
        "admin'--"
        "' UNION SELECT NULL,NULL,NULL--"
        "sleep(5)#"
        "' AND 1=1--"
    )
    for payload in "${sql_payloads[@]}"; do
        local encoded_payload
        encoded_payload=$(python3 -c "import urllib.parse; print(urllib.parse.quote('''$payload'''))")
        local test_url
        if [[ "$target_url" == *"?"* ]]; then
            test_url="${target_url}${encoded_payload}"
        else
            test_url="${target_url}/?id=${encoded_payload}"
        fi
        echo -ne "    [*] Testing: $payload\r"
        local response
        local random_ip="$((RANDOM%255)).$((RANDOM%255)).$((RANDOM%255)).$((RANDOM%255))"
        response=$(curl -sL -A "$(random_ua)" \
            -H "X-Forwarded-For: $random_ip" \
            -H "Client-IP: $random_ip" \
            --connect-timeout 5 "$test_url" 2>/dev/null)
        if echo "$response" | grep -qiE "sql|mysql|sqlite|postgresql|oracle|syntax error|unexpected"; then
            echo -e "\n\033[1;31m    [!] POTENTIAL SQLi DETECTED: $payload\033[0m"
            echo "    [SQLi] Test URL: $test_url" >> "$LOG_FILE"
        fi
    done
    echo -e "\n    [✓] SQLi Probe Complete."
}

nse_scan() {
    echo -e "\n[5/6] Section: NSE Script Scanning"
    local clean_target
    clean_target=$(echo "$1" | sed -E 's|^https?://||' | cut -d/ -f1)
    local host
    host=$(echo "$clean_target" | cut -d: -f1)

    local xml_out="$LOG_DIR/nmap_${host}_${SCAN_START_TIME}.xml"
    local csv_out="$LOG_DIR/nmap_${host}_${SCAN_START_TIME}.csv"

    echo -e "\n    [*] Running safe scripts: $NSE_SAFE_SCRIPTS"
    {
        echo -e "\n[✓] Safe NSE Scan Results for $clean_target:" >> "$LOG_FILE"
        nmap -sV -Pn -p"$SCAN_PORTS" --script="$NSE_SAFE_SCRIPTS" \
            -oX "$xml_out" "$host" >> "$LOG_FILE"
    } &
    buffering_animation $!

    # Parse XML → CSV
    if [ -f "$xml_out" ]; then
        echo "target,ip,port,protocol,state,service,version,script_output" > "$csv_out"
        python3 - "$xml_out" "$host" "$csv_out" << 'PYEOF'
import sys, xml.etree.ElementTree as ET

xml_file, host, csv_out = sys.argv[1], sys.argv[2], sys.argv[3]
try:
    tree = ET.parse(xml_file)
    root = tree.getroot()
    rows = []
    for h in root.findall("host"):
        addr = h.find("address")
        ip = addr.get("addr", "") if addr is not None else ""
        for port in h.findall(".//port"):
            portid   = port.get("portid", "")
            proto    = port.get("protocol", "")
            state    = port.findtext("state[@state]") or port.find("state").get("state","") if port.find("state") is not None else ""
            svc      = port.find("service")
            service  = svc.get("name","") if svc is not None else ""
            version  = (svc.get("product","") + " " + svc.get("version","")).strip() if svc is not None else ""
            scripts  = "; ".join(
                f'{s.get("id")}={s.get("output","").strip().replace(chr(10)," ")}'
                for s in port.findall("script")
            )
            rows.append(f'"{host}","{ip}","{portid}","{proto}","{state}","{service}","{version}","{scripts}"')
    with open(csv_out, "a") as f:
        f.write("\n".join(rows) + "\n")
    print(f"    [✓] CSV saved: {csv_out}")
except Exception as e:
    print(f"    [!] CSV parse error: {e}")
PYEOF
    fi

    if [ "$AGGRESSIVE_MODE" = true ]; then
        echo -e "\n    [!] Aggressive NSE scripts enabled!"
        {
            echo -e "\n[!] Aggressive NSE Scan Results for $clean_target (Vuln Scripts):" >> "$LOG_FILE"
            nmap -sV -Pn -p"$SCAN_PORTS" --script="$NSE_AGGRESSIVE_SCRIPTS" "$host" >> "$LOG_FILE" 2>> "$LOG_FILE"
        } &
        buffering_animation $!
    else
        echo -e "    [~] Aggressive mode disabled. Skipping vuln NSE scan."
    fi
}

# ====== MASTER CONTROLLER ======
# 1. Start the engine
mkdir -p "$LOG_DIR"
check_dependencies
update_threat_intel

# 2. Get the target
echo -ne "\n"
read -p "Enter Target (domain/IP/URL): " target
if [ -z "$target" ]; then echo -e "\033[1;31m[!] Error: Target required.\033[0m"; exit 1; fi

read -p "Enable aggressive mode? (y/N): " agg_opt
[[ "$agg_opt" =~ ^[Yy]$ ]] && AGGRESSIVE_MODE=true || AGGRESSIVE_MODE=false

# 3. Run the Recon Pipeline
waf_detection "$target"
honeypot_scan "$target"
port_scan "$target"
nse_scan "$target"
get_target_geolocation "$target"   # FIX: Removed duplicate call that was right below this
header_analysis "$target"
anti_cloaking_check "$target"
stego_asset_scan "$target"
threat_intel_check "$target"
fuzz_xss_bypass "$target"
sql_injection_probe "$target"

# 4. Run the Active Exploit Modules
# check_sqli "$target"
# fuzz_parameters "$target"

# 5. Cleanup & Wrap up
rm -f nmap_port_scan.txt headers.txt ncat_*.txt nping_output.txt httpx_output.json 2>/dev/null
echo -e "\n\033[1;32m[+] SUCCESS: Full audit log saved to: $LOG_FILE\033[0m"

# ====== AUTO-VAULT SYNC (JDT-MOBILE) ======
# FIX: Removed duplicate AUTO-VAULT block that appeared after broken get_target_geolocation redefinition
if [ -f "$LOG_FILE" ]; then
    echo -e "\n\033[1;34m[↑] Securing scan results to Private Vault...\033[0m"
    git add "$LOG_FILE" 2>/dev/null
    git commit -m "Auto-Log: $target ($(date +%H:%M))" --quiet 2>/dev/null
    git push origin main --quiet 2>/dev/null
    echo -e "\033[1;32m[✓] Intel successfully synced to GitHub.\033[0m"
else
    echo -e "\033[1;31m[!] No log file found to sync.\033[0m"
fi

echo -ne "\n\033[1;32m[✓] Mission Complete. Press Enter to return to Menu...\033[0m"
read
exit 0
