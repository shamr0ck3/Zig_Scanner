#!/usr/bin/env python3
"""
🛡️ defender_scan.py – Defensive URL/Image Analyzer
Detects potential tracking payloads (short links, stego images, capture pages)
For authorized security research only.
"""

import re
import sys
import json
import base64
import hashlib
import argparse
from urllib.parse import urlparse, parse_qs
from pathlib import Path

try:
    from PIL import Image
    import numpy as np
    HAS_STEGO = True
except ImportError:
    HAS_STEGO = False
    print("⚠️  Pillow/numpy not installed. Steganography analysis disabled.")
    print("   Install with: pip install Pillow numpy")

# === Configuration ===
SUSPICIOUS_PATTERNS = [
    r'/[A-Za-z0-9]{6}$',           # Short code pattern (e.g., /AbC123)
    r'/collect',                   # Data collection endpoint
    r'/analytics/',                # Analytics dashboard
    r'/stego',                     # Steganography endpoint
    r'navigator\.geolocation',     # Geo-tracking JS
    r'getUserMedia',               # Camera access JS
    r'canvas\.toDataURL',          # Screenshot capability
    r'fetch\(.*/collect',          # Beacon to collector
    r'WebGrab|Link Intel',         # Known tool signatures
]

STEGO_INDICATORS = {
    'lsb_patterns': True,          # Check for LSB manipulation
    'unusual_metadata': True,      # Check for hidden text in EXIF
    'size_anomaly': True,          # PNG larger than expected for quality
}

# === Analysis Functions ===

def analyze_url(url: str) -> dict:
    """Analyze a URL for suspicious tracking patterns."""
    result = {
        'url': url,
        'risk_level': 'low',
        'indicators': [],
        'recommendation': 'No obvious threats detected.'
    }
    
    parsed = urlparse(url)
    
    # Check for suspicious path patterns
    for pattern in SUSPICIOUS_PATTERNS:
        if re.search(pattern, url, re.I):
            result['indicators'].append(f"Pattern match: {pattern}")
            result['risk_level'] = 'medium'
    
    # Check for data exfiltration parameters
    params = parse_qs(parsed.query)
    if any(k.lower() in ['token', 'code', 'cid', 'uid'] for k in params):
        result['indicators'].append("Suspicious query parameters")
        result['risk_level'] = 'medium'
    
    # Check for known malicious domains (expand as needed)
    suspicious_domains = ['trycloudflare.com']  # Add known abuse domains
    if parsed.netloc.endswith(tuple(suspicious_domains)):
        result['indicators'].append(f"Domain in watchlist: {parsed.netloc}")
        result['risk_level'] = 'high'
    
    # Final recommendation
    if result['risk_level'] == 'high':
        result['recommendation'] = "⚠️  DO NOT CLICK. Analyze in isolated environment."
    elif result['risk_level'] == 'medium':
        result['recommendation'] = "⚠️  Exercise caution. Verify source before interacting."
    
    return result


def analyze_image_stego(image_path: str) -> dict:
    """Analyze image for LSB steganography indicators."""
    result = {
        'file': image_path,
        'risk_level': 'low',
        'indicators': [],
        'extracted_text': None
    }
    
    if not HAS_STEGO:
        result['error'] = "Stego analysis requires Pillow and numpy"
        return result
    
    try:
        img = Image.open(image_path).convert("RGB")
        pixels = np.array(img).flatten()
        
        # Basic LSB entropy check (random LSBs may indicate hidden data)
        lsb_bits = pixels & 1
        entropy = np.std(lsb_bits[:10000])  # Sample first 10k pixels
        
        if entropy < 0.3:  # Unusually low variance in LSBs
            result['indicators'].append("Low LSB entropy – possible steganography")
            result['risk_level'] = 'medium'
        
        # Try to extract text (basic LSB decoder)
        try:
            bits = []
            for i in range(min(5000, len(pixels))):
                bits.append(pixels[i] & 1)
            
            # Convert bits to bytes
            text_bytes = []
            for i in range(0, len(bits) - 7, 8):
                byte = 0
                for j in range(8):
                    byte = (byte << 1) | bits[i + j]
                text_bytes.append(byte)
            
            # Look for URL pattern in decoded text
            decoded = bytes(text_bytes).decode('ascii', errors='ignore')
            if 'http' in decoded and 'trycloudflare' in decoded:
                result['extracted_text'] = decoded[:200] + "..."
                result['indicators'].append("Hidden URL detected in LSB")
                result['risk_level'] = 'high'
                
        except Exception as e:
            result['indicators'].append(f"Extraction attempt failed: {e}")
            
    except Exception as e:
        result['error'] = f"Image analysis error: {e}"
        result['risk_level'] = 'unknown'
    
    return result


