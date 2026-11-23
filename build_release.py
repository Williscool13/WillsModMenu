"""Build the Will's Mod Menu release (folder WillsModMenu) from the dev source.

Dev-only code is marked in the Lua files and stripped here:
  a line ending in   -- @dev          is removed
  lines between      -- @dev-begin / -- @dev-end   are removed (markers too)

The ini/json libraries come from lib/ (the single source; the copies in
WillsModMenu/Scripts are for running the dev build).

Output:
  build/WillsModMenu/...                 the release tree (run tests/modmenusim.py on it)
  release/WillsModMenu-<VERSION>.zip

usage: python build_release.py          (run from this folder)
"""
import os, shutil, time, zipfile

VERSION = "1.0.0"


def strip_dev(src):
    out, skipping = [], False
    for line in src.split("\n"):
        tag = line.strip()
        if tag == "-- @dev-begin":
            assert not skipping, "nested @dev-begin"
            skipping = True
            continue
        if tag == "-- @dev-end":
            assert skipping, "@dev-end without begin"
            skipping = False
            continue
        if skipping or line.rstrip().endswith("-- @dev"):
            continue
        out.append(line)
    assert not skipping, "unclosed @dev-begin"
    return "\n".join(out)


def read(p):
    return open(p, encoding="utf-8").read().replace("\r\n", "\n")


files = {}   # path inside the zip -> text (LF; written as CRLF)
for name in ("main.lua", "screen.lua"):
    lua = strip_dev(read("WillsModMenu/Scripts/" + name))
    for bad in ("@dev", "Probe", "probe", "styleDump", "autoTests", "self-test", "debugEntry", "Open all doors", "Remove guards", "dbgHost"):
        assert bad not in lua, f"dev code left in {name}: {bad}"
    # a collapsed escape (backslash-a turned into a bell) once slipped into a Lua string
    ctl = [c for c in lua if ord(c) < 32 and c not in (chr(9), chr(10), chr(13))]
    assert not ctl, f"control characters in {name}: {ctl!r}"
    files["WillsModMenu/Scripts/" + name] = lua
# every S.<size> the screen uses must exist (a stray comment once swallowed two)
import re as _re
_scr = files["WillsModMenu/Scripts/screen.lua"]
_stab = _scr[_scr.index("local S = {"):]
_stab = _stab[:_stab.index(chr(10) + "}")]
_defined = set(_re.findall(r"(\w+)\s*=", _re.sub(r"--[^\n]*", "", _stab)))
_used = set(_re.findall(r"\bS\.(\w+)", _scr))
assert _used <= _defined, "screen.lua uses undefined sizes: " + ", ".join(sorted(_used - _defined))
for name in ("modmenu_ini.lua", "modmenu_json.lua"):
    src = read("lib/" + name)
    dev = read("WillsModMenu/Scripts/" + name)
    assert src == dev, f"WillsWillsModMenu/Scripts/{name} differs from lib/{name}: copy lib/ over first"
    files["WillsModMenu/Scripts/" + name] = src
for name in ("settings.ini", "settings.schema.json"):       # ModMenu's own settings (Debug)
    files["WillsModMenu/" + name] = read("WillsModMenu/" + name)
if os.path.isdir("WillsModMenu/schemas"):                    # bundled schemas for mods that ship none (currently none)
    for name in sorted(os.listdir("WillsModMenu/schemas")):
        files["WillsModMenu/schemas/" + name] = read("WillsModMenu/schemas/" + name)
if os.path.exists("release/README.txt"):
    files["WillsModMenu/README.txt"] = read("release/README.txt")
files["WillsModMenu/enabled.txt"] = ""
binaries = {}   # path inside the zip -> bytes
for name in sorted(os.listdir("WillsModMenu/assets")):
    binaries["WillsModMenu/assets/" + name] = open("WillsModMenu/assets/" + name, "rb").read()

crlf = lambda t: t.replace("\n", "\r\n").encode("utf-8")
if os.path.isdir("build/WillsModMenu"):
    shutil.rmtree("build/WillsModMenu")
for path, text in files.items():
    full = os.path.join("build", path)
    os.makedirs(os.path.dirname(full), exist_ok=True)
    open(full, "wb").write(crlf(text))
for path, data in binaries.items():
    full = os.path.join("build", path)
    os.makedirs(os.path.dirname(full), exist_ok=True)
    open(full, "wb").write(data)

os.makedirs("release", exist_ok=True)
zp = f"release/WillsModMenu-{VERSION}.zip"
dt = time.localtime()[:6]
with zipfile.ZipFile(zp, "w", zipfile.ZIP_DEFLATED) as z:
    for path, text in files.items():
        zi = zipfile.ZipInfo(path, dt)
        zi.compress_type = zipfile.ZIP_DEFLATED
        z.writestr(zi, crlf(text))
    for path, data in binaries.items():
        zi = zipfile.ZipInfo(path, dt)
        zi.compress_type = zipfile.ZIP_STORED        # already compressed
        z.writestr(zi, data)
with zipfile.ZipFile(zp) as z:
    assert z.testzip() is None
    names = z.namelist()
print(f"built {zp}: {len(names)} files")
for n in names:
    print("  " + n)
