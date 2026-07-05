#!/run/current-system/sw/bin/python3
import json
import sys
import urllib.request

diff = sys.stdin.read().strip()
if not diff:
    sys.exit(1)

prompt = f"""You are a git commit message generator for a NixOS configuration repository.
Given the following git diff, describe WHAT changed and WHY in a concise commit message.
Start with a subject line under 72 characters, then a blank line, then a short body.

Diff:
{diff}"""

payload = json.dumps({
    "model": "qwen2.5-coder:3b",
    "prompt": prompt,
    "stream": False,
}).encode()

req = urllib.request.Request(
    "http://localhost:11434/api/generate",
    data=payload,
    headers={"Content-Type": "application/json"},
)

try:
    resp = urllib.request.urlopen(req, timeout=60)
    data = json.loads(resp.read())
    msg = data.get("response", "").strip()
    if msg:
        print(msg)
    else:
        sys.exit(1)
except Exception:
    sys.exit(1)
