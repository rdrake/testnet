`iauth_parse()` read a client-addressed line's id with `strtol(params[0], NULL, 10)`, so `16x` was taken as client 16. It read the port with `strtol()` straight into an unsigned short, so a port above 65535 wrapped (65536 + p matched port p) and could match another connection's.

**The fix:** the id must be a whole number (`E BadId` otherwise) and the port a number from 0 to 65535 (`E BadPort` otherwise), as on ircv3.2-upgrade.

**Testing:** build and the test programs pass. With a test IAuth program, the old build accepted `D 11x ...` and a port of p + 65536. The new build answers `E BadId` and `E BadPort` and keeps the client.
