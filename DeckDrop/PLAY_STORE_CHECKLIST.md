# DeckDrop — Google Play Production Launch Checklist

This is the runbook for shipping DeckDrop v1.0.0 to the Google Play Store as
a public production release. Work top-to-bottom; check off as you go.

App identity (already configured in `project.godot` and `export_presets.cfg`):

| Field           | Value                       |
|-----------------|-----------------------------|
| Display name    | `DeckDrop`                  |
| Package ID      | `com.kriscagle.deckdrop`    |
| Version name    | `1.0.0`                     |
| Version code    | `1`                         |
| Target SDK      | `34` (Android 14)           |
| Min SDK         | `24` (Android 7.0, ~95% reach) |
| Format          | `.aab` (Android App Bundle) |

---

## 1. One-time Godot side setup

1. Open the project in Godot 4.6.
2. **Editor → Editor Settings → Export → Android**: confirm the paths to
   your Android SDK + Java JDK + Android Debug Bridge. If you installed
   Android Studio with defaults on macOS, these usually auto-detect.
3. **Project → Install Android Build Template**. This creates
   `DeckDrop/android/build/` — the customizable Gradle project Godot uses
   for AAB output. It's in `.gitignore`; you'll need to re-install on any
   fresh checkout.
4. **Project → Export**: the two presets from `export_presets.cfg` should
   appear automatically (Debug APK + Release AAB).

---

## 2. Generate a signing keystore (one-time, KEEP FOREVER)

The keystore is the cryptographic identity Play uses to verify that future
updates are really from you. **If you lose it, you can never update the
app** — you'd have to publish a new app under a new package ID.

Generate it OUTSIDE the project tree:

```bash
mkdir -p ~/keystores
keytool -genkey -v \
  -keystore ~/keystores/deckdrop-upload.keystore \
  -alias deckdrop-upload \
  -keyalg RSA -keysize 2048 \
  -validity 10000
```

It will prompt for:
- A **keystore password** (write it down + back it up)
- A **key password** (can be the same)
- Name/org/locality fields (use real ones — they're embedded in the cert)

Back up `~/keystores/deckdrop-upload.keystore` to two separate offline
locations (USB drive + cloud password manager). Losing it is fatal.

When exporting the release AAB in Godot, the dialog will ask for the
keystore path + alias + passwords. Fill these in once and Godot remembers
per machine (not committed). For CI / scripted builds, pass them via env:

```bash
export GODOT_ANDROID_KEYSTORE_RELEASE_PATH=~/keystores/deckdrop-upload.keystore
export GODOT_ANDROID_KEYSTORE_RELEASE_USER=deckdrop-upload
export GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD=<your_password>
```

---

## 3. Replace the placeholder app icon

`DeckDrop/icon_app.svg` is a serviceable placeholder (stacked cards with
gold spade on felt). For a polished store listing you want:

- **Hi-res icon** — 512×512 PNG, 32-bit, no alpha, ≤1 MB. Required for
  the Play Store listing.
- **Adaptive launcher icon** — two 432×432 PNGs (foreground + background)
  if you want the modern adaptive icon treatment. Optional but
  recommended.

Tooling:
- Free: Android Studio's *Image Asset Studio* (right-click `res/` →
  *New → Image Asset*) generates all sizes from a single source.
- Online: <https://romannurik.github.io/AndroidAssetStudio/icons-launcher.html>

Drop the assets into `DeckDrop/icons/` and point the export preset at them:
`launcher_icons/main_192x192`, `launcher_icons/adaptive_foreground_432x432`,
`launcher_icons/adaptive_background_432x432`.

---

## 4. Build the release AAB

In Godot: **Project → Export → Android (Release AAB) → Export Project**.

Output: `DeckDrop/builds/DeckDrop-release.aab`.

Sanity-check the file:

```bash
unzip -l DeckDrop/builds/DeckDrop-release.aab | head -20
ls -lh DeckDrop/builds/DeckDrop-release.aab
```

Expected size: ~30–50 MB.

Test it on a physical device with bundletool before uploading:

```bash
# https://developer.android.com/tools/bundletool
bundletool build-apks --bundle=DeckDrop-release.aab --output=DeckDrop.apks
bundletool install-apks --apks=DeckDrop.apks
```

