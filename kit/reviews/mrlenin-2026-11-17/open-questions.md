# nefarious2 draft PRs: open questions (2026-11-17)

Decisions still needed on the draft PRs to evilnet/nefarious2 after the 2026-11-17 review round. Each PR already does the option marked **(current)**, so nothing is blocked; changing a choice is a follow-up commit.

## #242 chathistory: SEARCH and timestamp parsing
1. **Decided: refuse.** A timestamp with an explicit zero offset (`2026-11-17T12:00:00.000+00:00`) is a spec violation: chathistory takes `timestamp=` in the server-time format, `YYYY-MM-DDThh:mm:ss.sssZ`, UTC with `Z`. #242 answers it with `FAIL ... INVALID_PARAMS`, as it does now.

## #245 bouncer: rollback keeps a newer build's session records
2. A session live when a newer build crashed, after which an older build ran and the newer build came back:
   - expire it at the roll-forward **(current)**;
   - keep holding it from the crash (needs the older build to keep the newer one's last heartbeat, e.g. under a per-writer key `bouncer/alive/<writer>`).
3. At restore, a session whose nick another account's restored session holds:
   - skip it; its record stays until its hold ends **(current)**;
   - restore it under a fallback nick.

## #246 / #247 rehash: a configuration with errors abandons the rehash
4. The mechanism:
   - a child-process check (`ircd -k` in a fresh process) **(current)**;
   - parse into staged structures, swapped in only on success;
   - an in-process syntax-only pass (catches syntax errors and missing includes, not semantic ones).
5. If the child process stays (#246 only), what GitSync does when the check itself crashes or cannot run:
   - refuse the commit after one crash **(current)**;
   - treat the result as unknown and proceed;
   - refuse only after a second failure.

## #252 chathistory: SEARCH without `in=` asks the other storage servers
6. Which channels a no-`in=` SEARCH federates (each part costs every storage peer a full scan in its main loop, about 2 s for 8 channels of 50 000 rows):
   - all of the requester's channels within the PR's bounds, at most 8 **(current)**;
   - only channels whose window this server did not fully receive (`channel_range_check()`, as pages already use);
   - all of them, sharing one scan budget across the parts (e.g. a `max=<n>` selector that older responders ignore);
   - a lower `SEARCH_FED_PARTS_MAX`, or fake lag charged per part.

## #253 persistence: the extras move to `evilnet.github.io/persistence`
7. Do the extras (ATTACH, DETACH, LIST, PROFILE, REPLAY) stay `PERSISTENCE` subcommands under the vendor capability **(current)**, or move to a vendor command of their own?
8. Does cap-less use of the extras end with this change, or only when `PERSISTENCE_DRAFT_EXTRAS` goes FALSE **(current)**?
9. Ordering with Seance: should evilnet/seance#327 merge and deploy before `PERSISTENCE_DRAFT_EXTRAS` is turned off? (While it is on, Seance develop sees no change.)
10. The capability's name form: `evilnet.github.io/persistence` **(current)**, a DNS name like the existing `evilnet.github.io/...` batch and tag names, or `evilnet/<name>` as `evilnet/channel-relocate` uses?

## #261 res, ssl, nick: three small inherited bugs
11. Split it into three PRs, one per bug?
12. Should `sslfp = ""` in a block mean "no fingerprint required"?

## Merge order notes (no decision needed)
- Whichever of #232 and #252 lands second needs `requester_type_mask()`.
- Whichever of #268 and #278 lands second drops #268's special case.
- #241 lands with or before #276.
