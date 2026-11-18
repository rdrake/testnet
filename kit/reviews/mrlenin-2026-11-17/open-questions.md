# nefarious2 draft PRs: open questions (updated 2026-11-18 19:35 UTC)

Decisions on the draft PRs to evilnet/nefarious2 from the 2026-11-17 review round. Each PR already implements the option marked **(current)**, so nothing is blocked; changing a choice later is a follow-up commit.

**How to read this:**
- Every item has a stable ID (`Q1`…`Q18`) and exactly one status line: `Status: 🟡 OPEN` (needs an answer) or `Status: ✅ RESOLVED` (decided and done or in progress).
- Open items come first. Resolved items stay below for the record and are never deleted.
- To answer one, reply with its ID and the option you want.

## Summary

| ID | PR | Question | Status |
|----|----|----------|--------|
| Q1 | #242 | Accept `+00:00` timestamps? | ✅ RESOLVED: no, spec form only |
| Q2 | #245 | Session live at a newer build's crash: expire or keep holding? | ✅ RESOLVED: expire (current), no heartbeat work |
| Q3 | #245 | Restored session whose nick another account holds: skip or fallback nick? | ✅ RESOLVED: skip (current) |
| Q4 | #246/#247 | Rehash pre-check mechanism | ✅ RESOLVED: child-process check (current), simplified |
| Q5 | #246 | GitSync when the check itself crashes | ✅ RESOLVED: apply only on a clean pass; else put back, retry next sync (nothing refused, see Q18) |
| Q6 | #252 | Which channels a no-`in=` SEARCH federates; scan cost | ✅ RESOLVED: keep scope, scan to the thread pool (#296) |
| Q7 | #253 | Extras as `PERSISTENCE` subcommands or their own command? | ✅ RESOLVED: subcommands |
| Q8 | #253 | Does cap-less use of the extras end? | ✅ RESOLVED: never |
| Q9 | #253 | Must Seance #327 ship before `PERSISTENCE_DRAFT_EXTRAS` goes FALSE? | ✅ RESOLVED: nef2 goes ahead; Seance tracked in evilnet/seance#333 |
| Q10 | #253 | Capability name form | ✅ RESOLVED: `evilnet.github.io/persistence` |
| Q11 | #261 | Split into three PRs? | ✅ RESOLVED: yes, one PR per bug (and #262 likewise) |
| Q12 | #291/#294 | Does `sslfp = ""` mean "no fingerprint required"? | ✅ RESOLVED: refuse every client (current); closes a small hole |
| Q13 | #253 | Cap-gating unsolicited output (restore batch, SET line) | ✅ RESOLVED: gated |
| Q14 | #289 | Offer the old `evilnet/channel-relocate` name for a transition release? | ✅ RESOLVED: no, as #289 does |
| Q15 | #280 | Fix shape for a services rename of a bouncer session's account | ✅ RESOLVED: re-file on rename, low priority (moot on Afternet) |
| Q16 | testnet | Is `testnet-svc/data/x3.conf` meant to be used, or stale? | ✅ RESOLVED: stale; deleted |
| Q17 | #289 | Move old vendor names to the DNS form? | ✅ RESOLVED: yes, draft #289 |
| Q18 | #246 | Do errors outside the commit refuse GitSync content? | ✅ RESOLVED: nothing is refused; every abandon retries next sync |
| Q19 | #276 | A renamed channel's history: follow it, clear it, or leave it? | ✅ RESOLVED: leave as today; presence split out as #297 |

---

# 🟡 OPEN: needs an answer

None. Every question is resolved.

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

### Q2 · #245 bouncer: rollback keeps a newer build's session records
Status: ✅ RESOLVED (2026-11-17, no code change)

**Decision:** expire it at the roll-forward, as #245 does. No per-build heartbeat.

**Why (Rubin):** downgrades across a record format bump are rare, and the worst outcome is that someone reconnects and rejoins their channels. No more machinery for the rollback-then-roll-forward round trip.

### Q3 · #245 bouncer: restore with a taken nick
Status: ✅ RESOLVED (2026-11-17, no code change)

**Decision:** skip it, as #245 does. No fallback nick. Same reason as Q2.

