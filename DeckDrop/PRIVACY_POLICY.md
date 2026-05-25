# DeckDrop — Privacy Policy

**Effective date:** 2026-05-25
**Last updated:** 2026-05-25

This is the privacy policy for **DeckDrop**, a mobile card game published on
the Google Play Store under the package identifier `com.kriscagle.deckdrop`.
This policy explains what data the app collects, stores, transmits, or
shares — the short answer is **none**.

## Data we collect

**None.** DeckDrop does not collect any personal data, device data,
gameplay data, usage data, identifiers, or telemetry of any kind.

## Data we store

DeckDrop saves your game progress (player level, XP, best score, daily
high scores, unlocked themes, achievement state, lifetime statistics)
locally on your device only. This data is stored in Godot's standard
`user://` data directory:

- **Android**: `/data/data/com.kriscagle.deckdrop/files/`

This data never leaves your device. Uninstalling the app deletes it
along with the rest of the app's storage.

## Data we transmit

**None.** DeckDrop has no network permissions in its Android manifest. It
cannot make outbound network requests of any kind. You can verify this by
inspecting the AAB manifest or by running the app with airplane mode
enabled — it functions identically.

Specifically, the app does **not**:

- Contain ads or ad SDKs.
- Use analytics, crash reporting, or telemetry SDKs.
- Connect to any backend servers, leaderboards, or cloud save services.
- Read or transmit your device identifier (IMEI, advertising ID, etc.).
- Read your contacts, location, microphone, camera, photos, or files.
- Use cookies or web storage.

## Permissions

DeckDrop requests **zero Android runtime permissions**. The only manifest
entries are the Godot engine's required baseline (audio playback, screen
orientation lock) — none of which expose personal data.

## Children's privacy

DeckDrop is suitable for general audiences. Because we collect no data of
any kind, we do not knowingly collect personal information from anyone,
including children under 13. The app complies with the United States
Children's Online Privacy Protection Act (COPPA) by collecting nothing.

## Changes to this policy

If a future version of DeckDrop adds any data collection (e.g. opt-in
cloud save), this policy will be updated and the "Last updated" date
above will be bumped. Material changes will be surfaced in-app.

## Contact

For privacy-related questions about DeckDrop, open an issue at the
project's source repository:

<https://github.com/KrisCagle/Godot-CardStack/issues>
