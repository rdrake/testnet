#!/bin/sh
# Refreshes the bodies of open PRs #237, #240, #241 and #246 for commits
# pushed since they were opened.  Reads each current body from GitHub and
# appends (or, for #241, replaces one paragraph); never overwrites blindly.
# Dry run by default (prints the new bodies); pass --post to edit.
set -e
cd "$(dirname "$0")"
R=evilnet/nefarious2
POST=0; [ "$1" = --post ] && POST=1
for n in 237 240 241 246; do
  gh pr view $n -R $R --json body --jq .body > /tmp/pr$n.cur
  python3 - "$n" <<'PY'
import sys
n=sys.argv[1]; cur=open(f'/tmp/pr{n}.cur').read().rstrip('\n')
if n=='241':
    old=open('refresh/241.old').read().strip(); new=open('refresh/241.new').read().strip()
    if new in cur: out=cur
    elif old in cur: out=cur.replace(old,new)
    else: sys.exit(f'#{n}: the paragraph to replace is not in the current body; edit by hand')
else:
    add=open(f'refresh/{n}.append').read().strip()
    out=cur if add in cur else cur+'\n\n'+add
open(f'/tmp/pr{n}.new','w').write(out+'\n')
PY
  if cmp -s /tmp/pr$n.cur /tmp/pr$n.new; then echo "#$n: already up to date"; continue; fi
  if [ $POST = 1 ]; then gh pr edit $n -R $R --body-file /tmp/pr$n.new; echo "#$n: edited"
  else echo "=== #$n would change:"; diff /tmp/pr$n.cur /tmp/pr$n.new || true; fi
done
