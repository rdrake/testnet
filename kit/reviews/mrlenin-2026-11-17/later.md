# Parked for later (2026-11-17)

1. **Netsplit, KILL and collision QUITs of remote users** get a different msgid on every server (`ircd/s_misc.c` ~630), so federated history stores one QUIT row per server. Idea: derive each QUIT's msgid from the SQUIT's or KILL's shared msgid plus the user's numeric, with the same function as #256's `msgid_derive_join()` and one more logical bit to keep QUIT ids apart from JOIN ids. About 30-40 lines plus tests. Check first that SQUIT and KILL lines carry a shared msgid tag. Own draft PR.
2. **#256 reserved-id handoff.** `generate_msgid_ahead()` drops the reserved id if the HLC moves (any mint or receive) between the reveal and the event's own mint; the event would then mint a fresh id and this server's JOIN would disagree with the others. Not seen on the paths tested live. Make the event always take the reserved id, or prove nothing can step the HLC in between. Worth an independent Fable review of the redesign at the same time.
3. **Hidden JOIN in history (unfiled).** On servers that hold a hidden (+D) member, CHATHISTORY on the channel also returns the member's original hidden JOIN row. Reproduce on the testnet and find the cause before filing.
4. **Untested for #256:** ASan run, reveals on bouncer devices, the reveal during a channel relocation.
5. **Codex review of #296**, held "for later if there's time".
6. Netjoin JOINs after a burst also differ per server, but are not stored; left alone on purpose.
