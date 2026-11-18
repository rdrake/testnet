# #256 review: Codex and Fable (2026-11-18)

Richard asked for a Codex review (run on the Mac) and a Fable review of #256's redesign. Both reviewed head b5664fe1 against ircv3.2-upgrade 426b2808. The two reviewers worked independently, in separate checkouts, from the same brief. Each was given the code and the intended design, not our conclusions. The raw reports are in `256-review/codex.md` and `256-review/fable.md`.

Neither reviewer could build: `./configure` fails on macOS because the OpenSSL link test passes `-Wl,-rpath=`, and CMocka is missing. "Confirmed by reading" means traced in the source. "Scratch" means a standalone C program that compiles `msgid_derive_join()` and `msgid_decode_time_ms()` copied verbatim. I re-read the code for items 1, 3 and 4 and the shapes match.

Status: findings only. Fixes wait for Richard's go.

## Findings, merged, most severe first

1. **A MODE split by the modebuf gives the origin a different JOIN id from every other server.** Found by both reviewers.
   - Where: `channel.c:5049-5050` reveals at parse time and reserves "the next mint". `modebuf_flush_int()` sends only the entries that fit (`BUFSIZE - 200`). An entry that doesn't fit gets `MODE_SAVE` and goes out in a second MODE (`:3270`) with its own mint.
   - What happens, e.g. `MODE #c +bbbv <3 long masks> hiddennick`: the origin's JOIN is derived from the first MODE's id (bans only). The other servers reveal on the second MODE and derive from its id.
   - Who can trigger it: any chanop, on purpose.
   - Fix: reveal where the MODE's id is known. Either reveal the non-saved `+o/h/v` entries in `modebuf_flush_int()` just before the id is chosen (`:3053`), or mint first and pass the id in.
   - The tests stub the sends, so they miss this.

2. **The JOIN's time comes from the event's msgid, not the event's effective time.** Found by both.
   - Where: `channel.c:6298-6299`, together with `parse.c:2101-2113`.
   - What happens: when a peer's clock is more than `HLC_MAX_FORWARD_MS` ahead, `parse.c` replaces the line's time with local HLC time but keeps the msgid. The event is stored at local now, while the JOIN is stored at the peer's time − 1 ms. With a peer 5 minutes fast, the JOIN sits in the future and sorts after its message and after the next 5 minutes of traffic in history. Before this change the JOIN used local HLC time.
   - Fix: keep the derived id, but `reveal_ms = min(decoded − 1, event_time − 1)`.

3. **A TOPIC target that reveals and then mints nothing leaves the reservation for the next target.** Found by Fable.
   - Where: `m_topic.c:338-347`.
   - What happens: `client_can_send_to_channel(..., 1)` reveals and reserves X. Then a `+c` (NOCOLOR) refusal, or an unchanged local `&channel` topic, does `continue` without minting. The next target's reveal gets X again. `msgid_derive_join()` has no channel input, so the user's JOINs in #a and #b share one msgid.
   - Example: `TOPIC #a,#b :<colour>` with the user hidden in both and #a set +c. Same outcome for a local `PRIVMSG #a,#b` in a build without RocksDB and with P10_MESSAGE_TAGS off, since the mint is under `#ifdef USE_ROCKSDB` (`ircd_relay.c:1029-1042`).
   - Background: 193d5ed0 had a per-target reset for this case; b5664fe1 removed it.
   - Fix: drop the reservation on each `continue` after a reveal, and/or fold the channel name into the derivation. Folding the channel name also covers the S2S comma-target case on every server.

4. **`make depend` in `ircd/test` appends preprocessed C to `Makefile.in` under clang.** Found by Fable; the flag behaviour was checked with Apple clang.
   - Where: `test/Makefile.in:7` puts `-MMD -MP` in `CFLAGS`, and `:242` runs `${CC} ${CFLAGS} -MM`. With clang, `-MM` plus `-MMD` writes the deps to `.d` files and prints the preprocessed source to stdout, which then lands in `Makefile.in`.
   - Fix: add `-MMD -MP` only in the compile rules, as `ircd/Makefile.in` already does.

