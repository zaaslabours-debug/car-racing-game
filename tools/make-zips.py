#!/usr/bin/env python3
"""Build the downloadable ZIPs into /home/user/ and refresh the
dev-preview copies in public/ (hardlinks, gitignored).

Usage:  npm run build && python3 tools/make-zips.py
"""
import os, zipfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DIST = os.path.join(ROOT, "dist")
TOOLS = os.path.join(ROOT, "tools")
PUBLIC = os.path.join(ROOT, "public")
OUT_DIR = "/home/user"


def add_dir(zf, root, arc_prefix="", skip=()):
    n = 0
    for dirpath, dirnames, filenames in os.walk(root):
        dirnames[:] = [d for d in dirnames if d not in skip]
        for f in filenames:
            if f.lower().endswith(".zip"):
                continue  # never pack zips inside zips (public/ holds preview copies)
            full = os.path.join(dirpath, f)
            rel = os.path.relpath(full, root)
            zf.write(full, os.path.join(arc_prefix, rel) if arc_prefix else rel)
            n += 1
    return n


def add_text(zf, src_path, arcname, crlf=False, executable=False):
    data = open(src_path, "rb").read()
    if crlf:
        data = data.replace(b"\r\n", b"\n").replace(b"\n", b"\r\n")
    zi = zipfile.ZipInfo(arcname)
    zi.compress_type = zipfile.ZIP_DEFLATED
    if executable:
        zi.create_system = 3  # unix
        zi.external_attr = (0o755 & 0xFFFF) << 16
    zf.writestr(zi, data)


def main():
    if not os.path.isfile(os.path.join(DIST, "index.html")):
        raise SystemExit("dist/ missing - run `npm run build` first.")

    game_zip = os.path.join(OUT_DIR, "silver-lake-gp-game.zip")
    if os.path.exists(game_zip):
        os.remove(game_zip)
    with zipfile.ZipFile(game_zip, "w", zipfile.ZIP_DEFLATED, compresslevel=6) as zf:
        n = add_dir(zf, DIST)
        add_text(zf, os.path.join(TOOLS, "HOW-TO-PLAY.txt"), "HOW-TO-PLAY.txt", crlf=True)
        add_text(zf, os.path.join(TOOLS, "PLAY-WINDOWS.bat"), "PLAY-WINDOWS.bat", crlf=True)
        add_text(zf, os.path.join(TOOLS, "play-mac-linux.sh"), "play-mac-linux.sh", executable=True)
    print(f"GAME ZIP: {n + 3} files, {os.path.getsize(game_zip) / 1e6:.1f} MB -> {game_zip}")

    src_zip = os.path.join(OUT_DIR, "silver-lake-gp-source.zip")
    if os.path.exists(src_zip):
        os.remove(src_zip)
    with zipfile.ZipFile(src_zip, "w", zipfile.ZIP_DEFLATED, compresslevel=6) as zf:
        n = add_dir(zf, ROOT, arc_prefix="car-racing-game",
                    skip={"node_modules", "dist", ".git"})
    print(f"SOURCE ZIP: {n} files, {os.path.getsize(src_zip) / 1e6:.1f} MB -> {src_zip}")

    for zp in (game_zip, src_zip):
        # integrity check
        with zipfile.ZipFile(zp) as zf:
            assert zf.testzip() is None, f"corrupt: {zp}"
        # refresh hardlink served by the dev preview (public/*.zip is gitignored)
        link = os.path.join(PUBLIC, os.path.basename(zp))
        if os.path.lexists(link):
            os.remove(link)
        os.link(zp, link)
        print(f"preview link refreshed: public/{os.path.basename(zp)}")
    print("integrity: OK")


if __name__ == "__main__":
    main()
