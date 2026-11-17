# New issue on evilnet/nefarious2

- Title: `ASYNC_LOGGING from ircd.conf never takes effect`

## Body

```
`main()` decides whether to start the async log writer by reading `feature_bool(FEAT_ASYNC_LOGGING)` immediately after `feature_init()`, before `init_conf()` has read ircd.conf. At that point only the compiled default (off) is known, so `log_async_init()` is never called. The feature has no notify callback, so a later `SET` or `REHASH` does not start the writer either; `log_vwrite()` checks `log_async_available() && feature_bool(FEAT_ASYNC_LOGGING)` and always takes the synchronous path. The effect is that `"ASYNC_LOGGING" = "TRUE"` is accepted and silently ignored.

`THREAD_POOL_SIZE` had the same problem and is fixed in #296 by starting the pool after `init_conf()`; the same move (or a notify callback that starts and stops the writer) would fix this. The feature is also missing from `doc/readme.features`.
```
