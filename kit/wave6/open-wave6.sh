#!/bin/sh
# Opens the wave-6 nefarious2 PRs from rdrake/nefarious2 branches as drafts.
# Dry run by default; pass --post to act.
set -e
cd "$(dirname "$0")"
DRAFT=--draft
R=evilnet/nefarious2
run() { if [ "$POST" = 1 ]; then gh pr create -R $R $DRAFT "$@"; else echo gh pr create -R $R $DRAFT "$@"; fi; }
[ "$1" = --post ] && POST=1
run --base ircv3.2-upgrade --head rdrake:fix/log-default-facility \
  --title "log: keep the configured default syslog facility" --body-file log-facility.md
run --base master --head rdrake:fix/log-default-facility-master \
  --title "log: keep the configured default syslog facility" --body-file log-facility-master.md
