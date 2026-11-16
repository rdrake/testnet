Every server reveals a hidden (+D) member itself, on the line that causes the reveal: a message, a TOPIC, or a MODE that gives the member a status. Each server minted its own msgid for that JOIN and stored its own row. Members on different servers therefore saw the reveal under different msgids, and federated history merged it once per server.

**The fix: a new compact-tag segment, `,J<numeric_5><msgid_14>`.**
- **Origin:** the server where the line starts mints the reveal's msgid and carries it on that line.
- **Receivers:** a server that receives the segment uses that msgid for that member, and takes the msgid's mint time as the event time. It shows and stores the JOIN under it, then passes the segment on with the line.
- **One reveal per line:** either the first reveal, or the one the line arrived with.
- **MODE:** the flush sends the line twice (to servers with oplevels and without), and both copies carry the segment.
- **TOPIC:** a hidden setter is now revealed before the TOPIC is relayed, so a server in the middle passes the segment on. Each target of `TOPIC #a,#b` starts with nothing armed, so one target's reveal can't ride another's line.
- **Multiline batches** are relayed link by link. Each link's first line carries the segment, both at the origin and at a relaying server.
- **No room:** the segment is left out when the tag region has no room for it.
- **Older servers:** an older server skips the segment, as it does any unknown one, and mints its own msgid as before. That still links and works, but the two sides then disagree, as they do today.

**Limits:**
- A line that reveals several members at once (a MODE on two hidden members, or `-D` showing everyone) carries only one. The others are still minted per server.
- A server without multiline that sits behind a relaying hub gets a batch's fallback lines without the segment, so it mints its own.

Also here: `sendcmdto_one()`'s tagged general path now consumes the armed msgid and time, as its inline fast path always did.

This is one of three PRs for the same issue (one msgid per event across servers); the other two cover SVSNICK and ACCOUNT.

**Testing:** build and all CMocka suites pass. New cases in `send_s2s_tags_cmocka` cover:
- the segment's placement before `,C`;
- one segment per line;
- consumption;
- leaving it out when it doesn't fit;
- the save and restore across the two MODE sends;
- the end-of-line reset.

I also checked on two linked servers, with a hidden member on B and watchers on A and B. A message, a TOPIC and a `+v` each now show the JOIN under the same msgid on both servers. Before, the msgids differed. With A running the old build, the link and the reveal still work, and each side keeps its own msgid.
