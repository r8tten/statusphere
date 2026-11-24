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
  **Location** tabs. Settings cards stay collapsed until clicked, one opens at
  a time, and they reset to collapsed when the panel is reopened.
- Effects: weather particles in the popup only — snow, rain, thunderstorms
  with a lightning flash, drifting fog, twinkling stars after dark, fireworks
  on New Year's Day and Bonfire Night, and a meteor shower on April Fools'
  Day. The bar button stays clean.
- Data: [Open-Meteo](https://open-meteo.com/) (no API key).
- Location: a custom location saved by Statusphere takes precedence, then the
  shared `~/.local/state/omarchy/settings/weather.json` the rest of Omarchy
  uses. If neither has coordinates, Statusphere geocodes the saved name, then
  falls back to `https://geo.omarchy.org/`. The Location tab can auto-detect
  once, search for a place by name, and keep a short list of saved locations
  to switch between.
- Cache: the last good response is kept in
  `~/.cache/naoko.statusphere/report.json` and shown (marked stale) if a refresh
  fails.

## Install

```bash
omarchy plugin add https://github.com/r8tten/statusphere.git --enable
omarchy restart shell
```

`--enable` turns Statusphere on and asks where to put it in the bar; the default
is the right side. Add `--yes` to accept the default without the prompt.

Requirements: Omarchy with Quickshell, and `curl`.

## Update

```bash
omarchy plugin update naoko.statusphere
omarchy restart shell
```

## Remove

```bash
omarchy plugin remove naoko.statusphere
omarchy restart shell
```

Removing the plugin leaves your settings in
`~/.local/state/naoko.statusphere/settings.json`; delete that file as well for a
clean slate.

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
click it, or when you pick a different tone, fading the old line out and the new
one in when **Comment fade** is on. Tone only affects the popup comment; the bar
tooltip stays plain. Comments come from a pack for the current weather, with
separate friendly, rude, and profane lines. On 24–26 December, 31 December–1
January, 31 October, and 1 April, a holiday pack (Christmas, New Year,
Halloween, April Fools) takes over for the day.

The cog in the popup opens the settings page. **General** holds the personality
and unit choices. **Appearance** controls the popup's gradient and weather
effects. **Location** shows the active source and lets you auto-detect once,
return to Omarchy's location, or search for a place by name. **Save this
location** pins the current place to a saved list you can switch between;
removing the active saved location falls back to Omarchy's. Tab and Shift+Tab
cycle the three tabs; closing the popup returns the page to General.

### Appearance

The gradient follows the theme accent by default, nudged by the current
condition (**Weather**). Switch to **Custom** to pick your own hue, vividness,
and brightness with three sliders; the first switch seeds them from the current
weather gradient, then your values are remembered. Brightness starts at the
theme's accent lightness and can move between 20% and 75%. Vividness also
deepens the wash, so higher values carry more colour down the card.

**Weather effects** is a single on/off switch for all particles. They only
appear in the popup, are paused while the settings page is open, and stop when
the popup closes:

| When | Effect |
| --- | --- |
| Snow | Snowflakes of varied sizes drifting down with a gentle sway. |
| Rain | Thin, slanted streaks falling fast. |
| Thunderstorm | Rain plus an occasional lightning flash. |
| Fog | Slow, translucent puffs drifting across. |
| After dark (sun 6° below the horizon) | Twinkling stars, unless rain, snow, fog, or a thunderstorm overrides them. |
| New Year's Day, Bonfire Night (5 Nov) | Fireworks bursting in the popup. |
| April Fools' Day (1 Apr) | A meteor shower streaks across the popup. |

Stars follow the sun at the selected location rather than your clock. They
appear once it is 6° below the horizon (the end of civil twilight) and fade out
at dawn, whatever the season. Any weather effect takes priority over them.
Fireworks and the meteor shower replace the weather effect for the day.

**Solar eclipses** come from a small curated table of upcoming events (2027–2030
for now). When the selected location falls inside an event's approximate
visibility region, the popup dims and a corona appears around the icon and
temperature: total eclipses go darkest, annular eclipses get a warm ring, and
partial eclipses dim with only a faint glow. The regions and times are
approximate, and the effect respects **Weather effects**.

**Comment fade** controls whether a new comment fades in, or swaps over
instantly. It is on by default.

**Temperature motion** is off by default. When enabled, either a quiet sphere
of dots turns behind the weather icon and temperature, or Saturn-style banded
rings orbit the hero, with the near half crossing in front. Both are centred on
the whole hero row and reach just past the feels-like line. Its dropdown chooses
**Globe** or **Rings** and controls the dot count, rotation speed, ring
diameter, tilt, planet size for rings, limb ring for the globe, dot colour
(auto or a custom hue), accent share, and opacity. In Rings mode **Ring size**
scales only the rings and **Planet size** scales only the central globe; the
rings, globe, and globe border each get their own opacity slider. In Globe mode
**Size** and a single **Opacity** control the dotted globe. It pauses while the settings are open or when animations are
disabled.

Effects and comment fade are on by default; Temperature motion is off. Neither
the gradient nor these preferences are written to `shell.json`; they live in the
plugin's own state file.

Picking a tone, changing units, choosing a location, saving or removing a
saved location, or changing appearance writes only this plugin's own state
file:

```
~/.local/state/naoko.statusphere/settings.json
```

It looks like:

```json
{
  "tone": "unhinged",
  "unit": "metric",
  "appearance": {
    "gradient": "custom", "hue": 205, "sat": 82, "lightness": 62,
    "effects": true, "commentFade": true,
    "tempGlobe": true, "tempGlobeStyle": "globe", "tempGlobeCount": 240,
    "tempGlobeSpeed": 18, "tempGlobeSize": 110, "tempGlobeTilt": 20,
    "tempGlobeCore": 100, "tempGlobeRing": 30,
    "tempGlobeRingOpacity": 35, "tempGlobeCoreOpacity": 35,
    "tempGlobeBorderOpacity": 35,
    "tempGlobeHue": -1, "tempGlobeAccent": 15, "tempGlobeOpacity": 35
  },
  "location": { "name": "Reykjavík", "latitude": 64.1466, "longitude": -21.9426 },
  "locationSource": "manual",
  "favourites": [
    { "name": "Reykjavík", "latitude": 64.1466, "longitude": -21.9426 },
    { "name": "Lisbon", "latitude": 38.7167, "longitude": -9.1333 }
  ]
}
```

Those values take precedence over the corresponding settings from then on.
`appearance.gradient` is `weather` or `custom`; `hue` (0–360), `sat` (0–100),
and `lightness` (20–75) are kept only once a custom gradient has been seeded.
`effects` and `commentFade` are booleans and default to on; `tempGlobe`
defaults to off, and its style (`globe` or `rings`), dot count (60–600), speed
(0–90°/s), size (75–180%), tilt (−60–60°), planet size (50–150%), limb ring
(0–100%), ring/globe/border opacity (0–100%), colour (−1 for auto, or 0–360°),
accent share (0–100%), and the globe-style opacity (10–80%) are kept. `locationSource` is
`manual` or `auto`; omit `location` to follow Omarchy's shared location again.
`favourites` holds up to 20 saved places, deduplicated by coordinates, and
survives **Use Omarchy location**; removing the active saved location also
clears `location`, so Statusphere falls back to Omarchy's. Delete the file to
fall back to the configured defaults. Statusphere never writes to
`~/.config/omarchy/shell.json` or to Omarchy's shared `weather.json`.

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
