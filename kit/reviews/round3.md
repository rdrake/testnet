# Review round 3: N014 after round 2

Branch fix/n014-rename-history on rdrake/nefarious2. New since round 2: a18001a6..91341a01, four commits pushed on top (no force-push).

| Commit | What |
|---|---|
| 0595434e | Trim: a REDACT row takes its original under an earlier name too (round-2 item 1). |
| b2c52c8d | Renames record at an arrival (same-second incarnation, item 3), at a crossing (item 2, new history_channel_rename_crossed()), and when the store fails (fail closed). TARGETS after a rename back. Cap cut to 4 earlier names (at most 5 iterators per read); a dropped name is logged. Record format version 2 (since_ms). |
| 99c794b1 | Strict presence follows a RENAME (item 4): rename_channel() moves members' open intervals; rows are checked against presence under the name they were stored as (HistoryMessage.stored_as) or the name the channel had at that time. |
| 91341a01 | New suite history_read_cmocka: 12 cases linking the real history.o, trim engine and RocksDB. |

Full cmocka passes (98 suites). The body is kit/wave5/n014.md.

Please review three ways again (Claude, Fable, Codex), against round 2's findings and fresh. Open points to check in particular:
- the version-2 record has no reader for a version-1 record (only the unposted a18001a6 build ever wrote one);
- the crossing's live check looked at one server only;
- trim across a rename and a failing store are covered by CMocka only;
- #241 should land with or before N014.
