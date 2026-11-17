#276 makes a renamed channel's history follow it: after `RENAME #old #new`, CHATHISTORY on `#new` returns the rows stored under `#old` as `#new`'s own (ircv3/ircv3-specifications#532: "this channel has always been this name"). It stores a `renames` mapping rather than rewriting rows, and each server records the rename when it applies it. This issue tracks what #276 leaves open, and the work that would close each gap.

### Gaps

1. **A store that missed the rename never learns it.** A server that was down or split when the rename was applied has no mapping, so its `#old` rows never show under `#new`, from it or through federation. Closing this needs the mapping on the wire. For example, a burst (or a `CH` advertisement) could carry a channel's former names with their incarnation and rename time, so a returning server can record them. This is a P10 change.
2. **Other per-channel state is still keyed by the old name.** This covers read markers (`MARKREAD`), channel metadata, and any other store keyed by channel name. After a rename, a member's read marker for `#old` doesn't apply to `#new`. These should move, or be aliased, at rename time, the way strict-presence intervals now are.
3. **No RENAME event is replayed.** A `draft/channel-rename` client with event-playback sees the old rows under the new name but no RENAME line. #276 leaves it out on purpose: a RENAME inside a batch that already shows the new name would tell the client to rename a buffer it doesn't have. If a replayed event is wanted (for example, as a notice-style marker), the mapping already keeps the old name and the rename time, so it can be synthesised at read time.
4. **Only the four most recent earlier names are followed.** A fifth rename drops the oldest, and its rows stop showing. The drop is logged ("no longer followed"). The cap keeps a page to at most five store iterators, because a chanop could otherwise force many. Lifting it means compacting old segments, for example by rewriting a dropped name's rows under the current name in the background, or merging segments, not raising the cap.
5. **Incarnations are creation times in seconds.** A channel recreated in the same second as a dead one with the same name can't be told apart from it. This was true before #276 for any recreated channel; #276 only stops it leaking through the mapping. A finer incarnation would close it, for example the creation time in milliseconds or an HLC stamp carried in the burst.
6. **Rename time is each server's own clock.** Each server records the rename at the moment it applies it. With clock skew, a row stored close to the rename can fall on different sides of the boundary on different servers, so one store may show it under the new name and another may not. A rename time carried on the wire, from the server that issued the rename, would make every store agree.
7. **A segment walk can skip without bound.** Rows under an earlier name that belong to the segment are interleaved with rows that don't, such as a relocation's old channel, which keeps the same incarnation and goes on storing. The walk skips the latter, and nothing bounds how many it skips in one page.

### Redaction edges

8. **The redaction link runs one way.** A REDACT stored under a name other than its original's also writes a link under the original's name, so renames can't undo it. A REDACT sent in a relocation's *old* channel after the move, for a message from before the move, hides that message there but not in the new channel. #276 treats the old channel's actions after the move as its own. Decide whether that is right.
9. **No link is written if the original isn't in this store.** A REDACT stored while its original is not on this server, for example one that came in by federation, gets no link. It then holds only through the names the mapping still keeps (see 4).
10. **#154 is separate.** Cap eviction can still bring back a redacted message within a single name. #276 fixes the trim cascade only across renamed names.

### Testing

11. **The store-failure paths are tested by fault injection on the in-memory store only.** The renames-record read and write failures, and the retry that deletes a distrusted record once the store takes writes, have no test against RocksDB. A RocksDB fault-injection hook, an env wrapper, would let `history_read_cmocka` cover them.
12. **Two-server checks were run by hand.** Federation across a rename, and crossing relocations checked on both servers, should become scripted multi-server tests in the testnet suite.

Applies to: fork (ircv3.2-upgrade), after #276. Related: #154 (cap eviction and redaction), #170 (crdt-mesh schema bump, which plans a rename op).
