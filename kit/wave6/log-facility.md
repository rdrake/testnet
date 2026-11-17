Setting `"LOG" = "local4"` in the Features block never takes effect. The server runs with the USER facility from startup, and stays on it after a REHASH. There are two inherited bugs here, one hiding the other:

- **`log_feature_mark()` resets in the wrong case.** It resets the default facility when the LOG feature is *marked*, that is, when the configuration has just set it. The test is inverted. The unmarked case, a configuration that no longer sets the facility, is the one that should go back to the default.
- **A subsystem line clears the mark.** A LOG line naming a subsystem (`"LOG" = "SYSTEM" "FACILITY" "local5"`) makes `feature_log_set()` return 0. `feature_set()` then falls through from FEAT_NONE into FEAT_INT, which reads `SYSTEM` as a number and clears the mark. So a default facility followed by any subsystem line was kept, by accident, while one on its own was reset.

**The fix:**
- The facility is reset only when it is unmarked.
- A set handler that returns 0 no longer falls through, and leaves the mark alone. LOG is the only FEAT_NONE feature.

**Testing:** checked as an oper with `GET LOG` on three configurations: the default facility only, the default facility plus a subsystem facility, and neither.

| Build | Facility only | Facility + subsystem | Neither |
|---|---|---|---|
| Before | USER | LOCAL4 | USER |
| After | LOCAL4 | LOCAL4 | USER |

These results hold both at startup and after REHASH. Dropping the line and rehashing goes back to USER, and putting it back gives LOCAL4. There is no CMocka suite for `ircd_features.c`.


#268 keeps the FEAT_NONE fall-through because of this bug, and says so in a comment there. Whichever of the two lands second should drop that special case (the `(feat->flags & FEAT_MASK) != FEAT_INT` branch) and its comment. The same fix is opened against master separately.
