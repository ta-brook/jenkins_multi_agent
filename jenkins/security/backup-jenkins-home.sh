#!/usr/bin/env bash
# Backup $JENKINS_HOME (jobs, JCasC, credentials store, plugins config).
#   usage: ./backup-jenkins-home.sh /var/jenkins_home /backups [keep]
# Produces /backups/jenkins-home-<timestamp>.tar.gz and prunes to $KEEP (default 10).
set -euo pipefail

SRC="${1:?usage: backup-jenkins-home.sh <src> <dst> [keep]}"
DST="${2:?usage: backup-jenkins-home.sh <src> <dst> [keep]}"
KEEP="${3:-10}"

[ -d "$SRC" ] || { echo "src dir missing: $SRC" >&2; exit 1; }
mkdir -p "$DST"

STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
FILE="$DST/jenkins-home-$STAMP.tar.gz"

echo "==> backing up $SRC -> $FILE"
tar --exclude="$SRC/workspace" --exclude="$SRC/builds" \
  --exclude="$SRC/caches" --exclude="$SRC/.cache" \
  -czf "$FILE" -C "$(dirname "$SRC")" "$(basename "$SRC")"

ls -1 "$DST"/jenkins-home-*.tar.gz \
  | sort -r \
  | tail -n +"$((KEEP + 1))" \
  | xargs -r rm -f

echo "==> done. retained backups:"
ls -1t "$DST"/jenkins-home-*.tar.gz | head -n "$KEEP"
