#!/bin/sh
# Files the #276 follow-up issue on evilnet/nefarious2.  Dry run by default; pass --post to act.
set -e
cd "$(dirname "$0")"
R=evilnet/nefarious2
T="chathistory: what #276 (history follows a RENAME) leaves open"
if [ "$1" = --post ]; then gh issue create -R $R --title "$T" --body-file issue-276.md
else echo gh issue create -R $R --title "\"$T\"" --body-file issue-276.md; echo "--- body:"; cat issue-276.md; fi
