"""Generates spoken audio for every Chinese phrase with Azure neural text-to-speech.

Usage (from china_compass/):
    python3 tool/generate_audio.py            # only phrases without audio yet
    python3 tool/generate_audio.py --force    # regenerate everything

Reads the key from tool/azure_speech.env. Writes assets/audio/phrases/<id>.mp3 and adds
"audio" to each phrase in all content files (the Chinese text is the same in every language).
"""
import hashlib
import json
import pathlib
import sys
import urllib.request
from xml.sax.saxutils import escape

ROOT = pathlib.Path(__file__).resolve().parent.parent
CONTENT = sorted((ROOT / "assets/content").glob("content.*.json"))
OUT = ROOT / "assets/audio/phrases"
VOICE = "zh-CN-XiaoxiaoNeural"  # mainland Mandarin, female, natural
RATE = "-10%"  # a little slower than normal speech, easier to follow


def load_env():
    env = {}
    for line in (ROOT / "tool/azure_speech.env").read_text().splitlines():
        if "=" in line and not line.lstrip().startswith("#"):
            k, v = line.split("=", 1)
            env[k.strip()] = v.strip()
    if not env.get("AZURE_SPEECH_KEY"):
        sys.exit("Add your key to tool/azure_speech.env first (AZURE_SPEECH_KEY=...).")
    return env["AZURE_SPEECH_KEY"], env.get("AZURE_SPEECH_REGION") or "eastasia"


def audio_id(zh):
    return hashlib.sha1(zh.encode("utf-8")).hexdigest()[:12]


def phrases(node):
    if isinstance(node, dict):
        if "zh" in node and "pinyin" in node:
            yield node
        for v in node.values():
            yield from phrases(v)
    elif isinstance(node, list):
        for v in node:
            yield from phrases(v)


def synthesize(key, region, text):
    # Speak "A / B" alternatives with a short pause instead of reading the slash.
    spoken = escape(text).replace(" / ", '<break time="400ms"/>')
    ssml = (
        '<speak version="1.0" xml:lang="zh-CN">'
        f'<voice name="{VOICE}"><prosody rate="{RATE}">{spoken}</prosody></voice></speak>'
    )
    req = urllib.request.Request(
        f"https://{region}.tts.speech.microsoft.com/cognitiveservices/v1",
        data=ssml.encode("utf-8"),
        headers={
            "Ocp-Apim-Subscription-Key": key,
            "Content-Type": "application/ssml+xml",
            "X-Microsoft-OutputFormat": "audio-24khz-48kbitrate-mono-mp3",
            "User-Agent": "china-compass-audio",
        },
    )
    with urllib.request.urlopen(req, timeout=30) as r:
        return r.read()


def main():
    force = "--force" in sys.argv
    key, region = load_env()
    OUT.mkdir(parents=True, exist_ok=True)

    texts = {p["zh"] for f in CONTENT for p in phrases(json.loads(f.read_text(encoding="utf-8")))}
    made = 0
    for zh in sorted(texts):
        path = OUT / f"{audio_id(zh)}.mp3"
        if path.exists() and not force:
            continue
        path.write_bytes(synthesize(key, region, zh))
        made += 1
        print(f"  {zh} -> {path.name}")

    for f in CONTENT:
        data = json.loads(f.read_text(encoding="utf-8"))
        for p in phrases(data):
            p["audio"] = f"assets/audio/phrases/{audio_id(p['zh'])}.mp3"
        f.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    print(f"{made} new audio files, {len(texts)} phrases in total.")


if __name__ == "__main__":
    main()
