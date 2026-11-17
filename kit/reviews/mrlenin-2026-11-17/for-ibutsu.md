# nefarious2 drafts: six calls after the simplification pass (2026-11-17)

Rubin asked us to stop over-engineering, so a pass removed machinery from the open drafts. Most of it was clearly unneeded. These six are judgement calls. For each: what it does, what the trim changed, and the choice. Answer by number (for example "1 keep, 2 drop").

---

## 1. #256: one msgid for a delayed-join (+D) reveal

**The bug.** A hidden (+D) member is revealed when they first speak, set the topic or get a status. Every server makes that JOIN on its own, so each one gives it a different msgid and time. Members on different servers see different msgids for the same JOIN. Federated history merges the copies as different events, so the JOIN can show up twice.

**The fix.** The server the line starts on makes the msgid and sends it with that line in a new compact S2S tag segment, `,J<numeric><msgid>`. Older servers skip the segment and make their own msgid, as they do today.

**Cost.** 284 lines in 11 files: a new wire segment, a per-connection field, and save/restore around the MODE double flush, the per-link multiline relay and multi-target TOPIC.

**It is not obsolete.** The bug is real but small: a reveal JOIN only. Two choices:
- **keep #256** as it is;
- **close it** and live with per-server msgids for reveal JOINs.

## 2. #283: who gets CAP DEL

**Before the trim**, the server remembered which caps each client had been told about (by CAP LS, NEW or ACK), and sent CAP DEL only to those clients.

**After the trim**, CAP DEL goes to every cap-notify client, as before #283. A client that was never told about a cap can get a DEL for it, which clients ignore.

- **keep the trim** (simpler; about 170 lines fewer);
- **restore the tracking**.

## 3. #284: read markers across a channel rename

**Before the trim**, a channel rename or relocation copied the members' read markers to the new name.

**After the trim**, the new name starts with no marker. MARKREAD reports `*` until the client sets one again, so the client shows the channel as all unread once.

- **keep the trim** (about 370 lines fewer; renames are rare);
- **restore the copy**.

## 4. #253: re-announcing persistence cap values

**Before the trim**, changing `CAP_evilnet_persistence`, `CAP_draft_persistence` or `PERSISTENCE_DRAFT_EXTRAS` on a running server sent cap-notify clients `CAP NEW` with the new value.

**After the trim**, enabling one sends a bare `CAP NEW` with no value, and flipping the extras flag sends nothing. Clients see the right value at their next `CAP LS`.

- **keep the trim** (runtime flips are rare);
- **restore the re-announce**.

## 5. #285: lower-case SASL mechanism names

**The leak #285 closes:** a client sends `AUTHENTICATE PLAIN` and `CAP END` together and registers. Its credentials line then arrives after registration, starts a new exchange, and the base64 credentials are sent to services as the mechanism name.

**The fix kept** (after the trim): the first `AUTHENTICATE` of an exchange must look like an RFC 4422 mechanism name (upper case `A-Z 0-9 - _`, at most 24 characters). Anything else gets 908 and 904 and reaches no backend.

**Side effect:** a client that sends lower-case `plain` now gets 904. Lower case is refused because a short PLAIN blob can be all letters and digits.

- **keep it** as it is;
- **allow lower case** (a one-line change; a few blobs could then still get through).

## 6. #276: a rare corner after the trim

#276 makes a renamed channel's history follow it. The trim dropped:
- an in-memory "distrust" list for rename records that could not be written;
- a trim-engine callback kept only for a row format no merged build ever wrote.

**What can now happen:** in a renamed channel, a REDACT that reached the store before its original gets no link across the two names. If that REDACT row is later trimmed, the original message under the old name would show again.

- **keep the trim** (needs a redaction to arrive before its message in a renamed channel, and then be evicted);
- **restore the callback**.
