# Review: small follow-ups (wave 6)

| PR | Branch | Commit | What |
|---|---|---|---|
| new (fork) | fix/log-default-facility | ebc11487 | log_feature_mark() resets the default syslog facility only when it is unmarked; FEAT_NONE no longer falls through into FEAT_INT. Reproduced live: a configured "LOG" = "local4" read USER before, and reads LOCAL4 after. |
| new (master) | fix/log-default-facility-master | 45d30351 | The same, on master. Reproduced the same way. |
| #268 | fix/int-feature-range | ef37ccc3 | A refused boolean value keeps its mark and value at REHASH. Live: TRUE/FALSE/TRUE before, TRUE/TRUE/TRUE after. |
| #269 | fix/int-feature-range-master | f1afd4eb | The same, on master. |

Interaction: #268 keeps the FEAT_NONE fall-through because of the log bug. The log PR removes the fall-through. Whichever lands second drops #268's special case.

Also in kit/wave6: issue-276.md, the issue tracking #276's gaps and future work, and file-issue-276.sh.

One Claude read of the diffs and a build are enough here. Then dry-run open-wave6.sh, refresh-wave6.sh and file-issue-276.sh.
