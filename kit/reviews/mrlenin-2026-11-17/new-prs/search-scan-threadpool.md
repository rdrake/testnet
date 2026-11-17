# New draft PR (opened as #296): the federated SEARCH scan on the thread pool (follow-up to #252, gist Q6)

- Repository: evilnet/nefarious2, base `ircv3.2-upgrade`
- Head: `rdrake:fix/search-scan-threadpool` (e15643b3)
- Draft: yes
- Title: `chathistory: the federated SEARCH responder scans on the thread pool`
- The branch sits on #252's head (9a965499), so until #252 merges this PR's diff shows #252's 4 commits too. Its own commits are the last 16.

## Body

```
Follow-up to #252, stacked on it: until #252 merges, this diff includes its commits. This PR's own are the last sixteen, from `log: let a thread pool worker mute its own logging`.

**Merge order with #237:** #237 starts the thread pool after ircd.conf is read, so `THREAD_POOL_SIZE` takes effect; this PR leaves that to it and does not move the pool start. Both touch `ircd_log.c`, `thread_pool.c`, `readme.features` (each adds a `THREAD_POOL_SIZE` entry in the same place) and the log tests, so whichever merges second needs a small rebase; the two `THREAD_POOL_SIZE` entries become one.

**Summary**

A storage server now scans for another server's SEARCH (CH Q … S) on the thread pool instead of the main loop. The answer lines are the same; they are sent from the main thread when the scan is done.

**Why**

Each CH Q S scans up to 50,000 rows, and one SEARCH without `in=` asks every storage server for up to eight scans in a row: about two seconds in which the server did nothing else. RocksDB reads are thread safe, so the scan can run on a worker.

**How**

- `store_job.c`: a small runner for a store read on the pool.
  - One of `run()` / `abandon()` is called, then `done()` exactly once.
  - At most one worker fewer than the pool has hold jobs (never more than 8); the rest wait in order. That bounds a password check's wait, it does not keep a worker free: a check queues behind the checks already there and behind at most that many scans, never behind the scans waiting their turn.
  - A job runs on the main loop, as before, when there is no pool, the pool refuses it, or 64 already wait.
- `history.c`: `history_view_open()` takes a store snapshot on the main thread and a walk can read through it; the filter can carry the channel's incarnation. `history_shutdown()` first cancels jobs not started and waits for walks under way.
- `m_chathistory.c`: `struct SearchJob`.
  - The main thread parses the line and copies in the selectors, the requester's presence record and type mask, the channel's incarnation and the snapshot.
  - The limit is cut to `MAX_FED_MESSAGES` (500), what a requester keeps for one request, so a job never holds more rows than that. The responder took the limit as sent before. A requester that asked for more gets the newest 500 and `T`; it used to be sent every match, oldest first, and kept the first 500 to arrive.
  - The worker runs `search_walk()` on that alone.
  - `search_job_done()` sends the rows and `E <reqid> <n>` (`T` when the budget cut the scan or the cut limit was filled, `E <reqid> 0 U` on a store error).
  - A job whose asking server has left sends nothing: `chathistory_fed_cleanup_link()` detaches it, and `done()` checks the link again.
- `ircd.c`: the pool's signal pipe is now registered with the event engine. It never was, so a finished task waited for the next timer or packet (1–3 s for a federated SEARCH on a quiet test pair, under 0.15 s now). OPER, SETHOST and WEBIRC password checks gain the same. The pipe is registered just before the listeners open, apart from the pool's start, which #237 moves.
- `ircd_log.c`: a worker can mute its own logging; the walk's log lines and the backend's last-error text are dropped on a worker instead of raced for. A redaction that could not be read is counted in the walk and logged on the main thread, and so is a scan that could not read the store. One line is not dropped: a failed `assert()` on a worker goes out through `log_dying_line()`, to syslog and, when the server kept its stderr (`-t`, `-x`), to descriptor 2.
- `doc/readme.features` documents `THREAD_POOL_SIZE` (read once at start) and what runs on the pool.

**Thread safety**

- The worker reads the job and the store, nothing else. Everything it needs from main-thread state is copied when the line arrives: presence record, type mask, selectors, channel incarnation, store snapshot.
- Because of the snapshot, the rows are the ones a scan at arrival would have found; a row stored after the requester left the channel cannot slip in. A match's redaction is looked up twice, in the snapshot and in the store as it is when the scan reaches it, and either one hides the message. The snapshot covers a trim that deletes a REDACT row and its message together while the job waits; the second lookup covers a REDACT that arrives while the job waits. A lookup that could not be read hides the message and is counted.
- The store is not closed under a scan: the close cancels queued jobs and waits for running ones. The pool cannot take a queued task back, so a cancelled job stays queued and the worker that reaches it sees its state under a mutex and leaves it alone.
- Memory-debug builds (`-DMDEBUG`, whose block list is unlocked) run every job on the main thread.
- A pool worker never logs: every worker mutes its own logging for its lifetime, and the pool's own start and exit `Debug()` lines are gone. With `-x`, the `Debug()` lines of a password check on a worker are no longer written.
- An allocation that fails on a worker never runs the out-of-memory handler: `ircd_alloc.c` calls it only on the thread that set it. On a worker it ran `server_restart()`, which hung waiting for its own job with the listeners closed, and every later DIE, SIGTERM or RESTART hung or did nothing after it. Off the main thread the process now says so through `log_dying_line()` and calls `_exit()`, as `server_panic()` does; the server does not re-exec itself on that path.
- Descriptor 2 is written only while it is the process's own: a daemon without `-t` or `-x` closes it at start and the number is reused, so there the line goes to syslog alone.
- Also fixed: `thread_pool_submit()` read the pending count for its log lines outside the queue lock (found by TSan).

**Testing**

- `store_job_cmocka` (11 cases): where a job runs, the cap and order, the link leaving a waiting, queued or running job, the store close, the pool shutting down with a job queued; and a stress case, 12,000 ungated jobs whose link leaves at a random moment so a cancel races the worker taking the job, exactly-once asserted for every job.
- `history_view_cmocka` (4 cases, real `history.c` on a temporary RocksDB store): a view does not move and a later redaction still hides; a redaction trimmed away after the view was taken still hides; 40 worker walks equal the main-thread walk while the main thread keeps writing (each walk is held at its first row until the main thread has written, so the overlap is forced); shutdown waits for walks under way and the waiting ones never run.
- `chathistory_search_job_cmocka` (18 cases, the real `m_chathistory.c` and `store_job.c`; the pool and the store are the test's): what `ms_chathistory()` copies into the job, the limit cut, and what `search_job_done()` sends: rows and `E`, `T`, `E 0 U`, and nothing once the asking server has left.
- `alloc_nomem_cmocka` (3 cases, the real `ircd_alloc.c`): a failed allocation on another thread exits there and never calls the handler.
- `log_async_cmocka` (2 new cases): a muted thread's assertion line reaches syslog and a kept stderr, and not the log file.
- `store_job_cmocka`, `history_view_cmocka` and `alloc_nomem_cmocka` clean under `-fsanitize=thread` (reports inside the uninstrumented librocksdb suppressed); `store_job_cmocka` clean under helgrind.
- Build and the full CMocka suite (98 programs) pass.
- Two linked servers, 32,000 rows:
  - federated results equal the store server's local results (up to the requester's existing 500-row cap per leg);
  - killing the requester with 120 scans in flight leaves the store server up;
  - SIGTERM on the store server with scans in flight shuts down cleanly;
- The out-of-memory exit on a worker is tested at the allocator (`alloc_nomem_cmocka`), not by starving a running server.

**Not in this PR**

- The requester's own scan (`m_search`) stays on the main loop: its channels share one scan budget in sequence and each channel's federated part starts between two walks, so moving it means rewriting `m_search` as a state machine. One budget per SEARCH remains there (about 0.25 s at worst), not eight.
- With several storage servers and a limit over 500, the requester still keeps the first 500 rows to arrive across them (`MAX_FED_MESSAGES`); reachable only with `CHATHISTORY_MAX` above 500.
- The other `CH Q` subcommands still take the limit as the asking server sent it.
- `THREAD_POOL_SIZE` and `ASYNC_LOGGING` from ircd.conf: both are read before ircd.conf today, so setting them there does nothing. #237 fixes both.
```
