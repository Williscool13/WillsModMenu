# Tests lib/modmenu_json.lua against the example schemas (compared with Python's json) and bad input.
import lupa.lua54 as lupa, json, glob
L = lupa.LuaRuntime()
J = L.execute(open("lib/modmenu_json.lua", encoding="utf-8").read())
dec = L.eval("function(J, s) local t, e = J.decode(s); return { t = t, e = e } end")
ok = True
for f in sorted(glob.glob("examples/*.json")):
    src = open(f, encoding="utf-8").read()
    r = dec(J, src)
    t, py = r["t"], json.loads(src)
    key = "YellowAt" if "Sentry" in f else "IconSize"
    good = (r["e"] is None and t["title"] == py["title"]
            and len(list(t["settings"].keys())) == len(py["settings"])
            and t["settings"][key]["max"] == py["settings"][key]["max"])
    print(f, "ok" if good else ("FAIL", r["e"]))
    ok &= good
for bad in ['{"a":', '{"a" 1}', '[1,2', '{"a":tru}']:
    r = dec(J, bad)
    print(repr(bad), "rejected:" if r["t"] is None else "ACCEPTED", r["e"])
    ok &= r["t"] is None
r = dec(J, '{"s":"a\\u00e9\\n", "n":-1.5e2, "arr":[true,false,null,{}], }')
t = r["t"]
good = t["s"] == "aé\n" and t["n"] == -150 and t["arr"][1] is True and t["arr"][2] is False
print("escapes/numbers/trailing comma:", "ok" if good else "FAIL")
ok &= good
print("JSON OK" if ok else "JSON FAIL")
