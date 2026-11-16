A user's N line carries no away state, and the burst sent no AWAY after it. A server that learned users in a burst therefore showed every one of them as present until their next AWAY change. WHOIS gave no 301, and the away-notify sent when an away user joins on the netjoin never fired, because nothing on the receiving side was away.

**The fix:** the burst sends AWAY after the user's N (next to SWHOIS) when the user is away. AWAY from a user is ordinary P10 that every server accepts at any time, the burst included.

**Testing:** build and the test programs pass. On two linked servers, with alice away on a and the link coming up afterwards:
- Unmodified master: WHOIS from b shows no 301.
- With the change: WHOIS shows 301, and bob, already in a shared channel on b, gets the AWAY right after alice's JOIN.

The same change, plus a bouncer-session exclusion and pre-away handling, is opened against ircv3.2-upgrade separately.