def generate_report(url_result: dict = None, image_result: dict = None) -> str:
    """Generate a human-readable security report."""
    report = ["\n" + "="*60, "🛡️  DEFENSIVE ANALYSIS REPORT", "="*60 + "\n"]
    
    if url_result:
        report.append(f"🔗 URL: {url_result['url']}")
        report.append(f"🚨 Risk Level: {url_result['risk_level'].upper()}")
        if url_result['indicators']:
            report.append("🔍 Indicators Found:")
            for ind in url_result['indicators']:
                report.append(f"   • {ind}")
        report.append(f"💡 Recommendation: {url_result['recommendation']}")
        report.append("")
    
    if image_result:
        report.append(f"🖼️  Image: {image_result['file']}")
        report.append(f"🚨 Risk Level: {image_result['risk_level'].upper()}")
        if image_result.get('error'):
            report.append(f"❌ Error: {image_result['error']}")
        elif image_result['indicators']:
            report.append("🔍 Indicators Found:")
            for ind in image_result['indicators']:
                report.append(f"   • {ind}")
        if image_result.get('extracted_text'):
            report.append(f"🔓 Extracted Payload: {image_result['extracted_text']}")
        report.append(f"💡 Recommendation: {'⚠️  Isolate and analyze in sandbox' if image_result['risk_level'] == 'high' else '✅ No immediate action required'}")
    
    report.append("\n" + "="*60)
    report.append("⚖️  LEGAL NOTICE: This tool is for authorized")
    report.append("    security research only. Do not use to access")
    report.append("    systems without explicit permission.")
    report.append("="*60 + "\n")
    
    return "\n".join(report)


# === Main CLI ===

def main():
    parser = argparse.ArgumentParser(
        description="🛡️  Defensive URL/Image Analyzer – Detect tracking payloads",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  %(prog)s -u "https://xyz.trycloudflare.com/AbC123"
  %(prog)s -i suspicious.png
  %(prog)s -u "https://..." -i image.png -o report.json
        """
    )
    parser.add_argument('-u', '--url', help='URL to analyze')
    parser.add_argument('-i', '--image', help='Image file to analyze for steganography')
    parser.add_argument('-o', '--output', help='Save JSON report to file')
    parser.add_argument('-q', '--quiet', action='store_true', help='Minimal output')
    
    args = parser.parse_args()
    
    if not args.url and not args.image:
        parser.print_help()
        sys.exit(1)
    
    url_result = analyze_url(args.url) if args.url else None
    image_result = analyze_image_stego(args.image) if args.image else None
    
    # Output
    if not args.quiet:
        print(generate_report(url_result, image_result))
    
    # Save JSON report if requested
    if args.output:
        report_data = {
            'timestamp': __import__('datetime').datetime.now().isoformat(),
            'url_analysis': url_result,
            'image_analysis': image_result
        }
        with open(args.output, 'w') as f:
            json.dump(report_data, f, indent=2)
        if not args.quiet:
            print(f"💾 JSON report saved to: {args.output}")


if __name__ == "__main__":
    main()