### Q4 · #246 / #247 rehash: the pre-check mechanism
Status: ✅ RESOLVED (2026-11-17, simplified: #246 ca340ea7, #247 8fd5fb08)

**Decision:** keep the child-process check (`ircd -k`). Staged parsing would be the ideal design some day.

**Done:** the check now has three results only (clean pass, errors, did not finish cleanly), and only a clean pass applies. The "did not run, go ahead" path and the re-check of a changed file are gone.

### Q5 · #246 GitSync when the check fails to run
Status: ✅ RESOLVED (2026-11-17, #246 ca340ea7; refusal removed 2026-11-18, #246 4f6b0a00, see Q18)

**Decision (Rubin):** none of the three as written. GitSync applies a commit only when the check passes. Anything else (crashed, killed from outside, could not start, timed out) puts the old file back and retries at the next sync, with no distinction between signals: an OOM kill can be the file's fault too, and an unchecked config from git is never applied. Errors found refuse the content until it changes, as before.

**Done:** `conf_file_check()` and the second rehash after an abandon are removed.

### Q6 · #252 which channels a SEARCH without `in=` federates
Status: ✅ RESOLVED (2026-11-17)

**Decision:** #252 keeps its scope (up to 8 of the requester's channels). The cost, about 2 s of a storage peer's main loop for 8 channels of 50 000 rows, is fixed by moving the SEARCH store walk to the thread pool in a separate follow-up PR built on #252 (draft evilnet/nefarious2#296).

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

**What it means:** #253 makes `PERSISTENCE_DRAFT_EXTRAS` FALSE by default (be612447), so the server behaves as the final state. Seance develop sees no change only on a network that turns the flag on; a network serving Seance builds without #333's persistence items (web, phone, desktop) keeps it on until they ship.

### Q10 · #253 the capability's name
Status: ✅ RESOLVED (2026-11-17)

**Decision:** `evilnet.github.io/persistence`.

**Why:** vendor-specific capability names "are prefixed by a valid DNS domain name" (`extensions/capability-negotiation.md:510`, cited by ibutsu), which `evilnet/<name>` is not.

### Q11 · #261 res, ssl, nick: one PR or three?
Status: ✅ RESOLVED (2026-11-17, done: #290–#295; #261 and #262 closed)

**Decision:** split into three PRs, one per bug (res `irc_in_addr_valid()`, ssl `verify_sslclifp()`, nick `ms_nick()` collision), and the master twin #262 the same way: #290 (res), #291 (ssl), #292 (nick) on `ircv3.2-upgrade`, #293–#295 on master. The `-Waddress` pragma cleanup goes with the ssl PR, and so does Q12.

**Why:** the repository's practice is one subject per PR.

### Q12 · #291 / #294 an empty `sslfp`
Status: ✅ RESOLVED (2026-11-17, no code change; descriptions corrected)

**Decision (Rubin):** refuse every client, as #291/#294 do.

**Correction:** the PRs said this keeps today's behaviour. It closes a small hole instead: before the fix, a client with no certificate has an empty fingerprint, which compared equal to an empty `sslfp` and passed.

### Q13 · #253 cap-gating unsolicited output
Status: ✅ RESOLVED (2026-11-17, done in 1b414b16)

**Decision:**
- The restore batch is wrapped only for a connection with `evilnet.github.io/persistence` (vendor type) or, while `PERSISTENCE_DRAFT_EXTRAS` is on, for any `batch` client (old type, as before). Otherwise its lines go out unwrapped.
- The non-spec `PERSISTENCE SET <state>` line before a SET's STATUS goes only to a vendor-cap connection or while the flag is on.

**Why:** ibutsu: "anything that has the server send unsolicited messages the client may not understand must be CAP gated … there's some gray area there since clients are supposed to ignore batch types they don't understand."

### Q14 · #289 old capability name during a transition
Status: ✅ RESOLVED (2026-11-17, no code change)

**Decision:** don't offer the old name. #289 stays as it is: a client asking for `evilnet/channel-relocate` is NAKed and gets the PART/JOIN fallback.

**Why:** nothing outside testing uses the old name, so there is no one to transition.

### Q15 · #280 a services rename of a bouncer session's account
Status: ✅ RESOLVED (2026-11-17, low priority, #280 stays open)

**Decision:** making a rename work (each server re-files the session under the new name on an `M` from services, merging by session id) is the right fix, but low priority. Nothing is changed now; evilnet/nefarious2#280 stays open as the record.

**Why:** ibutsu: moot for Afternet, where account renames are not allowed. Rubin noted that, as things stand, a rename is a desync trap across netsplits.

### Q16 · testnet: which X3 config is live
Status: ✅ RESOLVED (2026-11-17, testnet 51074c9)

**Decision:** stale. X3's configuration is generated in the image from `x3.conf-dist` and the `X3_*` variables; nothing reads `data/x3.conf`, so it is deleted, and the README, a script and a test comment stop naming it.

### Q17 · old vendor names to the DNS form
Status: ✅ RESOLVED (2026-11-17, draft evilnet/nefarious2#289)

**Decision:** both move to the DNS form.
- The capability `evilnet/channel-relocate` becomes `evilnet.github.io/channel-relocate`. The feature `CAP_evilnet_channel_relocate` keeps its name. The old name is not offered (Q14).
- The ISUPPORT token `evilnet/CHATHISTORYRETENTION` becomes `evilnet.github.io/CHATHISTORYRETENTION`. The old name is also advertised, with the same value, for a transition release.

**Why:**
- `capability-negotiation.md:510` covers the capability.
- ISUPPORT has no rule of its own. ibutsu: "maybe they're supposed to use the full name too". soju uses its DNS name for its own capabilities and most of its own ISUPPORT tokens (`soju.im/SAFERATE`, `soju.im/FILEHOST`).

### Q18 · #246 GitSync and errors outside the commit
Status: ✅ RESOLVED (2026-11-18, #246 4f6b0a00)

**Question (second review):** did Q5's "errors found refuse the content" cover errors outside the commit? As built, a valid commit was refused when ircd.conf had an error of its own, or an include was missing during the check, and stayed refused after the fix until `GITSYNC force`.

**Decision:** nothing is refused after an abandoned rehash. Whatever the reason, GitSync puts the old file back and tries the content again at the next sync.

**Why:** the check judges the whole configuration, so its errors need not be the commit's. Retrying is less code than a second check of the restored file. The cost: a commit that stays broken is checked and reported once per sync interval until it is fixed.

### Q19 · #276 a renamed channel's history
Status: ✅ RESOLVED (2026-11-18, draft evilnet/nefarious2#297)

**Decision:** the presence part (members' intervals close under the old name and open under the new one) is split out as #297. History stays as today: rows from before a rename stay under the old name. #276 stays a draft and is not being pursued for now.

**Why:** the #276 review: RENAME is low priority, the larger concern is desync between servers, and the presence part is needed whichever way history goes. Clearing the old rows at RENAME was not taken, since a rename only one side of a split executed would then delete rows a live channel still owns.

---

## Merge order notes (no decision needed)
- Whichever of #232 and #252 lands second needs `requester_type_mask()`.
- Whichever of #268 and #278 lands second drops #268's special case.
- #241 lands with or before #276.
