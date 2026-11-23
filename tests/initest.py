# Round-trip and edit tests for lib/modmenu_ini.lua against the real settings files.
import lupa.lua54 as lupa, sys, os, shutil, tempfile
L = lupa.LuaRuntime()
ini = L.execute(open("lib/modmenu_ini.lua", encoding="utf-8").read())
files = {
    "SentryHeat": "tests/fixtures/SentryHeat.settings.ini",
    "MethCook": "tests/fixtures/MethCook.settings.ini",
}
fails = 0
def check(name, cond):
    global fails
    print(("ok   " if cond else "FAIL ") + name)
    if not cond: fails += 1
for mod, path in files.items():
    raw = open(path, "rb").read()
    text = raw.decode("latin-1")             # bytes as-is
    doc = ini.parse(text)
    check(f"{mod}: unchanged round trip is byte-identical", doc.serialize(doc) == text)
    ents = doc.entries(doc)
    n = len(list(ents.values()))
    check(f"{mod}: found {n} settings", n >= 15)
    style = doc.get(doc, "Style")
    new = "panel" if mod == "SentryHeat" else "world"
    before = text.splitlines(keepends=True)
    doc.set(doc, "Style", new)
    after = doc.serialize(doc).splitlines(keepends=True)
    changed = [i for i in range(len(before)) if before[i] != after[i]]
    check(f"{mod}: editing Style changes exactly one line", len(changed) == 1 and len(before) == len(after))
    if changed:
        b, a = before[changed[0]], after[changed[0]]
        check(f"{mod}: comment column kept ({b.find(';')} -> {a.find(';')})", b.find(";") == a.find(";"))
        check(f"{mod}: line ending kept", b[-2:] == a[-2:] if b.endswith("\r\n") else (b.endswith("\n") == a.endswith("\n")))
        print("     " + b.rstrip() + "\n  -> " + a.rstrip())
    doc.set(doc, "Style", style)
    check(f"{mod}: setting it back restores the file exactly", doc.serialize(doc) == text)
    # a long value pushes the comment right but keeps one space
    doc.set(doc, "ToggleKey", "LeftMouseButtonAndMore")
    line = [l for l in doc.serialize(doc).splitlines() if l.startswith("ToggleKey")][0]
    check(f"{mod}: long value keeps a space before the comment", "LeftMouseButtonAndMore ;" in line)
    # missing setting appended with the file's newline style
    doc2 = ini.parse(text)
    doc2.set(doc2, "BrandNew", "42")
    out = doc2.serialize(doc2)
    check(f"{mod}: missing setting appended", out.rstrip("\r\n").endswith("BrandNew = 42") and out.startswith(text.rstrip("\r\n")))
    secs = sorted(set(e.section or "-" for e in ents.values()))
    print(f"     sections: {secs}; description: {doc.description!r}")
# save() via a temp copy
d = tempfile.mkdtemp()
p = os.path.join(d, "settings.ini"); shutil.copy(files["SentryHeat"], p)
doc = ini.load(p.replace("\\", "/"))
doc.set(doc, "YellowAt", "65")
ok = doc.save(doc, p.replace("\\", "/"))
check("save() writes the edit", ok and "YellowAt      = 65 " in open(p, encoding="latin-1").read())
check("save() leaves no temp/backup files", sorted(os.listdir(d)) == ["settings.ini"])
shutil.rmtree(d)
print("ALL PASS" if fails == 0 else f"{fails} FAILED")
