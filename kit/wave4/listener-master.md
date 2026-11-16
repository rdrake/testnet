`add_listener()` reuses the Listener a port already has. When a REHASH leaves that Listener no socket, it freed it on the spot. That happens, for instance, when a Port moves to an address family that cannot be bound. But the Listener was still on `ListenerPollList`, and clients that came in on it still held references. The `close_listeners()` at the end of the rehash and every later `release_listener()` then read and wrote freed memory.

**The fix:**
- A Listener the current Port block created is still freed at once, since it is not linked yet.
- One that an earlier configuration made is only marked inactive. `close_listeners()` then closes it, or the last `release_listener()` does if clients still hold it.

**Testing:**
- New CMocka suite `listener_rehash_cmocka` includes `listener.c`, with the sockets stubbed and `free()` wrapped. Its two rehash cases fail before the change and pass after. (On ircv3.2-upgrade; master has no CMocka harness.)
- Under valgrind, on a host without IPv6: a Port moved from `vhost = ipv4 "*"` to `vhost = ipv6 "*"`, with a client connected on it.
  - The old build gives 39 invalid reads and writes, in `close_listeners()` and in `release_listener()` when the client leaves.
  - The new build gives none, closes the port, and reopens it on the next REHASH.

The same change is opened against ircv3.2-upgrade separately.
