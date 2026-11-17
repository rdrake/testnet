# nefarious2 draft PRs: open questions (updated 2026-11-17 20:16 UTC)

Decisions on the draft PRs to evilnet/nefarious2 from the 2026-11-17 review round. Each PR already implements the option marked **(current)**, so nothing is blocked; changing a choice later is a follow-up commit.

**How to read this:**
- Every item has a stable ID (`Q1`…`Q16`) and exactly one status line: `Status: 🟡 OPEN` (needs an answer) or `Status: ✅ RESOLVED` (decided and done or in progress).
- Open items come first. Resolved items stay below for the record and are never deleted.
- To answer one, reply with its ID and the option you want.

## Summary

| ID | PR | Question | Status |
|----|----|----------|--------|
| Q2 | #245 | Session live at a newer build's crash: expire or keep holding? | 🟡 OPEN |
| Q3 | #245 | Restored session whose nick another account holds: skip or fallback nick? | 🟡 OPEN |
| Q4 | #246/#247 | Rehash pre-check mechanism | 🟡 OPEN |
| Q5 | #246 | GitSync when the check itself crashes | 🟡 OPEN |
| Q11 | #261 | Split into three PRs? | 🟡 OPEN |
| Q12 | #261 | Does `sslfp = ""` mean "no fingerprint required"? | 🟡 OPEN |
| Q14 | #289 | Offer the old `evilnet/channel-relocate` name for a transition release? | 🟡 OPEN |
| Q15 | #280 | Fix shape for a services rename of a bouncer session's account | 🟡 OPEN |
| Q16 | testnet | Is `testnet-svc/data/x3.conf` meant to be used, or stale? | 🟡 OPEN |
| Q1 | #242 | Accept `+00:00` timestamps? | ✅ RESOLVED: no, spec form only |
| Q6 | #252 | Which channels a no-`in=` SEARCH federates; scan cost | ✅ RESOLVED: keep scope, scan to the thread pool |
| Q7 | #253 | Extras as `PERSISTENCE` subcommands or their own command? | ✅ RESOLVED: subcommands |
| Q8 | #253 | Does cap-less use of the extras end? | ✅ RESOLVED: never |
| Q9 | #253 | Must Seance #327 ship before `PERSISTENCE_DRAFT_EXTRAS` goes FALSE? | ✅ RESOLVED: nef2 goes ahead; Seance tracked in evilnet/seance#333 |
| Q10 | #253 | Capability name form | ✅ RESOLVED: `evilnet.github.io/persistence` |
| Q13 | #253 | Cap-gating unsolicited output (restore batch, SET line) | ✅ RESOLVED: gated |
| Q17 | #289 | Move old vendor names to the DNS form? | ✅ RESOLVED: yes, draft #289 |

---

# 🟡 OPEN: needs an answer

### Q2 · #245 bouncer: rollback keeps a newer build's session records
Status: 🟡 OPEN

A session was live when a newer build crashed; an older build then ran, and the newer build came back. What happens to the session?
- expire it at the roll-forward **(current)**;
- keep holding it from the crash. This needs the older build to keep the newer one's last heartbeat, for example under a per-writer key `bouncer/alive/<writer>`.

### Q3 · #245 bouncer: restore with a taken nick
Status: 🟡 OPEN

At restore, another account's restored session already holds this session's nick.
- skip it; its record stays until its hold ends **(current)**;
- restore it under a fallback nick.

### Q4 · #246 / #247 rehash: the pre-check mechanism
Status: 🟡 OPEN

How should a configuration with errors be caught before a rehash applies it?
- a child-process check (`ircd -k` in a fresh process) **(current)**;
- parse into staged structures, swapped in only on success;
- an in-process syntax-only pass (catches syntax errors and missing includes, not semantic ones).

### Q5 · #246 GitSync when the check fails to run
Status: 🟡 OPEN

