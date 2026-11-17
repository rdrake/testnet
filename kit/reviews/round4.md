# Review round 4: N014 after round 3

Branch fix/n014-rename-history on rdrake/nefarious2. New since round 3: 91341a01..bd588b9d, three commits pushed on top (no force-push).

| Commit | What |
|---|---|
| 50b40bd7 | A redaction is kept under the name its original is stored under: storing a REDACT whose original is under another name of the channel writes a second reply-index entry there, in the same batch (the two name each other). The redaction lookup and history_attach_context follow it, and trim deletes it with the REDACT row. Fixes round 3's P1 (rename away and back past the cap) and P2 (relocation old channel). |
| e3e6981a | A RENAME moves an account's presence in one write (both or neither). |
| bd588b9d | A distrusted renames record is deleted once the store takes writes (retried at most once a second on read). |

Full cmocka suite: 99 suites, clean rebuild. Regression tests: history_read_cmocka (now links chathistory_merge.o and reads a page as m_chathistory.c builds it), history_trim_cmocka, new chathistory_presence_store_cmocka. Live checks: P1 and P2 fixed. Crossing on two servers, winner first: both servers return the full history for the winner. "Loser keeps none" was confirmed on the loser-first server only (the other redirects joins).

Please run the three-way review again (Claude, Fable, Codex), including Fable's round-3 test file f3_read_cmocka.c against bd588b9d. Then dry-run kit/wave5/open-wave5.sh. Points to judge:
- The link runs one way: a REDACT sent in a relocation's old channel after the move, for a pre-move message, hides it only there. Is that the intended semantics?
- A REDACT stored while its original is not on that store gets no link.
- The distrust retry has no test (no RocksDB fault injection).
- The build has no header dependency tracking, so use make clean before testing.
