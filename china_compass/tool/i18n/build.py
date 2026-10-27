"""Builds de/es content from the current English file, reusing existing translations.

English is the source. Translation memory comes from the last committed, aligned
versions (git HEAD) plus new.<lang>.json (EN -> DE/ES pairs added by hand).

Usage, from china_compass/:
    python3 tool/i18n/build.py assets/content collect   # writes tool/i18n/missing.<lang>.json
    # translate the missing strings into tool/i18n/new.<lang>.json, then:
    python3 tool/i18n/build.py assets/content build     # writes content.de.json / content.es.json
"""
import json, sys, pathlib
HERE = pathlib.Path(__file__).parent
CONTENT = pathlib.Path(sys.argv[1])
# Values under these keys are ids, codes or Chinese text: never translated.
SKIP = {"id", "url", "zh", "pinyin", "code", "rule", "type", "minutes", "stores", "tags", "guide",
        "appIcon", "apps", "popular", "source", "featured", "emoji", "audio"}

def strings(node, key=None):
    """Translatable strings in document order."""
    if isinstance(node, dict):
        for k, v in node.items():
            if k in SKIP and not (k == "apps" and isinstance(v, list) and v and isinstance(v[0], dict)):
                continue
            yield from strings(v, k)
    elif isinstance(node, list):
        for v in node:
            yield from strings(v, key)
    elif isinstance(node, str):
        yield node

def pairs(en_file, other_file):
    en = list(strings(json.load(open(en_file, encoding="utf-8"))))
    ot = list(strings(json.load(open(other_file, encoding="utf-8"))))
    assert len(en) == len(ot), (en_file, other_file, len(en), len(ot))
    return dict(zip(en, ot))

def translate(node, memory, missing, key=None):
    if isinstance(node, dict):
        out = {}
        for k, v in node.items():
            if k in SKIP and not (k == "apps" and isinstance(v, list) and v and isinstance(v[0], dict)):
                out[k] = v
            else:
                out[k] = translate(v, memory, missing, k)
        return out
    if isinstance(node, list):
        return [translate(v, memory, missing, key) for v in node]
    if isinstance(node, str):
        if node in memory:
            return memory[node]
        missing.setdefault(node, "")
        return node
    return node

import subprocess
for lang in ("en", "de", "es"):
    # The last committed, aligned versions serve as translation memory.
    committed = subprocess.run(["git", "show", f"HEAD:china_compass/assets/content/content.{lang}.json"],
                               capture_output=True, text=True, check=True).stdout
    (HERE / f"committed.{lang}.json").write_text(committed, encoding="utf-8")

mode = sys.argv[2]  # "collect" or "build"
en_now = json.load(open(CONTENT / "content.en.json", encoding="utf-8"))
for lang in ("de", "es"):
    memory = {}
    memory.update(pairs(HERE / "committed.en.json", HERE / f"committed.{lang}.json"))
    extra = HERE / f"new.{lang}.json"
    if extra.exists():
        memory.update(json.load(open(extra, encoding="utf-8")))
    missing = {}
    out = translate(en_now, memory, missing)
    if mode == "collect":
        json.dump(missing, open(HERE / f"missing.{lang}.json", "w", encoding="utf-8"), ensure_ascii=False, indent=1)
        print(lang, len(memory), "known,", len(missing), "missing")
    else:
        assert not missing, f"{lang}: {len(missing)} untranslated, e.g. {list(missing)[:3]}"
        json.dump(out, open(CONTENT / f"content.{lang}.json", "w", encoding="utf-8"), ensure_ascii=False, indent=2)
        print(lang, "written")
