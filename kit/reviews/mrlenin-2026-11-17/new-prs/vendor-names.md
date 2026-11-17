# New draft PR

- Repository: evilnet/nefarious2, base `ircv3.2-upgrade`
- Head: `rdrake:fix/vendor-cap-name` (5a3ba98b)
- Draft: yes
- Title: `cap, chathistory: DNS-prefixed vendor names for channel-relocate and CHATHISTORYRETENTION`

## Body

```
Capability negotiation says vendor-specific capability names "are prefixed by a valid DNS domain name" (`extensions/capability-negotiation.md`). `evilnet/` is not a domain. The persistence capability already uses `evilnet.github.io/`; this brings the two older vendor names in line.

### What changes

- **Capability.** `evilnet/channel-relocate` is now `evilnet.github.io/channel-relocate`. The feature that switches it, `CAP_evilnet_channel_relocate`, keeps its name, so no ircd.conf changes. A client that still requests the old name is NAKed and gets the PART/JOIN fallback, as a client without the capability does. No client we know of requests it (Seance does not).
- **ISUPPORT.** `evilnet/CHATHISTORYRETENTION` is now `evilnet.github.io/CHATHISTORYRETENTION`. ISUPPORT has no rule of its own for vendor tokens, so it follows the capability rule, as soju does with `soju.im/FILEHOST`. The old name is advertised beside it, with the same value, for a transition release.

### Not in this PR

Dropping the old ISUPPORT name after the transition.

### Tests

Build and the whole CMocka suite pass. The names appear only in the capability table, the feature notifier and the ISUPPORT update.
```
