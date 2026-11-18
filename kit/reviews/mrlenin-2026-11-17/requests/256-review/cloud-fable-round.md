# Review: fix/n067-reveal-msgid (426b2808..b5664fe1), now at 36d9f0fc

Build: configure (debug, rocksdb, zstd, keycloak) + make + all 93 CMocka programs pass before and after;
no new warnings. Two confirmed bugs fixed as new commits and pushed (b5664fe1..36d9f0fc).

## Findings, by severity

### 1. CONFIRMED, fixed (dac79fa3) - a MODE split over two lines names the JOIN after the wrong MODE
ircd/channel.c modebuf_flush_int() (the "modes with arguments" loop, ~l.2874-2900) with
mode_process_clients() (~l.5049) and reveal_msgid_for() (~l.6292).
A MODE whose parameters pass the flush budget (BUFSIZE-200 = 312) is emitted as two MODE lines, each
minting its own msgid. Entries that did not fit were MODE_SAVEd for the second pass, and status
changes are added last (mode_parse: keys, bans, excepts, then clients), so they were the ones that waited.
Scenario: `MODE #c +bbbv <100-char mask> <100-char mask> <100-char mask> hiddennick` (about 330 bytes, a
legal client line). The origin reveals hiddennick in mode_process_clients() with generate_msgid_ahead() = A;
pass 1 (the three bans) takes A; pass 2 (+v hiddennick) mints B. Every other server gets `+v` on the
line tagged B and derives the JOIN from B; the origin showed and stored derive(A). One reveal, two msgids,
and on the origin the JOIN is named after the ban MODE.
Fix: the flush takes the room of its status changes first, so they are never deferred (6 nicks always
fit); a ban/key that no longer fits goes in the next MODE as before. Letter and parameter order unchanged.
Test: channel_speak_cmocka reveal_named_after_the_mode_that_carries_it (failed before:
"ACMIAZp6]R56AB" != "ACMJAZp6]R56AB").

### 2. CONFIRMED, fixed (36d9f0fc) - the JOIN is stamped in the future, after its event, when the line's time was replaced
ircd/channel.c reveal_msgid_for() (~l.6306), with ircd/parse.c ~l.2101-2113.
The JOIN's time was read only from the derived msgid (event msgid time - 1 ms). When a peer's clock is
more than HLC_MAX_FORWARD_MS ahead, parse.c refuses it and replaces cli_s2s_time_ms with local now, so
the event is shown and stored "now"; the msgid still carries the peer's reading. The JOIN was then sent
(@time) and stored that far in the future: after the event it precedes, live and in CHATHISTORY - the
case the replacement exists to prevent.
Fix: the derived id is kept (same on every server); the JOIN's time is the line's time - 1 ms when its
own would not be before it. Normal lines (tag time == msgid time) are unchanged.
Test: channel_speak_cmocka reveal_before_a_line_whose_time_was_replaced (failed before).

### 3. Not a bug in practice (theoretical) - "a derived id never equals a minted id"
ircd/ircd_string.c msgid_derive_join() (~l.2223) vs ircd/crdt_hlc.c hlc_step().
The HLC logical is a full uint16 and only carries at 65535, so minted ids can have bit 15 set: the
logical counts every mint and every received tagged line while the HLC is pinned ahead of the wall clock
(clock stepped back, or a peer's reading adopted). 32768 events inside one pin are needed, and a collision
additionally needs the pinned ms to carry by exactly 1 and node/counter chars to match the member's
numeric. The comment's "never" is "not in practice". No change.

### 4. Not a bug in practice - "two reveals never share an id"
msgid_derive_join(): same member + two events in the same millisecond differ only in the 9-bit fold
(fold = sum of 7 chars with weights 1+32k mod 512). Needs the member revealed, parted, rejoined hidden and
revealed again within 1 ms of event time and a fold collision; typical consecutive ids differ by
65*dl+dc, not 0 mod 512. Also: a legacy multi-target `PRIVMSG #a,#b` server line already gives both
messages one minted stash msgid (pre-existing), so a member hidden in both gets one JOIN id in two
channels (rows are per target). No change.

### 5. Not a bug - generate_msgid_ahead() / msgid_ahead_pending() (ircd/send.c ~l.776-808)
Checked every reveal path for something between the reveal and the event's own mint that mints, advances
the HLC or sends a tagged S2S line:
- RevealDelayedJoin itself: JOIN/AWAY sends are local-only (no S2S, no mint); the history row is given
  the id; CheckDelayedJoins' MODE -d has no msgid. Nothing takes the reserved id.
- relay_channel_message / notice / statusmsg: mint immediately after the reveal.
- server relays: s2s_mint_link_event() fills the stash before the reveal; the reveal reads the stash.
- TOPIC: reveal (m_topic l.338 or do_settopic l.178), then mint or stash; an unchanged topic lets the S2S
  tag mint take the id. wallchops/hops/voices: the S2S tag mint takes it.
- MODE: reveal, then the flush's mint (after fix 1 the right pass); -D reveals inside the pass that
  carries -D; a mid-parse flush consumes the id and later reveals take a new one for the next flush.
- relocate_follow: reveal, then modebuf mint. Multiline: explicit id, minted first.
- HLC only moves on a mint, a received line (parse), metadata stamps and forwarded labels; none sits
  between a reveal and its mint. A reserved id nobody took is cleared after every client and server line
  and before every server line (packet.c), so no unrelated event of a later line gets it; within one
  line a leftover (TOPIC refused for colour after the l.338 reveal) can name a later target's event,
  which is harmless (unique, same clock reading).

### 6. Not a bug - Makefile -MMD -MP (ircd/Makefile.in, ircd/test/Makefile.in)
.d files land beside each object (kc/ too), are read back with `-include`, removed by clean, ignored by
git; paths are relative to the build dir so an out-of-tree build works; -MP covers deleted headers. Only
note: the flags are GCC/Clang-specific and not probed by configure.

### 7. Pre-existing, not from this PR (not changed)
- A local bouncer device speaking in a channel where its primary is hidden: relay_channel_message reveals
  `sptr`'s own membership (the device's), not the primary's, while receivers see the primary speak and
  reveal the primary. Not traced further; unchanged from base.
- m_topic l.338 reveals the setter even when the TOPIC is then refused (colour) or is a refresh; other
  servers do not reveal. Unchanged from base.
- modebuf passes of one inbound tagged MODE split here share the line's msgid (two MODE rows, one id).

## For the PR description
A MODE too long for one line is flushed as two with two msgids; status changes now always go out in the
first, so a hidden member given a status is named after the MODE that carries it on every server (before,
`MODE #c +bbbv <3 long masks> nick` gave the origin a different JOIN msgid from everyone else). The reveal's
JOIN keeps its derived msgid but takes the line's time less 1 ms when the line's time was replaced
(sender's clock past HLC_MAX_FORWARD_MS), so it no longer lands in the future, after its event. Both have
CMocka cases in channel_speak_cmocka that fail without the fix.
