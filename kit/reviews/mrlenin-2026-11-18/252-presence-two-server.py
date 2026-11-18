"""#252 at 448cd5a3: the presence filter on a federated SEARCH, two linked scratch servers
(A = 127.0.0.1:6797, B = :6798, containers n252a/n252b, CHATHISTORY_STRICT_PRESENCE TRUE in
the last features block of each /scratch/local.conf).  A is stopped while "needle before" is
said on B, so only B stores it; the requesters join after A is back and linked."""
import socket, ssl, time, subprocess, base64, random, string
PW = dict(tuple(l.strip().split("=", 1)[1].split(":", 1))
          for l in open("/Users/rdrake/workspace/afternet/nef2-conformance-run/testnet-accounts.txt") if "=" in l)
def conn(port):
    s = socket.create_connection(("127.0.0.1", port), timeout=10)
    ctx = ssl.create_default_context(); ctx.check_hostname = False; ctx.verify_mode = ssl.CERT_NONE
    s = ctx.wrap_socket(s); s.settimeout(1); return s
def rd(s, wait=2.0):
    out = b""; end = time.time() + wait
    while time.time() < end:
        try:
            d = s.recv(65536)
            if not d: break
            out += d
        except Exception: pass
    lines = out.decode(errors="replace").split("\r\n")
    for l in lines:
        if l.startswith("PING"): s.sendall(("PONG" + l[4:] + "\r\n").encode())
    return [l for l in lines if l]
def tx(s, l): s.sendall((l + "\r\n").encode())
CAPS = ["batch", "server-time", "message-tags", "labeled-response", "soju.im/search", "draft/chathistory", "standard-replies"]
def reg(port, nick, acct=None):
    s = conn(port); tx(s, "CAP LS 302"); tx(s, f"NICK {nick}"); tx(s, f"USER {nick} 0 * :{nick}"); rd(s, 2)
    tx(s, "CAP REQ :" + " ".join(CAPS + (["sasl"] if acct else []))); rd(s, 2)
    ok = None
    if acct:
        tx(s, "AUTHENTICATE PLAIN"); rd(s, 2)
        tx(s, "AUTHENTICATE " + base64.b64encode(f"{acct}\0{acct}\0{PW[acct]}".encode()).decode())
        ok = any(" 903 " in l for l in rd(s, 5))
    tx(s, "CAP END"); rd(s, 3); return s, ok
def ctl(c, cmd): return subprocess.run(["docker", "exec", c, "sh", "-c", cmd], capture_output=True, text=True).stdout.strip()
def search(s, label, q):
    tx(s, f"@label={label} SEARCH {q}"); r = rd(s, 6)
    rows = [l.split(" :", 1)[-1] for l in r if " PRIVMSG " in l and "needle" in l]
    fails = [l for l in r if "FAIL" in l]
    return sorted(rows), fails
run = "".join(random.choice(string.ascii_lowercase) for _ in range(4)); ch = "#pt" + run
print("channel", ch)
sp, _ = reg(6798, "spk" + run); tx(sp, "JOIN " + ch); rd(sp, 2)
print("stop A:", ctl("n252a", "sh /ctl.sh stop").splitlines()[-1])
tx(sp, f"PRIVMSG {ch} :needle before"); rd(sp, 2)
print("start A:", ctl("n252a", "sh /ctl.sh start b").splitlines()[-1]); time.sleep(5)
op, _ = reg(6797, "opr" + run); tx(op, "OPER oper shmoo"); o = rd(op, 3)
print("oper:", any(" 381 " in l for l in o))
linked = False
for attempt in range(6):
    tx(op, "CONNECT leaf.fractalrealities.net"); rd(op, 5)
    tx(op, "MAP"); m = rd(op, 3)
    if any("leaf.fractalrealities.net" in l for l in m): linked = True; break
print("linked:", linked)
r1, ok = reg(6797, "rqa" + run, "hista"); print("requester with account: SASL ok =", ok)
r2, _ = reg(6797, "rqn" + run)
for r in (r1, r2): tx(r, "JOIN " + ch)
j = rd(r1, 3); rd(r2, 1)
print("A sees the speaker in NAMES (linked):", any("spk" + run in l and " 353 " in l for l in j))
time.sleep(2)
tx(sp, f"PRIVMSG {ch} :needle after"); rd(sp, 2); rd(r1, 2); rd(r2, 1)
def both(tag):
    for name, r in (("account", r1), ("no account", r2)):
        a = search(r, tag + "i", f"in={ch};text=needle")
        b = search(r, tag + "n", "text=needle")
        print(f"  {name:10s} in=: {a[0]} {a[1] or ''}   no in=: {b[0]} {b[1] or ''}")
print("strict presence ON:"); both("on")
for c in ("n252a", "n252b"):
    ctl(c, "sed -i 's/\"CHATHISTORY_STRICT_PRESENCE\" = \"TRUE\"; };$/\"CHATHISTORY_STRICT_PRESENCE\" = \"FALSE\"; };/' /scratch/local.conf; pkill -HUP -x ircd")
time.sleep(4); rd(r1, 1); rd(r2, 1)
print("strict presence OFF:"); both("off")
print("servers up:", ctl("n252a", "pgrep -x ircd >/dev/null && echo A-up"), ctl("n252b", "pgrep -x ircd >/dev/null && echo B-up"))
