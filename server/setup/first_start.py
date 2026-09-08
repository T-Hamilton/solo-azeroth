#!/usr/bin/env python3
"""First boot of the worldserver: runs it with a piped console, waits for the world to initialize (the first boot also
imports the whole world database, which takes a few minutes), creates your account with GM level 3, then shuts the
server down cleanly.  Usage: first_start.py   (account/password come from settings.json / settings.local.json)"""
import json, os, subprocess, sys, threading, time

SERVER = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RUNTIME = os.path.join(SERVER, "runtime")
S = json.load(open(os.path.join(SERVER, "settings.json"), encoding="utf-8-sig"))
if os.path.exists(os.path.join(SERVER, "settings.local.json")):
    S.update(json.load(open(os.path.join(SERVER, "settings.local.json"), encoding="utf-8-sig")))
acct, pw = S["Account"], S["Password"]
log_path = os.path.join(SERVER, "setup", "first_start.log")
log = open(log_path, "w", encoding="utf-8", errors="replace")

os.makedirs(os.path.join(RUNTIME, "logs"), exist_ok=True)   # AC does not create LogsDir itself
p = subprocess.Popen([os.path.join(RUNTIME, "worldserver.exe"), "-c", os.path.join(RUNTIME, "configs", "worldserver.conf")],
                     cwd=RUNTIME, stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                     text=True, encoding="utf-8", errors="replace", bufsize=1)
state = {"ready": False, "done": False, "lines": 0}


def pump():
    for line in p.stdout:
        log.write(line); log.flush(); state["lines"] += 1
        if "world initialized" in line.lower() or "worldserver-daemon) ready" in line or "AC>" in line:
            state["ready"] = True
        if state["lines"] % 2000 == 0:
            print("  ... %d lines (%s)" % (state["lines"], line.strip()[:70]))
    state["done"] = True


threading.Thread(target=pump, daemon=True).start()

t0 = time.time()
while not state["ready"] and not state["done"] and time.time() - t0 < 3600:
    time.sleep(2)
if not state["ready"]:
    print("world never became ready (exit=%s). See %s" % (p.poll(), log_path)); sys.exit(1)
print("world ready after %.0fs; creating account %s" % (time.time() - t0, acct))
time.sleep(5)
for cmd in ["account create %s %s" % (acct, pw), "account set gmlevel %s 3 -1" % acct, "account set addon %s 2" % acct]:
    p.stdin.write(cmd + "\n"); p.stdin.flush(); time.sleep(2)
time.sleep(3)
p.stdin.write("server shutdown 5\n"); p.stdin.flush()
try:
    p.wait(timeout=180)
except subprocess.TimeoutExpired:
    p.kill()
print("worldserver exited %s; log %s (%d lines)" % (p.returncode, log_path, state["lines"]))

