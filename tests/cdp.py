#!/usr/bin/env python3
"""Minimal Chrome DevTools Protocol client, standard library only.

  cdp.py PORT pages                  list open pages (id, url)
  cdp.py PORT nav URL                navigate the first page to URL, wait for load
  cdp.py PORT eval 'JS'              evaluate JS in the first page, print the value as JSON
  cdp.py PORT wait 'JS' [SECONDS]    poll JS (every 2 s) until truthy or timeout, print the value

Chrome must run with --remote-debugging-port=PORT (and --remote-allow-origins=* on newer versions).
"""
import base64, json, os, socket, struct, sys, time, urllib.request


def pages(port):
    with urllib.request.urlopen(f"http://127.0.0.1:{port}/json", timeout=10) as r:
        return [p for p in json.load(r) if p.get("type") == "page"]


class WS:
    def __init__(self, url):
        rest = url.split("://", 1)[1]
        hostport, path = rest.split("/", 1)
        host, port = hostport.split(":")
        self.s = socket.create_connection((host, int(port)), timeout=60)
        key = base64.b64encode(os.urandom(16)).decode()
        self.s.sendall((f"GET /{path} HTTP/1.1\r\nHost: {hostport}\r\nUpgrade: websocket\r\n"
                        f"Connection: Upgrade\r\nSec-WebSocket-Key: {key}\r\nSec-WebSocket-Version: 13\r\n\r\n").encode())
        buf = b""
        while b"\r\n\r\n" not in buf:
            buf += self.s.recv(4096)
        head, self.buf = buf.split(b"\r\n\r\n", 1)
        if b" 101 " not in head.split(b"\r\n", 1)[0]:
            raise ConnectionError(head.decode(errors="replace"))
        self.id = 0

    def _recv(self, n):
        while len(self.buf) < n:
            d = self.s.recv(65536)
            if not d:
                raise ConnectionError("websocket closed")
            self.buf += d
        out, self.buf = self.buf[:n], self.buf[n:]
        return out

    def _frame(self, op, data):
        mask = os.urandom(4)
        hdr = bytes([0x80 | op])
        n = len(data)
        if n < 126:
            hdr += bytes([0x80 | n])
        elif n < 65536:
            hdr += bytes([0x80 | 126]) + struct.pack(">H", n)
        else:
            hdr += bytes([0x80 | 127]) + struct.pack(">Q", n)
        self.s.sendall(hdr + mask + bytes(b ^ mask[i % 4] for i, b in enumerate(data)))

    def recv(self):
        while True:
            b0, b1 = self._recv(2)
            op, n = b0 & 0x0F, b1 & 0x7F
            if n == 126:
                n = struct.unpack(">H", self._recv(2))[0]
            elif n == 127:
                n = struct.unpack(">Q", self._recv(8))[0]
            if b1 & 0x80:
                self._recv(4)
            payload = self._recv(n)
            if op == 1:
                return json.loads(payload)
            if op == 8:
                raise ConnectionError("websocket closed")
            if op == 9:
                self._frame(0xA, payload)

    def call(self, method, **params):
        self.id += 1
        self._frame(1, json.dumps({"id": self.id, "method": method, "params": params}).encode())
        while True:
            m = self.recv()
            if m.get("id") == self.id:
                if "error" in m:
                    raise RuntimeError(m["error"])
                return m.get("result", {})


def connect(port):
    for _ in range(30):
        try:
            ps = pages(port)
            if ps:
                return WS(ps[0]["webSocketDebuggerUrl"])
        except Exception:
            pass
        time.sleep(1)
    sys.exit("cdp: no page on port %s" % port)


def evaluate(ws, js):
    r = ws.call("Runtime.evaluate", expression=js, returnByValue=True, awaitPromise=True)
    if "exceptionDetails" in r:
        raise RuntimeError(r["exceptionDetails"].get("text", "exception"))
    return r.get("result", {}).get("value")


def main():
    if len(sys.argv) < 3:
        sys.exit(__doc__)
    port, cmd = sys.argv[1], sys.argv[2]
    if cmd == "pages":
        for p in pages(port):
            print(p["id"], p["url"])
        return
    ws = connect(port)
    if cmd == "nav":
        ws.call("Page.enable")
        ws.call("Page.navigate", url=sys.argv[3])
        for _ in range(60):
            if evaluate(ws, "document.readyState") == "complete" and evaluate(ws, "location.href") != "about:blank":
                return
            time.sleep(1)
        sys.exit("cdp: page did not load")
    if cmd == "eval":
        print(json.dumps(evaluate(ws, sys.argv[3])))
        return
    if cmd == "wait":
        js, limit = sys.argv[3], float(sys.argv[4]) if len(sys.argv) > 4 else 600
        t0 = time.time()
        while time.time() - t0 < limit:
            try:
                v = evaluate(ws, js)
            except (RuntimeError, ConnectionError):
                v = None
                ws = connect(port)
            if v:
                print(json.dumps(v))
                return
            time.sleep(2)
        sys.exit("cdp: timeout")
    sys.exit(__doc__)


if __name__ == "__main__":
    main()
