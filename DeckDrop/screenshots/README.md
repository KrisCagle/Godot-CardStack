# DeckDrop Play Store Marketing Screenshots

This folder holds two things:

- **`raw/`** — actual Godot screen captures, untouched. These are the
  files the marketing wrappers reference. Saved as PNG, portrait.
- **`marketing/`** — SVG templates that embed each raw screenshot
  inside a branded frame (casino felt + gold border + headline + tagline +
  DECKDROP wordmark). These are what get converted to PNG and uploaded
  to Play Console.

## Pipeline

1. Capture screenshots in Godot at the four moments below. Save them
   into `raw/` with these exact filenames so the templates find them:

   | File              | Capture moment |
   |-------------------|----------------|
   | `01_title.png`    | Title screen with level/XP bar visible |
   | `02_game.png`     | Mid-run with cards in columns + actions panel |
   | `03_gameover.png` | Dealer-wins / payout panel |
   | `04_perks.png`    | Choose-a-perk shop overlay |

2. Open each `marketing/0X_*.svg` in a browser to preview. The headline
   sits above; the gold-bordered screenshot fills the middle; DECKDROP
   wordmark at the bottom. Felt background matches the icon + feature
   graphic so the listing reads as one brand.

3. Convert each SVG to a 1080×1920 PNG. Pick one tool:

   ```bash
   # rsvg-convert (cleanest output; install via "brew install librsvg")
   for f in marketing/0*.svg; do
     rsvg-convert -w 1080 -h 1920 "$f" -o "${f%.svg}.png"
   done
   ```

   ```bash
   # macOS Preview alternative:
   # File → Export → PNG → set resolution → save
   ```

   ```
   # No-install alternative: https://cloudconvert.com/svg-to-png
   # Set output width=1080, height=1920
   ```

4. Upload the PNGs into Play Console:
   **Main store listing → Phone screenshots → Add screenshots**.
   You need 2–8; we have 4 which is the sweet spot.

## Tweaking the templates

Each `marketing/0X_*.svg` is self-contained. To change a headline, edit
the `<text>` element with the all-caps headline. Same for the subtitle
below it. The screenshot embed (`<image href="...">`) and the gold frame
won't move.

If you re-capture a screenshot, just overwrite the matching file in
`raw/` — no need to touch the SVGs.
