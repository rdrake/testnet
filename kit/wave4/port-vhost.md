A Port block's vhost went straight to `add_listener()`, which returned quietly when `ircd_aton()` could not read it. So `vhost = "300.1.2.3"`, or a host name, gave no listener and no error: at boot, at REHASH, and under `ircd -k`, which reported "checked okay".

**The fix:**
- The parser checks each Port vhost. It reports a bad one the way a bad General vhost is reported (`Invalid virtual host '%s' in Port block.`) and skips it. The port number on the vhost line is still taken first, so a vhost without its own number keeps inheriting it.
- A bind that fails on a live server is still only logged, not counted as a configuration error. It means the port is busy, not that the file is wrong, and counting it would make a REHASH be abandoned over a busy port.

**Upgrade note:** like any parse error, such a block now stops the configuration from loading. The server exits at boot instead of starting without that listener, and a REHASH is refused. The block never opened a listener, so nothing that worked is lost, but a configuration that carries one has to be fixed before upgrading.

**Testing:**
- `ircd -k` against Port blocks with vhosts `"300.1.2.3"` and `"not-an-address"`: before, rc 0; after, rc 7 with both blocks named.
- `Port { vhost = "127.0.0.1"; vhost = "irc.example.org" 16684; }` names the bad vhost and still binds 127.0.0.1:16684.
- A valid configuration still checks okay, and a normal start still listens.

This complements #238 / #239, which stop `ircd -k` from opening listeners. The two do not overlap.

The same change is opened against master separately.
