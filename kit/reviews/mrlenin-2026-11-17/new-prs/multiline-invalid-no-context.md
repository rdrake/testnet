Split out of #286, as its review asked. The commit is unchanged.

The [multiline spec](https://ircv3.net/specs/extensions/multiline) defines the failure as `FAIL BATCH MULTILINE_INVALID :<description>`. Three sites in `m_batch.c` sent the batch reference as a context parameter; they now send none, matching the sites in `m_privmsg.c` and `m_notice.c` that already sent no context.

- `MULTILINE_INVALID_TARGET`, `MULTILINE_MAX_LINES` and `MULTILINE_MAX_BYTES` keep their parameters.
- A client that read the batch reference as context can no longer tell which batch failed from the line alone. Only one multiline batch can be open per connection, so nothing is ambiguous.

**Tests:** irctest `multiline.py` `testInvalidBlankConcatTag` passes (run on #286 before the split). Debug build with no warnings; the whole CMocka suite passes.
