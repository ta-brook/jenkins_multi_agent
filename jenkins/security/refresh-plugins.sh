#!/usr/bin/env bash
# Refresh plugin pins in jenkins/controller/plugins.txt to the latest versions
# on the official update center (upgrade policy: pin -> test on dev controller
# -> then commit the bump; never blind-upgrade production).
#   usage: ./refresh-plugins.sh            # print updated file to stdout
#          ./refresh-plugins.sh --write    # rewrite plugins.txt in place
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
PLUGINS_FILE="$ROOT/jenkins/controller/plugins.txt"
[ -f "$PLUGINS_FILE" ] || { echo "missing $PLUGINS_FILE" >&2; exit 1; }

PY=python3
command -v "$PY" >/dev/null 2>&1 || PY=python

"$PY" - "$PLUGINS_FILE" "${1:-}" <<'PY'
import json, sys, urllib.request

plugins_file = sys.argv[1]
write = sys.argv[2] == "--write"

with open(plugins_file, "r", encoding="utf-8") as fh:
    lines = fh.read().splitlines()

meta = json.load(urllib.request.urlopen(
    "https://updates.jenkins.io/current/plugin-versions.json", timeout=60))
index = meta["plugins"]

out, missing, keep = [], [], []
for line in lines:
    stripped = line.strip()
    if not stripped or stripped.startswith("#"):
        out.append(line)
        continue
    artifact = stripped.split(":")[0]
    if artifact not in index:
        missing.append(artifact)
        out.append(line)
        continue
    versions = list(index[artifact].keys())
    latest = versions[-1]
    out.append(f"{artifact}:{latest}")

text = "\n".join(out) + "\n"
if write:
    with open(plugins_file, "w", encoding="utf-8") as fh:
        fh.write(text)
    print(f"updated {plugins_file}")
else:
    print(text, end="")

if missing:
    print("WARN: not on update center, left unchanged:", ", ".join(missing), file=sys.stderr)
    sys.exit(2)
PY
