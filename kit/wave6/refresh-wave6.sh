#!/bin/sh
# Appends the boolean paragraph to #268 and #269 (once).  Dry run by default; pass --post to edit.
set -e
cd "$(dirname "$0")"
R=evilnet/nefarious2
POST=0; [ "$1" = --post ] && POST=1
f=refresh/268-269.append
for n in 268 269; do
  gh pr view $n -R $R --json body --jq .body > /tmp/pr$n.cur
  if python3 -c "import sys;a=open('/tmp/pr$n.cur').read();b=open('$f').read().strip();sys.exit(b[:80] not in a)"; then echo "#$n: already appended"; continue; fi
  python3 -c "a=open('/tmp/pr$n.cur').read().rstrip('\\n');b=open('$f').read().strip();open('/tmp/pr$n.new','w').write(a+'\\n\\n'+b+'\\n')"
  if [ $POST = 1 ]; then gh pr edit $n -R $R --body-file /tmp/pr$n.new; echo "#$n: edited"
  else echo "=== #$n would append:"; cat $f; fi
done
