#!/usr/bin/env bash
# Restore a $JENKINS_HOME backup onto a (replacement) controller's home dir.
# Use as part of the restore drill on a scratch controller BEFORE pointing prod
# traffic at it. The controller must be stopped while restoring.
#   usage: ./restore-jenkins-home.sh <backup-file.tar.gz> <jenkins-home-target>
set -euo pipefail

BACKUP="${1:?usage: restore-jenkins-home.sh <backup-file> <target-dir>}"
TARGET="${2:?usage: restore-jenkins-home.sh <backup-file> <target-dir>}"

[ -f "$BACKUP" ] || { echo "backup file missing: $BACKUP" >&2; exit 1; }
[ -d "$TARGET" ] || { echo "target dir missing: $TARGET" >&2; exit 1; }
if [ -n "$(find "$TARGET" -mindepth 1 2>/dev/null)" ]; then
  echo "target dir is not empty: $TARGET (restore into an empty home)" >&2
  exit 1
fi

echo "==> restoring $BACKUP into $TARGET"
tar -xzf "$BACKUP" -C "$(dirname "$TARGET")"

echo "==> restore complete. Verify before going live:"
echo "    1. chown -R jenkins:jenkins $TARGET"
echo "    2. start the controller and confirm: jobs list, JCasC config,"
echo "       credentials store, plugins, and one green dev pipeline."
