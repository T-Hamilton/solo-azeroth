"""Run a worldserver GM command through AzerothCore's SOAP interface.

usage: python tools/soap.py "<command without leading dot>" [more commands...]
   e.g. python tools/soap.py "ollama status"  "server info"
Port and the GM account come from server/settings.json (+ settings.local.json); SOAP is enabled in our generated config.
"""
import base64, html, json, os, re, sys, urllib.error, urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
S = json.load(open(os.path.join(ROOT, "server", "settings.json"), encoding="utf-8"))
if os.path.exists(os.path.join(ROOT, "server", "settings.local.json")):
    S.update(json.load(open(os.path.join(ROOT, "server", "settings.local.json"), encoding="utf-8")))


def soap(command):
    body = f'''<?xml version="1.0" encoding="utf-8"?>
<SOAP-ENV:Envelope xmlns:SOAP-ENV="http://schemas.xmlsoap.org/soap/envelope/" xmlns:ns1="urn:AC">
 <SOAP-ENV:Body><ns1:executeCommand><command>{html.escape(command)}</command></ns1:executeCommand></SOAP-ENV:Body>
</SOAP-ENV:Envelope>'''.encode()
    req = urllib.request.Request(f'http://127.0.0.1:{S["SoapPort"]}/', data=body, method='POST')
    req.add_header('Content-Type', 'application/xml')
    req.add_header('Authorization', 'Basic ' + base64.b64encode(f'{S["Account"]}:{S["Password"]}'.encode()).decode())
    try:
        with urllib.request.urlopen(req, timeout=30) as r:
            txt = r.read().decode('utf-8', 'replace')
    except urllib.error.HTTPError as e:
        txt = e.read().decode('utf-8', 'replace')
    m = re.search(r'<result>(.*?)</result>', txt, re.S) or re.search(r'<faultstring>(.*?)</faultstring>', txt, re.S)
    return html.unescape(m.group(1)) if m else txt


if __name__ == '__main__':
    if len(sys.argv) < 2:
        print(__doc__); sys.exit(1)
    for c in sys.argv[1:]:
        print(soap(c))
