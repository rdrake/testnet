# New draft PR: the federated SEARCH scan on the thread pool (follow-up to #252, gist Q6)

- Repository: evilnet/nefarious2, base `ircv3.2-upgrade`
- Head: `rdrake:fix/search-scan-threadpool` (e70aea88)
- Draft: yes
- Title: `chathistory: the federated SEARCH responder scans on the thread pool`
- The branch sits on #252's head (35ec75e7), so until #252 merges this PR's diff shows #252's 4 commits too. Its own commits are the last 5.

## Body

```
Follow-up to #252, stacked on it: until #252 merges, this diff includes its commits. This PR's own are the last five, from `log: let a thread pool worker mute its own logging`.

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
- `ircd.c`: the pool's signal pipe is now registered with the event engine. It never was, so a finished task waited for the next timer or packet (1–3 s for a federated SEARCH on a quiet test pair, under 0.15 s now). OPER, SETHOST and WEBIRC password checks gain the same.
- `ircd_log.c`: a worker can mute its own logging; the walk's log lines and the backend's last-error text are dropped on a worker instead of raced for. A redaction that could not be read is counted in the walk and logged on the main thread.
- `doc/readme.features` documents `THREAD_POOL_SIZE`.

**Thread safety**

- The worker reads the job and the store, nothing else. Everything it needs from main-thread state is copied when the line arrives: presence record, type mask, selectors, channel incarnation, store snapshot.
- Because of the snapshot, the rows are the ones a scan at arrival would have found; a row stored after the requester left the channel cannot slip in. The one exception is on the safe side: a match's redaction is looked up when the scan reaches it, so a REDACT that arrives while the job waits still hides the message.
- The store is not closed under a scan: the close cancels queued jobs and waits for running ones. The pool cannot take a queued task back, so a cancelled job stays queued and the worker that reaches it sees its state under a mutex and leaves it alone.
- Memory-debug builds (`-DMDEBUG`, whose block list is unlocked) run every job on the main thread.
- Also fixed: `thread_pool_submit()` read the pending count for a debug line outside the queue lock (found by TSan).

**Testing**

- `store_job_cmocka` (10 cases): where a job runs, the cap and order, the link leaving a waiting, queued or running job, the store close, the pool shutting down with a job queued.
- `history_view_cmocka` (3 cases, real `history.c` on a temporary RocksDB store): a view does not move and a later redaction still hides; 40 worker walks equal the main-thread walk while the main thread keeps writing; shutdown waits for walks under way and the waiting ones never run.
- Both clean under `-fsanitize=thread` (reports inside the uninstrumented librocksdb suppressed); `store_job_cmocka` clean under helgrind.
- Build and the full CMocka suite (96 programs) pass.
- Two linked servers, 32,000 rows:
  - federated results equal the store server's local results (up to the requester's existing 500-row cap per leg);
  - killing the requester with 120 scans in flight leaves the store server up;
  - SIGTERM on the store server with scans in flight shuts down cleanly.

**Not in this PR**

- The requester's own scan (`m_search`) stays on the main loop: its channels share one scan budget in sequence and each channel's federated part starts between two walks, so moving it means rewriting `m_search` as a state machine. One budget per SEARCH remains there (about 0.25 s at worst), not eight.
- The pool's own workers and the password-check worker still call `Debug()` unmuted (matters only with `-x`).
- A federated SEARCH with a limit over 500 keeps the oldest 500 of a responder's rows (`MAX_FED_MESSAGES`); reachable only with `CHATHISTORY_MAX` above 500.
```
