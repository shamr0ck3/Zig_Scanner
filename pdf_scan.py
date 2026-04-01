import os
import sys
import subprocess
import requests
import datetime
import json
import shutil
from urllib.parse import urljoin, urlparse

# ================= AUTO INSTALL =================

required = ["flask", "flask_sqlalchemy", "beautifulsoup4", "requests"]
for pkg in required:
    try:
        __import__(pkg.replace("-", "_") if pkg != "beautifulsoup4" else "bs4")
    except ImportError:
        print(f"[+] Installing missing dependency: {pkg}")
        subprocess.check_call([sys.executable, "-m", "pip", "install", pkg, "--quiet"])

# ================= IMPORTS =================

from flask import Flask, request, render_template_string, jsonify, Response
from flask_sqlalchemy import SQLAlchemy
from bs4 import BeautifulSoup

# ================= BANNER =================

print(r"""
    __  ___  ___    ____ ___  _  _    ____ _  _ ____
    |__] |  \ |__]   [__  |    |__|   |___  \/  |___
    |    |__/ |      ___] |___ |  | . |___ _/\_ |___
    ================================================
    [ LOXS OMNI ] [ CLAMAV INTEGRATED ] [ v3.1 ]
""")

# ================= APP CONFIG =================

app = Flask(__name__)
app.config['SQLALCHEMY_DATABASE_URI'] = 'sqlite:///scan_logs/pdf_scanner.db'
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False
db = SQLAlchemy(app)

BASE_DIR = os.path.expanduser("~/Zig_Scanner/pdf_samples/")
os.makedirs(BASE_DIR, exist_ok=True)

# ================= MODELS =================

