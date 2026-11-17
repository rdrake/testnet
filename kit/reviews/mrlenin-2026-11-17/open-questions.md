# nefarious2 draft PRs: open questions (2026-11-17)

Decisions still needed on the draft PRs to evilnet/nefarious2 after the 2026-11-17 review round. Each PR already does the option marked **(current)**, so nothing is blocked; changing a choice is a follow-up commit.

## #242 chathistory: SEARCH and timestamp parsing
1. **Decided (2026-11-17):** a timestamp with an explicit zero offset (`+00:00`) stays refused with `FAIL ... INVALID_PARAMS`. `extensions/chathistory.md:67` says a `timestamp` parameter MUST have the format `timestamp=YYYY-MM-DDThh:mm:ss.sssZ`; ibutsu agrees it is a spec violation and a matter of strictness. The #242 description says so.
   - **Done (2026-11-17, 1ec4bc92):** following the spec all the way: a client timestamp is taken only as exactly `YYYY-MM-DDThh:mm:ss.sssZ` (three fractional digits, uppercase `T`/`Z`, fields in range, seconds to 60 for a leap second) in CHATHISTORY, SEARCH and MARKREAD. A missing `Z` or fraction, or a fraction of another length, is now refused too.

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
   - **Dev input (ibutsu, 2026-11-17):** "rocksdb reads are thread safe and we can use the threadpool for them". So the scan could move off the main loop: a `thread_pool_submit()` worker walks the store, and the callback filters and replies on the main thread. That removes the ~2 s stall whichever channels federate.
   - **In progress (2026-11-17):** moving the SEARCH store walk to the thread pool.
   - **Decided (2026-11-17):** the thread-pool scan goes in a separate follow-up PR built on #252 (in progress); #252 keeps its current scope (up to 8 channels).

## #253 persistence: the extras move to `evilnet.github.io/persistence`
7. Do the extras (ATTACH, DETACH, LIST, PROFILE, REPLAY) stay `PERSISTENCE` subcommands under the vendor capability **(current)**, or move to a vendor command of their own?
   - **Dev input (ibutsu, 2026-11-17):** "the proposed spec says unknown subcommands should be ignored, so it allows for extending really." This supports keeping the extras as `PERSISTENCE` subcommands.
   - **Decided (2026-11-17): they stay `PERSISTENCE` subcommands.** The draft: "Implementations SHOULD ignore unrecognized subcommands, to be compatible with future extensions of this specification." No code change.
8. Does cap-less use of the extras end with this change, or only when `PERSISTENCE_DRAFT_EXTRAS` goes FALSE **(current)**?
   - **Dev input (ibutsu, 2026-11-17):** "Not allowing the command without the cap blocks bouncer users without the CAP from adjusting the auto-replay, so that's something to consider." At #253's head (e10e4c08), `REPLAY` (the auto-replay setting) is one of the gated extras (`persistence_extras_allowed()`, `ircd/m_persistence.c:1009`, gate at `:1051`). So once `PERSISTENCE_DRAFT_EXTRAS` is FALSE, a client without `evilnet.github.io/persistence` cannot change auto-replay.
   - **Decided (2026-11-17, c70cd604): cap-less use never ends.** The extras are reachable by every connection, whatever the caps and the flag. The gate protected nothing: each extra requires the account and acts only on that account's own sessions and settings, and a cap is not a credential. `evilnet.github.io/persistence` now announces the extras and names the restore batch type; `PERSISTENCE_DRAFT_EXTRAS` controls only the old names (the value on `draft/persistence` and the `draft/persistence` batch type).
9. Ordering with Seance: should evilnet/seance#327 merge and deploy before `PERSISTENCE_DRAFT_EXTRAS` is turned off? (While it is on, Seance develop sees no change.)
10. **Decided (2026-11-17):** the capability's name is `evilnet.github.io/persistence`. Vendor-specific capability names "are prefixed by a valid DNS domain name" (`extensions/capability-negotiation.md:510`, cited by ibutsu), which `evilnet/<name>` is not.

## #261 res, ssl, nick: three small inherited bugs
11. Split it into three PRs, one per bug?
12. Should `sslfp = ""` in a block mean "no fingerprint required"?

## Vendor name prefixes on ircv3.2-upgrade
- **Decided (2026-11-17): both move to the DNS form**, on branch `fix/vendor-cap-name` (new draft PR):
  - the capability `evilnet/channel-relocate` becomes `evilnet.github.io/channel-relocate` (`capability-negotiation.md:510`). The feature `CAP_evilnet_channel_relocate` keeps its name. A client still asking for the old name is NAKed and gets the PART/JOIN fallback; no known client (Seance included) requests it;
  - the ISUPPORT token `evilnet/CHATHISTORYRETENTION` becomes `evilnet.github.io/CHATHISTORYRETENTION`, with the old name also advertised, same value, for a transition release.

  ibutsu (2026-11-17): "isupport tokens don't really get any clarification, and I've only seen "draft/" ones, but maybe they're supposed to use the full name too". The IRCv3 specs only show `draft/` ISUPPORT tokens (`draft/ICON`, `draft/ACCOUNTREQUIRED`). soju uses its DNS name for its own capabilities and for most of its own ISUPPORT tokens (`soju.im/SAFERATE`, `soju.im/FILEHOST`; `BOUNCER_NETID` is unprefixed).
- **Open:** should the old capability name also be offered for a transition release? This PR does not (two names for one capability need new plumbing).

## Merge order notes (no decision needed)
- Whichever of #232 and #252 lands second needs `requester_type_mask()`.
- Whichever of #268 and #278 lands second drops #268's special case.
- #241 lands with or before #276.
