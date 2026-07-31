"""Patch the ngrok entry into a bundled mngr_latchkey wheel's services.json.

Usage: python3 patch_wheel.py <wheel_path>
Backs up the original wheel to <wheel_path>.orig once.
"""
import sys
import os
import json
import shutil
import zipfile

wheel = sys.argv[1]
backup = wheel + ".orig"
if not os.path.exists(backup):
    shutil.copy2(wheel, backup)

with zipfile.ZipFile(wheel, "r") as zin:
    names = zin.namelist()
    blobs = {n: zin.read(n) for n in names}

member = next((n for n in names if n.endswith("mngr_latchkey/extensions/services.json")), None)
if member is None:
    print("ERROR: services.json member not found in wheel")
    sys.exit(1)

catalog = json.loads(blobs[member])
before = "ngrok" in catalog
if not before:
    catalog["ngrok"] = [
        {
            "scope": "ngrok-api",
            "display_name": "ngrok",
            "description": "All requests to the ngrok API.",
            "permissions": [],
        }
    ]
    blobs[member] = json.dumps(catalog, indent=2).encode("utf-8")

tmp = wheel + ".tmp"
with zipfile.ZipFile(tmp, "w", zipfile.ZIP_DEFLATED) as zout:
    for n in names:
        zout.writestr(n, blobs[n])
os.replace(tmp, wheel)

with zipfile.ZipFile(wheel, "r") as zcheck:
    after = "ngrok" in json.loads(zcheck.read(member))
print(f"member={member}")
print(f"ngrok before={before} after={after}")
