# #261 / #262 split: six new draft PRs, then close #261 and #262

Per Q11 (one PR per bug) and `requests/261-262-split.md`. Each branch holds one subject, builds on its own and passes its tests (ircv3.2-upgrade: build plus the whole CMocka suite and `ircd_in_addr_t`; master: build plus `ircd_in_addr_t`). The three are independent: no merge order.

**Closing, not reusing:** #261 and #262 close in favour of the new PRs, rather than being force-pushed down to one subject, so their review stays readable against the code it was about. Close each with the comment given at the end.

All six: repository evilnet/nefarious2, draft: yes.

---

## 1. res, base `ircv3.2-upgrade`

- Head: `rdrake:fix/n050-in-addr-valid` (452cb67c)
- Title: `res: irc_in_addr_valid() refuses the all-ones address`

```
Inherited from ircu: `irc_in_addr_valid()` tested `in6_16[0]` with `x && ~x`. `~` on the promoted unsigned short is an int (`~0xFFFF` is `0xFFFF0000`), never 0, so an all-ones address counted as valid. It now compares with `0xFFFF`.

**Testing:** `ircd_in_addr_t` now checks all-0s, all-1s and two near misses; the all-1s case failed before the change. Build and the other tests pass.

Split out of #261 (one PR per bug). The same change is opened against master separately.
```

## 2. ssl, base `ircv3.2-upgrade`

- Head: `rdrake:fix/n050-sslclifp` (c71d73d2)
- Title: `ssl: verify_sslclifp() tests the fingerprint, not its address`

```
Inherited from ircu: `verify_sslclifp()` tested `!cli_sslclifp(cptr)`, the address of an array, which is never NULL. The "no certificate" return was dead code, and a client without a fingerprint failed only because the compare did not match. It now tests the first character.

The `-Waddress` pragmas around `s_conf.c` in `conf_include_cmocka` and `conf_reattach_cmocka` go too: they were there only because of this test, and `s_conf.c` no longer trips the warning.

**Testing:** build and the whole CMocka suite pass, with the pragmas gone.

**Not decided:** what `sslfp = "";` in a block should mean. This PR keeps what happens today (every client is refused); the other reading is "no fingerprint required".

Split out of #261 (one PR per bug). The same change is opened against master separately.
```

## 3. nick, base `ircv3.2-upgrade`

- Head: `rdrake:fix/n050-nick-collision-read` (fa47fddf)
- Title: `nick: read the collided client's last nick before it exits`

```
Inherited from ircu: `ms_nick()`'s collision path read `cli_lastnick(acptr)` after `exit_client_msg()` had freed `acptr`. It worked only because the freed Client sits untouched on the freelist. It is now read before the exit.

**Testing:** build and the CMocka suite pass. No test reaches this path; the change moves one read.

Split out of #261 (one PR per bug). The same change is opened against master separately.
```

## 4. res, base `master`

- Head: `rdrake:fix/n050-in-addr-valid-master` (6bf53381)
- Title: `res: irc_in_addr_valid() refuses the all-ones address`
- Body: as 1, with the last line `Split out of #262 (one PR per bug). The same change is opened against ircv3.2-upgrade separately.`

## 5. ssl, base `master`

- Head: `rdrake:fix/n050-sslclifp-master` (d1f87bbb)
- Title: `ssl: verify_sslclifp() tests the fingerprint, not its address`

```
Inherited from ircu: `verify_sslclifp()` tested `!cli_sslclifp(cptr)`, the address of an array, which is never NULL. The "no certificate" return was dead code, and a client without a fingerprint failed only because the compare did not match. It now tests the first character.

**Testing:** build passes. No test reaches this path.

**Not decided:** what `sslfp = "";` in a block should mean. This PR keeps what happens today (every client is refused); the other reading is "no fingerprint required".

Split out of #262 (one PR per bug). The same change is opened against ircv3.2-upgrade separately.
```

## 6. nick, base `master`

- Head: `rdrake:fix/n050-nick-collision-read-master` (905ab00c)
- Title: `nick: read the collided client's last nick before it exits`
- Body: as 3, with `**Testing:** build passes. No test reaches this path; the change moves one read.` and the last line `Split out of #262 (one PR per bug). The same change is opened against ircv3.2-upgrade separately.`

---

## Closing #261 and #262

After the six are open, close #261 with this comment (filling in the numbers of 1–3):

```
Split into one PR per bug: #A (res), #B (ssl), #C (nick). Closing in favour of those; the review here stays for reference.
```

and #262 the same way with the numbers of 4–6.
