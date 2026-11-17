#!/bin/sh
# Replaces the bodies of #257, #259, #264, #268, #269, #270 and #274 with the
# updated kit text, for the commits pushed after review, and appends a
# paragraph to #252 and #246.  Each is replaced only if the current
# body is still the one the kit posted (prev/); otherwise it stops for a hand
# edit.  Dry run by default (shows the diff); pass --post to edit.
set -e
cd "$(dirname "$0")"
R=evilnet/nefarious2
POST=0; [ "$1" = --post ] && POST=1
for pair in 257:n036.md 259:n034.md 264:n022.md 268:int-feature.md 269:int-feature-master.md 270:listener.md 274:away-burst.md; do
  n=${pair%%:*}; f=${pair#*:}
  gh pr view $n -R $R --json body --jq .body > /tmp/pr$n.cur
  if ! python3 -c "import sys;a=open('/tmp/pr$n.cur').read().strip();b=open('prev/$f').read().strip();sys.exit(a!=b)"; then
    if python3 -c "import sys;a=open('/tmp/pr$n.cur').read().strip();b=open('$f').read().strip();sys.exit(a!=b)"; then echo "#$n: already up to date"; continue; fi
    echo "#$n: current body is not the one the kit posted; edit by hand"; continue
  fi
  if [ $POST = 1 ]; then gh pr edit $n -R $R --body-file $f; echo "#$n: edited"
  else echo "=== #$n would change:"; diff prev/$f $f || true; fi
done
# Appends: only if the paragraph is not there yet.
for pair in 252:refresh/252.append 246:refresh/246.append2; do
  n=${pair%%:*}; f=${pair#*:}
  gh pr view $n -R $R --json body --jq .body > /tmp/pr$n.cur
  if python3 -c "import sys;a=open('/tmp/pr$n.cur').read();b=open('$f').read().strip();sys.exit(b[:80] not in a)"; then echo "#$n: already appended"; continue; fi
  python3 -c "a=open('/tmp/pr$n.cur').read().rstrip('\\n');b=open('$f').read().strip();open('/tmp/pr$n.new','w').write(a+'\\n\\n'+b+'\\n')"
  if [ $POST = 1 ]; then gh pr edit $n -R $R --body-file /tmp/pr$n.new; echo "#$n: edited"
  else echo "=== #$n would append:"; cat $f; fi
done
