"""Install and control Clean Home on a rooted LG TV over telnet.

cleanhome.py [--host IP] push [DIR]        upload clean-home/ to DIR (default /media/developer/clean-home)
cleanhome.py [--host IP] home <args>       run clean-home.sh <args> on the TV
cleanhome.py [--host IP] install FILE.ipk  install the Clean Home app
cleanhome.py [--host IP] run "<command>"   run a shell command as root and print its output
cleanhome.py [--host IP] shot [file.jpg]   save a 1920x1080 capture of the screen

The TV address comes from --host or LGTV_HOST.
"""
import base64
import os
import pathlib
import re
import socket
import sys
import time

HOST = os.environ.get("LGTV_HOST", "")
PAYLOAD = pathlib.Path(__file__).resolve().parent.parent / "clean-home"
HOME_DIR = "/media/developer/clean-home"
PROMPT = re.compile(r"^\S* # ")
IAC, DONT, DO, WONT, WILL, SB, SE = 255, 254, 253, 252, 251, 250, 240


def _strip(sock, data):
    out = bytearray()
    i = 0
    while i < len(data):
        if data[i] == IAC and i + 1 < len(data):
            cmd = data[i + 1]
            if cmd in (DO, DONT, WILL, WONT) and i + 2 < len(data):
                sock.sendall(bytes([IAC, WONT if cmd in (DO, DONT) else DONT, data[i + 2]]))
                i += 3
            elif cmd == SB:
                j = data.find(bytes([IAC, SE]), i)
                i = j + 2 if j >= 0 else len(data)
            else:
                i += 2
            continue
        out.append(data[i])
        i += 1
    return bytes(out)


def run(cmd, timeout=60):
    begin, end = "__B%d__" % time.time_ns(), "__E%d__" % time.time_ns()
    s = socket.create_connection((HOST, 23), timeout=10)
    s.settimeout(0.5)
    time.sleep(0.8)
    try:
        _strip(s, s.recv(65536))
    except socket.timeout:
        pass
    script = "stty -echo 2>/dev/null; PS1=''; PS2=''\necho %s\n%s\necho %s$?\n" % (begin, cmd, end)
    s.sendall(script.encode())
    buf = b""
    deadline = time.time() + timeout
    while time.time() < deadline:
        try:
            chunk = s.recv(65536)
        except socket.timeout:
            continue
        if not chunk:
            break
        buf += _strip(s, chunk)
        lines = [PROMPT.sub("", l) for l in buf.decode("utf-8", "replace").replace("\r", "").split("\n")]
        if any(l.startswith(end) and l[len(end):].isdigit() for l in lines[:-1]):
            break
    s.sendall(b"exit\n")
    s.close()
    text = buf.decode("utf-8", "replace").replace("\r", "")
    lines = [PROMPT.sub("", l) for l in text.split("\n")]
    starts = [i for i, l in enumerate(lines) if l.rstrip().endswith(begin) and "echo " + begin not in l]
    ends = [i for i, l in enumerate(lines) if l.startswith(end) and l[len(end):].isdigit()]
    if not starts or not ends:
        raise RuntimeError("no complete output from the TV:\n" + text[-2000:])
    code = int(lines[ends[-1]][len(end):] or 1)
    return "\n".join(lines[starts[-1] + 1:ends[-1]]), code


def push(home_dir=HOME_DIR):
    parts = ["mkdir -p %s" % home_dir]
    for f in sorted(p for p in PAYLOAD.iterdir() if p.is_file()):
        data = base64.encodebytes(f.read_bytes()).decode()
        dest = "%s/%s" % (home_dir, f.name)
        parts.append("base64 -d > %s.new <<'B64EOF'\n%sB64EOF" % (dest, data))
        parts.append("cat %s.new > %s && rm %s.new" % (dest, dest, dest))
        if f.suffix == ".sh":
            parts.append("chmod 755 %s" % dest)
        parts.append("sha256sum %s" % dest)
    return run("\n".join(parts), 120)


def install(ipk):
    data = base64.encodebytes(pathlib.Path(ipk).read_bytes()).decode()
    return run("base64 -d > /tmp/clean-home.ipk <<'B64EOF'\n%sB64EOF\n"
               "luna-send -w 60000 -i luna://com.webos.appInstallService/dev/install "
               "'{\"id\":\"io.github.kiri11.cleanhome\",\"ipkUrl\":\"/tmp/clean-home.ipk\",\"subscribe\":true}' "
               "| grep -m 1 -E 'installed|failed|errorText'; rm -f /tmp/clean-home.ipk" % data, 90)


def shot(path):
    out, code = run('luna-send -n 1 luna://com.webos.service.capture/executeOneShot '
                    '\'{"path":"/tmp/lgtv-shot.jpg","method":"DISPLAY","format":"JPG","width":1920,"height":1080}\' >/dev/null'
                    ' && base64 /tmp/lgtv-shot.jpg; rm -f /tmp/lgtv-shot.jpg', 120)
    if code == 0:
        pathlib.Path(path).write_bytes(base64.b64decode(re.sub(r"[^A-Za-z0-9+/=]", "", out)))
        out = path
    return out, code


def main():
    global HOST
    args = sys.argv[1:]
    if len(args) > 1 and args[0] == "--host":
        HOST = args[1]
        args = args[2:]
    if not args or not HOST:
        print(__doc__)
        return 2
    if args[0] == "push":
        out, code = push(args[1] if len(args) > 1 else HOME_DIR)
    elif args[0] == "shot":
        out, code = shot(args[1] if len(args) > 1 else "clean-home.jpg")
    elif args[0] == "home":
        out, code = run("%s/clean-home.sh %s" % (HOME_DIR, " ".join(args[1:])), 120)
    elif args[0] == "install" and len(args) > 1:
        out, code = install(args[1])
    elif args[0] == "run":
        out, code = run(args[1], float(args[2]) if len(args) > 2 else 60)
    else:
        print(__doc__)
        return 2
    print(out)
    return code


if __name__ == "__main__":
    sys.exit(main())