If the child process stays (#246 only), what does GitSync do when the check itself crashes or cannot run?
- refuse the commit after one crash **(current)**;
- treat the result as unknown and proceed;
- refuse only after a second failure.

### Q11 · #261 res, ssl, nick: one PR or three?
Status: 🟡 OPEN

#261 carries three independent inherited-bug fixes. Should it be split into three PRs, one per bug, following the one-subject-per-PR practice?

### Q12 · #261 an empty `sslfp`
Status: 🟡 OPEN

What should `sslfp = "";` in a block mean?
- refuse every client **(current)**;
- treat an empty `sslfp` as no requirement.

### Q14 · #289 old capability name during a transition
Status: 🟡 OPEN

Should the old capability name `evilnet/channel-relocate` also be offered for one transition release?

#289 does not offer it: a client still asking for it is NAKed and gets the PART/JOIN fallback. Two names for one capability would need new plumbing, and no known client (Seance included) requests it. The old ISUPPORT name is kept for a release.

### Q15 · #280 a services rename of a bouncer session's account
Status: 🟡 OPEN

X3's `RENAME` sends `AC M`, which changes every connection's account while the session stays filed under the old name. After a split and heal, both halves are killed (issue evilnet/nefarious2#280). What should the fix be?
- each server re-files the session under the new name on an `M` from a services server, merging by session id (proposed in #280);
- services are kept from renaming an account with a live bouncer session;
- something else.

### Q16 · testnet: which X3 config is live
Status: 🟡 OPEN

In the testnet-svc compose setup, X3 reads `/x3/data/x3.conf` from the `x3_data` volume (seeded from `x3/docker/x3.conf-dist`), not `testnet-svc/data/x3.conf`. Is `data/x3.conf` meant to be used, or is it stale?

---

# ✅ RESOLVED

### Q1 · #242 timestamps with an explicit zero offset
Status: ✅ RESOLVED (2026-11-17, done in 1ec4bc92)

**Decision:** follow the spec exactly. A client timestamp is accepted only as `YYYY-MM-DDThh:mm:ss.sssZ`, in CHATHISTORY, SEARCH and MARKREAD:
- three fractional digits;
- uppercase `T` and `Z`;
- fields in range, with seconds up to 60 for a leap second.

`+00:00`, a missing `Z` or fraction, and a fraction of another length are refused with `FAIL ... INVALID_PARAMS`.

**Why:** `extensions/chathistory.md:67`: "A `timestamp` parameter MUST have the format `timestamp=YYYY-MM-DDThh:mm:ss.sssZ`". `read-marker.md:52` says the same. ibutsu: "technically a spec violation, so it's really a matter of how strict we want to be".

### Q6 · #252 which channels a SEARCH without `in=` federates
Status: ✅ RESOLVED (2026-11-17)

**Decision:** #252 keeps its scope (up to 8 of the requester's channels). The cost, about 2 s of a storage peer's main loop for 8 channels of 50 000 rows, is fixed by moving the SEARCH store walk to the thread pool in a separate follow-up PR built on #252 (in progress).

**Why:** ibutsu: "rocksdb reads are thread safe and we can use the threadpool for them".

### Q7 · #253 extras as subcommands
Status: ✅ RESOLVED (2026-11-17, no code change)

**Decision:** ATTACH, DETACH, LIST, PROFILE and REPLAY stay `PERSISTENCE` subcommands.

**Why:** the draft says "Implementations SHOULD ignore unrecognized subcommands, to be compatible with future extensions of this specification" (ibutsu).

### Q8 · #253 cap-less use of the extras
Status: ✅ RESOLVED (2026-11-17, done in c70cd604)

**Decision:** the extras work on every connection, whatever the caps and the `PERSISTENCE_DRAFT_EXTRAS` flag. `evilnet.github.io/persistence` announces them; the flag controls only the old names.

**Why:**
- ibutsu: a gate "blocks bouncer users without the CAP from adjusting the auto-replay". REPLAY is the only way to set auto-replay.
- The gate protected nothing: each extra requires the account and acts only on that account's own sessions and settings.

### Q9 · #253 ordering with Seance
Status: ✅ RESOLVED (2026-11-17, tracked in evilnet/seance#333)

**Decision:** nefarious2 makes its transitions without waiting for Seance. #253 can merge first. Seance's side (evilnet/seance#327: request the vendor cap, read `attach-cursor` from either value, accept either batch type) is tracked in evilnet/seance#333 with the other nefarious2 transitions, and is worked separately.

**Why:** while `PERSISTENCE_DRAFT_EXTRAS` is on (the default), Seance develop sees no change. Turning it FALSE is a deployment step, to be taken once #333's persistence items are in every shipped Seance build (web, phone, desktop).

### Q10 · #253 the capability's name
Status: ✅ RESOLVED (2026-11-17)

**Decision:** `evilnet.github.io/persistence`.

**Why:** vendor-specific capability names "are prefixed by a valid DNS domain name" (`extensions/capability-negotiation.md:510`, cited by ibutsu), which `evilnet/<name>` is not.

### Q13 · #253 cap-gating unsolicited output
Status: ✅ RESOLVED (2026-11-17, done in 1b414b16)

**Decision:**
- The restore batch is wrapped only for a connection with `evilnet.github.io/persistence` (vendor type) or, while `PERSISTENCE_DRAFT_EXTRAS` is on, for any `batch` client (old type, as before). Otherwise its lines go out unwrapped.
- The non-spec `PERSISTENCE SET <state>` line before a SET's STATUS goes only to a vendor-cap connection or while the flag is on.

**Why:** ibutsu: "anything that has the server send unsolicited messages the client may not understand must be CAP gated … there's some gray area there since clients are supposed to ignore batch types they don't understand."

### Q17 · old vendor names to the DNS form
Status: ✅ RESOLVED (2026-11-17, draft evilnet/nefarious2#289)

**Decision:** both move to the DNS form.
- The capability `evilnet/channel-relocate` becomes `evilnet.github.io/channel-relocate`. The feature `CAP_evilnet_channel_relocate` keeps its name. Whether to keep offering the old name is Q14.
- The ISUPPORT token `evilnet/CHATHISTORYRETENTION` becomes `evilnet.github.io/CHATHISTORYRETENTION`. The old name is also advertised, with the same value, for a transition release.

**Why:**
- `capability-negotiation.md:510` covers the capability.
- ISUPPORT has no rule of its own. ibutsu: "maybe they're supposed to use the full name too". soju uses its DNS name for its own capabilities and most of its own ISUPPORT tokens (`soju.im/SAFERATE`, `soju.im/FILEHOST`).

---

## Merge order notes (no decision needed)
- Whichever of #232 and #252 lands second needs `requester_type_mask()`.
- Whichever of #268 and #278 lands second drops #268's special case.
- #241 lands with or before #276.
