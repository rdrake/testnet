`client_sock_callback()`'s ET_DESTROY could call `free_connection(con)` and then `ssl_free(ev_socket(ev))`, where the socket lives inside the Connection just freed. It worked only because freed Connections go to a freelist.

**The fix:** free the TLS state first.

**Testing:** build and the test programs pass.

This is the master part of the event-loop ordering fixes. The ircv3.2-upgrade part, which also needs the engine changes, is opened separately.
