#!/bin/sh
# Opens the wave-3 nefarious2 PRs from rdrake/nefarious2 branches as drafts.
# Dry run by default; pass --post to act.
set -e
cd "$(dirname "$0")"
DRAFT=--draft
R=evilnet/nefarious2
run() { if [ "$POST" = 1 ]; then gh pr create -R $R $DRAFT "$@"; else echo gh pr create -R $R $DRAFT "$@"; fi; }
[ "$1" = --post ] && POST=1
run --base ircv3.2-upgrade --head rdrake:fix/n073-notice-echo-tags \
  --title "relay: a private notice's echo to its sender carries its client tags" --body-file n073.md
run --base ircv3.2-upgrade --head rdrake:fix/n074-cap-302-tags \
  --title "cap, tags: CAP 302 additions only to CAP 302 clients; client tags only with message-tags" --body-file n074.md
run --base ircv3.2-upgrade --head rdrake:fix/n066-event-time \
  --title "send: an event's client @time is its own" --body-file n066.md
run --base master --head rdrake:fix/n009-overdue-timer-master \
  --title "engines: an overdue timer polls now instead of waiting forever" --body-file n009-master.md
run --base ircv3.2-upgrade --head rdrake:fix/n013-search-federate \
  --title "chathistory: SEARCH without in= asks the other storage servers too" --body-file n013.md
run --base ircv3.2-upgrade --head rdrake:fix/n027-persistence-names \
  --title "persistence: the extras move to evilnet.github.io/persistence" --body-file n027.md
run --base ircv3.2-upgrade --head rdrake:fix/n067-svsnick-msgid \
  --title "svsnick: one NICK msgid on every server" --body-file n067-svsnick.md
run --base ircv3.2-upgrade --head rdrake:fix/n067-account-msgid \
  --title "account: a login or webhook deauth is one msgid on every server" --body-file n067-account.md
run --base ircv3.2-upgrade --head rdrake:fix/n067-reveal-msgid \
  --title "channel: a delayed-join reveal is one msgid on every server" --body-file n067-reveal.md