class ScanLog(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    filename = db.Column(db.String(255))
    url = db.Column(db.String(500))
    risk = db.Column(db.String(20))
    detail = db.Column(db.Text)
    timestamp = db.Column(db.DateTime, default=datetime.datetime.utcnow)

with app.app_context():
    db.create_all()

# ================= STYLE =================

STYLE = """
<style>
@import url('https://fonts.googleapis.com/css2?family=Share+Tech+Mono&family=Orbitron:wght@400;700;900&display=swap');
:root {
    --bg: #02050a; --panel: #0d1520; --border: #1a2840;
    --cyan: #00ffe7; --green: #00ff88; --red: #ff2244;
    --yellow: #ffe500; --text: #a0c8e0; --muted: #4a6080;
}
* { box-sizing: border-box; margin: 0; padding: 0; }
body {
    background: var(--bg); color: var(--text);
    font-family: 'Share Tech Mono', monospace;
    background-image: linear-gradient(var(--border) 1px, transparent 1px),
                      linear-gradient(90deg, var(--border) 1px, transparent 1px);
    background-size: 40px 40px;
}
.container { max-width: 900px; margin: 30px auto; padding: 16px; }
header {
    text-align: center; margin-bottom: 24px;
    border: 1px solid var(--cyan); padding: 20px;
    background: rgba(0,0,0,0.85);
    clip-path: polygon(0 0, calc(100% - 20px) 0, 100% 20px, 100% 100%, 20px 100%, 0 calc(100% - 20px));
}
h1 { font-family: 'Orbitron'; font-size: 2rem; color: var(--cyan); letter-spacing: 4px; }
h1 span { color: var(--green); }
.badge { font-size: 10px; color: var(--muted); letter-spacing: 3px; margin-top: 4px; }
.panel { background: var(--panel); border: 1px solid var(--border); padding: 18px; margin-bottom: 16px; }
.t-header { font-size: 11px; color: var(--cyan); margin-bottom: 12px; letter-spacing: 2px; }
input[type="text"] {
    width: 100%; padding: 11px; background: #000;
    border: 1px solid var(--border); color: var(--cyan);
    font-family: 'Share Tech Mono'; outline: none; font-size: 13px;
}
input:focus { border-color: var(--cyan); box-shadow: 0 0 10px rgba(0,255,231,0.15); }
.btn {
    display: inline-block; padding: 11px 22px; background: transparent;
    border: 1px solid var(--green); color: var(--green);
    font-family: 'Orbitron'; font-size: 11px; cursor: pointer;
    margin-top: 12px; letter-spacing: 2px; transition: 0.2s;
}
.btn:hover { background: var(--green); color: var(--bg); box-shadow: 0 0 15px var(--green); }
.btn:disabled { opacity: 0.4; cursor: not-allowed; }

/* Progress bar */
#progressWrap { display: none; margin-top: 14px; }
#progressLabel { font-size: 11px; color: var(--cyan); margin-bottom: 6px; letter-spacing: 1px; }
#progressBar {
    width: 100%; height: 6px; background: #0a1520;
    border: 1px solid var(--border); position: relative; overflow: hidden;
}
#progressFill {
    height: 100%; width: 0%; background: var(--cyan);
    box-shadow: 0 0 8px var(--cyan); transition: width 0.3s;
}

/* Console log */
#consoleLog {
    height: 160px; overflow-y: auto; background: #000; padding: 12px;
    border: 1px solid var(--border); font-size: 11px; line-height: 1.7;
}
#consoleLog::-webkit-scrollbar { width: 3px; }
#consoleLog::-webkit-scrollbar-thumb { background: var(--muted); }
.log-info { color: var(--muted); }
.log-ok   { color: var(--green); }
.log-err  { color: var(--red); }
.log-warn { color: var(--yellow); }
.log-cyan { color: var(--cyan); }

/* Stats row */
.stats { display: grid; grid-template-columns: repeat(3,1fr); gap: 10px; margin-bottom: 16px; }
.stat-box { background: var(--panel); border: 1px solid var(--border); padding: 14px; text-align: center; }
.stat-num { font-family: 'Orbitron'; font-size: 24px; font-weight: 700; display: block; }
.stat-label { font-size: 9px; color: var(--muted); letter-spacing: 2px; margin-top: 4px; display: block; }
.cyan-num { color: var(--cyan); text-shadow: 0 0 8px var(--cyan); }
.green-num { color: var(--green); text-shadow: 0 0 8px var(--green); }
.red-num { color: var(--red); text-shadow: 0 0 8px var(--red); }

/* Table */
table { width: 100%; border-collapse: collapse; }
th { text-align: left; color: var(--cyan); border-bottom: 1px solid var(--cyan); padding: 9px 10px; font-size: 11px; letter-spacing: 1px; }
td { padding: 9px 10px; border-bottom: 1px solid var(--border); font-size: 12px; word-break: break-all; }
.risk-SAFE   { color: var(--green); font-weight: bold; }
.risk-DANGER { color: var(--red); font-weight: bold; animation: pulse 1s infinite; }
.risk-ERROR  { color: var(--yellow); }
.risk-SCANNING { color: var(--cyan); animation: pulse 0.7s infinite; }
@keyframes pulse { 0%,100% { opacity: 1; } 50% { opacity: 0.3; } }

/* Scanning row animation */
.scanning-row td { opacity: 0.6; }

footer { text-align: center; margin-top: 30px; color: var(--muted); font-size: 10px; letter-spacing: 1px; }
</style>
"""

# ================= HOME ROUTE =================

@app.route("/")
def home():
    logs = ScanLog.query.order_by(ScanLog.timestamp.desc()).limit(20).all()
    safe_count  = ScanLog.query.filter_by(risk='SAFE').count()
    danger_count= ScanLog.query.filter_by(risk='DANGER').count()
    total_count = ScanLog.query.count()

    rows = ""
    for log in logs:
        rows += f"""<tr>
            <td title="{log.url}">{log.filename}</td>
            <td>{log.detail}</td>
            <td><span class="risk-{log.risk}">{log.risk}</span></td>
            <td style="color:var(--muted);font-size:10px;">{log.timestamp.strftime('%H:%M:%S')}</td>
        </tr>"""

    return render_template_string("""<!DOCTYPE html>
<html><head><meta charset="UTF-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>PDF_SCAN.EXE v3.1</title>""" + STYLE + """</head>
<body>
<div class="container">

  <header>
    <div class="badge">[ LOXS OMNI SECURITY // CLAMAV INTEGRATED ]</div>
    <h1>PDF<span>_SCAN</span>.EXE</h1>
    <div class="badge" style="margin-top:6px;">AUTO DOWNLOAD → CLAMAV SCAN → THREAT REPORT</div>
  </header>

  <div class="stats">
    <div class="stat-box"><span class="stat-num cyan-num" id="s-total">""" + str(total_count) + """</span><span class="stat-label">TOTAL SCANNED</span></div>
    <div class="stat-box"><span class="stat-num green-num" id="s-safe">""" + str(safe_count) + """</span><span class="stat-label">SAFE</span></div>
    <div class="stat-box"><span class="stat-num red-num" id="s-danger">""" + str(danger_count) + """</span><span class="stat-label">DANGER</span></div>
  </div>

  <div class="panel">
    <div class="t-header">>> TARGET_URL_INPUT</div>
    <input type="text" id="targetUrl" placeholder="https://target-website.com/docs" autocomplete="off">
    <button class="btn" id="scanBtn" onclick="startScan()">[ INITIATE_SCAN ]</button>

    <div id="progressWrap">
      <div id="progressLabel">INITIALIZING...</div>
      <div id="progressBar"><div id="progressFill"></div></div>
    </div>
  </div>

  <div class="panel">
    <div class="t-header">>> SYSTEM_LOG</div>
    <div id="consoleLog"></div>
  </div>

  <div class="panel">
    <div class="t-header">>> ANALYSIS_REPORT</div>
    <table>
      <thead><tr><th>FILENAME</th><th>CLAMAV_RESULT</th><th>RISK</th><th>TIME</th></tr></thead>
      <tbody id="resultsTable">""" + rows + """</tbody>
    </table>
  </div>

  <footer>PDF_SCAN.EXE v3.1 // LOXS Security Suite // ClamAV Integrated // Educational Use Only</footer>
</div>

<script>
const logBox = document.getElementById('consoleLog');
let totalScanned = """ + str(total_count) + """;
let safeCount    = """ + str(safe_count) + """;
let dangerCount  = """ + str(danger_count) + """;

function addLog(msg, type='info') {
    const line = document.createElement('div');
    line.className = 'log-' + type;
    const ts = new Date().toLocaleTimeString('en-GB',{hour12:false});
    line.textContent = `[${ts}] ${msg}`;
    logBox.appendChild(line);
    logBox.scrollTop = logBox.scrollHeight;
}

function setProgress(pct, label) {
    document.getElementById('progressWrap').style.display = 'block';
    document.getElementById('progressFill').style.width = pct + '%';
    document.getElementById('progressLabel').textContent = label;
}

function updateStats() {
    document.getElementById('s-total').textContent  = totalScanned;
    document.getElementById('s-safe').textContent   = safeCount;
    document.getElementById('s-danger').textContent = dangerCount;
}

function addPendingRow(filename, pdfUrl) {
    const tbody = document.getElementById('resultsTable');
    const row = document.createElement('tr');
    row.id = 'row-' + btoa(pdfUrl).replace(/[^a-z0-9]/gi,'').slice(0,12);
    row.className = 'scanning-row';
    row.innerHTML = `<td title="${pdfUrl}">${filename}</td>
        <td id="detail-${row.id}">⬡ Downloading...</td>
        <td><span class="risk-SCANNING" id="risk-${row.id}">SCANNING</span></td>
        <td style="color:var(--muted);font-size:10px;">--:--:--</td>`;
    tbody.prepend(row);
    return row.id;
}

function updateRow(rowId, detail, risk) {
    const detailEl = document.getElementById('detail-' + rowId);
    const riskEl   = document.getElementById('risk-' + rowId);
    const row      = document.getElementById(rowId);
    if (detailEl) detailEl.textContent = detail;
    if (riskEl) {
        riskEl.className = 'risk-' + risk;
        riskEl.textContent = risk;
    }
    if (row) {
        row.className = '';
        const timeEl = row.querySelector('td:last-child');
        if (timeEl) timeEl.textContent = new Date().toLocaleTimeString('en-GB',{hour12:false});
    }
}

async function startScan() {
    const url = document.getElementById('targetUrl').value.trim();
    if (!url) return;

    document.getElementById('scanBtn').disabled = true;
    document.getElementById('resultsTable').innerHTML = '';
    logBox.innerHTML = '';

    addLog('=== PDF_SCAN.EXE v3.1 STARTED ===', 'cyan');
    addLog('Target: ' + url, 'info');
    setProgress(5, 'CRAWLING TARGET PAGE...');

    let data;
    try {
        const res = await fetch('/scan', {
            method: 'POST',
            headers: {'Content-Type': 'application/json'},
            body: JSON.stringify({url})
        });
        data = await res.json();
    } catch(e) {
        addLog('Network error: ' + e.message, 'err');
        document.getElementById('scanBtn').disabled = false;
        return;
    }

    if (data.status !== 'success' || data.links.length === 0) {
        addLog('No PDF assets found or page blocked.', 'err');
        setProgress(100, 'SCAN COMPLETE — NO PDF FOUND');
        document.getElementById('scanBtn').disabled = false;
        return;
    }

    addLog(`Found ${data.links.length} PDF file(s). Starting ClamAV pipeline...`, 'ok');
    setProgress(15, `FOUND ${data.links.length} PDF — QUEUING CLAMAV...`);

    const total = data.links.length;
    for (let i = 0; i < total; i++) {
        const pdfUrl = data.links[i];
        const name = decodeURIComponent(pdfUrl.split('/').pop().split('?')[0]) || 'file.pdf';
        const pct = 15 + Math.round(((i) / total) * 80);

        setProgress(pct, `[${i+1}/${total}] DOWNLOADING: ${name}`);
        addLog(`[${i+1}/${total}] Downloading: ${name}`, 'info');

        const rowId = addPendingRow(name, pdfUrl);

        // Update detail to show scanning stage
        setTimeout(() => {
            const d = document.getElementById('detail-' + rowId);
            if (d && d.textContent.includes('Downloading')) d.textContent = '⬡ ClamAV scanning...';
        }, 800);

        let result;
        try {
            const r = await fetch('/clamav', {
                method: 'POST',
                headers: {'Content-Type': 'application/json'},
                body: JSON.stringify({url: pdfUrl})
            });
            result = await r.json();
        } catch(e) {
            updateRow(rowId, 'Network error', 'ERROR');
            addLog('Error: ' + e.message, 'err');
            continue;
        }

        updateRow(rowId, result.detail, result.risk);

        totalScanned++;
        if (result.risk === 'DANGER') {
            dangerCount++;
            addLog(`THREAT DETECTED: ${result.filename} — ${result.detail}`, 'err');
        } else if (result.risk === 'ERROR') {
            addLog(`ERROR scanning ${result.filename}: ${result.detail}`, 'warn');
        } else {
            safeCount++;
            addLog(`CLEAN: ${result.filename}`, 'ok');
        }
        updateStats();
    }

    setProgress(100, `SCAN COMPLETE — ${total} FILE(S) PROCESSED`);
    addLog('=== ALL FILES PROCESSED ===', 'cyan');
    document.getElementById('scanBtn').disabled = false;
}

document.getElementById('targetUrl').addEventListener('keydown', e => {
    if (e.key === 'Enter') startScan();
});
</script>
</body></html>""")

# ================= SCAN ROUTE =================

@app.route("/scan", methods=["POST"])
def scan():
    target = request.json.get("url", "").strip()
    if not target.startswith("http"):
        target = "https://" + target
    try:
        r = requests.get(target, timeout=15, headers={
            'User-Agent': 'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36'
        })
        soup = BeautifulSoup(r.text, 'html.parser')
        links = set()
        for a in soup.find_all('a', href=True):
            href = a['href']
            if href.lower().endswith('.pdf'):
                links.add(urljoin(target, href))
        # Also check embed/object tags
        for tag in soup.find_all(['embed','object'], src=True):
            src = tag.get('src') or tag.get('data','')
            if src.lower().endswith('.pdf'):
                links.add(urljoin(target, src))
        return jsonify({"status": "success", "links": list(links)})
    except Exception as e:
        return jsonify({"status": "error", "msg": str(e), "links": []})

# ================= CLAMAV ROUTE =================

@app.route("/clamav", methods=["POST"])
def clamav():
    pdf_url = request.json.get("url", "")
    filename = os.path.basename(urlparse(pdf_url).path) or "downloaded_file.pdf"
    if not filename.lower().endswith('.pdf'):
        filename += '.pdf'
    filepath = os.path.join(BASE_DIR, filename)

    try:
        # ── STEP 1: Download ──
        res = requests.get(pdf_url, stream=True, timeout=30, headers={
            'User-Agent': 'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36'
        })
        res.raise_for_status()

        with open(filepath, 'wb') as f:
            for chunk in res.iter_content(chunk_size=8192):
                if chunk:
                    f.write(chunk)

        file_size = os.path.getsize(filepath)

        # ── STEP 2: ClamAV scan ──
        if shutil.which("clamscan") is None:
            risk   = "ERROR"
            detail = "ClamAV not installed — run: pkg install clamav"
        else:
            cmd = ["clamscan", "--infected", "--no-summary", filepath]
            proc = subprocess.run(cmd, capture_output=True, text=True, timeout=60)

            if "FOUND" in proc.stdout:
                risk   = "DANGER"
                detail = proc.stdout.strip()
            elif proc.returncode == 0:
                risk   = "SAFE"
                detail = f"CLEAN — {round(file_size/1024,1)} KB scanned"
            else:
                risk   = "ERROR"
                detail = (proc.stderr or proc.stdout).strip()[:120]

        # ── STEP 3: Auto-delete after scan ──
        if os.path.exists(filepath):
            os.remove(filepath)

        # ── STEP 4: Log to DB ──
        log = ScanLog(filename=filename, url=pdf_url, risk=risk, detail=detail)
        db.session.add(log)
        db.session.commit()

        return jsonify({"filename": filename, "risk": risk, "detail": detail})

    except requests.exceptions.Timeout:
        return jsonify({"filename": filename, "risk": "ERROR", "detail": "Download timeout (30s)"})
    except requests.exceptions.HTTPError as e:
        return jsonify({"filename": filename, "risk": "ERROR", "detail": f"HTTP {e.response.status_code}"})
    except subprocess.TimeoutExpired:
        return jsonify({"filename": filename, "risk": "ERROR", "detail": "ClamAV scan timeout"})
    except Exception as e:
        return jsonify({"filename": filename, "risk": "ERROR", "detail": str(e)[:120]})

# ================= RUN =================

if __name__ == "__main__":
    if shutil.which("clamscan") is None:
        print("[!] ClamAV not found. Run: pkg install clamav && freshclam")
    else:
        print("[✓] ClamAV detected.")
    print("[*] Starting server → http://127.0.0.1:5000")
    app.run(host="127.0.0.1", port=5000, debug=False)
