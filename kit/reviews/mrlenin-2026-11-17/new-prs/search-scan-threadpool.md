# New draft PR (opened as #296): the federated SEARCH scan on the thread pool (follow-up to #252, gist Q6)

- Repository: evilnet/nefarious2, base `ircv3.2-upgrade`
- Head: `rdrake:fix/search-scan-threadpool` (32f14a86)
- Draft: yes
- Title: `chathistory: the federated SEARCH responder scans on the thread pool`
- The branch sits on #252's head (35ec75e7), so until #252 merges this PR's diff shows #252's 4 commits too. Its own commits are the last 8.

## Body

```
Follow-up to #252, stacked on it: until #252 merges, this diff includes its commits. This PR's own are the last eight, from `log: let a thread pool worker mute its own logging`.

**Summary**

A storage server now scans for another server's SEARCH (CH Q … S) on the thread pool instead of the main loop. The answer lines are the same; they are sent from the main thread when the scan is done.

**Why**

Each CH Q S scans up to 50,000 rows, and one SEARCH without `in=` asks every storage server for up to eight scans in a row: about two seconds in which the server did nothing else. RocksDB reads are thread safe, so the scan can run on a worker.

**How**

- `store_job.c`: a small runner for a store read on the pool.
  - One of `run()` / `abandon()` is called, then `done()` exactly once.
  - At most one worker fewer than the pool has hold jobs (never more than 8), so a password check always finds a free worker; the rest wait in order.
  - A job runs on the main loop, as before, when there is no pool, the pool refuses it, or 64 already wait.
- `history.c`: `history_view_open()` takes a store snapshot on the main thread and a walk can read through it; the filter can carry the channel's incarnation. `history_shutdown()` first cancels jobs not started and waits for walks under way.
- `m_chathistory.c`: `struct SearchJob`.
  - The main thread parses the line and copies in the selectors, the requester's presence record and type mask, the channel's incarnation and the snapshot.
  - The worker runs `search_walk()` on that alone.
  - `search_job_done()` sends the rows and `E <reqid> <n>` (`T` when the budget cut the scan, `E <reqid> 0 U` on a store error).
  - A job whose asking server has left sends nothing: `chathistory_fed_cleanup_link()` detaches it, and `done()` checks the link again.
- `ircd.c`: the pool's signal pipe is now registered with the event engine. It never was, so a finished task waited for the next timer or packet (1–3 s for a federated SEARCH on a quiet test pair, under 0.15 s now). OPER, SETHOST and WEBIRC password checks gain the same. The pool is now started after ircd.conf is read: it was started before, so `THREAD_POOL_SIZE` from ircd.conf never applied and every pool had 4 workers.
- `ircd_log.c`: a worker can mute its own logging; the walk's log lines and the backend's last-error text are dropped on a worker instead of raced for. A redaction that could not be read is counted in the walk and logged on the main thread, and so is a scan that could not read the store.
- `doc/readme.features` documents `THREAD_POOL_SIZE` (read once at start, from ircd.conf).

**Thread safety**

- The worker reads the job and the store, nothing else. Everything it needs from main-thread state is copied when the line arrives: presence record, type mask, selectors, channel incarnation, store snapshot.
- Because of the snapshot, the rows are the ones a scan at arrival would have found; a row stored after the requester left the channel cannot slip in. A match's redaction is looked up twice, in the snapshot and in the store as it is when the scan reaches it, and either one hides the message. The snapshot covers a trim that deletes a REDACT row and its message together while the job waits; the second lookup covers a REDACT that arrives while the job waits. A lookup that could not be read hides the message and is counted.
- The store is not closed under a scan: the close cancels queued jobs and waits for running ones. The pool cannot take a queued task back, so a cancelled job stays queued and the worker that reaches it sees its state under a mutex and leaves it alone.
- Memory-debug builds (`-DMDEBUG`, whose block list is unlocked) run every job on the main thread.
- A pool worker never logs: every worker mutes its own logging for its lifetime, and the pool's own start and exit `Debug()` lines are gone. With `-x`, the `Debug()` lines of a password check on a worker are no longer written.
- An allocation that fails on a worker no longer runs `server_restart()` there (it hung, waiting for its own job with the listeners closed). Off the main thread the out-of-memory handler writes one line to stderr and calls `_exit()`, as `server_panic()` does; the server does not re-exec itself on that path.
- Also fixed: `thread_pool_submit()` read the pending count for its log lines outside the queue lock (found by TSan).

**Testing**

- `store_job_cmocka` (10 cases): where a job runs, the cap and order, the link leaving a waiting, queued or running job, the store close, the pool shutting down with a job queued.
- `history_view_cmocka` (4 cases, real `history.c` on a temporary RocksDB store): a view does not move and a later redaction still hides; a redaction trimmed away after the view was taken still hides; 40 worker walks equal the main-thread walk while the main thread keeps writing; shutdown waits for walks under way and the waiting ones never run.
- Both clean under `-fsanitize=thread` (reports inside the uninstrumented librocksdb suppressed); `store_job_cmocka` clean under helgrind.
- Build and the full CMocka suite (96 programs) pass.
- Two linked servers, 32,000 rows:
  - federated results equal the store server's local results (up to the requester's existing 500-row cap per leg);
  - killing the requester with 120 scans in flight leaves the store server up;
  - SIGTERM on the store server with scans in flight shuts down cleanly;
  - `THREAD_POOL_SIZE` set to 2 in one server's ircd.conf gives that server 2 workers.
- Not tested: the out-of-memory exit on a worker.

**Not in this PR**

- The requester's own scan (`m_search`) stays on the main loop: its channels share one scan budget in sequence and each channel's federated part starts between two walks, so moving it means rewriting `m_search` as a state machine. One budget per SEARCH remains there (about 0.25 s at worst), not eight.
- A federated SEARCH with a limit over 500 keeps the oldest 500 of a responder's rows (`MAX_FED_MESSAGES`); reachable only with `CHATHISTORY_MAX` above 500.
```
