## A. Earlier findings

| # | Judgment | Evidence at HEAD |
|---|---|---|
| 1. MODE size split changes event ID | **Fixed** | `ircd/channel.c:2879–2899` reserves space for all status arguments before fitting other arguments. Status grants therefore accompany the first mint that the reveal reserved. Parameter-count flushing remains immediately after adding the argument (`:3456`). |
| 2. JOIN time ignores replaced link time | **Partly fixed** | `ircd/channel.c:6300–6314` captures the effective inbound time and clamps the JOIN before it. The explicit-event caller is the locally minted multiline path (`ircd/m_batch.c:1652`), so it needs no inbound correction. A decoder-boundary case still produces an unset timestamp; see below. |
| 3. TOPIC reservation leaks across targets | **Fixed** | The reservation can still survive a rejected target, but `ircd/ircd_string.c:2244–2252` includes the canonical channel name. Reusing the event reservation no longer deterministically gives different channels the same JOIN ID. |
| 4. clang `make depend` with `-MMD -MP` | **Fixed** | `ircd/test/Makefile.in:9–10,247` separates compilation flags from dependency-generation flags. `depend` no longer uses `CFLAGS`. |
| 5. Nine-bit fold collisions | **Partly fixed** | `ircd/ircd_string.c:2257–2272` replaces the fold with a 39-bit hash. Collisions are much less frequent but remain reproducible, including between different event IDs. |
| 6. Minted logical bit 15 | **Fixed** | `ircd/crdt_hlc.c:35–44` carries at `0x7FFF`, including when receiving an older peer’s larger logical value. Locally minted stamps keep bit 15 clear. |
| 7. Untagged CLEARMODE relay | **Fixed on tag-preserving links** | `ircd/m_clearmode.c:183–184,323–328` reserves the first MODE’s ID and explicitly requests tagged CLEARMODE propagation. Older relays remain a limitation below. |
| 8. Tests stub the handoff | **Fixed for the outgoing handoff** | `ircd/test/Makefile.in:690–704` links real handlers, channel code, send code and HLC. The tests inspect formatted outgoing tags. They still do not exercise receiving `parse.c` or actual history storage (`ircd/test/reveal_handlers_cmocka.c:204–223`). |

## Findings

### 1. Medium — Different events still produce identical JOIN IDs

**Location:** `ircd/ircd_string.c:2261–2272`  
**Confidence:** High; reproduced with an ASan/UBSan standalone harness using the decoder and derivation code extracted from HEAD.

For channel `#review` and member numeric `ABAAC`, these different, valid event IDs produce the same JOIN ID:

```text
event 1: sQABnaMYXFAABo
event 2: 2xAA1aMYXFAAA2
JOIN:    LnO97aMYXE]]wg
```

Both events encode `1800000000000` ms. Their logical/counter combinations are consistent with ordinary sequential minting on different origin servers.

If that member is revealed, parts and rejoins hidden, then is revealed by the other event at the same encoded millisecond, two distinct JOINs acquire one identity. History indexing and client deduplication cannot distinguish them. This does **not** make identical inputs disagree between HEAD servers; it aliases different reveals.

The comment’s `2^-39` figure is a pairwise probability. The birthday scale is roughly a million inputs sharing an encoded millisecond.

**Minimal fix:** Widen the derived-ID format, using a substantially larger digest, and update its time decoder. The existing 39-bit payload cannot provide strong collision resistance for the full input tuple.

### 2. Medium — Mixed-version servers deterministically disagree

**Location:** `ircd/ircd_string.c:2244–2272`; `ircd/m_clearmode.c:323–328`  
**Confidence:** High, from comparison with `b5664fe1`. This is a rollout limitation introduced by changing the derivation.

HEAD changes the algorithm without negotiating a derivation version. A HEAD server and a `b5664fe1` server receiving the **same tagged event** derive different JOIN IDs: the earlier algorithm embeds the member’s server numeric at the start; HEAD uses hash bits there.

For the collision example above, the earlier algorithm’s result starts `AB`, whereas HEAD’s starts `Ln`.

Additionally, a `b5664fe1` intermediate server relays CLEARMODE untagged. A HEAD server beyond it loses the original event identity and reserves another one.

**Minimal fix:** Negotiate and preserve a reveal-derivation version/event identity, or explicitly require a coordinated upgrade of the entire relevant server-link component. Existing IRCv3 tag support alone does not establish algorithm compatibility.

### 3. Medium — Opaque event IDs still cause server-specific IDs and potentially later JOIN times

**Location:** `ircd/channel.c:6315–6317`  
**Confidence:** High. This survives from the earlier head.

The parser can retain an incoming 14-character msgid that `msgid_decode_time_ms()` rejects—for example, an older layout or another implementation’s opaque ID. Every receiving server then independently calls `generate_msgid()` for the JOIN.

Consequently:

- Servers derive different JOIN IDs.
- The JOIN uses the local HLC time, which can be **after** the incoming event’s effective time.

For example, an opaque-ID event timestamped one second behind the receiving server produces a JOIN timestamped near the receiver’s present time.

**Minimal fix:** Derive identity from arbitrary nonempty event IDs and pass effective event time separately. Independently minting the JOIN cannot satisfy cross-server agreement.

### 4. Low — The accepted epoch boundary makes the JOIN sort after its event

**Location:** `ircd/ircd_string.c:2199,2263`; `ircd/channel.c:6309`; `ircd/send.c:281–286`  
**Confidence:** High; reproduced. This survives from the earlier head.

The decoder accepts an event exactly at `1577836800000` ms. Derivation subtracts one millisecond, producing a JOIN outside the decoder’s accepted range:

```text
event: ABAABW9eZugAAB → 1577836800000
JOIN:  NlPhNW9eZuf]Bz → decoder returns 0
```

`reveal_msgid_for()` therefore supplies timestamp zero. Live formatting treats zero as unset and uses wall time; history storage substitutes local HLC time (`ircd/channel.c:148–149`). Both can sort after the accepted event.

**Minimal fix:** Return the derived timestamp directly from derivation rather than decoding it through the event-validation range; permit the corresponding derived boundary timestamp.

## Checked and found correct

- The `0x7FFF` carry preserves HLC ordering against older peers with logical `0x8000..0xFFFF`. A standalone sanitized check passed receiving `0xFFFF` and 100,000 subsequent pinned-time steps.
- Physical-time carry precedes logical comparison in HLC, metadata ordering and packed presence timestamps. Existing decoders still retain all 16 logical bits.
- The hash uses the complete event ID, separated input components and IRC channel case folding. Unsigned hash arithmetic has defined wraparound.
- MODE parameter ordering remains aligned with its mode letters. CLEARMODE retains its command body and uses existing tagged/legacy wire variants.
- Normal corrected inbound timestamps reach both live JOIN formatting and history storage. No newly introduced memory-safety or UB defect was found in the changed production code.
- Full CMocka execution was unavailable: generated build files are absent, and the existing configure log ends at the macOS OpenSSL rpath failure. Standalone checks used ASan/UBSan; temporary files were removed and the checkout is clean.