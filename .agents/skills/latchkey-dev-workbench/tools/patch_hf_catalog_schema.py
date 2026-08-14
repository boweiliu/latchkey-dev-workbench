#!/usr/bin/env python3
"""Durably add the huggingface catalog entry + Detent enforcement schema.

Patches every cached build in uv's archive cache so the change survives the
Minds app's on-boot venv reprovision (which copies these files from the cache).
Idempotent; backs up each file once before first edit.
"""
import glob
import json
import os
import sys

UVCACHE = os.path.expanduser("~/.minds/.uv-cache/archive-v0")

# --- catalog entry (services.json): makes the permission requestable/approvable
CATALOG_KEY = "huggingface"
CATALOG_ENTRY = [
    {
        "scope": "huggingface-api",
        "display_name": "Hugging Face",
        "description": "All requests to the Hugging Face Hub and Inference APIs.",
        "permissions": [],
    }
]

# --- enforcement schema (additional_services.json): lets Detent RESOLVE the
#     huggingface-api scope at grant/enforcement time. Covers both the Hub host
#     and the Inference router via an anchored pattern (Detent supports regex
#     patterns; ngrok's schema used one on the path).
SCHEMA_KEY = "huggingface"
SCHEMA_ENTRY = {
    "display_name": "Hugging Face",
    "base_api_url": "https://huggingface.co/",
    "scope": {
        "name": "huggingface-api",
        "schema": {
            "properties": {
                "domain": {"pattern": "^(huggingface\\.co|router\\.huggingface\\.co)$"}
            },
            "required": ["domain"],
        },
    },
    "permissions": [
        {
            "name": "everything",
            "description": "Full read access to the Hugging Face Hub and Inference APIs.",
            "schema": {},
        }
    ],
}


def backup_once(path):
    bak = path + ".prehf.bak"
    if not os.path.exists(bak):
        with open(path) as f:
            data = f.read()
        with open(bak, "w") as f:
            f.write(data)


def patch_catalog():
    n = 0
    for f in glob.glob(f"{UVCACHE}/**/mngr_latchkey/extensions/services.json", recursive=True):
        d = json.load(open(f))
        if CATALOG_KEY not in d:
            backup_once(f)
            d[CATALOG_KEY] = CATALOG_ENTRY
            json.dump(d, open(f, "w"), indent=2)
            n += 1
    return n


def patch_schema():
    n = 0
    for f in glob.glob(f"{UVCACHE}/**/mngr_latchkey/additional_services.json", recursive=True):
        d = json.load(open(f))
        if SCHEMA_KEY not in d:
            backup_once(f)
            d[SCHEMA_KEY] = SCHEMA_ENTRY
            json.dump(d, open(f, "w"), indent=2)
            n += 1
    return n


if __name__ == "__main__":
    c = patch_catalog()
    s = patch_schema()
    print(f"patched catalog copies: {c}")
    print(f"patched schema copies: {s}")
    if c == 0 and s == 0:
        print("NOTE: nothing patched (already present, or cache paths not found)", file=sys.stderr)
