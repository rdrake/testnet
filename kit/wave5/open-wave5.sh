#!/bin/sh
# Opens the wave-5 nefarious2 PRs from rdrake/nefarious2 branches as drafts.
# Dry run by default; pass --post to act.
set -e
cd "$(dirname "$0")"
DRAFT=--draft
R=evilnet/nefarious2
run() { if [ "$POST" = 1 ]; then gh pr create -R $R $DRAFT "$@"; else echo gh pr create -R $R $DRAFT "$@"; fi; }
[ "$1" = --post ] && POST=1
run --base ircv3.2-upgrade --head rdrake:fix/n014-rename-history \
  --title "chathistory: a renamed channel's history follows it to the new name" --body-file n014.md
run --base ircv3.2-upgrade --head rdrake:fix/n069-log-ring-full \
  --title "log: a wakeup on a full async log ring is not room" --body-file n069.md
