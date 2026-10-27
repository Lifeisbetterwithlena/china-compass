# China Compass

Practical guides for traveling, studying and living in China, in English, German and Spanish.

**Live web app:** https://lifeisbetterwithlena.github.io/china-compass/

## What's inside

| Folder | What it is |
|---|---|
| `china_compass/` | The Flutter app (web, iPhone, Android) |
| `china_compass/assets/content/` | All guide content, one JSON file per language |
| `china_compass/supabase/` | Database setup for accounts and saved progress |
| `china_compass/docs/` | Setup notes (email login, Supabase) |
| `web_prototype/` | The first plain-HTML prototype (no longer updated) |

## Run it locally

```bash
cd china_compass
flutter run -d chrome --dart-define-from-file=supabase.json
```

## Publishing

Every push to `main` runs the tests, builds the web app and publishes it to GitHub Pages
(see `.github/workflows/deploy-web.yml`).
