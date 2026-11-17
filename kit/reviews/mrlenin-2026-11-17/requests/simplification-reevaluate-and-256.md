# Re-evaluate the simplification pass; finish #256's review (decided 2026-11-17)

**Decision (Richard, 2026-11-17):** "Rubin is just being a grump. Reevaluate the items you've dropped. Address additional shortcomings that 256 review identified. Try to find simple elegant solutions."

The pass was driven by "stop over-engineering". That is no longer the bar. The bar is: keep the behaviour if it is correct and worth having, but find the simplest way to get it.

## 1. Re-evaluate every item the simplification pass dropped

Not only the six in `for-ibutsu.md`: every removal in the pass (c6d4349, acdaaee and the commits they describe), including the ones the pass called clearly unneeded. For each:
- restore the behaviour if it was correct and worth having, in a smaller form if one exists;
- keep it dropped only if it was really unneeded (dead code, a row format nothing ever wrote, a guard nothing can reach), and say why in one line.

The six from `for-ibutsu.md`, with what to aim for:
1. **#256:** keep it. It is not closed (see part 2).
2. **#283 CAP DEL:** spec-wise a DEL for a cap the client was never told about is harmless. Restore the targeting only if it can be done much more simply than the 170 lines, e.g. derived from what the client already has (its active caps, plus "saw LS/NEW since connect" as one bit) instead of a per-cap told-set.
3. **#284 read markers across a rename:** restore, simply. One copy of the marker rows from the old name to the new at the point the rename's history moves (#276 already moves history; the marker copy should ride the same step), not a parallel mechanism.
4. **#253 cap value re-announce:** restore, simply: one notify callback shared by the three features that sends `CAP DEL` then `CAP NEW <cap>=<value>` (or just `CAP NEW` with the value) for the affected caps to cap-notify clients.
5. **#285 lower-case mechanism names:** keep the strict check (a credential blob must never reach services as a mechanism name). If there is a simple way to also accept a lower-case *known* mechanism (compare case-insensitively against the advertised mechanism list rather than a character class), do that: it closes the leak and keeps lower-case clients working.
6. **#276 the REDACT-before-original corner in a renamed channel:** restore the protection, simply. Prefer making the trim treat a redaction row as linked by msgid regardless of channel name (one lookup) over bringing back the distrust list.

## 2. #256: the review's remaining shortcomings

Already done: the TOPIC reveal order and the `,J` comment in `format_s2s_tags_with_client()` (714468a2). Still open from `256.md`:
- **Docs:** add `,J<numeric_5><msgid_14>` to the segment table in `nefarious/.claude/skills/p10-protocol/SKILL.md` (and `P10_PROTOCOL_REFERENCE.md` if it lists segments).
- **Tests:** CMocka cases for `reveal_from_line()`, the `,J` parse, the moved TOPIC reveal, the per-link multiline re-arm and the `sendcmdto_one()` change; and a case that runs a real modebuf flush across the two MODE sends, not only the formatter.
- **Build:** the `struct Connection` change in `include/client.h` was not picked up by an incremental build (`recv_classify.o` kept the old layout until `make clean`). Fix the dependency tracking for the test objects, or add the header to their dependencies.
- **Order from an untagged origin** (the review called it "not this PR's", but it is the same bug as the TOPIC one): a message or multiline batch from an untagged origin mints its own msgid before the reveal (`ircd/ircd_relay.c:1304` before `:1328`; `ircd/m_batch.c:1591` before `:1648`), so the JOIN sorts after the message it precedes. Move the reveal before the mint, as 714468a2 did for TOPIC.
- **Description:** fix "the save and restore across the two MODE sends" once a real flush test exists, and list what each new test covers.

Also worth a look (found while answering Richard, not from the review): netjoin JOINs after a burst (`m_burst.c:979`) and netsplit/collision QUITs of remote users (`s_misc.c:630`) get a per-server msgid too, the same class as the reveal. Not part of #256; say in its description that they are not covered, and propose whether a follow-up is worth it.

Then update bodies in `bodies-N/` and `for-ibutsu.md` (or retire it) as usual.
