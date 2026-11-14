# Statusphere

A weather widget for the Omarchy bar with a Carrot-style hero, a 3-day
forecast, and opinions about the weather.

![Statusphere preview](preview.png)

![Statusphere settings](preview-settings.png)

- Bar button: current condition glyph + temperature, with a hover tooltip.
- Popup: location, large icon + temperature, `FEELS` line, a weather comment,
  humidity / wind / rain tiles, a 3-day forecast, and a footer with the last
  update time and refresh. The cog opens a settings page with **General**
  (personality and units), **Appearance** (gradient and effects), and
  **Location** tabs.
- Effects: weather particles in the popup only — snow, rain, thunderstorms
  with a lightning flash, drifting fog, and twinkling stars on a clear night.
  The bar button stays clean.
- Data: [Open-Meteo](https://open-meteo.com/) (no API key).
- Location: a custom location saved by Statusphere takes precedence, then the
  shared `~/.local/state/omarchy/settings/weather.json` the rest of Omarchy
  uses. If neither has coordinates, Statusphere geocodes the saved name, then
  falls back to `https://geo.omarchy.org/`. The Location tab can auto-detect
  once or search for a place by name.
- Cache: the last good response is kept in
  `~/.cache/naoko.statusphere/report.json` and shown (marked stale) if a refresh
  fails.

## Install

```bash
git clone https://github.com/r8tten/statusphere.git \
  ~/.config/omarchy/plugins/naoko.statusphere
```

Then add **Statusphere** to the bar from the Omarchy bar settings. Do not add it
by hand unless you already edit `~/.config/omarchy/shell.json`.

Requirements: Omarchy with Quickshell, and `curl`.

## Settings

Defaults are read from the widget's entry in `shell.json`, and Omarchy's
settings panel can edit the same keys through this plugin's `schema`. The
in-popup settings page overrides tone, units, and appearance locally.

| Key | Type | Default | Meaning |
| --- | --- | --- | --- |
| `tone` | `friendly` / `snarky` / `unhinged` | `snarky` | How much attitude the comment gets. |
| `unit` | `auto` / `metric` / `imperial` | `auto` | `auto` follows the locale. The General tab's units control overrides it and remembers the choice. |
| `refreshMinutes` | integer (5–120) | `15` | How often to refetch Open-Meteo. |

Example entry:

```json
{ "id": "naoko.statusphere", "tone": "unhinged", "unit": "metric", "refreshMinutes": 15 }
```

The comment rerolls when the panel opens, when the weather refreshes, when you
click it, or when you pick a different tone. Tone only affects the popup
comment; the bar tooltip stays plain. Comments come from a pack for the current
weather, with separate friendly, rude, and profane lines. On 24–26 December,
31 December–1 January, and 31 October, a holiday pack (Christmas, New Year,
Halloween) takes over for the day.

The cog in the popup opens the settings page. **General** holds the personality
and unit choices. **Appearance** controls the popup's gradient and weather
effects. **Location** shows the active source and lets you auto-detect once,
return to Omarchy's location, or search for a place by name. Tab and Shift+Tab
cycle the three tabs; closing the popup returns the page to General.

### Appearance

The gradient follows the theme accent by default, nudged by the current
condition (**Weather**). Switch to **Custom** to pick your own hue and
vividness with two sliders; the first switch seeds them from the current
weather gradient, then your values are remembered. Custom keeps the theme's
accent lightness, so the popup still belongs to the desktop.

**Weather effects** is a single on/off switch for all particles. They only
appear in the popup, are paused while the settings page is open, and stop when
the popup closes:

| Weather | Effect |
| --- | --- |
| Snow | Snowflakes of varied sizes drifting down with a gentle sway. |
| Rain | Thin, slanted streaks falling fast. |
| Thunderstorm | Rain plus an occasional lightning flash. |
| Fog | Slow, translucent puffs drifting across. |
| Clear night | Twinkling stars. |

Effects are on by default. Neither the gradient nor the effects are written to
`shell.json`; they live in the plugin's own state file.

Picking a tone, changing units, choosing a location, or changing appearance
writes only this plugin's own state file:

```
~/.local/state/naoko.statusphere/settings.json
```

It looks like:

```json
{
  "tone": "unhinged",
  "unit": "metric",
  "appearance": { "gradient": "custom", "hue": 205, "sat": 82, "effects": true },
  "location": { "name": "Reykjavík", "latitude": 64.1466, "longitude": -21.9426 },
  "locationSource": "manual"
}
```

Those values take precedence over the corresponding settings from then on.
`appearance.gradient` is `weather` or `custom`; `hue` (0–360) and `sat`
(0–100) are kept only once a custom gradient has been seeded. `locationSource`
is `manual` or `auto`; omit `location` to follow Omarchy's shared location
again. Delete the file to fall back to the configured defaults. Statusphere
never writes to `~/.config/omarchy/shell.json` or to Omarchy's shared
`weather.json`.

## Files

| File | Purpose |
| --- | --- |
| `manifest.json` | Plugin metadata and settings schema. |
| `Panel.qml` | Bar button, popup, fetch/location/cache logic, settings page. |
| `Effects.qml` | Weather particles: snow, rain, storm flash, fog, night stars. |
| `Model.js` | Open-Meteo parsing, validation, icons, units, mood hue, effect kind. |
| `Snark.js` | Comment packs for each weather category and tone. |

## Notes

- API responses are validated before use; a malformed payload is ignored rather
  than shown.
- Network calls use `curl` through Quickshell's `Process`, with timeouts and a
  response-size cap.
- All API text is rendered as `Text.PlainText`.
- Weather data by [Open-Meteo](https://open-meteo.com/) (CC BY 4.0).

## License

MIT. See [LICENSE](LICENSE).