---

## 5. Play Console — first-time app setup

Sign in to <https://play.google.com/console> and **Create app**:

| Field              | Value                                                  |
|--------------------|--------------------------------------------------------|
| App name           | DeckDrop                                               |
| Default language   | English (United States)                                |
| App or game        | Game                                                   |
| Free or paid       | Free                                                   |
| Declarations       | Check both: meets Developer Program Policies + US export laws |

Then complete **all** of these (Play won't let you publish to production
until every section is green):

### 5a. Store listing
- **Short description** (80 chars):
  > Connect 4 meets poker. Drop cards, build hands, chase the high score.
- **Full description** (4000 chars) — see `STORE_LISTING.md` (TODO: create
  the long copy file when you're ready to fine-tune).
- **App icon**: 512×512 PNG (from step 3).
- **Feature graphic**: 1024×500 PNG. Used in featured placements.
- **Screenshots**: 4–8 portrait phone screenshots (recommended 1080×1920).
  Capture from the Godot editor with the device-frame disabled — show
  Title, mid-run with a hand firing, the perk shop, and the progress
  panel. 7" tablet + 10" tablet screenshots are optional but boost the
  listing on tablet form factors.

### 5b. Privacy policy
**Required for production.** Use `PRIVACY_POLICY.md` (in this folder) as
the source. You need it hosted at a public HTTPS URL — easiest path is a
GitHub Pages site:

1. Push `PRIVACY_POLICY.md` to a public repo (or this one).
2. Enable Pages: Settings → Pages → Branch: main, /(root).
3. The URL will be `https://kriscagle.github.io/<repo>/PRIVACY_POLICY.html`
   (GitHub Pages auto-renders MD to HTML).

Paste that URL into the Play Console **App content → Privacy policy** field.

### 5c. App content (the consent/declarations gauntlet)
- **Privacy policy** — URL from 5b.
- **Ads** — "No, my app does not contain ads."
- **App access** — "All functionality available without special access."
- **Content rating** — Fill out the questionnaire. DeckDrop is a card
  game with no real-money gambling, no violence, no user-generated
  content — should land at **Everyone** (or **Everyone 10+** if Play
  classifies "card games involving betting mechanics" higher).
- **Target audience** — Select age groups. Recommend 13+ (avoids the
  COPPA / Designed for Families regulatory load).
- **News app** — No.
- **COVID-19 contact tracing** — No.
- **Data safety** — DeckDrop collects nothing and shares nothing. Fill
  out as: no data collected, no data shared. (This is verified against
  the AAB's manifest — keep `permissions/internet=false` so the form
  stays simple.)
- **Government app** — No.
- **Financial features** — No.
- **Health features** — No.

### 5d. Main store listing → Categorization
- **App category**: Game → Card
- **Tags**: poker, puzzle, casino, cards, solitaire (pick 5 most relevant)

---

## 6. Upload the first release

**Production → Create new release**:

1. **Use Play App Signing** (recommended). Play holds the master signing
   key for you; your upload key (from step 2) is only used to verify
   uploads. If you ever lose the upload key, Play can issue a new one —
   this is the safety net for the "lose key = lose app" disaster.
2. **Upload `DeckDrop-release.aab`**.
3. **Release name**: `1.0.0` (auto-filled from versionName).
4. **Release notes** (English):
   ```
   Initial release.
   • Connect 4–style column drops + poker hand scoring
   • 10 unlockable card themes
   • Daily seed mode
   • 24 achievements, mid-run perk shop, named dealer bosses
   ```
5. **Review release** → resolve any warnings (usually around 64-bit
   support, target SDK, or screenshot count — all should be satisfied
   by our presets).
6. **Start rollout to Production** — staged rollout at 10% is a safe
   default for v1.

---

## 7. Post-launch

- **Crash reports**: Play Console → Quality → Android vitals. Check
  weekly the first month.
- **Reviews**: respond within 7 days to anything 1–3 stars. Empty
  responses count as "no response" in Play's metrics.
- **Updates**: bump `config/version_code` (integer) AND `config/version`
  (string) in `project.godot` for every upload. Play rejects re-uploads
  of the same `version_code`.
