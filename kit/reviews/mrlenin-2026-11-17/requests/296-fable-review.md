# #296: findings from an independent review (2026-11-17)

Read-only review of #296's own commits (35ec75e7..e70aea88, head e70aea88), focused on the threading. No serious problem in the normal paths. A TSan stress harness on the real `store_job.c` and `thread_pool.c` ran 305,976 jobs (95,926 on a worker), including a start-then-link-gone split of about 82,000 run to 188,000 cancelled: exactly-once held, no leak, no double free, no TSan report in `store_job.c`.

Held up: the worker reaches only the job and the store (followed through the walk, deserialise, multiline resolve, filter, presence hook and redaction lookup); a split server always reaches `chathistory_fed_cleanup_link()`; die and restart close the stores before the pool, and there is no reopen; the wake pipe is level-triggered, drained each pass and removed before close; rows, order and the `E n` / `E n T` / `E 0 U` lines match the old path. The MDEBUG fallback was checked by reading only.

Not run by the reviewer: `store_job_cmocka`, `history_view_cmocka`, the full suite, helgrind, the two-server runs.

## To fix

1. **Out of memory on a worker hangs it, and every later DIE, SIGTERM or RESTART.**
   - `DoMalloc()` (`ircd_alloc.c:72`) calls the no-memory handler on whatever thread allocates. On a worker that is `outofmemory()` → `server_restart()` → `history_shutdown()` → `store_jobs_quiesce()` (`store_job.c:339`), which waits for `running_count == 0` while counting the calling worker. It never returns.
   - `restarting` is now set, so later RESTARTs do nothing (`ircd.c:469`), and a later DIE or SIGTERM blocks in the same quiesce. Nothing is logged, since the worker is muted.
   - Wanted: the no-memory handler never runs the restart off the main thread. For example, a worker's allocation failure fails the job (store error, `E <reqid> 0 U`), or the handler on a non-main thread aborts with a line written unmuted to stderr. Add a test that a failed allocation on a worker does not reach `server_restart()`.

2. **Wording: "a password check always finds a free worker".** It is a bound: with every non-scan worker busy hashing, a new check still queues behind them, and behind at most `cap` scans. Say that in the body and the `store_job.c` comment.

3. **An `assert()` failing on a muted worker aborts with no log line** (`ircd_log.h:163`, `ircd_log.c:477`). Let assertion output bypass the mute, or note it.

## Tests

4. `store_job_cmocka` is gate-driven and deterministic, so it never races QUEUED→RUNNING against a cancel. Add a stress case (many jobs, cancel at random points) that runs under TSan.
5. `history_view_cmocka` uses its own row hook, so `struct SearchJob`, `search_job_done()` and the parse/copy block in `ms_chathistory()` have no unit test. Add one for the job path: copy-in, done with rows, done with `T`, done with a store error, done after the link left.
6. Its 40-walk case does not force overlap with the main thread's writes (the walks may finish before the writes). Use a barrier so they really overlap.

Then update #296's description for 1–6 in `bodies-N/`, as usual.
