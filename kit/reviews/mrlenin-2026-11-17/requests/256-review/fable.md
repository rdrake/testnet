## Findings (most severe first)

1. **`ircd/channel.c:5049-5050` with `:2884-2886`, `:3060`, `:3270-3271` — a MODE that the modebuf splits in two gives the origin a different JOIN id from every other server.**
   - What is wrong: `mode_process_clients()` reveals at parse time and reserves the id of "the next mint" (X). `modebuf_flush_int()` then emits only the entries that fit `totalbuflen` (`BUFSIZE - 200` = 312); an entry that does not fit is marked `MODE_SAVE` and goes out in a second MODE (tail recursion at `:3270`), which mints its own id (Y). The first MODE takes X.
   - Scenario: local chanop sends `MODE #c +bbbv <mask1> <mask2> <mask3> hiddennick` with three 100-character masks (each costs its length + 1, so 303 of 312 are used and 9 are left; a client entry is saved when `left - max(9, nicklen) <= 0`, so the `+v` is saved). Origin: JOIN = derive(X), then `MODE +bbb` (id X), then `MODE +v hiddennick` (id Y). Every other server gets line 1 (tag X, bans only, no reveal) and line 2 (tag Y), reveals on line 2, and stores JOIN = derive(Y). The origin's JOIN row and live msgid differ from the rest of the network.
   - Confidence: confirmed by reading (no test run): bans enter the modebuf before clients (`mode_parse` `:5735`, `:5742`), and nothing between the reveal and the flush mints or moves the HLC (`bounce_mark_dirty`, `bounce_sync_alias_chanmodes`, `modebuf_mode_client`; `m_mode.c:191-192`). One link not re-read: that a local ban mask can be 100 characters (ircu's `pretty_mask` allows nick!user@host up to 30+10+75). Any chanop can trigger it deliberately; by accident it needs long ban masks and a status grant to a hidden member in one command.
   - Minimal fix: reveal where the MODE's id is known. In `modebuf_flush_int()`, just before the id is chosen at `:3053`, reveal the non-`MODE_SAVE` `MODE_ADD` o/h/v entries whose member is still delayed, and drop the reveal from `mode_process_clients()`; or keep it there and have the flush mint first and pass the id as `event_msgid`.

2. **`ircd/channel.c:6298-6299` (with `ircd/parse.c:2101-2113`) — the JOIN's time is taken from the event's msgid, not from the event's time, so with a refused peer clock the JOIN sorts after its event.**
   - What is wrong: `reveal_ms = msgid_decode_time_ms(derived)` = (time embedded in the event's msgid) - 1. The event itself is delivered and stored at `cli_s2s_time_ms(link)`. `parse.c` replaces that link time with the local HLC time when the peer is more than `HLC_MAX_FORWARD_MS` (default 60000) ahead, but the msgid keeps the peer's time.
   - Scenario: server S's clock is 5 minutes ahead. A hidden member on S speaks in `#c`. On every other server the PRIVMSG is stored and shown at local now; the reveal JOIN is stored and shown at now + 5 min - 1 ms. Live `@time` on the JOIN is in the future, and in CHATHISTORY the JOIN sorts after its message and after the next five minutes of traffic. Before this change the JOIN took the local HLC time.
   - Confidence: confirmed by reading.
   - Minimal fix: when the event id came from the link's stash, use `min(decoded - 1, history_event_time_ms(link) - 1)` for `reveal_ms` (the id stays the derived one, so servers still agree on it).

3. **`ircd/m_topic.c:338-347` (reservation at `ircd/channel.c:6294-6295`) — a TOPIC target that reveals and then mints nothing leaves the reservation for the next target; one user's JOINs in two channels get the same msgid.**
   - What is wrong: `client_can_send_to_channel(sptr, chptr, 1)` reveals and reserves X. If the target is then refused for colour (`EXMODE_NOCOLOR`, `:343-347`), or the topic is unchanged on a local `&channel` (`do_settopic` with `newtopic == 0` neither mints nor relays), nothing takes X. The next target's reveal asks `generate_msgid_ahead()` again and gets the same X, and `msgid_derive_join()` has no channel input. The earlier series had a per-target reset for this shape (193d5ed0); b5664fe1 removed it.
   - Scenario: user hidden in `#a` (+D, no-colour) and `#b` (+D) sends `TOPIC #a,#b :\x034red`. `#a`: JOIN shown with derive(X, user), then 404. `#b`: JOIN shown with derive(X, user) — the identical msgid — then TOPIC with id X. Two different JOIN events carry one msgid, and `#a`'s JOIN is named after `#b`'s TOPIC.
   - Impact is limited: history's msgid index is keyed `msgid\0target`, so both rows are kept; a client that dedups by msgid may drop one JOIN.
   - Another instance: local `PRIVMSG #a,#b` in a build without `USE_ROCKSDB` and with `P10_MESSAGE_TAGS` off. The handler's mint is inside `#ifdef USE_ROCKSDB` (`ircd_relay.c:1029-1042`), and with tags off `format_s2s_tags` mints nothing either, so `#a`'s reservation is still pending at `#b`'s reveal.
   - The same duplicate arises on every server for a tagged S2S line with a comma target list (`ms_topic` loops over targets under one stash id) when the setter is hidden in two of them; plausible only for a service or foreign server, since this code sends one target per line.
   - Confidence: confirmed by reading; the "same event id + same member gives the same id whatever the channel" part confirmed by scratch.
   - Minimal fix: drop the reservation at each `continue` after the reveal in `m_topic()` (a small `generate_msgid_ahead_drop()`), and/or fold the channel name into `msgid_derive_join()`.

4. **`ircd/test/Makefile.in:7` with `:242` — `make depend` in `ircd/test` appends preprocessed C source to `Makefile.in` under clang.**
   - What is wrong: `-MMD -MP` were added to `CFLAGS`, and the depend rule runs `${CC} ${CFLAGS} -MM ${CPPFLAGS} ${DEP_SRC} >> Makefile.in`. With clang, `-MM` together with `-MMD` writes the dependencies to `.d` files and puts the preprocessed source on stdout.
   - Scenario: `cc -g -Wall -MMD -MP -MM a.c` printed the preprocessed `a.c` and created `a.d`. gcc was not tested; its documentation suggests `-MM` wins there and the list only gains the `-MP` phony header targets.
   - Confidence: flag behaviour confirmed by scratch (Apple clang); the Makefile target itself not run.
   - Minimal fix: keep `CFLAGS` as it was and add `-MMD -MP` in the `.c.o` rule and the explicit compile rules (as `ircd/Makefile.in` does), or strip them in the depend rule.

5. **`ircd/ircd_string.c:2242-2246` — the 9-bit fold collides for mints 18 apart in one millisecond, and in general 1 in ~512.**
   - What is wrong: only 9 bits of the event id survive in the derived id; node, counter and first client char are the member's, the time is shared by all events of that millisecond.
   - Scenario: event ids `ABAAIaHQiPkAFs` and `ABAAaaHQiPkAF[` (same server, same ms, logical and counter both +18) give the same JOIN id `ACPnDaHQiPj]4f` for member `AC`+`D4f`. `MAXTARGETS` is 20, so `PRIVMSG` to 20 +D channels the sender is hidden in can pair targets 1/19 or 2/20 (about 1% of such pairs collide, when all 20 land in one ms). Two unrelated events in one ms that reveal the same member in two channels collide 1 in 518 (measured over 2M random pairs).
   - Confidence: confirmed by scratch; low reachability, and the effect is a duplicate JOIN msgid across two channels as in finding 3. The CMocka case only tries four adjacent counters.
   - Minimal fix: use more bits (the counter's 12 bits could carry fold bits too if the member's client chars 2-3 are folded in rather than copied), or accept and document the odds.

6. **`ircd/ircd_string.c:2215-2218` (doc claim) vs `ircd/crdt_hlc.c:30-42` — "a minted id has bit 15 clear" is not enforced.**
   - What is wrong: `hlc_step()` counts logical up to 0xFFFF before carrying, and logical only resets when the wall clock passes the HLC's physical time. After a backward wall-clock step, or after adopting a peer up to 60 s ahead that then goes quiet, every mint and every received tagged line increments logical for that whole span; 32768 of them put bit 15 into minted ids (and peers adopt the high logical through `hlc_receive`).
   - Scenario: scratch built a well-formed minted id (node `AC`, logical 0xFE43, time T-1, counter 3615) equal to a derived JOIN id. Meeting it in practice also needs the right node, logical and 12-bit counter.
   - Confidence: mechanism confirmed by reading and scratch; collision is theoretical.
   - Minimal fix: carry into physical time at 0x7FFF in `mint_msgid()`/`hlc_step()`, or soften the comment.

7. **`ircd/m_clearmode.c:292`, `:315` — CLEARMODE removing +D with `JOIN_ON_REMOVEDELAY` on still gives one JOIN id per server.**
   - What is wrong: the flush's `show_delayed_joins()` reveals every hidden member, but the CLEARMODE line is relayed untagged (`sendcmdto_serv_butone` without `sendcmdto_want_s2s_tags`), so each server reserves and derives from its own id.
   - Confidence: confirmed by reading; needs a non-default feature. Same outcome as before the change, but it is a reveal path the "same id on every server" claim does not cover.
   - Minimal fix: relay CLEARMODE with the flush's msgid and time (`sendcmdto_set_s2s_tags` + `sendcmdto_want_s2s_tags(1)`).

8. **Tests do not exercise the handoff where it can fail.**
   - `ircd/test/channel_speak_cmocka.c:88-115` replaces `generate_msgid()`/`generate_msgid_ahead()` with its own copy (no HLC guard, no end-of-line reset), so the reveal cases prove only that `reveal_msgid_for()` picks its source in the stated order.
   - `send_s2s_tags_cmocka.c` compiles the real `send.c` and does test reserve/take/reset/HLC-moved, against a stub HLC (`:42-49`, logical only), in isolation.
   - Nothing drives a handler: no multi-target TOPIC (finding 3), no split modebuf (finding 1), no relay path, no clamped link time (finding 2). `s2s_handlers_cmocka.c` and `rename_handlers_cmocka.c` stub `RevealDelayedJoin` and ignore the new argument.
   - `send_label_cmocka.c:63-67` adds an `hlc_global()` that always returns zeros: fine as a link stub, but the guard can never fire there.

## Checked and found correct

- Reserve-to-mint window on local PRIVMSG, NOTICE, statusmsg (`ircd_relay.c:1021`, `:1167`, `:1618`), WALLCHOPS/WALLHOPS/WALLVOICES and `do_settopic()`: nothing between the reveal and the event's mint calls `generate_msgid()` or moves the HLC. The JOIN sends, the AWAY, `store_channel_event()` (id supplied), and `CheckDelayedJoins()`' `MODE -d` mint nothing; `hlc_global_event()`'s other callers (metadata, forwarded labels) are not reachable there.
- Untagged S2S lines: `s2s_mint_link_event()` runs before the reveal in the PRIVMSG/NOTICE/statusmsg relays, so the reveal reads the stash; TOPIC, MODE and wall commands reserve and the event (or `format_s2s_tags`) takes the id, and the onward relay carries it.
- A reservation made inside a line does not outlive it: `sendcmdto_reset_s2s_overrides()` runs after every `parse_client`/`parse_server` (and before each server line); it is called only from `packet.c`. A reveal outside any line (timer, callback) that nothing took would be taken by the next client line's event with a stale time; I found no such reveal (the two timer-side modebufs in `m_rename.c:1986`, `:2007` only set or clear +L). A reserved id taken by another event is still used once, never twice (the JOIN uses the derived id, not X).
- Multi-target PRIVMSG/NOTICE: each target reveals, then mints, so each gets its own reservation (with `USE_ROCKSDB` or `P10_MESSAGE_TAGS` on; see finding 3 otherwise).
- A 6-entry modebuf flushes inside `modebuf_mode_client()` immediately after the entry is added, before the next member's reveal, so count-based splits stay consistent; only the size-based split (finding 1) breaks.
- MODE source agreement: for a server line `mb_connect` is the inbound link in `ms_mode`, OPMODE, CLEARMODE and `relocate_follow`, so the reveal (inbound stash) and the flush (`cli_s2s_msgid(mb_connect)`, ungated) read the same id. The flush's read is ungated, which is fragile, but I found no revealing path where they differ (`m_burst.c` not traced in detail).
- Multiline: the origin mints the batch id first and passes it in; a receiving multiline server reveals on the start line, whose stash is the batch id; a non-multiline server gets the batch id on the first fallback line from both the origin (`m_batch.c:2157`) and a relaying hub (`:3163`).
- Same member numeric everywhere for an ordinary sender: server numeric + client numeric of `member->user`, the same client on the origin and on the relays. Not established for a line sent by a bouncer device: the relays reveal the primary, and whether the origin reveals anyone depends on the alias's membership (two alias-add sites skip channels where the primary is hidden; the others were not read). That behaviour predates this diff.
- `msgid_derive_join()`: output is 14 chars + NUL with `outlen > 14` checked; logical is at most 0xFFFF so it decodes; numerics are validated against the alphabet; `out` is cleared on failure; `ms--` only breaks at the 2020-01-01 lower bound (decodes to 0 — unreachable). `msgid_ahead[16]` fits the 14-char mint; `ircd_strncpy` terminates.
- A derive failure (foreign event id, 1-character server numeric) falls back to a local mint; if the id was reserved the JOIN takes it and the event mints another, so no duplicate.
- Live order: every reveal is sent before its event. Stored order in the normal case: JOIN at T-1, event at T.
- `ircd/Makefile.in`: `-MMD -MP` are in the `.c.o` rule only, `-include *.d kc/*.d` sits at the end (default target unchanged), `clean` removes the `.d` files; its `depend` rule is not affected.

## Limits of this review

Not built or run here: `./configure` fails on this Mac (the OpenSSL link test passes `-Wl,-rpath=…`, which the macOS linker rejects) and there is no CMocka or RocksDB installed, so none of the CMocka suites ran. "Confirmed by reading" above means traced in the source; "confirmed by scratch" means a program under `<scratch>/fable-scratch/` (`derive_test.c`, which compiles `msgid_derive_join` and `msgid_decode_time_ms` extracted verbatim from `ircd/ircd_string.c`; `mm/` for the compiler-flag check).
