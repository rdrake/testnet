Title: chathistory: strict presence follows a channel RENAME
Base: ircv3.2-upgrade   Branch: rdrake:fix/n014-rename-presence   Draft

Split out of #276, as its review suggested: this part is needed whichever way a renamed channel's history goes.

**The bug.** Strict presence is kept by channel name. A RENAME left every member's interval open under the old name and none under the new one. With `CHATHISTORY_STRICT_PRESENCE` on:
- members saw nothing said after the rename until they left and rejoined;
- they stayed "present" under the old name, which another channel may take next.

**The fix.** `rename_channel()` calls a new `presence_on_channel_rename()` (46 lines), which closes each member's open interval under the old name and opens one under the new name.
- An alias membership opens nothing, as at a JOIN.
- A kicked member whose PART has not arrived is closed under the old name and not reopened.
- A rename between two spellings of one name does nothing.
- Nothing is moved or copied, and no PN is sent: every server runs it as it executes the rename.
- A relocation needs none of this: its members leave the old channel and join the new one through the ordinary hooks.

**Not in this PR**
- A renamed channel's history. Rows from before the rename stay under the old name, as today. #276 is the larger attempt at that.
- One time for the rename across servers. Each server stamps the move from its own clock, because the RN line carries no time. A server whose clock lags can store a row just before its members' new interval opens, and strict presence then hides that row. This was traced in the #276 review, not run. The fix is for RN to carry a time, which is a wire change and is left for when RENAME is taken up.

**Testing:** debug build with no warnings, all CMocka suites pass. `chathistory_presence_cmocka` gains `test_presence_rename_moves_open_intervals` (member, kicked member, alias, two spellings, feature off). Not run on a live server.

**Where this can run:** RENAME is refused while a stock server is linked, so on such a network this code is not reached.
