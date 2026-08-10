#!/usr/bin/env python3
"""Swap the live Hugging Face hot-mod to the refined granular scopes.

Updates both the catalog (extensions/services.json -> requestable permissions)
and the enforcement schema (additional_services.json -> per-permission matchers)
across every uv-cache copy, so a restart reprovisions them. Idempotent; backs up
once. Mirrors the Detent huggingface-* scopes.
"""
import glob
import json
import os
import sys

UVCACHE = os.path.expanduser("~/.minds/.uv-cache/archive-v0")

CATALOG_ENTRY = [
    {
        "scope": "huggingface-api",
        "display_name": "Hugging Face",
        "description": "All requests to the Hugging Face Hub and Inference APIs.",
        "permissions": [
            {"name": "huggingface-read", "description": "Read from the Hugging Face APIs (list/search models, datasets, Spaces; download files)."},
            {"name": "huggingface-write", "description": "Create, update, or delete through the Hugging Face APIs (create repos, upload, manage settings)."},
            {"name": "huggingface-inference", "description": "Run hosted inference through the Inference Providers router (consumes compute/quota)."},
        ],
    }
]

SCHEMA_ENTRY = {
    "display_name": "Hugging Face",
    "base_api_url": "https://huggingface.co/",
    "scope": {
        "name": "huggingface-api",
        "schema": {
            "properties": {"domain": {"enum": ["huggingface.co", "router.huggingface.co"]}},
            "required": ["domain"],
        },
    },
    "permissions": [
        {
            "name": "huggingface-read",
            "description": "Read from the Hugging Face APIs.",
            "schema": {"properties": {"method": {"const": "GET"}}, "required": ["method"]},
        },
        {
            "name": "huggingface-write",
            "description": "Write through the Hugging Face APIs.",
            "schema": {"properties": {"method": {"enum": ["POST", "PUT", "PATCH", "DELETE"]}}, "required": ["method"]},
        },
        {
            "name": "huggingface-inference",
            "description": "Run hosted inference through the Inference Providers router.",
            "schema": {"properties": {"domain": {"const": "router.huggingface.co"}}, "required": ["domain"]},
        },
    ],
}


def backup_once(path):
    bak = path + ".pregranular.bak"
    if not os.path.exists(bak):
        with open(path) as f:
            open(bak, "w").write(f.read())


def patch(pattern, key, value):
    n = 0
    for f in glob.glob(pattern, recursive=True):
        d = json.load(open(f))
        if d.get(key) != value:
            backup_once(f)
            d[key] = value
            json.dump(d, open(f, "w"), indent=2)
            n += 1
    return n


if __name__ == "__main__":
    c = patch(f"{UVCACHE}/**/mngr_latchkey/extensions/services.json", "huggingface", CATALOG_ENTRY)
    s = patch(f"{UVCACHE}/**/mngr_latchkey/additional_services.json", "huggingface", SCHEMA_ENTRY)
    print(f"catalog copies updated: {c}")
    print(f"schema copies updated: {s}")
    if c == 0 and s == 0:
        print("NOTE: nothing changed (already granular, or paths missing)", file=sys.stderr)
