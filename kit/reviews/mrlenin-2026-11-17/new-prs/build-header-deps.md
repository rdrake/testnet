Split out of #256, as its review asked. The two commits are unchanged.

The test objects had no header dependencies, and the `make depend` list knew 195 of 270 objects, so a change to a header could leave an object built against the old layout until `make clean`.

- The compile rules in `ircd/Makefile.in` and `ircd/test/Makefile.in` now pass `-MMD -MP` and read the `.d` files back. The `.d` files are ignored by git and live only in the build directory.
- `make depend` in `ircd/test` runs without `-MMD -MP`. With both, clang appended preprocessed source to `Makefile.in` and gcc appended nothing.

**Testing:** as reviewed on #256: in-tree and out-of-tree builds with gcc, `.d` files only in the build directory, and a touched `include/crdt_hlc.h` rebuilds 11 objects. Checked with clang 18 and gcc. On this branch alone: debug build with no warnings, all CMocka suites pass. BSD make was not tried (INSTALL requires GNU make).
