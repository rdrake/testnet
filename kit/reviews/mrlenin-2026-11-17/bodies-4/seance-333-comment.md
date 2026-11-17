# Comment to add on evilnet/seance#333

```
Correction to the persistence item: nefarious2 #253 now makes `PERSISTENCE_DRAFT_EXTRAS` FALSE by default (be612447), so the server does not wait on its clients. Once #253 merges, a network that leaves the flag at its default gives Seance develop unwrapped restores (seen as live JOINs), no `attach-cursor` on `draft/persistence`, and no SET line. A network serving Seance builds without #327 turns the flag on until they ship.
```
