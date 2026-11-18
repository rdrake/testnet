# nefarious2 drafts: what changed after the simplification pass was re-evaluated (2026-11-18)

The earlier version of this page asked six questions about trims. The owner decided instead to re-evaluate every trim: restore what was correct, in the smallest form found, and keep a trim only where the code was really unneeded. Nothing here needs an answer; comments on the PRs are welcome.

| PR | Outcome |
| --- | --- |
| #256 | Redesigned. The `,J` wire segment is gone. Each server derives the reveal JOIN's msgid from the event's msgid and the member's numeric, 1 ms before the event. No wire change, no per-connection state, and both old limits (several members on one line, a non-multiline server behind a hub) are gone. An older server in the path no longer cuts the sharing. Header dependencies are now tracked in the Makefiles. |
| #283 | CAP DEL is targeted again, with one server-wide set of announced caps instead of per-client tracking (about 25 lines of logic). |
| #253 | Cap values are re-announced again: a bare `CAP NEW` now carries the cap's stored value, so the generic hooks do it; no hand-written hooks. |
| #249 | A value-only change goes to CAP 302 clients only again, decided inside `send_cap_notify()` with the same set as #283, for every valued cap. |
| #284 | Read markers follow a rename or relocation again, through one function at three call sites. |
| #285 | Lower-case advertised mechanisms (`plain`) are accepted again: compared case-insensitively with the advertised list and relayed in its spelling, so the credential leak stays closed. |
| #276 | The trim engine's renamed-parent lookup is back, so a REDACT stored before its message in a renamed channel still takes it when trimmed. The distrust list and the one-batch presence move stay out. |
| #252 | A SEARCH whose S2S query line cannot fit is refused again, instead of silently answering from one server. The one-search-per-client rule stays out. |
| #237 | Changing THREAD_POOL_SIZE or ASYNC_LOGGING at run time logs that it takes effect at restart. Run-time switching stays out. |
| #259 | CREATE (and now RENAME) clear rows an older build left under the name again. |
| #282 | Unchanged: every password check is answered, so the wait needs no timeout. |

Not covered by #256 and left for a possible follow-up: the QUITs of remote users on a netsplit or KILL still get a per-server msgid (a small change using the same derivation). Netjoin JOINs are not stored, so they were left alone.

Seen while testing #256, not yet filed: on the servers that hold a hidden member, `CHATHISTORY` on a +D channel also returns the member's original hidden JOIN row.
