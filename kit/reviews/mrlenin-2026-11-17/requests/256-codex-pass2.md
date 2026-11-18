# #256 Codex pass 2 (2026-11-18, head 16d2e25f)

Richard asked for a Codex pass over the fixes. Codex ran on the Mac. Its brief listed the eight earlier findings and asked it to check, from the code, whether each one is fixed on every path, and to look for regressions in `b5664fe1..16d2e25f`. The raw report is `256-review/codex-pass2-16d2e25f.md`. Codex couldn't run CMocka on macOS (OpenSSL rpath); it used standalone programs built with ASan and UBSan.

## Earlier findings

| # | Verdict |
|---|---|
| 1. The modebuf splits a MODE | Fixed: status arguments get their space first, so they go out in the first MODE |
| 2. The JOIN's time when the line's time was replaced | Fixed for normal ids; see 4 below |
| 3. The TOPIC reservation is reused | Fixed, because the channel is in the derivation (the reservation itself can still carry over) |
| 4. clang `make depend` | Fixed |
| 5. The fold collides | Mostly fixed: a 39-bit hash replaces it; see 1 below |
| 6. Bit 15 | Fixed: carries at 0x7FFF, including when an older peer sends a larger logical |
| 7. CLEARMODE is untagged | Fixed on links that keep tags |
| 8. The tests stub the handoff | Fixed for the outgoing side; nothing tests receive-side `parse.c` or history storage |

## New or remaining findings, with my assessment

1. **Different events can still give one JOIN id** (`ircd_string.c:2261-2272`). Codex found a pair: two valid ids from different servers in the same ms, for one channel and one member, give the same JOIN id. The odds are 2^-39 per pair, and both events must reveal the same member in the same channel in the same millisecond. *My view:* a theoretical risk only. Note it as a limit; changing the format isn't worth it.
2. **A b5664fe1 server and a 16d2e25f server derive differently.** *My view:* moot. b5664fe1 was never released (draft PR), so no network runs it. Put a line in the description saying the derivation is part of the protocol and changing it needs a coordinated upgrade.
3. **An event id that doesn't decode (older layout, other implementation)** falls back to a local mint at local HLC time (`channel.c:6315-6317`). The per-server id is already a stated limit. Not stated: the JOIN's *time* can then be after the event's effective time, e.g. an event dated 1 s behind this server. *My view:* worth a tiny fix. On that fallback, clamp `reveal_ms` to `event_time - 1` as the decoded path does.
4. **An event at exactly 2020-01-01 00:00:00.000** gives a JOIN at the decoder's lower bound minus 1, which decodes to 0 and gets wall or HLC time. *My view:* unreachable in practice. At most, have `msgid_derive_join()` return its time instead of decoding it again.

Suggested follow-up for the cloud, only if Richard says go: item 3's clamp (a few lines), and optionally item 4's direct time. Add a sentence to the description for items 1 and 2. Receive-side and history tests (row 8) would be good if cheap.
