A user's N line carries no away state, and the burst sent no AWAY after it. A server that learned users in a burst therefore showed every one of them as present until their next AWAY change. WHOIS gave no 301, and the away-notify that `m_burst` sends when an away user joins on the netjoin never fired, because nothing on the receiving side was away.

**The fix:**
- The burst sends AWAY after the user's N (next to SWHOIS) when the user is away. AWAY from a user is ordinary P10 that every server accepts at any time, the burst included.
- Users in a bouncer session are left out. Aliases never reach this point anyway. A session's away is decided and sent by the server that holds it, which restates it to its own links at their away barrier (`bounce_away_restate_to()`); a second statement here could race that.
- The pre-away star goes as a star to an IRCv3-aware link and as the configured text to a legacy one, as `away_send_to_servers()` does for a fork user's star.
- `m_burst`'s netjoin away-notify now sends a stored star the way `away_notify_channel()` does: as a star to draft/pre-away clients and as the configured text to the rest. Until now no burst user was ever away at that point, so the raw `*` it would have sent was never reached.

- The netjoin AWAY gets a msgid of its own. It used to go out while the JOIN's msgid was still set, so a message-tags client got two events with one msgid.

**Not covered, as before:**
- A session held on another server and learned through this burst is not restated to this link by anyone; only its holder restates, and only to its own direct links. Bursting it from here would mean a non-holder sending AWAY for a session user (invariant #22), which needs the bouncer design's say.
- A legacy user's literal `AWAY :*` crosses a fork server live unchanged, but reaches a further legacy link in a burst as the configured text, since the stored away does not record where the star came from.

**Testing:** build and all CMocka suites pass (`s2s_handlers_cmocka` gains two stubs for the netjoin change). On two linked servers, with alice away on a and the link coming up afterwards:
- Before: WHOIS from b shows no 301, and bob, already in a shared channel on b, sees alice's JOIN with no AWAY.
- After: WHOIS shows 301, and bob gets the AWAY right after the JOIN.
- With alice away as the pre-away star, bob (who has no draft/pre-away) gets `Away`, not `*`.
- With message-tags, bob's JOIN and AWAY carry different msgids.
- An unmodified master server on b accepts the burst AWAY and shows the 301.

The same change, without the bouncer and pre-away parts, is opened against master separately.
