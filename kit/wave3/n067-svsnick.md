Every server applies an SVSNICK itself, and the relayed SVSNICK carried no msgid. Each server therefore minted its own msgid for the resulting NICK.
- The NICK lines that `set_nick_name()` relays did carry the first server's msgid, but never toward the target.
- The target's server learned of the rename only from the SVSNICK, so it minted another msgid.
- As a result, the target's side of the network and the rest stored and showed the rename under two msgids.

**The fix:**
- `ms_svsnick()` takes the msgid and time from the SVSNICK line when it carries them, and mints them otherwise.
- It arms them for `set_nick_name()` through the new `set_nick_name_event()`.
- It sends them on the SVSNICK it relays, to tag-capable links only. Stock servers get the untagged line.

This is one of three PRs for the same issue (one msgid per event across servers); the other two cover ACCOUNT and the delayed-join reveal.

**Testing:** build and all CMocka suites pass. Two new cases in `s2s_handlers_cmocka`:
- The first server mints the event, uses it for the rename, and arms it on the relay.
- A server further along takes it from the line.
