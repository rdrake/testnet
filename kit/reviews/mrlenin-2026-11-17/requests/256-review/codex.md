- **P1 — Split MODE output makes servers derive different JOIN IDs.** `ircd/channel.c:5050` and `ircd/send.c:778`.
  - **Scenario:** A local operator sends `MODE #c +bbbv <mask1> <mask2> <mask3> hidden`, with masks consuming enough of `modebuf_flush_int()`’s output budget that `+v hidden` receives `MODE_SAVE`. The origin reveals `hidden` first, reserving ID **E**. The first output MODE contains the bans and consumes **E**; the later MODE containing `+v` mints **F**. The receiving server reveals `hidden` while processing **F**, producing a different JOIN ID.
  - **Confidence:** Confirmed by reading the reveal, `MODE_SAVE`, recursive flush, and mint paths.
  - **Minimal fix:** Assign an ID to each output MODE and reveal its affected members only after determining which changes that MODE contains. Pass that ID explicitly to `RevealDelayedJoin()`. The current tests stub sends and manually consume the reservation, so they miss this interaction.

- **P1 — Different events deterministically collide after the nine-bit fold.** `ircd/ircd_string.c:2242–2246`.
  - **Scenario:** Events `ABAAbaHQiPkAAc` and `ABABAaHQiPkABB`, both at `1794500000000` ms, reveal member `AC/D4f` in different channels. Both derive **`ACOLDaHQiPj]4f`**. These event IDs are compatible with consecutive minting at one physical timestamp. Distinct JOIN events therefore share an ID, defeating global identity and deduplication.
  - **Confidence:** Confirmed with a compiled standalone C harness using the checkout’s decoder and derivation functions.
  - **Minimal fix:** Encode the complete event identity and member identity in a separate derived-ID format, with corresponding decoder support. Nine bits cannot preserve event uniqueness. The test checks only four selected counter values and holds logical constant; real consecutive mints advance logical too.

- **P1 — Bit 15 does not separate derived IDs from minted IDs.** `ircd/ircd_string.c:2245`.
  - **Scenario:** The derived ID above has node `AC`, logical **58051**, time **1794499999999**, and counter **3615**. `mint_msgid()` can produce exactly that tuple. The HLC permits all 16 logical bits, including while its physical clock is pinned ahead following clock movement or peer adoption. A later event on another server can consequently derive a JOIN ID identical to an already minted event.
  - **Confidence:** Confirmed by reading `mint_msgid()` and `crdt_hlc.c`; the derived tuple was verified by the C harness.
  - **Minimal fix:** Use an explicitly disjoint derived-ID namespace, or enforce a reserved logical range throughout HLC minting and receiving. Merely asserting that 32768 mints per wall-clock millisecond is unlikely does not establish separation.

- **P2 — The reveal timestamp can sort after its triggering event.** `ircd/channel.c:6299`.
  - **Scenario:** A tagged remote message carries a valid minted msgid encoding future time **T**, beyond `HLC_MAX_FORWARD_MS`. `parse_server()` retains the msgid but replaces the event’s S2S timestamp with the local HLC time **N**. The JOIN gets **T−1** from its derived ID, while the message is delivered and stored at **N**. When `T−1 > N`, chronological history and client timestamp sorting place the JOIN after the message.
  - **Confidence:** Confirmed by reading timestamp rejection in `parse.c`, event-time selection, and reveal storage.
  - **Minimal fix:** Pass the event’s effective timestamp separately and stamp the reveal at that timestamp minus one millisecond. Resolve how intrinsic derived-ID time should behave when transport time has been clamped.

Checked and found correct:

- Derivation validates numeric lengths/alphabet, requires 15 output bytes, and terminates the 14-character ID. Unsigned fold overflow is defined.
- For one valid event, different valid member numerics produce different derived IDs.
- Ordinary valid-time reveals use the same timestamp for live JOIN tags and stored JOIN history, one millisecond before the event.
- Packet handling clears unused reservations between parsed lines; the nested `CheckDelayedJoins()` local `MODE -d` send does not itself mint an ID.
- The `-MMD -MP` changes include dependency files and remove them during clean.
- Full build/CMocka validation was unavailable: `./configure` failed to find OpenSSL. The standalone collision harness passed; review artifacts were removed and the working tree is clean.