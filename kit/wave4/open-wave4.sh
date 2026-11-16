#!/bin/sh
# Opens the wave-4 nefarious2 PRs from rdrake/nefarious2 branches as drafts.
# Dry run by default; pass --post to act.
set -e
cd "$(dirname "$0")"
DRAFT=--draft
R=evilnet/nefarious2
run() { if [ "$POST" = 1 ]; then gh pr create -R $R $DRAFT "$@"; else echo gh pr create -R $R $DRAFT "$@"; fi; }
[ "$1" = --post ] && POST=1
run --base ircv3.2-upgrade --head rdrake:fix/n036-nickask-match \
  --title "bouncer: only a refusal of the asked nick answers a device's NICK request" --body-file n036.md
run --base ircv3.2-upgrade --head rdrake:fix/n071-paste-shutdown \
  --title "paste: close in-flight paste connections at shutdown" --body-file n071.md
run --base ircv3.2-upgrade --head rdrake:fix/n034-profile-long-keys \
  --title "persistence: profile delete, rename and listing reach keys of any length" --body-file n034.md
run --base ircv3.2-upgrade --head rdrake:fix/n006-nick-persist \
  --title "bouncer: a session primary's nick change marks the session for persisting" --body-file n006.md
run --base ircv3.2-upgrade --head rdrake:fix/n050-small-inherited \
  --title "res, ssl, nick: three small inherited bugs" --body-file n050.md
run --base master --head rdrake:fix/n050-small-inherited-master \
  --title "res, ssl, nick: three small inherited bugs" --body-file n050-master.md
run --base master --head rdrake:fix/n047-iauth-id-port-master \
  --title "IAuth: reject a malformed client id or an out-of-range port" --body-file n047-master.md
run --base ircv3.2-upgrade --head rdrake:fix/n022-setname-case \
  --title "setname: a case-only change is a change" --body-file n022.md
run --base ircv3.2-upgrade --head rdrake:fix/n080-chghost-self \
  --title "chghost: the user hears its own change, under the old user@host" --body-file n080.md
run --base ircv3.2-upgrade --head rdrake:fix/n049-event-loop-order \
  --title "events: drop an error raised while deleting; end the event batch at DIE" --body-file n049.md
run --base master --head rdrake:fix/n049-ssl-free-order-master \
  --title "s_bsd: free a connection's TLS state before the connection" --body-file n049-master.md
run --base ircv3.2-upgrade --head rdrake:fix/int-feature-range \
  --title "features: refuse an integer value that is not a whole int" --body-file int-feature.md
run --base master --head rdrake:fix/int-feature-range-master \
  --title "features: refuse an integer value that is not a whole int" --body-file int-feature-master.md
run --base ircv3.2-upgrade --head rdrake:fix/listener-rehash-free \
  --title "listener: a REHASH that leaves a port no socket no longer frees it in use" --body-file listener.md
run --base master --head rdrake:fix/listener-rehash-free-master \
  --title "listener: a REHASH that leaves a port no socket no longer frees it in use" --body-file listener-master.md
run --base ircv3.2-upgrade --head rdrake:fix/port-vhost-check \
  --title "Port: a vhost that is not an address is a configuration error" --body-file port-vhost.md
run --base master --head rdrake:fix/port-vhost-check-master \
  --title "Port: a vhost that is not an address is a configuration error" --body-file port-vhost-master.md
run --base ircv3.2-upgrade --head rdrake:fix/away-burst \
  --title "burst: send each user's away state" --body-file away-burst.md
run --base master --head rdrake:fix/away-burst-master \
  --title "burst: send each user's away state" --body-file away-burst-master.md