5. **The 9-bit fold collides.** Found by both; confirmed with scratch.
   - What happens: two different events in one millisecond that reveal the same member collide about 1 time in 512. Mints 18 apart always collide, e.g. targets 1 and 19 of a 20-target PRIVMSG to +D channels the sender is hidden in. The description's "one member revealed by two events in the same millisecond gets two ids" is therefore not true in general.
   - The CMocka case tries only four adjacent counters and holds `logical` constant.
   - Fix: carry more of the event id. For example, fold the member's last two client characters together with the event's counter, freeing the 12-bit counter field for more fold bits. A separate derived-id format is the bigger alternative. Folding in the channel (item 3) helps the cross-channel case.

6. **"A minted id has bit 15 clear" is not enforced.** Found by both.
   - Where: `crdt_hlc.c:30-42` counts the logical counter to 0xFFFF before carrying.
   - What happens: after a backward clock step, or after adopting a peer clock up to 60 s ahead, every mint and every received tagged line bumps the logical counter. After 32768 of them, minted ids have bit 15 set, and peers adopt that counter. Scratch built a minted tuple equal to a derived id. In practice a collision also needs a matching node, counter and time, so it is theoretical.
   - Fix: carry into physical time at 0x7FFF in `hlc_step()`/`mint_msgid()`, or soften the claim.

7. **CLEARMODE removing +D with `JOIN_ON_REMOVEDELAY` still gives a per-server JOIN id.** Found by Fable.
   - Where: `m_clearmode.c:292`, `:315`. The line is relayed without S2S tags, so each server derives from its own id.
   - This needs a non-default feature, and the behaviour is the same as before #256, but the description's "every reveal path" claim doesn't cover it.
   - Fix: relay CLEARMODE with the flush's msgid and time (`sendcmdto_set_s2s_tags` + `sendcmdto_want_s2s_tags(1)`), or list it under the limits.

8. **The tests don't exercise the handoff where it can fail.** Found by both.
   - `channel_speak_cmocka.c:88-115` replaces `generate_msgid()`/`generate_msgid_ahead()` with its own copy, which has no HLC guard and no end-of-line reset.
   - No test drives a handler: none for a multi-target TOPIC, a split modebuf, a relay, or a clamped link time.
   - `s2s_handlers_cmocka.c` and `rename_handlers_cmocka.c` stub `RevealDelayedJoin` and ignore its new argument.
   - Add handler-level cases for items 1–3.

## Checked and found correct (both reviewers, summarised)

- Local PRIVMSG, NOTICE, statusmsg, WALL*, and `do_settopic()`: nothing between the reveal and the event's mint mints or moves the HLC.
- Untagged S2S lines: the relay mints before the reveal, or the reveal reserves and the event takes the id; the onward relay carries it.
- A reservation never outlives its line. `sendcmdto_reset_s2s_overrides()` runs after every parsed line. No reveal happens outside a line.
- Count-based modebuf splits (6 entries) flush before the next member's reveal, so they stay consistent. Only the size-based split (item 1) breaks.
- Multiline: the origin, a receiving multiline server, a non-multiline server and a relaying hub all derive from the batch id.
- `msgid_derive_join()` bounds, validation, and failure fallback (no duplicate id) are correct. The `ircd/Makefile.in` dependency change is correct; only the test Makefile has the problem in item 4.
- Not established: the member numeric used when the sender is a bouncer device. This behaviour predates #256.

## Suggested order, if Richard says go

1. Item 1, then items 3 and 2. These break the PR's own claim or its ordering. Fold the channel into the derivation as part of item 3, and decide item 5 at the same time.
2. Item 4: a one-line Makefile fix.
3. Items 6 and 7: a small HLC carry fix and a CLEARMODE tag relay, or document both as limits.
4. Item 8's tests alongside items 1–3.
5. Rewrite the #256 description's claims to match: items 3, 5 and 6 contradict sentences in bodies-8/256.md.
