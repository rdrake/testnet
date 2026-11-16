An integer feature was read with `strtoul()` straight into an int, with no check for trailing text or range: `"4294967296"` became 0, `"4294967303"` became 7, and `"100junk"` became 100. Setting `NICKLEN = "4294967296"` set NICKLEN to 0, and every NICK was then refused with 432.

**The fix:**
- Integer values go through a new `ircd_strtoint()`. It takes what `strtol()` with base 0 takes and allows white space around the number. It refuses an empty string, trailing junk and anything outside an int.
- A refused value leaves the feature as it was. It is reported the way a bad boolean is: `ERR_BADFEATVALUE` to an oper's SET, and a CONFIG error from ircd.conf.
- The custom-feature (`FEAT_NONE`) case used to fall through into the integer code whenever its set handler returned 0, which `feature_log_set()` does for every `"LOG" = "SUBSYSTEM" ...` line. That stored junk in an unused `v_int`. With the new check it would have reported every such line as a bad value, so the case now ends with its own `break`.

**Testing:**
- Unit test: new `ircd_strtoint` cases (in `ircd_string_cmocka` on ircv3.2-upgrade, in `ircd_string_t` on master) for valid values, out-of-range values and junk.
- Running servers, with `MAXCHANNELSPERUSER "4294967303"`, `NICKLEN "4294967296"`, `CHANNELLEN "100junk"` and `MAXSILES "17"`, plus LOG lines:
  - The old build refuses every nick with 432.
  - The new build logs three bad values and keeps their defaults (NICKLEN=15, CHANNELLEN=200, MAXCHANNELS=20). It applies SILENCE=17 and reports nothing for the LOG lines.

The same change is opened against master separately.
