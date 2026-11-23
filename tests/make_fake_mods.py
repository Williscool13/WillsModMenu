"""Build a fake Mods folder for tests/modmenusim.py.

It mirrors the real install's kinds of folders, plus the cases the mod list has
to handle. SentryHeat's and Meth Lab HUD's settings come from tests/fixtures
(their shipped settings.ini) and examples/ (their schemas); every run starts
from a clean copy.

usage: python make_fake_mods.py <fake_dir>     (run from the repo root)
"""
import os, shutil, sys

out = os.path.abspath(sys.argv[1])
if os.path.isdir(out):
    shutil.rmtree(out)


def put(rel, data=b""):
    p = os.path.join(out, rel)
    os.makedirs(os.path.dirname(p), exist_ok=True)
    open(p, "wb").write(data if isinstance(data, bytes) else data.encode())


# the menu itself, from the dev source
shutil.copytree("WillsModMenu", os.path.join(out, "WillsModMenu"))
put("WillsModMenu/enabled.txt")
# our two mods: shipped settings + schema, a stub main.lua
for mod in ("SentryHeat", "MethCook"):
    put(mod + "/Scripts/main.lua", "-- stub\n")
    put(mod + "/enabled.txt")
    shutil.copy(os.path.join("tests", "fixtures", mod + ".settings.ini"), os.path.join(out, mod, "settings.ini"))
    shutil.copy(os.path.join("examples", mod + ".settings.schema.json"), os.path.join(out, mod, "settings.schema.json"))
# UE4SS's own kinds
put("Keybinds/Scripts/main.lua", "-- stub\n")
put("BPML_GenericFunctions/Scripts/main.lua", "-- stub\n")
put("AllowModsMod/dlls/AllowModsMod.dll", b"MZ")   # as shipped: not main.dll
put("shared/UEHelpers/UEHelpers.lua", "-- stub\n")
put("mods.txt", "BPML_GenericFunctions : 1\r\nAllowModsMod : 0\r\n\r\n; Built-in keybinds, do not move up!\r\nKeybinds : 1\r\n")
# cases the list must handle
put("NestedMod/NestedMod/Scripts/main.lua", "-- stub\n")          # unpacked one level too deep
put("NestedMod/NestedMod/enabled.txt")
put("PlainMod/Scripts/main.lua", "-- stub\n")                    # no settings
put("PlainMod/enabled.txt")
put("OffMod/Scripts/main.lua", "-- stub\n")                      # switched off, has a key that would clash
put("OffMod/enabled.txt.off")
put("OffMod/settings.ini", "; off\r\nToggleKey = F7\r\n")
put("ClashMod/Scripts/main.lua", "-- stub\n")                    # on, clashes with SentryHeat/MethCook's F5
put("ClashMod/enabled.txt")
put("ClashMod/settings.ini", "; clash\r\nPanicKey = F5\r\n")
put("LockedMod/Scripts/main.lua", "-- stub\n")                   # author opted out of the switch
put("LockedMod/enabled.txt")
put("LockedMod/settings.ini", "; locked\r\nVolume = 50\r\n")
put("LockedMod/settings.schema.json", '{ "schema": 0, "allowToggle": false }')
put("TextMod/Scripts/main.lua", "-- stub\n")                     # a free-text setting and a readonly one
put("TextMod/enabled.txt")
put("TextMod/settings.ini", "; text\r\nPlayerName = Bob   ; shown on the HUD\r\nLocked = 5\r\n")
put("TextMod/settings.schema.json", '{ "schema": 0, "settings": { "Locked": { "readonly": true, "note": "Set in the file." } } }')
print("fake mods at " + out)
