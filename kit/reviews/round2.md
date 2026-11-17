# Review round 2: the sweep's fixes

All of these are new commits on rdrake/nefarious2, pushed on top of the posted PR branches with no force-push.

| PR | Branch | Commit(s) | What |
|---|---|---|---|
| #252 | fix/n013-search-federate | ce86335a | A SEARCH whose CH Q S line would pass 510 bytes stays local. Reproduced on two servers (150-char channel, 325-byte text the message lacks): 1 false row before, 0 after. A short query still federates. |
| #259 | fix/n034-profile-long-keys | 680c648d | Delete and rename fold the profile name before matching the (folded) stored keys. The new cmocka case is red before the fix. |
| #257 | fix/n036-nickask-match | 60cdbf36, be411d85 | First-word compare of the refused nick, made exact (strncmp). Case test added. |
| #274 | fix/away-burst | 349b2b01 | The netjoin AWAY gets its own msgid, not the JOIN's. Checked live. #275 (master) has no msgids and is unaffected. |
| #246 | fix/n016-rehash-parse-error | ee7f51e2 | conf_rehash_abandoned() says why (CONF_ABANDON_ERRORS / _OTHER). GitSync refuses content only on ERRORS; on OTHER (unreadable or kept changing) it restores and retries at the next sync. Not reproduced live, since that needs a writer racing the check. |
| #268 | fix/int-feature-range | 58de54c4, 5041bb47 | FEAT_NONE fall-through restored; a refused value on REHASH is kept, not reset. |
| #269 | fix/int-feature-range-master | 02b399cd, eade0597 | The same, on master. |
| #270 | fix/listener-rehash-free | 4f8722b7 | conf_is_check_only() stub, so the test links alongside #238. |
| #264 | fix/n022-setname-case | db90cc4e | Exact strcmp. |

Review for correctness against the PR's stated intent: build, run the full cmocka suite, and check each finding in the code before reporting it.

## New, not yet posted (kit/wave5)

| Branch | Commit(s) | What |
|---|---|---|
| fix/n014-rename-history | e2ab120f, a18001a6 | N014: chathistory follows a channel RENAME through a persistent `renames` mapping (new module history_rename.c, merged cursor in history.c). About 2,400 lines, so review it carefully: the read paths in history.c, the incarnation/time bounds, relocate and crossing hooks, and downgrade safety. Body in wave5/n014.md lists the known gaps. Use `git diff -w` for history.c (a re-indent). |
| fix/n069-log-ring-full | 81af3323 | Async log ring: a wakeup on a full ring is not room. Test red before, green after. |
