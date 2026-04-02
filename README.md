```
                    :::!~!!!!!:.
                .xUHWH!! !!?M88WHX:.
              .X*#M@$!!  !X!M$$$$$$WWx:.
             :!!!!!!?H! :!$!$$$$$$$$$$8X:
            !!~  ~:~!! :~!$!#$$$$$$$$$$8X:
           :!~::!H!<   ~.U$X!?R$$$$$$$$MM!
           ~!~!!!!~~ .:XW$$$U!!?$$$$$$RMM!

         ██╗      ██████╗ ██╗  ██╗███████╗
         ██║     ██╔═══██╗╚██╗██╔╝██╔════╝
         ██║     ██║   ██║ ╚███╔╝ ███████╗
         ██║     ██║   ██║ ██╔██╗ ╚════██║
         ███████╗╚██████╔╝██╔╝ ██╗███████║
         ╚══════╝ ╚═════╝ ╚═╝  ╚═╝╚══════╝
```

# Zig_Scanner v3.1 — JDT-Mobile Edition
> **Termux-native web vulnerability scanner. Non-root. Cyberpunk. No mercy.**

![Shell](https://img.shields.io/badge/Shell-Bash-1a1a2e?style=flat-square&logo=gnubash&logoColor=00ff9f)
![Platform](https://img.shields.io/badge/Platform-Termux%20%7C%20Android-1a1a2e?style=flat-square&logo=android&logoColor=00ff9f)
![Status](https://img.shields.io/badge/Status-Active-1a1a2e?style=flat-square&color=00ff9f)
![License](https://img.shields.io/badge/License-MIT-1a1a2e?style=flat-square&color=00ff9f)

---

## 〉 What Is This

Zig_Scanner is a modular, Termux-optimized recon and vulnerability scanning framework written in Bash with Python bridge modules. Designed for Android non-root environments — no `sudo`, no desktop, no excuses.

Built for legal penetration testing, CTF targets, and bug bounty recon.

---

## 〉 Features

| Module | Description |
|---|---|
| `WAF Detection` | Fingerprints Cloudflare, Sucuri, Akamai, ModSecurity, Incapsula via headers |
| `Honeypot Detection` | Runs `honeydetect.py` to flag deception infrastructure |
| `Port Scanner` | Nmap non-root safe mode — top 20 ports, service + version detection |
| `NSE Scripts` | Safe + aggressive Nmap script sets with auto CSV/XML export |
| `Geolocation` | IP → country/city/ASN via `checkip.py` + `jq` pretty-print |
| `SQL Injection` | 6-payload JDT-Mobile SQLi probe with rotating IPs and user agents |
| `Header Analysis` | Full HTTP response header dump |
| `Anti-Cloaking` | Detects content served differently to bots vs mobile browsers |
| `Steganography Scan` | Asset analysis via `defender_scan.py` |
| `XSS Fuzzing` | WAF bypass fuzzing module |
| `Threat Intel` | Auto-updates IP blacklist DB from external C2 feed |
| `CSV Export` | Every NSE scan auto-exports structured `.csv` + `.xml` to `scan_logs/` |
| `Auto-Vault Sync` | Git push scan results to private repo after each run |

---

## 〉 Requirements

### Termux Packages
```bash
pkg install nmap python curl git jq dnsutils
```

### Python Dependencies
```bash
pip install requests
```

### Optional Python Scripts (place in `~/Zig_Scanner/`)
| File | Purpose |
|---|---|
| `checkip.py` | Geolocation lookup |
| `honeydetect.py` | Honeypot detection |
| `analyzer.py` | Deep payload analysis (JDT bridge) |
| `defender_scan.py` | Steganography asset scanner |

### PayloadsAllTheThings (optional but recommended)
```bash
cd ~/Zig_Scanner
git clone https://github.com/swisskyrepo/PayloadsAllTheThings.git
```

---

## 〉 Installation

```bash
# Clone the repo
git clone https://github.com/shamr0ck3/Zig_Scanner.git
cd Zig_Scanner

# Make executable
chmod +x intelijen_v3.sh

# Run
bash intelijen_v3.sh
```

---

## 〉 Usage

```bash
bash intelijen_v3.sh
```

```
Enter Target (domain/IP/URL): demo.testfire.net
Enable aggressive mode? (y/N): y
```

The scanner will run the full recon pipeline automatically:

```
[1] WAF Detection
[2] Honeypot Scan
[3] Port Scan
[4] NSE Script Scan  →  auto-exports CSV + XML
[5] Geolocation
[6] Header Analysis
[7] Anti-Cloaking Check
[8] Threat Intel Check
[9] XSS Fuzz
[10] SQL Injection Probe
[✓] Auto-Vault Sync → git push
```

---

## 〉 Output Files

All outputs saved to `scan_logs/`:

| File | Description |
|---|---|
| `scan_results_TIMESTAMP.log` | Full human-readable scan log |
| `nmap_HOST_TIMESTAMP.xml` | Raw Nmap XML output |
| `nmap_HOST_TIMESTAMP.csv` | Structured CSV — port, service, version, script output (base64) |
| `report_TIMESTAMP.json` | JSON report (Python bridge) |

---

## 〉 Standalone Tools

### `nmap2csv.sh`
Convert any existing Nmap XML or log file to CSV:

```bash
# Single XML
./nmap-nse-scripts/nmap2csv.sh scan_logs/nmap_target_20260402.xml

# Plain-text log
./nmap-nse-scripts/nmap2csv.sh scan_logs/scan_results_20260402.log

# Batch convert entire folder
./nmap-nse-scripts/nmap2csv.sh scan_logs/
```

---

## 〉 Project Structure

```
Zig_Scanner/
├── intelijen_v3.sh          # Main scanner
├── checkip.py               # Geolocation module
├── honeydetect.py           # Honeypot detection module
├── analyzer.py              # JDT Python bridge
├── defender_scan.py         # Steganography scanner
├── waf_bypass.sh            # WAF bypass fuzzer
├── csv_logger.sh            # CSV logging utility
├── nmap-nse-scripts/
│   ├── nmap2csv.sh          # Standalone XML→CSV converter
│   ├── scripts/             # Custom NSE scripts
│   └── data/
├── scan_logs/               # All scan output (auto-generated)
├── backups/                 # Script version backups
├── PayloadsAllTheThings/    # Payload library (git submodule)
└── .gitignore
```

---

## 〉 Legal Disclaimer

> This tool is intended **strictly for authorized penetration testing, CTF competitions, and security research** on systems you own or have explicit written permission to test.
>
> Unauthorized scanning of systems you do not own is **illegal** under computer crime laws in most jurisdictions including the Computer Fraud and Abuse Act (CFAA), the Computer Misuse Act (CMA), and equivalent local legislation.
>
> The author assumes **zero liability** for misuse of this tool. Use responsibly.

---

## 〉 Author

**JDT-Mobile** — [`shamr0ck3`](https://github.com/shamr0ck3)
Blog: [Chaos Code](https://chaoscod3.blogspot.com)

---

*Built in Termux. Runs on vibes and caffeine.*
