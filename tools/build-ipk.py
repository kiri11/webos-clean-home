"""Build the Clean Home .ipk and its Homebrew Channel manifest into dist/.

build-ipk.py [VERSION]    VERSION defaults to appinfo.json's major.minor plus the commit count
"""
import gzip
import hashlib
import io
import json
import os
import pathlib
import subprocess
import sys
import tarfile

ROOT = pathlib.Path(__file__).resolve().parent.parent
REPO = "kiri11/webos-clean-home"
MTIME = int(os.environ.get("SOURCE_DATE_EPOCH", "1700000000"))


def tar_gz(entries):
    raw = io.BytesIO()
    with tarfile.open(fileobj=raw, mode="w", format=tarfile.GNU_FORMAT) as tar:
        for name, data, mode in entries:
            info = tarfile.TarInfo(name)
            info.mtime = MTIME
            info.uname = info.gname = "root"
            if data is None:
                info.type = tarfile.DIRTYPE
                info.mode = 0o755
                tar.addfile(info)
            else:
                info.size = len(data)
                info.mode = mode
                tar.addfile(info, io.BytesIO(data))
    out = io.BytesIO()
    with gzip.GzipFile(fileobj=out, mode="wb", mtime=MTIME) as gz:
        gz.write(raw.getvalue())
    return out.getvalue()


def ar(members):
    out = bytearray(b"!<arch>\n")
    for name, data in members:
        out += b"%-16s%-12d%-6d%-6d%-8s%-10d`\n" % (name.encode(), MTIME, 0, 0, b"100644", len(data))
        out += data
        if len(data) % 2:
            out += b"\n"
    return bytes(out)


def commit_version(version):
    try:
        count = subprocess.check_output(["git", "rev-list", "--count", "HEAD"], cwd=ROOT, text=True).strip()
    except (OSError, subprocess.CalledProcessError):
        return version
    return "%s.%s" % (version.rsplit(".", 1)[0], count)


def main():
    appinfo = json.loads((ROOT / "app" / "appinfo.json").read_text())
    appinfo["version"] = sys.argv[1].lstrip("v") if len(sys.argv) > 1 else commit_version(appinfo["version"])
    app_id, version = appinfo["id"], appinfo["version"]
    app_dir = "./usr/palm/applications/%s/" % app_id
    files = [(p.name, p) for p in sorted((ROOT / "app").iterdir()) if p.is_file() and p.name != "appinfo.json"]
    files += [("clean-home/" + p.name, p) for p in sorted((ROOT / "clean-home").iterdir()) if p.is_file()]

    entries = [(d, None, 0) for d in ("./", "./usr/", "./usr/palm/", "./usr/palm/applications/", app_dir,
                                      app_dir + "clean-home/", "./usr/palm/packages/", "./usr/palm/packages/%s/" % app_id)]
    entries.append((app_dir + "appinfo.json", (json.dumps(appinfo, indent=4) + "\n").encode(), 0o644))
    for name, path in files:
        entries.append((app_dir + name, path.read_bytes(), 0o755 if name.endswith(".sh") else 0o644))
    package_info = {"app": app_id, "id": app_id, "loc_name": appinfo["title"], "package_format_version": 2,
                    "vendor": appinfo["vendor"], "version": version}
    entries.append(("./usr/palm/packages/%s/packageinfo.json" % app_id, (json.dumps(package_info, indent=4) + "\n").encode(), 0o644))
    size = sum(len(e[1]) for e in entries if e[1])

    control = ("Package: %s\nVersion: %s\nSection: misc\nPriority: optional\nArchitecture: all\n"
               "Installed-Size: %d\nMaintainer: %s\nDescription: %s\n"
               "webOS-Package-Format-Version: 2\nwebOS-Packager-Version: x.y.x\n"
               % (app_id, version, size, appinfo["vendor"], appinfo["title"])).encode()
    ipk = ar([("debian-binary", b"2.0\n"),
              ("control.tar.gz", tar_gz([("./", None, 0), ("./control", control, 0o644)])),
              ("data.tar.gz", tar_gz(entries))])

    dist = ROOT / "dist"
    dist.mkdir(exist_ok=True)
    ipk_name = "%s_%s_all.ipk" % (app_id, version)
    (dist / ipk_name).write_bytes(ipk)
    manifest = {
        "id": app_id,
        "version": version,
        "type": "web",
        "title": appinfo["title"],
        "appDescription": appinfo["appDescription"],
        "iconUri": "https://raw.githubusercontent.com/%s/main/app/largeIcon.png" % REPO,
        "sourceUrl": "https://github.com/%s" % REPO,
        "rootRequired": True,
        "ipkUrl": "https://github.com/%s/releases/download/v%s/%s" % (REPO, version, ipk_name),
        "ipkHash": {"sha256": hashlib.sha256(ipk).hexdigest()},
    }
    (dist / ("%s.manifest.json" % app_id)).write_text(json.dumps(manifest, indent=4) + "\n", newline="\n")
    print(dist / ipk_name)


if __name__ == "__main__":
    main()
