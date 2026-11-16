Every engine computes its wait as `timer_next - CurrentTime`, with -1 (or `tv_sec < 0`) meaning "no timers, wait forever". An overdue next timer makes the value negative too:
- `epoll_wait()`, `poll()` and `/dev/poll` take any negative timeout as infinite.
- kqueue and select are handed NULL when `tv_sec < 0`.

With no traffic, the loop then sleeps forever and no timer fires again. A slow boot of a quiet server is enough to trigger it, because the first timers are due before the loop is entered.

**The fix:** in all five engines, an overdue timer now gives a zero wait. With no timers, the wait is still -1, so the server still blocks. The fork has carried the same clamp since 4e39612b and 91fff9cc.

**Testing:** checked under gdb on a server with no clients, with `CurrentTime` moved 30 s past the first timers when the loop was entered.
- Before: `epoll_wait` was called with -29000 and never returned.
- After: it is called with 0, then with the timers' own waits (1000, then 59000).
