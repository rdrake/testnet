# #242: accept only the spec's timestamp form (decided 2026-11-17)

**Decision (Richard, 2026-11-17, after ibutsu: "technically a spec violation, so it's really a matter of how strict we want to be"):** follow the spec. A client-supplied timestamp is accepted only in exactly the form `YYYY-MM-DDThh:mm:ss.sssZ`.

Spec text (ircv3-specifications main, 9ff58d1):
- `extensions/chathistory.md:67`: "A `timestamp` parameter MUST have the format `timestamp=YYYY-MM-DDThh:mm:ss.sssZ`, as in the server-time extension."
- `extensions/read-marker.md:52`: MARKREAD's timestamp "MUST be a literal `*`, or have the format `timestamp=YYYY-MM-DDThh:mm:ss.sssZ`".
- `extensions/server-time.md:34-36`: `<value> ::= YYYY-MM-DDThh:mm:ss.sssZ`, UTC, ISO 8601 extended format. The examples include a leap second, `23:59:60.419Z`.

## What #242 (head 3bf7f213) still accepts that the spec does not
`history_iso_to_unix()` (`ircd/history_record.c:650`) accepts, and `history_cmocka` asserts that it accepts:
- no `Z` (end of string after the seconds or fraction);
- no fraction (`...:ss` then `Z` or the end);
- a fraction of any length other than three digits (`.5`, `.123456`).

Its `strtol` fields also take a sign, leading spaces and any number of digits.

## The change wanted
- A client-supplied timestamp must match exactly 4 digits, `-`, 2, `-`, 2, `T`, 2, `:`, 2, `:`, 2, `.`, 3 digits, `Z`, then the end of the string.
  - Uppercase `T` and `Z` only.
  - Seconds 00–60 (keep the leap second the spec shows).
  - Anything else is refused with the replies the PR already uses (`FAIL ... INVALID_PARAMS`, MARKREAD's refusal, SEARCH's `Invalid timestamp`).
- This covers every client entry point: CHATHISTORY references (BEFORE, AFTER, LATEST, AROUND, BETWEEN, TARGETS), SEARCH `after=`/`before=` (`m_chathistory.c:9786`, `:9791`), and MARKREAD (`m_markread.c:218`).
- `CH Q` from an older requester passes the client's text through. A responder that cannot read it already answers `E <reqid> 0 U`, so a non-spec timestamp relayed by an old server gets a partial page instead of a wrong one. That is fine.
- Unix `sec.mmm` values used internally between servers stay as they are. The internal fallbacks at `m_chathistory.c:6522` and `:6771` are not client gates.
- `history_cmocka`:
  - flip the cases for no `Z`, no fraction and a long fraction to refused;
  - add `.5Z`, `.1234Z`, a missing `T`, a lowercase `t`/`z`, a sign or space in a field, `2026-1-17T...`, and seconds `61`;
  - keep `+00:00`, `+02:00` and `Zjunk` refused, and `...:60.419Z` accepted.

## Description update for #242 (to be posted from the Mac once the code is pushed)
Put the change under **Changed after review**. The `history_cmocka` sentence ("It checks that `Z`, the end of the string, a long fraction and no fraction are accepted...") must be rewritten to match the new cases.
