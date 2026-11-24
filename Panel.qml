import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "Model.js" as Model
import "Snark.js" as Snark

// Statusphere — a bar-sized weather widget with a Carrot-style hero, a 3-day
// forecast, and a personality. Data comes from Open-Meteo. The location is
// Omarchy's shared weather.json unless the in-popup Location tab saves an
// override in the plugin's own state.
Panel {
  id: root

  moduleName: "naoko.statusphere"
  ipcTarget: "naoko.statusphere"
  manageIpc: false

  // --- State -------------------------------------------------------------

  property var weather: null
  property var locationState: ({ name: "", latitude: null, longitude: null })
  property var detectedLocation: ({ name: "", latitude: null, longitude: null })
  property var customLocation: ({ name: "", latitude: null, longitude: null })
  property var favourites: []
  property string locationSource: ""
  property bool settingsOpen: false
  property string settingsTab: "general"
  property string activeSettingsCard: ""
  property var geocodeResults: []
  property bool locationBusy: false
  property string locationError: ""
  property string detectMode: "fallback"
  property string searchOutput: ""
  property bool locationAttempted: false
  property bool loaded: false
  property bool unavailable: false
  property bool stale: false
  property double lastUpdated: 0
  property double nowMs: Date.now()
  property string comment: ""
  property string shownComment: ""

  property string unitOverride: ""
  property int retryCount: 0
  property bool refreshPending: false
  property bool settingsPending: false
  property string weatherOutput: ""
  property bool weatherCollected: false
  property bool weatherExited: false
  property bool weatherExitOk: false
  property string geocodeOutput: ""
  property string detectOutput: ""
  property string pendingLocationName: ""
  property string gradientMode: "weather"
  property real gradientHue: 0
  property real gradientSat: 0
  property real gradientLight: -1
  property bool gradientSeeded: false
  property bool gradientDragging: false
  property bool effectsEnabled: true
  property bool commentFadeEnabled: true
  property bool tempGlobeEnabled: false
  property int tempGlobeCount: 240
  property int tempGlobeSpeed: 18
  property int tempGlobeSize: 110
  property int tempGlobeTilt: 20
  property string tempGlobeStyle: "globe"
  property int tempGlobeCore: 100
  property int tempGlobeRingOpacity: 35
  property int tempGlobeCoreOpacity: 35
  property int tempGlobeBorderOpacity: 35
  property int tempGlobeRing: 30
  property int tempGlobeHue: -1
  property int tempGlobeAccent: 15
  property int tempGlobeOpacity: 35

  readonly property string cachePath: Quickshell.env("HOME")
    + "/.cache/naoko.statusphere/report.json"
  readonly property string settingsPath: Quickshell.env("HOME")
    + "/.local/state/naoko.statusphere/settings.json"
  readonly property var toneChoices: [
    { value: "friendly", label: "Friendly",
      description: "Nice weather commentary, no attitude." },
    { value: "snarky", label: "Snarky",
      description: "Mostly friendly, occasionally rude." },
    { value: "unhinged", label: "Unhinged",
      description: "Swears when the weather deserves it." }
  ]
  readonly property var unitChoices: [
    { value: "", label: "Auto" },
    { value: "metric", label: "\u00b0C" },
    { value: "imperial", label: "\u00b0F" }
  ]
  readonly property var settingsTabChoices: [
    { value: "general", label: "GENERAL" },
    { value: "appearance", label: "APPEARANCE" },
    { value: "location", label: "LOCATION" }
  ]
  readonly property var currentWeather: root.weather ? root.weather.current : null
  readonly property var forecast: root.weather
    && Array.isArray(root.weather.daily) ? root.weather.daily : []
  readonly property string dayKey: Qt.formatDate(new Date(root.nowMs), "MM-dd")
  readonly property string holidayEffect: Model.holidayEffectFor(root.dayKey)
  // Stars follow the sun at the selected location: civil twilight ends when it
  // is 6 degrees below the horizon, which is dark enough to see them.
  readonly property bool darkNow: root.hasCoordinates
    && Model.isDark(root.nowMs, root.latitude, root.longitude)
  readonly property string effectKind: root.holidayEffect !== ""
    ? root.holidayEffect
    : root.currentWeather
      ? Model.effectForCode(root.currentWeather.code, root.darkNow)
      : ""
  readonly property var eclipse: Model.eclipseState(root.nowMs,
    root.latitude, root.longitude)
  readonly property bool eclipseActive: root.effectsEnabled && root.opened
    && root.loaded && !root.unavailable && !root.settingsOpen
    && root.eclipse !== null
  readonly property bool effectsActive: root.effectsEnabled && root.opened
    && root.loaded && !root.unavailable && !root.settingsOpen
    && root.effectKind !== "" && !root.eclipseActive
  readonly property bool hasCustomLocation: root.customLocation
    && root.customLocation.latitude !== null
    && root.customLocation.longitude !== null
  readonly property var effectiveLocation: {
    if (root.hasCustomLocation) return root.customLocation
    if (root.locationState
        && root.locationState.latitude !== null
        && root.locationState.longitude !== null)
      return root.locationState
    if (root.detectedLocation
        && root.detectedLocation.latitude !== null
        && root.detectedLocation.longitude !== null)
      return root.detectedLocation
    return root.locationState || { name: "", latitude: null, longitude: null }
  }
  readonly property real latitude: parseFloat(String(root.effectiveLocation.latitude))
  readonly property real longitude: parseFloat(String(root.effectiveLocation.longitude))
  readonly property bool hasCoordinates: !isNaN(root.latitude) && !isNaN(root.longitude)
  readonly property bool currentIsFavourite: root.isFavourite(root.effectiveLocation)
  readonly property bool favouritesVisible: root.favourites.length > 0
    && root.geocodeResults.length === 0
  readonly property string displayLocation: {
    if (root.hasCustomLocation && String(root.customLocation.name || "") !== "")
      return String(root.customLocation.name)
    const configured = root.locationState
      ? String(root.locationState.name || "").trim() : ""
    const detected = root.detectedLocation
      ? String(root.detectedLocation.name || "").trim() : ""
    return configured || detected || "Your location"
  }
  readonly property string locationCoords: {
    const location = root.effectiveLocation
    if (!location || location.latitude === null || location.longitude === null)
      return ""
    return Number(location.latitude).toFixed(2) + ", "
      + Number(location.longitude).toFixed(2)
  }
  readonly property string locationSourceLabel: {
    if (root.hasCustomLocation)
      return root.isFavourite(root.customLocation)
        ? "Saved location"
        : root.locationSource === "auto" ? "Auto-detected" : "Custom location"
    if (root.locationState
        && root.locationState.latitude !== null
        && root.locationState.longitude !== null)
      return "Omarchy location"
    if (root.detectedLocation
        && root.detectedLocation.latitude !== null
        && root.detectedLocation.longitude !== null)
      return "Auto-detected"
    return "Not set"
  }
  readonly property string localeName: {
    const value = String(Commons.I18n.formatLocale || "")
    return value !== "" ? value : Qt.locale().name
  }
  readonly property bool baseImperial: {
    const setting = String(root.setting("unit", "")).toLowerCase()
    if (setting === "imperial") return true
    if (setting === "metric") return false
    return Model.localeUsesImperial(root.localeName)
  }
  readonly property bool useImperial: root.unitOverride === "imperial"
    ? true : root.unitOverride === "metric" ? false : root.baseImperial
  readonly property string toneSetting: {
    const value = String(root.setting("tone", "snarky")).toLowerCase()
    return value === "friendly" || value === "unhinged" ? value : "snarky"
  }
  property string toneOverride: ""
  readonly property string activeTone: root.toneOverride !== ""
    ? root.toneOverride : root.toneSetting
  readonly property int refreshMinutes: Math.max(1,
    parseInt(root.setting("refreshMinutes", 15), 10) || 15)

  // --- Theme -------------------------------------------------------------

  readonly property color ink: root.bar
    ? root.bar.foreground : Commons.Color.foreground
  readonly property color accent: root.bar
    ? root.bar.urgent : Commons.Color.accent
  readonly property color mutedInk: Commons.Util.alpha(root.ink, 0.62)
  readonly property color faintInk: Commons.Util.alpha(root.ink, 0.38)
  readonly property color tileFill: Commons.Util.alpha(root.ink, 0.05)
  readonly property color tileBorder: Commons.Util.alpha(root.ink, 0.10)
  readonly property color activeFill: Commons.Util.alpha(root.accent, 0.12)
  readonly property string fontFamily: root.bar
    ? root.bar.fontFamily : Style.font.family

  // The accent stays the base; the condition only nudges hue and saturation.
  readonly property var mood: root.currentWeather
    ? Model.moodFor(root.currentWeather.code, root.currentWeather.tempC,
        root.currentWeather.humidity, root.currentWeather.windKmh)
    : ({ hue: 0.04, sat: 1.0 })
  readonly property real heroHue: root.gradientMode === "custom"
    ? root.gradientHue / 360
    : (root.accent.hslHue + root.mood.hue + 1) % 1
  readonly property real heroSat: root.gradientMode === "custom"
    ? Math.min(1, Math.max(0, root.gradientSat / 100))
    : Math.min(1, Math.max(0, root.accent.hslSaturation * root.mood.sat))
  // Custom brightness follows the accent until the slider is moved, then the
  // stored value (20-75%) wins.
  readonly property real heroLight: root.gradientMode === "custom"
    && root.gradientLight >= 0
      ? Math.max(0.2, Math.min(0.75, root.gradientLight / 100))
      : root.accent.hslLightness
  // Custom vividness also deepens the wash, not just the saturation, so 100%
  // reads as a rich colour instead of a faint tint over the card.
  readonly property real customVivid: root.gradientMode === "custom"
    ? root.heroSat : 0
  readonly property color heroTop: Qt.hsla(root.heroHue, root.heroSat,
    root.heroLight, 0.32 + 0.30 * root.customVivid)
  readonly property color heroMid: Qt.hsla(root.heroHue, root.heroSat,
    root.heroLight, 0.13 + 0.17 * root.customVivid)
  readonly property color heroEnd: Qt.hsla(root.heroHue, root.heroSat,
    root.heroLight, 0.0)
  readonly property color tempGlow: Qt.hsla(root.heroHue, root.heroSat,
    Math.min(0.8, root.heroLight + 0.18), 1.0)

  // --- Derived text ------------------------------------------------------

  readonly property string currentIcon: root.currentWeather
    ? root.currentWeather.icon : "\u00b7"
  readonly property string currentTemp: root.currentWeather
    ? Model.formatTemp(root.useImperial
        ? root.currentWeather.tempF : root.currentWeather.tempC) : ""
  readonly property string feelsText: root.currentWeather
    ? "FEELS " + Model.formatTemp(root.useImperial
        ? root.currentWeather.feelsF : root.currentWeather.feelsC) : ""
  readonly property string humidityText: root.currentWeather
    ? Math.round(root.currentWeather.humidity) + "%" : ""
  readonly property string windText: root.currentWeather
    ? Math.round(root.useImperial
        ? root.currentWeather.windMph : root.currentWeather.windKmh)
        + (root.useImperial ? " mph" : " km/h") : ""
  readonly property string rainText: root.forecast.length > 0
    ? Math.round(root.forecast[0].rain) + "%" : ""
  readonly property string updatedText: {
    if (!root.loaded || root.lastUpdated <= 0) return ""
    const minutes = Math.max(0,
      Math.floor((root.nowMs - root.lastUpdated) / 60000))
    var label
    if (minutes < 1) label = "Updated just now"
    else if (minutes < 60) label = "Updated " + minutes + "m ago"
    else label = "Updated " + Math.floor(minutes / 60) + "h ago"
    return root.stale ? label + " \u00b7 stale" : label
  }
  readonly property string tooltipText: {
    if (!root.loaded)
      return root.unavailable
        ? "Statusphere \u00b7 weather unavailable"
        : "Statusphere \u00b7 loading weather"
    if (!root.currentWeather) return "Statusphere"
    return root.displayLocation + " \u00b7 "
      + root.currentWeather.description + " \u00b7 " + root.currentTemp
      + (root.stale ? " \u00b7 stale" : "")
  }
  readonly property string barGlyph: root.loaded ? root.currentIcon : "\u00b7"
  readonly property string barTemp: root.loaded ? root.currentTemp : ""
  // The bar lays an icon button out at the icon slot width unless we reserve
  // room for the temperature label too. The extra width also gives the pair
  // breathing room on both sides.
  readonly property real barPadding: Style.space(6)
  readonly property real barLabelWidth: barLabelMetrics.advanceWidth(
    root.barTemp !== "" ? root.barTemp : "88\u00b0")
  readonly property real barButtonWidth: Math.max(Style.bar.iconSlot,
    root.barPadding * 2 + Style.bar.iconCanvas + Style.space(4)
      + root.barLabelWidth)
  readonly property string requestUrl: root.hasCoordinates
    ? "https://api.open-meteo.com/v1/forecast?latitude=" + root.latitude
      + "&longitude=" + root.longitude
      + "&current=temperature_2m,apparent_temperature,relative_humidity_2m,"
      + "wind_speed_10m,weather_code,is_day"
      + "&daily=weather_code,temperature_2m_max,temperature_2m_min,"
      + "precipitation_probability_max,uv_index_max,sunrise,sunset"
      + "&forecast_days=3&timezone=auto"
    : ""

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  // --- Actions -----------------------------------------------------------

  function rangeText(day) {
    if (!day) return ""
    const high = Math.round(root.useImperial ? day.maxF : day.maxC)
    const low = Math.round(root.useImperial ? day.minF : day.minC)
    return high + "\u00b0 / " + low + "\u00b0"
  }

  function dayLabel(dateString, index) {
    if (index === 0) return "Today"
    if (index === 1) return "Tomorrow"
    const date = new Date(String(dateString || "") + "T00:00:00")
    if (isNaN(date.getTime())) return String(dateString || "")
    const locale = Qt.locale(root.localeName)
    return locale.standaloneDayName(date.getDay(), Locale.ShortFormat)
  }

  function snarkContext() {
    if (!root.currentWeather) return null
    return {
      code: root.currentWeather.code,
      isDay: root.currentWeather.isDay,
      tempC: root.currentWeather.tempC,
      feelsC: root.currentWeather.feelsC,
      humidity: root.currentWeather.humidity,
      windKmh: root.currentWeather.windKmh,
      rain: root.forecast.length > 0 ? root.forecast[0].rain : 0,
      description: root.currentWeather.description,
      dayKey: root.dayKey
    }
  }

  function rerollComment() {
    const context = root.snarkContext()
    if (!context) {
      root.comment = ""
      return
    }
    root.comment = Snark.lineFor(context, root.activeTone, root.comment)
  }

  function validTone(value) {
    const tone = String(value || "").toLowerCase()
    return tone === "friendly" || tone === "snarky" || tone === "unhinged"
      ? tone : ""
  }

  function validUnit(value) {
    const unit = String(value || "").toLowerCase()
    return unit === "metric" || unit === "imperial" ? unit : ""
  }

  function setTone(value) {
    const tone = root.validTone(value)
    if (tone === "") return
    const changed = tone !== root.activeTone || root.toneOverride !== tone
    root.toneOverride = tone
    root.rerollComment()
    if (changed) root.writeSettings()
  }

  function seedGradient() {
    if (root.gradientSeeded) return
    const hue = (root.accent.hslHue + root.mood.hue + 1) % 1
    const sat = Math.min(1, Math.max(0,
      root.accent.hslSaturation * root.mood.sat))
    root.gradientHue = Math.round(hue * 360)
    root.gradientSat = Math.round(sat * 100)
    root.gradientLight = Math.round(
      Math.max(0.2, Math.min(0.75, root.accent.hslLightness)) * 100)
    root.gradientSeeded = true
  }

  function setGradientMode(value) {
    const custom = String(value || "").toLowerCase() === "custom"
    var changed = false
    if (custom && !root.gradientSeeded) {
      root.seedGradient()
      changed = true
    }
    const next = custom ? "custom" : "weather"
    if (next !== root.gradientMode) {
      root.gradientMode = next
      changed = true
    }
    if (changed) root.writeSettings()
  }

  function setGradientHue(value) {
    const hue = Number(value)
    if (!isFinite(hue)) return
    root.gradientHue = Math.max(0, Math.min(360, hue))
    root.gradientSeeded = true
  }

  function hueNear(value, target) {
    const delta = Math.abs(Number(value) - Number(target))
    return Math.min(delta, 360 - delta) < 6
  }

  function setGradientSat(value) {
    const sat = Number(value)
    if (!isFinite(sat)) return
    root.gradientSat = Math.max(0, Math.min(100, sat))
    root.gradientSeeded = true
  }

  function setGradientLight(value) {
    const light = Number(value)
    if (!isFinite(light)) return
    root.gradientLight = Math.max(20, Math.min(75, light))
    root.gradientSeeded = true
  }

  function setEffectsEnabled(value) {
    const enabled = value === true
    if (enabled === root.effectsEnabled) return
    root.effectsEnabled = enabled
    root.writeSettings()
  }

  function setCommentFadeEnabled(value) {
    const enabled = value === true
    if (enabled === root.commentFadeEnabled) return
    root.commentFadeEnabled = enabled
    root.writeSettings()
  }

  function setTempGlobeEnabled(value) {
    const enabled = value === true
    if (enabled === root.tempGlobeEnabled) return
    root.tempGlobeEnabled = enabled
    root.writeSettings()
  }

  function setTempGlobeCount(value) {
    const count = Number(value)
    if (!isFinite(count)) return
    root.tempGlobeCount = Math.max(60, Math.min(600, Math.round(count)))
  }

  function setTempGlobeSpeed(value) {
    const speed = Number(value)
    if (!isFinite(speed)) return
    root.tempGlobeSpeed = Math.max(0, Math.min(90, Math.round(speed)))
  }

  function setTempGlobeSize(value) {
    const size = Number(value)
    if (!isFinite(size)) return
    root.tempGlobeSize = Math.max(75, Math.min(180, Math.round(size)))
  }

  function setTempGlobeTilt(value) {
    const tilt = Number(value)
    if (!isFinite(tilt)) return
    root.tempGlobeTilt = Math.max(-60, Math.min(60, Math.round(tilt)))
  }

  function setTempGlobeStyle(value) {
    const style = value === "rings" ? "rings" : "globe"
    if (style === root.tempGlobeStyle) return
    root.tempGlobeStyle = style
    root.writeSettings()
  }

  function setTempGlobeCore(value) {
    const core = Number(value)
    if (!isFinite(core)) return
    root.tempGlobeCore = Math.max(50, Math.min(150, Math.round(core)))
  }

  function setTempGlobeRingOpacity(value) {
    const opacity = Number(value)
    if (!isFinite(opacity)) return
    root.tempGlobeRingOpacity = Math.max(0,
      Math.min(100, Math.round(opacity)))
  }

  function setTempGlobeCoreOpacity(value) {
    const opacity = Number(value)
    if (!isFinite(opacity)) return
    root.tempGlobeCoreOpacity = Math.max(0,
      Math.min(100, Math.round(opacity)))
  }

  function setTempGlobeBorderOpacity(value) {
    const opacity = Number(value)
    if (!isFinite(opacity)) return
    root.tempGlobeBorderOpacity = Math.max(0,
      Math.min(100, Math.round(opacity)))
  }

  function setTempGlobeRing(value) {
    const ring = Number(value)
    if (!isFinite(ring)) return
    root.tempGlobeRing = Math.max(0, Math.min(100, Math.round(ring)))
  }

  function setTempGlobeHue(value) {
    const hue = Number(value)
    if (!isFinite(hue)) return
    root.tempGlobeHue = Math.max(-1, Math.min(360, Math.round(hue)))
  }

  function setTempGlobeAccent(value) {
    const accent = Number(value)
    if (!isFinite(accent)) return
    root.tempGlobeAccent = Math.max(0, Math.min(100, Math.round(accent)))
  }

  function setTempGlobeOpacity(value) {
    const opacity = Number(value)
    if (!isFinite(opacity)) return
    root.tempGlobeOpacity = Math.max(10, Math.min(80, Math.round(opacity)))
  }

  function applySettings(raw) {
    try {
      const data = JSON.parse(String(raw || ""))
      if (!data || typeof data !== "object") return
      const tone = root.validTone(data.tone)
      if (tone !== "" && tone !== root.toneOverride) {
        root.toneOverride = tone
        if (root.loaded) root.rerollComment()
      }
      const unit = root.validUnit(data.unit)
      if (unit !== root.unitOverride) root.unitOverride = unit
      const appearance = data.appearance && typeof data.appearance === "object"
        ? data.appearance : null
      if (!root.gradientDragging) {
        root.gradientMode = appearance && appearance.gradient === "custom"
          ? "custom" : "weather"
        if (appearance) {
          const hue = Number(appearance.hue)
          const sat = Number(appearance.sat)
          if (isFinite(hue)) {
            root.gradientHue = Math.max(0, Math.min(360, hue))
            root.gradientSeeded = true
          }
          if (isFinite(sat)) {
            root.gradientSat = Math.max(0, Math.min(100, sat))
            root.gradientSeeded = true
          }
          const light = Number(appearance.lightness)
          if (isFinite(light)) {
            root.gradientLight = Math.max(20, Math.min(75, light))
            root.gradientSeeded = true
          } else if (root.gradientLight >= 0) {
            root.gradientLight = -1
          }
          root.effectsEnabled = appearance.effects !== false
          root.commentFadeEnabled = appearance.commentFade !== false
          root.tempGlobeEnabled = appearance.tempGlobe === true
            || (appearance.tempGlobe === undefined
              && appearance.tempDots === true)
          const globeCount = Number(appearance.tempGlobeCount)
          if (isFinite(globeCount))
            root.tempGlobeCount = Math.max(60,
              Math.min(600, Math.round(globeCount)))
          const globeSpeed = Number(appearance.tempGlobeSpeed)
          if (isFinite(globeSpeed))
            root.tempGlobeSpeed = Math.max(0,
              Math.min(90, Math.round(globeSpeed)))
          const globeSize = Number(appearance.tempGlobeSize)
          if (isFinite(globeSize))
            root.tempGlobeSize = Math.max(75,
              Math.min(180, Math.round(globeSize)))
          const globeTilt = Number(appearance.tempGlobeTilt)
          if (isFinite(globeTilt))
            root.tempGlobeTilt = Math.max(-60,
              Math.min(60, Math.round(globeTilt)))
          if (appearance.tempGlobeStyle === "rings")
            root.tempGlobeStyle = "rings"
          else if (appearance.tempGlobeStyle === "globe")
            root.tempGlobeStyle = "globe"
          const globeCore = Number(appearance.tempGlobeCore)
          if (isFinite(globeCore))
            root.tempGlobeCore = Math.max(50,
              Math.min(150, Math.round(globeCore)))
          const globeRing = Number(appearance.tempGlobeRing)
          if (isFinite(globeRing))
            root.tempGlobeRing = Math.max(0,
              Math.min(100, Math.round(globeRing)))
          const ringOpacity = Number(appearance.tempGlobeRingOpacity)
          if (isFinite(ringOpacity))
            root.tempGlobeRingOpacity = Math.max(0,
              Math.min(100, Math.round(ringOpacity)))
          const coreOpacity = Number(appearance.tempGlobeCoreOpacity)
          if (isFinite(coreOpacity))
            root.tempGlobeCoreOpacity = Math.max(0,
              Math.min(100, Math.round(coreOpacity)))
          const borderOpacity = Number(appearance.tempGlobeBorderOpacity)
          if (isFinite(borderOpacity))
            root.tempGlobeBorderOpacity = Math.max(0,
              Math.min(100, Math.round(borderOpacity)))
          const globeHue = Number(appearance.tempGlobeHue)
          if (isFinite(globeHue))
            root.tempGlobeHue = Math.max(-1,
              Math.min(360, Math.round(globeHue)))
          const globeAccent = Number(appearance.tempGlobeAccent)
          if (isFinite(globeAccent))
            root.tempGlobeAccent = Math.max(0,
              Math.min(100, Math.round(globeAccent)))
          const globeOpacity = Number(appearance.tempGlobeOpacity)
          if (isFinite(globeOpacity))
            root.tempGlobeOpacity = Math.max(10,
              Math.min(80, Math.round(globeOpacity)))
          if (appearance.tempGlobeRingOpacity === undefined)
            root.tempGlobeRingOpacity = root.tempGlobeOpacity
          if (appearance.tempGlobeCoreOpacity === undefined)
            root.tempGlobeCoreOpacity = root.tempGlobeOpacity
          if (appearance.tempGlobeBorderOpacity === undefined)
            root.tempGlobeBorderOpacity = root.tempGlobeOpacity
        } else {
          root.effectsEnabled = true
          root.commentFadeEnabled = true
          root.tempGlobeEnabled = false
          root.tempGlobeCount = 240
          root.tempGlobeSpeed = 18
          root.tempGlobeSize = 110
          root.tempGlobeTilt = 20
          root.tempGlobeStyle = "globe"
          root.tempGlobeCore = 100
          root.tempGlobeRingOpacity = 35
          root.tempGlobeCoreOpacity = 35
          root.tempGlobeBorderOpacity = 35
          root.tempGlobeRing = 30
          root.tempGlobeHue = -1
          root.tempGlobeAccent = 15
          root.tempGlobeOpacity = 35
        }
      }
      const location = Model.parseLocation(JSON.stringify(data.location || {}))
      if (location.latitude !== null && location.longitude !== null) {
        const changed = !root.hasCustomLocation
          || root.customLocation.latitude !== location.latitude
          || root.customLocation.longitude !== location.longitude
          || String(root.customLocation.name || "") !== location.name
        root.customLocation = location
        root.locationSource = data.locationSource === "auto" ? "auto" : "manual"
        if (changed) root.refresh(true)
      } else if (root.hasCustomLocation) {
        root.customLocation = { name: "", latitude: null, longitude: null }
        root.locationSource = ""
        root.refresh(true)
      }
      root.favourites = Model.parseFavourites(data.favourites || [])
    } catch (error) {
    }
  }

  function clearOverrides() {
    const hadTone = root.toneOverride !== ""
    const hadLocation = root.hasCustomLocation
    if (hadTone) root.toneOverride = ""
    root.unitOverride = ""
    root.customLocation = { name: "", latitude: null, longitude: null }
    root.locationSource = ""
    root.favourites = []
    root.gradientMode = "weather"
    root.gradientHue = 0
    root.gradientSat = 0
    root.gradientLight = -1
    root.gradientSeeded = false
    root.effectsEnabled = true
    root.commentFadeEnabled = true
    root.tempGlobeEnabled = false
    root.tempGlobeCount = 240
    root.tempGlobeSpeed = 18
    root.tempGlobeSize = 110
    root.tempGlobeTilt = 20
    root.tempGlobeStyle = "globe"
    root.tempGlobeCore = 100
    root.tempGlobeRingOpacity = 35
    root.tempGlobeCoreOpacity = 35
    root.tempGlobeBorderOpacity = 35
    root.tempGlobeRing = 30
    root.tempGlobeHue = -1
    root.tempGlobeAccent = 15
    root.tempGlobeOpacity = 35
    if (hadTone && root.loaded) root.rerollComment()
    if (hadLocation && root.loaded) root.refresh(true)
  }

  function writeSettings() {
    if (settingsWrite.running) {
      root.settingsPending = true
      return
    }
    const data = {}
    if (root.toneOverride !== "") data.tone = root.toneOverride
    if (root.unitOverride !== "") data.unit = root.unitOverride
    const appearance = {
      gradient: root.gradientMode === "custom" ? "custom" : "weather",
      effects: root.effectsEnabled,
      commentFade: root.commentFadeEnabled
    }
    if (root.gradientSeeded) {
      appearance.hue = Math.round(root.gradientHue)
      appearance.sat = Math.round(root.gradientSat)
      if (root.gradientLight >= 0)
        appearance.lightness = Math.round(root.gradientLight)
    }
    if (root.tempGlobeEnabled || root.tempGlobeCount !== 240
        || root.tempGlobeSpeed !== 18 || root.tempGlobeSize !== 110
        || root.tempGlobeTilt !== 20 || root.tempGlobeRing !== 30
        || root.tempGlobeStyle !== "globe" || root.tempGlobeCore !== 100
        || root.tempGlobeRingOpacity !== 35
        || root.tempGlobeCoreOpacity !== 35
        || root.tempGlobeBorderOpacity !== 35
        || root.tempGlobeHue !== -1 || root.tempGlobeAccent !== 15
        || root.tempGlobeOpacity !== 35) {
      appearance.tempGlobe = root.tempGlobeEnabled
      appearance.tempGlobeCount = root.tempGlobeCount
      appearance.tempGlobeSpeed = root.tempGlobeSpeed
      appearance.tempGlobeSize = root.tempGlobeSize
      appearance.tempGlobeTilt = root.tempGlobeTilt
      appearance.tempGlobeStyle = root.tempGlobeStyle
      appearance.tempGlobeCore = root.tempGlobeCore
      appearance.tempGlobeRingOpacity = root.tempGlobeRingOpacity
      appearance.tempGlobeCoreOpacity = root.tempGlobeCoreOpacity
      appearance.tempGlobeBorderOpacity = root.tempGlobeBorderOpacity
      appearance.tempGlobeRing = root.tempGlobeRing
      appearance.tempGlobeHue = root.tempGlobeHue
      appearance.tempGlobeAccent = root.tempGlobeAccent
      appearance.tempGlobeOpacity = root.tempGlobeOpacity
    }
    data.appearance = appearance
    if (root.hasCustomLocation) {
      data.location = {
        name: root.customLocation.name,
        latitude: root.customLocation.latitude,
        longitude: root.customLocation.longitude
      }
      if (root.locationSource !== "") data.locationSource = root.locationSource
    }
    if (root.favourites.length > 0) {
      data.favourites = root.favourites.map(function (entry) {
        return {
          name: entry.name,
          latitude: entry.latitude,
          longitude: entry.longitude
        }
      })
    }
    settingsWrite.command = ["/bin/sh", "-c",
      "mkdir -p \"$(dirname \"$1\")\" && printf '%s' \"$2\" > \"$1.tmp\""
        + " && mv \"$1.tmp\" \"$1\"",
      "sh", root.settingsPath, JSON.stringify(data)]
    settingsWrite.running = true
  }

  function applyReport(parsed) {
    root.weather = parsed
    root.loaded = true
    root.unavailable = false
    root.stale = false
    root.lastUpdated = parsed.fetchedAt
    root.retryCount = 0
    root.rerollComment()
  }

  function applyCached(raw) {
    if (root.loaded) return
    try {
      const wrapper = JSON.parse(String(raw || ""))
      if (!wrapper || typeof wrapper.raw !== "string") return
      const stamp = Number(wrapper.fetchedAt)
      const parsed = Model.parseWeather(wrapper.raw,
        isFinite(stamp) ? stamp : Date.now())
      if (!parsed) return
      root.weather = parsed
      root.loaded = true
      root.unavailable = false
      root.stale = true
      root.lastUpdated = parsed.fetchedAt
      root.rerollComment()
    } catch (error) {
    }
  }

  function writeCache(raw) {
    if (cacheWrite.running || raw === "") return
    const payload = JSON.stringify({ fetchedAt: Date.now(), raw: raw })
    cacheWrite.command = ["/bin/sh", "-c",
      "mkdir -p \"$(dirname \"$1\")\" && printf '%s' \"$2\" > \"$1.tmp\""
        + " && mv \"$1.tmp\" \"$1\"",
      "sh", root.cachePath, payload]
    cacheWrite.running = true
  }

  function markStale() {
    if (root.loaded) root.stale = true
    else root.unavailable = true
    root.scheduleRetry()
  }

  function scheduleRetry() {
    if (root.retryCount >= 3) return
    root.retryCount++
    retryTimer.restart()
  }

  function refresh(force) {
    if (!root.hasCoordinates) return
    if (weatherProc.running) {
      if (force === true) root.refreshPending = true
      return
    }
    root.weatherOutput = ""
    root.weatherCollected = false
    root.weatherExited = false
    root.weatherExitOk = false
    weatherProc.command = ["curl", "-fsS", "--max-time", "8",
      "--max-filesize", "262144", root.requestUrl]
    weatherProc.running = true
  }

  function finishWeather() {
    if (!root.weatherCollected || !root.weatherExited) return
    const output = root.weatherOutput
    const ok = root.weatherExitOk
    const pending = root.refreshPending
    root.weatherOutput = ""
    root.weatherCollected = false
    root.weatherExited = false
    root.weatherExitOk = false
    root.refreshPending = false
    if (ok && output.trim() !== "") {
      const parsed = Model.parseWeather(output)
      if (parsed) {
        root.applyReport(parsed)
        root.writeCache(output)
        if (pending) pendingRefresh.restart()
        return
      }
    }
    root.markStale()
    if (pending) pendingRefresh.restart()
  }

  function applyLocation(raw) {
    const parsed = Model.parseLocation(raw)
    const current = root.locationState
    // A name-only entry gets geocoded into coordinates. The delayed reload of
    // the same file must not throw those coordinates away again.
    if (parsed.latitude === null && parsed.longitude === null
        && current && current.latitude !== null && current.longitude !== null
        && parsed.name !== ""
        && parsed.name.toLowerCase() === String(current.name || "").toLowerCase())
      return
    root.locationState = parsed
    if (parsed.latitude !== null && parsed.longitude !== null) {
      root.locationAttempted = true
      if (!root.hasCustomLocation) root.refresh(true)
      return
    }
    if (root.locationAttempted) return
    root.locationAttempted = true
    if (root.hasCustomLocation) return
    if (parsed.name !== "") root.geocodeLocation(parsed.name)
    else root.detectLocation()
  }

  function geocodeLocation(name) {
    if (geocodeProc.running) return
    root.pendingLocationName = name
    root.geocodeOutput = ""
    geocodeProc.command = ["curl", "-fsS", "--max-time", "6",
      "--max-filesize", "65536",
      "https://geocoding-api.open-meteo.com/v1/search?name="
        + encodeURIComponent(name) + "&count=1&language=en&format=json"]
    geocodeProc.running = true
  }

  function detectLocation() {
    if (detectProc.running) return
    root.detectMode = "fallback"
    detectProc.running = true
  }

  // --- Settings / location ------------------------------------------------

  function setCustomLocation(name, latitude, longitude, source) {
    const location = Model.parseLocation(JSON.stringify({
      name: name, latitude: latitude, longitude: longitude
    }))
    if (location.latitude === null || location.longitude === null) {
      root.locationError = "That location could not be saved."
      return
    }
    root.customLocation = location
    root.locationSource = source === "auto" ? "auto" : "manual"
    root.locationError = ""
    root.geocodeResults = []
    root.writeSettings()
    root.refresh(true)
  }

  function clearCustomLocation() {
    if (!root.hasCustomLocation) return
    root.customLocation = { name: "", latitude: null, longitude: null }
    root.locationSource = ""
    root.locationError = ""
    root.geocodeResults = []
    root.writeSettings()
    root.locationAttempted = false
    locationFile.reload()
    root.refresh(true)
  }

  function favouriteKey(location) {
    if (!location || location.latitude === null || location.longitude === null)
      return ""
    return Number(location.latitude).toFixed(3) + ","
      + Number(location.longitude).toFixed(3)
  }

  function isFavourite(location) {
    const key = root.favouriteKey(location)
    if (key === "") return false
    return root.favourites.some(function (entry) {
      return root.favouriteKey(entry) === key
    })
  }

  function isActiveFavourite(entry) {
    return root.hasCustomLocation
      && root.favouriteKey(root.customLocation) === root.favouriteKey(entry)
  }

  function addFavourite() {
    const location = root.effectiveLocation
    if (!root.hasCoordinates || root.isFavourite(location)) return
    const label = String(root.displayLocation || "").trim()
    const list = root.favourites.slice()
    list.push({
      name: label === "" || label === "Your location"
        ? Number(location.latitude).toFixed(2) + ", "
          + Number(location.longitude).toFixed(2)
        : label,
      latitude: Number(location.latitude),
      longitude: Number(location.longitude)
    })
    root.favourites = Model.parseFavourites(JSON.stringify(list))
    root.writeSettings()
  }

  function removeFavourite(entry) {
    if (!entry) return
    const key = root.favouriteKey(entry)
    const active = root.isActiveFavourite(entry)
    root.favourites = root.favourites.filter(function (item) {
      return root.favouriteKey(item) !== key
    })
    if (!active) {
      root.writeSettings()
      return
    }
    // Fall back to Omarchy's location in the same write as the removal. Two
    // separate writes would let the file watcher reload the old location
    // before the cleared one lands, resurrecting it.
    root.customLocation = { name: "", latitude: null, longitude: null }
    root.locationSource = ""
    root.locationError = ""
    root.geocodeResults = []
    root.locationAttempted = false
    root.writeSettings()
    locationFile.reload()
    root.refresh(true)
  }

  function applyFavourite(entry) {
    if (!entry) return
    root.setCustomLocation(entry.name, entry.latitude, entry.longitude,
      "manual")
  }

  function searchLocation(query) {
    const text = String(query || "").trim()
    if (text.length < 2) {
      root.geocodeResults = []
      root.locationError = text === "" ? "" : "Type at least 2 characters."
      return
    }
    if (searchProc.running) return
    root.locationBusy = true
    root.locationError = ""
    root.geocodeResults = []
    root.searchOutput = ""
    searchProc.command = ["curl", "-fsS", "--max-time", "6",
      "--max-filesize", "131072",
      "https://geocoding-api.open-meteo.com/v1/search?name="
        + encodeURIComponent(text) + "&count=4&language=en&format=json"]
    searchProc.running = true
  }

  function chooseGeocodeResult(result) {
    if (!result) return
    root.setCustomLocation(result.name, result.latitude, result.longitude,
      "manual")
    if (typeof searchField !== "undefined") searchField.text = ""
  }

  function autoDetectCustomLocation() {
    if (detectProc.running) return
    root.detectMode = "custom"
    root.locationBusy = true
    root.locationError = ""
    root.geocodeResults = []
    detectProc.running = true
  }

  function toggleSettings() {
    if (root.settingsOpen) {
      root.closeSettings()
      return
    }
    root.settingsOpen = true
    root.settingsTab = "general"
    root.activeSettingsCard = ""
    root.locationError = ""
    root.geocodeResults = []
  }

  function closeSettings() {
    root.settingsOpen = false
    root.settingsTab = "general"
    root.activeSettingsCard = ""
    root.locationBusy = false
    root.locationError = ""
    root.geocodeResults = []
  }

  function switchSettingsTab(tab) {
    const value = String(tab || "").toLowerCase()
    root.settingsTab = root.settingsTabChoices.some(function(choice) {
      return choice.value === value
    }) ? value : "general"
    root.locationError = ""
    root.geocodeResults = []
  }

  function cycleSettingsTab(direction) {
    const count = root.settingsTabChoices.length
    const current = root.settingsTabChoices.findIndex(function(choice) {
      return choice.value === root.settingsTab
    })
    const step = direction < 0 ? -1 : 1
    const next = ((current < 0 ? 0 : current) + step + count) % count
    root.switchSettingsTab(root.settingsTabChoices[next].value)
  }

  function retryAll() {
    root.locationAttempted = false
    root.retryCount = 0
    locationFile.reload()
    root.refresh(true)
  }

  // --- Bar button --------------------------------------------------------

  FontMetrics {
    id: barLabelMetrics

    font.family: root.fontFamily
    font.pixelSize: Style.font.body
  }

  BarIconButton {
    id: button

    anchors.fill: parent
    bar: root.bar
    text: root.barGlyph
    labelText: root.barTemp
    fixedWidth: root.barButtonWidth
    slotSize: Style.space(58)
    fontFamily: root.fontFamily
    foreground: root.ink
    tooltipText: root.tooltipText

    onPressed: function(buttonCode) {
      if (buttonCode === Qt.LeftButton) root.toggle()
    }
  }

  // --- Popup -------------------------------------------------------------

  KeyboardPanel {
    id: panel

    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    gap: Style.space(4)
    focusTarget: panel.loadedContent
    borderSpec: Border.surfaceSpec("popups", "border",
      Commons.Color.popups.border, Style.space(3))

    contentWidth: panel.fittedContentWidth(Style.space(344))
    contentHeight: panel.fittedContentHeight(panel.loadedContentHeight,
      Style.space(640))

    content: PanelKeyCatcher {
      id: keyCatcher

      anchors.fill: parent
      implicitHeight: contentColumn.implicitHeight
      blocked: searchField.activeFocus

      onCloseRequested: root.settingsOpen ? root.closeSettings() : root.close()
      onReturnRequested: {
        if (!root.settingsOpen) root.rerollComment()
      }
      onTabRequested: function(direction) {
        if (root.settingsOpen) {
          root.cycleSettingsTab(direction)
        } else {
          root.switchPanel(direction)
        }
      }

      // One atmospheric wash for the whole card. It extends under the panel
      // padding; the card clips it to the rounded corners, and the alpha lets
      // the card background and border show through.
      Rectangle {
        id: wash

        anchors.fill: parent
        anchors.margins: -panel.padding
        radius: Math.max(0, Style.cornerRadius - Style.space(3))
        gradient: Gradient {
          orientation: Gradient.Vertical
          GradientStop { position: 0.0; color: root.heroTop }
          GradientStop { position: 0.45; color: root.heroMid }
          GradientStop { position: 1.0; color: root.heroEnd }
        }
      }

      // A solar eclipse dims the whole card behind the content.
      Rectangle {
        anchors.fill: wash
        radius: wash.radius
        color: "#000000"
        opacity: root.eclipseActive ? root.eclipse.darkness : 0
        visible: opacity > 0.001

        Behavior on opacity {
          NumberAnimation {
            duration: Style.duration(700)
            easing.type: Easing.InOutQuad
          }
        }
      }

      // Weather particles ride above the wash but under the hairline and the
      // content, so text stays crisp and nothing escapes the card.
      Effects {
        id: weatherEffects

        anchors.fill: wash
        anchors.margins: Style.space(3)
        kind: root.effectKind
        active: root.effectsActive
        tint: root.ink
        flashColor: root.accent
        fontFamily: root.fontFamily
      }

      // Hairline flush against the accent border: no gap, and its radius
      // follows the wash so it stays parallel around the corners too.
      Rectangle {
        anchors.fill: wash
        radius: wash.radius
        color: "transparent"
        border.width: 2
        border.color: Commons.Util.alpha(root.ink, 0.12)
      }

      Column {
        id: contentColumn

        width: parent.width
        spacing: Style.space(10)

        // --- Header -----------------------------------------------------

        Item {
          id: panelHeader

          width: parent.width
          implicitHeight: Math.max(locationLabel.implicitHeight,
            closeButton.height)

          CursorSurface {
            id: settingsButton

            width: Style.space(22)
            height: width
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            hasCursor: settingsArea.containsMouse
            foreground: root.ink
            accent: root.accent

            Text {
              anchors.centerIn: parent
              textFormat: Text.PlainText
              text: root.settingsOpen ? "\udb81\udc5a" : "\ueb51"
              color: settingsButton.hasCursor ? root.ink : root.mutedInk
              font.family: root.fontFamily
              font.pixelSize: Style.font.title
              renderType: Text.NativeRendering
            }

            MouseArea {
              id: settingsArea

              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: root.toggleSettings()
            }
          }

          Text {
            id: locationLabel

            anchors.centerIn: parent
            width: Math.min(implicitWidth, parent.width - settingsButton.width
              - closeButton.width - Style.space(24))
            textFormat: Text.PlainText
            text: root.settingsOpen ? "SETTINGS" : root.displayLocation
            elide: Text.ElideRight
            color: root.ink
            font.family: root.fontFamily
            font.pixelSize: Style.font.title
            font.bold: true
            font.letterSpacing: root.settingsOpen ? 1.5 : 0
            renderType: Text.NativeRendering
          }

          CursorSurface {
            id: closeButton

            width: Style.space(22)
            height: width
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            hasCursor: closeArea.containsMouse
            foreground: root.ink
            accent: root.accent

            Text {
              // Optical nudge: the times glyph reads a touch left in its square.
              anchors.centerIn: parent
              anchors.horizontalCenterOffset: 0.5
              textFormat: Text.PlainText
              renderType: Text.QtRendering
              text: "\uf00d"
              color: closeButton.hasCursor ? root.ink : root.mutedInk
              font.family: root.fontFamily
              font.pixelSize: Style.font.title
            }

            MouseArea {
              id: closeArea

              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: root.close()
            }
          }
        }

        // --- Settings tabs ----------------------------------------------

        Rectangle {
          id: tabBar

          visible: root.settingsOpen
          width: parent.width
          height: Style.space(30)
          radius: Style.space(10)
          color: Commons.Util.alpha(root.ink, 0.04)
          border.width: 1
          border.color: root.tileBorder

          Row {
            id: tabRow

            anchors.fill: parent
            anchors.margins: 2
            spacing: 2

            Repeater {
              model: root.settingsTabChoices

              delegate: Rectangle {
                id: tabButton

                required property var modelData

                readonly property bool selected: root.settingsTab
                  === tabButton.modelData.value
                readonly property bool hovered: tabMouse.containsMouse

                width: (tabRow.width - tabRow.spacing
                  * (root.settingsTabChoices.length - 1))
                  / root.settingsTabChoices.length
                height: tabRow.height
                radius: Style.space(8)
                color: tabButton.selected ? root.activeFill
                  : tabButton.hovered
                    ? Commons.Util.alpha(root.ink, 0.06) : "transparent"

                Text {
                  anchors.centerIn: parent
                  textFormat: Text.PlainText
                  text: tabButton.modelData.label
                  color: tabButton.selected ? root.accent
                    : tabButton.hovered ? root.ink : root.mutedInk
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                  font.bold: true
                  font.letterSpacing: 1.0
                  renderType: Text.NativeRendering
                }

                MouseArea {
                  id: tabMouse

                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: root.switchSettingsTab(tabButton.modelData.value)
                }
              }
            }
          }
        }

        // --- Loading / empty state --------------------------------------

        Column {
          visible: !root.loaded && !root.settingsOpen
          width: parent.width
          spacing: Style.space(8)

          Item { width: 1; height: Style.space(10) }

          Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            textFormat: Text.PlainText
            text: root.unavailable ? "\udb80\udd90" : "\udb80\udd95"
            color: root.mutedInk
            opacity: 0.7
            font.family: root.fontFamily
            font.pixelSize: Style.font.displayLarge
            renderType: Text.NativeRendering
          }

          Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            textFormat: Text.PlainText
            text: root.unavailable
              ? "The sky is unavailable" : "Consulting the sky\u2026"
            color: root.ink
            font.family: root.fontFamily
            font.pixelSize: Style.font.title
            font.bold: true
            renderType: Text.NativeRendering
          }

          Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            textFormat: Text.PlainText
            text: root.unavailable
              ? "Check your connection and try again."
              : "One moment."
            color: root.mutedInk
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
            renderType: Text.NativeRendering
          }

          Rectangle {
            visible: root.unavailable
            width: Style.space(104)
            height: Style.space(28)
            radius: Style.space(8)
            anchors.horizontalCenter: parent.horizontalCenter
            color: retryArea.containsMouse ? root.activeFill : root.tileFill
            border.width: 1
            border.color: root.tileBorder

            Text {
              anchors.centerIn: parent
              textFormat: Text.PlainText
              text: "Try again"
              color: retryArea.containsMouse ? root.accent : root.ink
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
              renderType: Text.NativeRendering
            }

            MouseArea {
              id: retryArea

              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: root.retryAll()
            }
          }

          Item { width: 1; height: Style.space(4) }
        }

        // --- Hero -------------------------------------------------------

        Item {
          id: hero

          visible: root.loaded && !root.settingsOpen
          clip: true
          width: parent.width
          readonly property bool ringStyle: root.tempGlobeEnabled
            && root.tempGlobeStyle === "rings"
          readonly property real coreHeight: ringStyle
            ? 2 * tempGlobe.planetRadius + Style.space(10)
            : 0
          readonly property real ringHeight: ringStyle
            ? 2 * tempGlobe.ringRadius
              * Math.abs(Math.sin(root.tempGlobeTilt * Math.PI / 180))
              + Style.space(10)
            : 0

          implicitHeight: Math.max(heroRow.implicitHeight + Style.space(30),
            Style.space(150), root.eclipseActive ? Style.space(204) : 0,
            coreHeight, ringHeight)

          Behavior on implicitHeight {
            NumberAnimation {
              duration: Style.duration(450)
              easing.type: Easing.InOutQuad
            }
          }

          // Solar eclipse corona around the icon and temperature.
          Item {
            id: eclipseCorona

            anchors.centerIn: parent
            width: Math.min(hero.width - Style.space(30),
              Style.space(190))
            height: width
            visible: opacity > 0.001
            opacity: root.eclipseActive ? root.eclipse.corona : 0

            readonly property color glowColor: root.eclipse
              && root.eclipse.type === "annular" ? "#ffcf7a" : root.ink

            Behavior on opacity {
              NumberAnimation {
                duration: Style.duration(700)
                easing.type: Easing.InOutQuad
              }
            }

            // Soft outer glow.
            Rectangle {
              anchors.centerIn: parent
              width: parent.width
              height: width
              radius: width / 2
              color: "transparent"
              border.width: Style.space(10)
              border.color: eclipseCorona.glowColor
              opacity: 0.08
            }

            // Main ring.
            Rectangle {
              anchors.centerIn: parent
              width: parent.width
              height: width
              radius: width / 2
              color: "transparent"
              border.width: 2
              border.color: eclipseCorona.glowColor
              opacity: 0.85
            }

            // Inner ring.
            Rectangle {
              anchors.centerIn: parent
              width: parent.width * 0.82
              height: width
              radius: width / 2
              color: "transparent"
              border.width: 1
              border.color: eclipseCorona.glowColor
              opacity: 0.30
            }

            // Slow corona rays.
            Item {
              anchors.fill: parent

              Repeater {
                model: 18

                Item {
                  width: parent.width
                  height: parent.height
                  rotation: index * 20

                  Rectangle {
                    width: 1.5
                    height: 10 + (index % 3) * 5
                    x: (parent.width - width) / 2
                    y: 2
                    radius: width / 2
                    color: eclipseCorona.glowColor
                    opacity: 0.22
                  }
                }
              }

              NumberAnimation on rotation {
                from: 0
                to: 360
                duration: 90000
                loops: Animation.Infinite
                running: root.eclipseActive
              }
            }
          }

          Canvas {
            id: tempGlobe

            readonly property real baseRadius: Math.max(
              heroRow.width, heroRow.height) / 2 + Style.space(3)
            readonly property real ringRadius: baseRadius * 1.62
              * root.tempGlobeSize / 100
            readonly property real planetRadius: baseRadius * 1.10
              * Math.max(0.5, Math.min(1.5, root.tempGlobeCore / 100))
            readonly property real circleRadius:
              root.tempGlobeStyle === "rings"
                ? Math.max(ringRadius, planetRadius)
                : baseRadius * root.tempGlobeSize / 100
            readonly property var ringBands: [
              { inner: 0.690, outer: 0.737, alpha: 0.55 },
              { inner: 0.758, outer: 0.858, alpha: 1.00 },
              { inner: 0.892, outer: 0.958, alpha: 0.80 },
              { inner: 0.976, outer: 0.990, alpha: 0.60 }
            ]

            x: heroRow.x + (heroRow.width - width) / 2
            y: heroRow.y + (heroRow.height - height) / 2
            width: circleRadius * 2
            height: width
            visible: root.tempGlobeEnabled
            property var sphere: []
            property real angle: 0

            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()

            function buildSphere() {
              const count = Math.max(60, Math.min(600,
                Math.round(root.tempGlobeCount)))
              const points = []

              if (root.tempGlobeStyle === "rings") {
                const sparkleCount = Math.max(16, Math.round(count * 0.25))
                const weights = []
                var total = 0
                for (var b = 0; b < ringBands.length; b++) {
                  const width = ringBands[b].outer - ringBands[b].inner
                  weights.push(width)
                  total += width
                }
                for (var j = 0; j < sparkleCount; j++) {
                  var pick = Math.random() * total
                  var band = ringBands[0]
                  for (var k = 0; k < ringBands.length; k++) {
                    pick -= weights[k]
                    if (pick <= 0) {
                      band = ringBands[k]
                      break
                    }
                  }
                  const fraction = band.inner + Math.random()
                    * (band.outer - band.inner)
                  const theta = Math.random() * Math.PI * 2
                  points.push({
                    x: Math.cos(theta) * fraction,
                    y: (Math.random() - 0.5) * 0.006,
                    z: Math.sin(theta) * fraction,
                    accent: Math.random() * 100
                      < Math.round(root.tempGlobeAccent)
                  })
                }
              } else {
                const golden = Math.PI * (3 - Math.sqrt(5))
                for (var i = 0; i < count; i++) {
                  const y = 1 - (i / Math.max(1, count - 1)) * 2
                  const ring = Math.sqrt(Math.max(0, 1 - y * y))
                  const theta = i * golden
                  points.push({
                    x: Math.cos(theta) * ring,
                    y: y,
                    z: Math.sin(theta) * ring,
                    accent: (i * 37) % 100
                      < Math.round(root.tempGlobeAccent)
                  })
                }
              }

              sphere = points
              requestPaint()
            }

            function projectPoints(cx, cy, radius, cosA, sinA,
              sinT, cosT) {
              const out = []
              for (var i = 0; i < sphere.length; i++) {
                const p = sphere[i]
                const x1 = p.x * cosA - p.z * sinA
                const z1 = p.x * sinA + p.z * cosA
                out.push({
                  x: cx + x1 * radius,
                  y: cy + (p.y * cosT - z1 * sinT) * radius,
                  z: p.y * sinT + z1 * cosT,
                  accent: p.accent
                })
              }
              return out
            }

            function paintBands(ctx, cx, cy, radius, ratio, strength,
              color, startAngle, endAngle, factor) {
              ctx.save()
              ctx.translate(cx, cy)
              ctx.scale(1, ratio)
              ctx.strokeStyle = color
              ctx.lineWidth = Math.max(1, radius * 0.008)
              for (var b = 0; b < ringBands.length; b++) {
                const band = ringBands[b]
                const steps = Math.max(2, Math.ceil(
                  (band.outer - band.inner) / 0.004))
                ctx.globalAlpha = strength * band.alpha * factor * 0.060
                for (var st = 0; st < steps; st++) {
                  const f = band.inner + (band.outer - band.inner)
                    * (st / (steps - 1))
                  ctx.beginPath()
                  ctx.arc(0, 0, radius * f, startAngle, endAngle, false)
                  ctx.stroke()
                }
              }
              ctx.restore()
            }

            function paintSparkles(ctx, points, radius, strength,
              color, front) {
              const dotBase = Math.max(0.8, radius * 0.010)
              for (var i = 0; i < points.length; i++) {
                const point = points[i]
                if ((point.z >= 0) !== front) continue
                const depth = (point.z + 1) / 2
                const alpha = strength * (0.15 + 0.85 * depth * depth)
                const dot = dotBase * (0.55 + 0.85 * depth)
                ctx.fillStyle = point.accent ? root.accent : color
                ctx.globalAlpha = alpha
                ctx.beginPath()
                ctx.arc(point.x, point.y, dot, 0, Math.PI * 2)
                ctx.fill()
              }
            }

            Component.onCompleted: buildSphere()

            Timer {
              interval: 33
              repeat: true
              running: root.tempGlobeEnabled && root.opened
                && !root.settingsOpen && Style.duration(1) > 0
                && root.tempGlobeSpeed > 0
              onTriggered: {
                tempGlobe.angle = (tempGlobe.angle
                  + root.tempGlobeSpeed * interval / 1000) % 360
                tempGlobe.requestPaint()
              }
            }

            onPaint: {
              const ctx = getContext("2d")
              ctx.reset()
              ctx.clearRect(0, 0, width, height)
              if (!visible || sphere.length === 0) return
              const cx = width / 2
              const cy = height / 2
              const radius = Math.min(width, height) / 2 - 1
              if (radius < 4) return
              const radians = angle * Math.PI / 180
              const sinA = Math.sin(radians)
              const cosA = Math.cos(radians)
              const strength = root.tempGlobeOpacity / 100
              const baseColor = root.tempGlobeHue < 0 ? root.ink
                : Qt.hsla(root.tempGlobeHue / 360, 0.72, 0.64, 1)

              if (root.tempGlobeStyle === "rings") {
                // Negative tilt puts the near half of the rings below the
                // planet, like Saturn viewed from above its equator.
                const tilt = -root.tempGlobeTilt * Math.PI / 180
                const sinT = Math.sin(tilt)
                const cosT = Math.cos(tilt)
                const ratio = Math.max(0.04, Math.abs(sinT))
                const ringR = Math.max(4, tempGlobe.ringRadius - 1)
                const planetR = Math.max(8, Math.min(
                  tempGlobe.planetRadius, radius))
                const ringStrength = root.tempGlobeRingOpacity / 100
                const coreStrength = root.tempGlobeCoreOpacity / 100
                const borderStrength = root.tempGlobeBorderOpacity / 100

                const projected = projectPoints(cx, cy, ringR,
                  cosA, sinA, sinT, cosT)

                // Far half of the rings behind the planet.
                paintBands(ctx, cx, cy, ringR, ratio, ringStrength,
                  baseColor, Math.PI, Math.PI * 2, 0.6)
                paintSparkles(ctx, projected, ringR, ringStrength,
                  baseColor, false)

                // Soft planet body so the rings have something to orbit.
                const glow = ctx.createRadialGradient(
                  cx - planetR * 0.32, cy - planetR * 0.36,
                  planetR * 0.08, cx, cy, planetR)
                glow.addColorStop(0,
                  Commons.Util.alpha(baseColor, coreStrength * 0.18))
                glow.addColorStop(0.62,
                  Commons.Util.alpha(baseColor, coreStrength * 0.06))
                glow.addColorStop(1,
                  Commons.Util.alpha(baseColor, 0))
                ctx.globalAlpha = 1
                ctx.fillStyle = glow
                ctx.beginPath()
                ctx.arc(cx, cy, planetR, 0, Math.PI * 2)
                ctx.fill()

                ctx.globalAlpha = borderStrength * 0.32
                ctx.strokeStyle = baseColor
                ctx.lineWidth = Math.max(0.8, radius * 0.008)
                ctx.beginPath()
                ctx.arc(cx, cy, planetR - 0.4, 0, Math.PI * 2)
                ctx.stroke()

                // The near half lives in tempRingsFront, above the hero
                // content, so it can cross in front of the icon and temp.
                ctx.globalAlpha = 1
                return
              }

              const tilt = root.tempGlobeTilt * Math.PI / 180
              const sinT = Math.sin(tilt)
              const cosT = Math.cos(tilt)
              const dotBase = Math.max(0.8, radius * 0.020)

              // Soft body so the dots read as a sphere.
              ctx.globalAlpha = strength * 0.07
              ctx.fillStyle = baseColor
              ctx.beginPath()
              ctx.arc(cx, cy, radius, 0, Math.PI * 2)
              ctx.fill()

              const projected = []
              for (var i = 0; i < sphere.length; i++) {
                const p = sphere[i]
                const x1 = p.x * cosA - p.z * sinA
                const z1 = p.x * sinA + p.z * cosA
                projected.push({
                  x: cx + x1 * radius,
                  y: cy + (p.y * cosT - z1 * sinT) * radius,
                  z: p.y * sinT + z1 * cosT,
                  accent: p.accent
                })
              }

              for (var pass = 0; pass < 2; pass++) {
                for (var j = 0; j < projected.length; j++) {
                  const point = projected[j]
                  const front = point.z >= 0
                  if ((pass === 1) !== front) continue
                  const depth = (point.z + 1) / 2
                  const alpha = strength * (0.08 + 0.92 * depth * depth)
                  const dot = dotBase * (0.55 + 0.85 * depth)
                  ctx.fillStyle = point.accent ? root.accent : baseColor
                  ctx.globalAlpha = alpha * 0.16
                  ctx.beginPath()
                  ctx.arc(point.x, point.y, dot * 2.2, 0, Math.PI * 2)
                  ctx.fill()
                  ctx.globalAlpha = alpha
                  ctx.beginPath()
                  ctx.arc(point.x, point.y, dot, 0, Math.PI * 2)
                  ctx.fill()
                }
              }

              if (root.tempGlobeRing > 0) {
                const stroke = Math.max(0.7, radius * 0.009)
                ctx.globalAlpha = strength
                  * (root.tempGlobeRing / 100) * 0.9
                ctx.strokeStyle = baseColor
                ctx.lineWidth = stroke
                ctx.beginPath()
                ctx.arc(cx, cy, radius - stroke / 2, 0, Math.PI * 2)
                ctx.stroke()
              }
              ctx.globalAlpha = 1
            }
          }

          Connections {
            target: root

            function onTempGlobeCountChanged() {
              tempGlobe.buildSphere()
            }

            function onTempGlobeOpacityChanged() {
              tempGlobe.requestPaint()
            }

            function onTempGlobeTiltChanged() {
              tempGlobe.requestPaint()
            }

            function onTempGlobeRingChanged() {
              tempGlobe.requestPaint()
            }

            function onTempGlobeStyleChanged() {
              tempGlobe.buildSphere()
            }


            function onTempGlobeHueChanged() {
              tempGlobe.requestPaint()
            }

            function onTempGlobeAccentChanged() {
              tempGlobe.buildSphere()
            }
          }

          Row {
            id: heroRow

            anchors.centerIn: parent
            spacing: Style.space(14)

            Text {
              textFormat: Text.PlainText
              text: root.currentIcon
              color: root.ink
              font.family: root.fontFamily
              font.pixelSize: Math.round(Style.font.displayLarge * 2.1)
              renderType: Text.NativeRendering
            }

            Column {
              id: heroTextColumn

              width: Math.max(tempText.implicitWidth, feelsText.implicitWidth)
              spacing: Style.space(1)

              Item {
                id: tempWrap

                width: parent.width
                height: tempText.implicitHeight

                Text {
                  id: tempText

                  width: parent.width
                  horizontalAlignment: Text.AlignHCenter
                  textFormat: Text.PlainText
                  text: root.currentTemp
                  color: root.ink
                  font.family: root.fontFamily
                  font.pixelSize: Math.round(Style.font.displayLarge * 2.2)
                  font.bold: true
                  renderType: Text.NativeRendering

                  layer.enabled: true
                  layer.smooth: true
                  layer.effect: MultiEffect {
                    shadowEnabled: true
                    shadowColor: root.tempGlow
                    shadowOpacity: 0.5
                    shadowBlur: 0.5
                    shadowHorizontalOffset: 0
                    shadowVerticalOffset: 0
                    autoPaddingEnabled: true
                    blurMax: 32
                  }
                }

                Canvas {
                  id: tempRingsFront

                  x: tempGlobe.x - heroRow.x - heroTextColumn.x - tempWrap.x
                  y: tempGlobe.y - heroRow.y - heroTextColumn.y - tempWrap.y
                  width: tempGlobe.width
                  height: tempGlobe.height
                  visible: root.tempGlobeEnabled
                    && root.tempGlobeStyle === "rings"
                  property real angle: tempGlobe.angle
                  property var sphere: tempGlobe.sphere

                  onAngleChanged: requestPaint()
                  onSphereChanged: requestPaint()
                  onWidthChanged: requestPaint()
                  onHeightChanged: requestPaint()

                  onPaint: {
                    const ctx = getContext("2d")
                    ctx.reset()
                    ctx.clearRect(0, 0, width, height)
                    if (!visible || sphere.length === 0) return
                    const cx = width / 2
                    const cy = height / 2
                    const ringR = Math.max(4, tempGlobe.ringRadius - 1)
                    if (ringR < 4) return
                    const radians = angle * Math.PI / 180
                    const sinA = Math.sin(radians)
                    const cosA = Math.cos(radians)
                    const tilt = -root.tempGlobeTilt * Math.PI / 180
                    const sinT = Math.sin(tilt)
                    const cosT = Math.cos(tilt)
                    const ratio = Math.max(0.04, Math.abs(sinT))
                    const strength = root.tempGlobeRingOpacity / 100 * 0.85
                    const baseColor = root.tempGlobeHue < 0 ? root.ink
                      : Qt.hsla(root.tempGlobeHue / 360, 0.72, 0.64, 1)
                    const projected = tempGlobe.projectPoints(cx, cy, ringR,
                      cosA, sinA, sinT, cosT)
                    tempGlobe.paintBands(ctx, cx, cy, ringR, ratio, strength,
                      baseColor, 0, Math.PI, 1)
                    tempGlobe.paintSparkles(ctx, projected, ringR, strength,
                      baseColor, true)
                    ctx.globalAlpha = 1
                  }
                }
              }

              Text {
                id: feelsText

                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                textFormat: Text.PlainText
                text: root.feelsText
                color: root.mutedInk
                font.family: root.fontFamily
                font.pixelSize: Style.font.bodySmall
                font.bold: true
                font.letterSpacing: 1.1
                renderType: Text.NativeRendering
              }
            }
          }


        }

        // --- Snark ------------------------------------------------------

        Item {
          visible: root.loaded && !root.settingsOpen
          width: parent.width
          implicitHeight: commentText.implicitHeight

          Text {
            id: commentText

            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            lineHeight: 1.15
            textFormat: Text.PlainText
            text: root.shownComment
            opacity: 0
            color: commentArea.containsMouse ? root.accent : root.ink
            font.family: root.fontFamily
            font.pixelSize: Style.font.subtitle
            renderType: Text.NativeRendering

            Behavior on color {
              ColorAnimation { duration: Style.duration(120) }
            }
          }

          // Rerolls fade the old line out, swap at zero opacity, then fade the
          // new one in. The first line skips the fade-out so it does not blink.
          SequentialAnimation {
            id: commentFade

            NumberAnimation {
              target: commentText
              property: "opacity"
              to: 0
              duration: Style.duration(90)
              easing.type: Easing.InQuad
            }
            ScriptAction { script: root.shownComment = root.comment }
            NumberAnimation {
              target: commentText
              property: "opacity"
              to: 1
              duration: Style.duration(180)
              easing.type: Easing.OutQuad
            }
          }

          NumberAnimation {
            id: commentFadeIn

            target: commentText
            property: "opacity"
            from: 0
            to: 1
            duration: Style.duration(220)
            easing.type: Easing.OutQuad
          }

          // The animations live inside the popup's content component, so the
          // comment change has to be watched from here rather than on root.
          // On (re)creation, sync to whatever line already exists and fade it
          // in, since a change may have landed before this component existed.
          Component.onCompleted: {
            root.shownComment = root.comment
            if (!root.commentFadeEnabled) {
              commentText.opacity = 1
            } else if (root.shownComment !== "") {
              commentFadeIn.restart()
            }
          }

          Connections {
            target: root

            function onCommentChanged() {
              if (root.comment === root.shownComment) return
              if (!root.commentFadeEnabled) {
                commentFade.stop()
                commentFadeIn.stop()
                root.shownComment = root.comment
                commentText.opacity = 1
                return
              }
              if (root.shownComment === "") {
                root.shownComment = root.comment
                commentFadeIn.restart()
              } else {
                commentFade.restart()
              }
            }

            function onCommentFadeEnabledChanged() {
              if (root.commentFadeEnabled) return
              commentFade.stop()
              commentFadeIn.stop()
              root.shownComment = root.comment
              commentText.opacity = 1
            }
          }

          MouseArea {
            id: commentArea

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.rerollComment()
          }
        }

        // --- Current details -------------------------------------------

        Row {
          id: statsRow

          visible: root.loaded && !root.settingsOpen
          width: parent.width
          spacing: Style.space(8)

          StatTile {
            width: (statsRow.width - statsRow.spacing * 2) / 3
            value: root.humidityText
            label: "Humidity"
          }

          StatTile {
            width: (statsRow.width - statsRow.spacing * 2) / 3
            value: root.windText
            label: "Wind"
          }

          StatTile {
            width: (statsRow.width - statsRow.spacing * 2) / 3
            value: root.rainText
            label: "Rain"
          }
        }

        // --- Forecast ---------------------------------------------------

        Column {
          visible: root.loaded && !root.settingsOpen && root.forecast.length > 0
          width: parent.width
          spacing: Style.space(6)

          Text {
            textFormat: Text.PlainText
            text: "3-DAY FORECAST"
            color: root.mutedInk
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            font.bold: true
            font.letterSpacing: 1.2
            renderType: Text.NativeRendering
          }

          Row {
            id: forecastRow

            width: parent.width
            spacing: Style.space(8)

            Repeater {
              model: root.forecast

              delegate: Rectangle {
                id: forecastCard

                required property var modelData
                required property int index

                width: (forecastRow.width - forecastRow.spacing * 2) / 3
                height: Style.space(116)
                radius: Style.space(12)
                color: forecastCard.index === 0
                  ? root.activeFill : root.tileFill
                border.width: 1
                border.color: forecastCard.index === 0
                  ? root.accent : root.tileBorder

                Column {
                  anchors.fill: parent
                  anchors.margins: Style.space(8)
                  spacing: Style.space(2)

                  Text {
                    width: parent.width
                    textFormat: Text.PlainText
                    text: root.dayLabel(forecastCard.modelData.date,
                      forecastCard.index)
                    color: root.mutedInk
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                    font.bold: true
                    font.letterSpacing: 1.0
                    elide: Text.ElideRight
                    renderType: Text.NativeRendering
                  }

                  Text {
                    textFormat: Text.PlainText
                    text: forecastCard.modelData.icon
                    color: forecastCard.index === 0
                      ? root.accent : root.ink
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.display
                    renderType: Text.NativeRendering
                  }

                  Text {
                    width: parent.width
                    textFormat: Text.PlainText
                    text: root.rangeText(forecastCard.modelData)
                    color: root.ink
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.body
                    font.bold: true
                    elide: Text.ElideRight
                    renderType: Text.NativeRendering
                  }

                  Text {
                    width: parent.width
                    textFormat: Text.PlainText
                    text: Math.round(forecastCard.modelData.rain) + "% rain"
                    color: root.faintInk
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                    elide: Text.ElideRight
                    renderType: Text.NativeRendering
                  }
                }
              }
            }
          }
        }

        // --- Footer -----------------------------------------------------

        Row {
          visible: root.loaded && !root.settingsOpen
          width: parent.width
          height: Style.space(24)
          spacing: Style.space(6)

          Text {
            id: updatedLabel

            anchors.verticalCenter: parent.verticalCenter
            textFormat: Text.PlainText
            text: root.updatedText
            color: root.faintInk
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            renderType: Text.NativeRendering
          }

          Item {
            width: Math.max(0, parent.width - updatedLabel.implicitWidth
              - refreshButton.width - parent.spacing)
            height: 1
          }

          CursorSurface {
            id: refreshButton

            width: Style.space(22)
            height: width
            anchors.verticalCenter: parent.verticalCenter
            hasCursor: refreshArea.containsMouse
            foreground: root.ink
            accent: root.accent

            Text {
              anchors.centerIn: parent
              textFormat: Text.PlainText
              text: "\udb81\udc50"
              color: refreshButton.hasCursor ? root.ink : root.mutedInk
              font.family: root.fontFamily
              font.pixelSize: Style.font.icon
              renderType: Text.NativeRendering
            }

            MouseArea {
              id: refreshArea

              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: root.refresh(true)
            }
          }
        }

        // --- Settings ---------------------------------------------------

        // --- Settings viewport ------------------------------------------

        Item {
          id: settingsViewport

          visible: root.settingsOpen
          width: parent.width

          readonly property real cardCap: Math.min(Style.space(640),
            panel.availableCardHeight > 1
              ? panel.availableCardHeight : Style.space(640))
          readonly property real availableHeight: Math.max(Style.space(180),
            cardCap - panel.verticalContentInset - panelHeader.implicitHeight
              - tabBar.height - contentColumn.spacing * 2)

          height: Math.min(settingsBody.implicitHeight, availableHeight)

          property Item pendingRevealCard: null

          function revealTempGlobe() {
            if (!root.tempGlobeEnabled) return
            Qt.callLater(function() { settingsScrollToBottom.restart() })
          }

          function revealCard(item) {
            settingsViewport.pendingRevealCard = item
            cardRevealTimer.restart()
          }

          Timer {
            id: cardRevealTimer

            interval: Style.duration(240)
            onTriggered: {
              const item = settingsViewport.pendingRevealCard
              if (!item || !root.settingsOpen) return
              settingsViewport.pendingRevealCard = null
              const cardY = item.mapToItem(settingsBody, 0, 0).y
              const maxY = Math.max(0,
                settingsFlick.contentHeight - settingsFlick.height)
              const headerBottom = cardY + Style.space(52)
              const viewTop = settingsFlick.contentY
              const viewBottom = viewTop + settingsFlick.height
              if (cardY < viewTop || headerBottom > viewBottom) {
                settingsScrollCard.to = Math.max(0,
                  Math.min(maxY, cardY - Style.space(6)))
                settingsScrollCard.restart()
              }
            }
          }

          Flickable {
            id: settingsFlick

            anchors.fill: parent
            contentWidth: width
            contentHeight: settingsBody.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            interactive: contentHeight > height
            flickDeceleration: 1800
            maximumFlickVelocity: 2600

            function clampScroll() {
              const maxY = Math.max(0, contentHeight - height)
              if (contentY > maxY) contentY = maxY
            }

            onContentHeightChanged: clampScroll()
            onHeightChanged: clampScroll()

        Column {
          id: settingsBody

          width: settingsFlick.width
          spacing: Style.space(10)

          // --- General --------------------------------------------------

          Column {
            visible: root.settingsTab === "general"
            width: parent.width
            spacing: Style.space(8)

            SettingsCard {
              title: "Personality"
              cardKey: "personality"
              subtitle: "How much attitude the comment gets."
              glyph: "\uf007"

              Column {
                width: parent.width
                spacing: Style.space(2)

                Repeater {
                  model: root.toneChoices

                  delegate: Rectangle {
                    id: toneRow

                    required property var modelData

                    readonly property bool selected: root.activeTone
                      === String(toneRow.modelData.value)
                    readonly property bool hovered: toneMouse.containsMouse

                    width: parent.width
                    height: Style.space(40)
                    radius: Style.space(8)
                    color: toneRow.selected ? root.activeFill
                      : toneRow.hovered
                        ? Commons.Util.alpha(root.ink, 0.06) : "transparent"

                    Column {
                      anchors.left: parent.left
                      anchors.right: checkText.left
                      anchors.verticalCenter: parent.verticalCenter
                      anchors.leftMargin: Style.space(8)
                      anchors.rightMargin: Style.space(6)
                      spacing: Style.space(1)

                      Text {
                        width: parent.width
                        textFormat: Text.PlainText
                        text: toneRow.modelData.label
                        color: toneRow.selected ? root.accent : root.ink
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.bodySmall
                        font.bold: true
                        elide: Text.ElideRight
                        renderType: Text.NativeRendering
                      }

                      Text {
                        width: parent.width
                        textFormat: Text.PlainText
                        text: toneRow.modelData.description
                        color: root.mutedInk
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.caption
                        elide: Text.ElideRight
                        renderType: Text.NativeRendering
                      }
                    }

                    Text {
                      id: checkText

                      visible: toneRow.selected
                      anchors.right: parent.right
                      anchors.rightMargin: Style.space(8)
                      anchors.verticalCenter: parent.verticalCenter
                      textFormat: Text.PlainText
                      text: "\uf00c"
                      color: root.accent
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.caption
                      renderType: Text.NativeRendering
                    }

                    MouseArea {
                      id: toneMouse

                      anchors.fill: parent
                      hoverEnabled: true
                      cursorShape: Qt.PointingHandCursor
                      onClicked: root.setTone(toneRow.modelData.value)
                    }
                  }
                }
              }
            }

            SettingsCard {
              title: "Units"
              cardKey: "units"
              subtitle: "Temperature scale in the popup."
              glyph: "\uf2c7"
              iconTint: "#7bed9f"

              Rectangle {
                width: parent.width
                height: Style.space(30)
                radius: Style.space(9)
                color: Commons.Util.alpha(root.ink, 0.035)
                border.width: 1
                border.color: root.tileBorder

                Row {
                  id: unitRow

                  anchors.fill: parent
                  anchors.margins: 2
                  spacing: 2

                  Repeater {
                    model: root.unitChoices

                    delegate: Rectangle {
                      id: unitPill

                      required property var modelData

                      readonly property bool selected: root.unitOverride
                        === String(unitPill.modelData.value)
                      readonly property bool hovered: unitMouse.containsMouse

                      width: (unitRow.width - unitRow.spacing * 2) / 3
                      height: unitRow.height
                      radius: Style.space(7)
                      color: unitPill.selected ? root.activeFill
                        : unitPill.hovered
                          ? Commons.Util.alpha(root.ink, 0.06) : "transparent"

                      Text {
                        anchors.centerIn: parent
                        textFormat: Text.PlainText
                        text: unitPill.modelData.label
                        color: unitPill.selected ? root.accent
                          : unitPill.hovered ? root.ink : root.mutedInk
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.caption
                        font.bold: true
                        renderType: Text.NativeRendering
                      }

                      MouseArea {
                        id: unitMouse

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                          root.unitOverride = String(unitPill.modelData.value)
                          root.writeSettings()
                        }
                      }
                    }
                  }
                }
              }
            }
          }

          // --- Appearance ------------------------------------------------

          Column {
            visible: root.settingsTab === "appearance"
            width: parent.width
            spacing: Style.space(8)

            SettingsCard {
              title: "Gradient"
              cardKey: "gradient"
              subtitle: "The wash behind the popup."
              glyph: "\uf043"

              Rectangle {
                width: parent.width
                height: Style.space(30)
                radius: Style.space(9)
                color: Commons.Util.alpha(root.ink, 0.035)
                border.width: 1
                border.color: root.tileBorder

                Row {
                  id: gradientModeRow

                  anchors.fill: parent
                  anchors.margins: 2
                  spacing: 2

                  Repeater {
                    model: [
                      { value: "weather", label: "WEATHER" },
                      { value: "custom", label: "CUSTOM" }
                    ]

                    delegate: Rectangle {
                      id: gradientModePill

                      required property var modelData

                      readonly property bool selected: root.gradientMode
                        === String(gradientModePill.modelData.value)
                      readonly property bool hovered: gradientModeMouse.containsMouse

                      width: (gradientModeRow.width - gradientModeRow.spacing) / 2
                      height: gradientModeRow.height
                      radius: Style.space(7)
                      color: gradientModePill.selected ? root.activeFill
                        : gradientModePill.hovered
                          ? Commons.Util.alpha(root.ink, 0.06) : "transparent"

                      Text {
                        anchors.centerIn: parent
                        textFormat: Text.PlainText
                        text: gradientModePill.modelData.label
                        color: gradientModePill.selected ? root.accent
                          : gradientModePill.hovered ? root.ink : root.mutedInk
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.caption
                        font.bold: true
                        font.letterSpacing: 1.0
                        renderType: Text.NativeRendering
                      }

                      MouseArea {
                        id: gradientModeMouse

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.setGradientMode(
                          gradientModePill.modelData.value)
                      }
                    }
                  }
                }
              }

              Column {
                visible: root.gradientMode === "custom"
                width: parent.width
                spacing: Style.space(8)

                Item {
                  width: parent.width
                  height: Style.space(14)

                  Text {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    textFormat: Text.PlainText
                    text: "HUE"
                    color: root.mutedInk
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                    font.bold: true
                    font.letterSpacing: 1.1
                    renderType: Text.NativeRendering
                  }

                  ValueBadge {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: Math.round(root.gradientHue) + "\u00b0"
                  }
                }

                Rectangle {
                  id: hueStrip

                  width: parent.width
                  height: Style.space(8)
                  radius: height / 2
                  gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: "#ff4d4d" }
                    GradientStop { position: 1 / 6; color: "#ffd24d" }
                    GradientStop { position: 2 / 6; color: "#6bff6b" }
                    GradientStop { position: 3 / 6; color: "#4dd8ff" }
                    GradientStop { position: 4 / 6; color: "#4d7dff" }
                    GradientStop { position: 5 / 6; color: "#d24dff" }
                    GradientStop { position: 1.0; color: "#ff4d4d" }
                  }

                  Rectangle {
                    width: Style.space(12)
                    height: width
                    radius: width / 2
                    y: (parent.height - height) / 2
                    x: Math.max(0, Math.min(parent.width - width,
                      (root.gradientHue / 360) * parent.width - width / 2))
                    color: Qt.hsla(root.gradientHue / 360, 1, 0.55, 1)
                    border.width: 2
                    border.color: root.ink
                  }

                  MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor

                    function update(mouseX) {
                      const fraction = Math.max(0, Math.min(1, mouseX / width))
                      root.setGradientHue(fraction * 360)
                    }

                    onPressed: function(mouse) {
                      root.gradientDragging = true
                      update(mouse.x)
                    }
                    onPositionChanged: function(mouse) {
                      if (pressed) update(mouse.x)
                    }
                    onReleased: {
                      root.gradientDragging = false
                      root.writeSettings()
                    }
                  }
                }

                Row {
                  width: parent.width
                  spacing: Style.space(6)

                  Repeater {
                    model: [0, 45, 120, 200, 280, 325]

                    delegate: Rectangle {
                      required property var modelData

                      readonly property bool selected: root.hueNear(
                        root.gradientHue, modelData)

                      width: Style.space(16)
                      height: width
                      radius: width / 2
                      color: Qt.hsla(modelData / 360, 0.8, 0.62, 1)
                      border.width: selected ? 2 : 1
                      border.color: selected ? root.ink
                        : Commons.Util.alpha(root.ink, 0.20)

                      MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                          root.setGradientHue(modelData)
                          root.writeSettings()
                        }
                      }
                    }
                  }
                }

                Item {
                  width: parent.width
                  height: Style.space(14)

                  Text {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    textFormat: Text.PlainText
                    text: "VIVIDNESS"
                    color: root.mutedInk
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                    font.bold: true
                    font.letterSpacing: 1.1
                    renderType: Text.NativeRendering
                  }

                  ValueBadge {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: Math.round(root.gradientSat) + "%"
                  }
                }

                Rectangle {
                  id: vividStrip

                  width: parent.width
                  height: Style.space(8)
                  radius: height / 2
                  gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop {
                      position: 0.0
                      color: Qt.hsla(root.gradientHue / 360, 0, 0.6, 1)
                    }
                    GradientStop {
                      position: 1.0
                      color: Qt.hsla(root.gradientHue / 360, 1, 0.6, 1)
                    }
                  }

                  Rectangle {
                    width: Style.space(12)
                    height: width
                    radius: width / 2
                    y: (parent.height - height) / 2
                    x: Math.max(0, Math.min(parent.width - width,
                      (root.gradientSat / 100) * parent.width - width / 2))
                    color: Qt.hsla(root.gradientHue / 360,
                      Math.max(0.001, root.gradientSat / 100), 0.6, 1)
                    border.width: 2
                    border.color: root.ink
                  }

                  MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor

                    function update(mouseX) {
                      const fraction = Math.max(0, Math.min(1, mouseX / width))
                      root.setGradientSat(fraction * 100)
                    }

                    onPressed: function(mouse) {
                      root.gradientDragging = true
                      update(mouse.x)
                    }
                    onPositionChanged: function(mouse) {
                      if (pressed) update(mouse.x)
                    }
                    onReleased: {
                      root.gradientDragging = false
                      root.writeSettings()
                    }
                  }
                }

                Item {
                  width: parent.width
                  height: Style.space(14)

                  Text {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    textFormat: Text.PlainText
                    text: "BRIGHTNESS"
                    color: root.mutedInk
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                    font.bold: true
                    font.letterSpacing: 1.1
                    renderType: Text.NativeRendering
                  }

                  ValueBadge {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: Math.round(root.heroLight * 100) + "%"
                  }
                }

                Rectangle {
                  id: lightStrip

                  width: parent.width
                  height: Style.space(8)
                  radius: height / 2
                  gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop {
                      position: 0.0
                      color: Qt.hsla(root.gradientHue / 360,
                        Math.max(0.001, root.gradientSat / 100), 0.2, 1)
                    }
                    GradientStop {
                      position: 0.5
                      color: Qt.hsla(root.gradientHue / 360,
                        Math.max(0.001, root.gradientSat / 100), 0.5, 1)
                    }
                    GradientStop {
                      position: 1.0
                      color: Qt.hsla(root.gradientHue / 360,
                        Math.max(0.001, root.gradientSat / 100), 0.75, 1)
                    }
                  }

                  Rectangle {
                    width: Style.space(12)
                    height: width
                    radius: width / 2
                    y: (parent.height - height) / 2
                    x: Math.max(0, Math.min(parent.width - width,
                      Math.max(0, Math.min(1, (root.heroLight * 100 - 20) / 55))
                        * parent.width - width / 2))
                    color: Qt.hsla(root.gradientHue / 360,
                      Math.max(0.001, root.gradientSat / 100),
                      root.heroLight, 1)
                    border.width: 2
                    border.color: root.ink
                  }

                  MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor

                    function update(mouseX) {
                      const fraction = Math.max(0, Math.min(1, mouseX / width))
                      root.setGradientLight(20 + fraction * 55)
                    }

                    onPressed: function(mouse) {
                      root.gradientDragging = true
                      update(mouse.x)
                    }
                    onPositionChanged: function(mouse) {
                      if (pressed) update(mouse.x)
                    }
                    onReleased: {
                      root.gradientDragging = false
                      root.writeSettings()
                    }
                  }
                }
              }

              Text {
                visible: root.gradientMode === "weather"
                width: parent.width
                wrapMode: Text.WordWrap
                textFormat: Text.PlainText
                text: "Follows the theme accent and the current weather."
                color: root.mutedInk
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                renderType: Text.NativeRendering
              }
            }

            SettingsCard {
              title: "Effects"
              cardKey: "effects"
              subtitle: "Particles and motion."
              glyph: "\uf005"
              iconTint: "#ffcf7a"

              SettingsSwitchRow {
                label: "Weather effects"
                description: "Snow, rain, storms, fog, and night stars."
                checked: root.effectsEnabled
                onToggled: root.setEffectsEnabled(!root.effectsEnabled)
              }

              SettingsDivider { }

              SettingsSwitchRow {
                label: "Comment fade"
                description: "Fade the line out and in when it changes."
                checked: root.commentFadeEnabled
                onToggled: root.setCommentFadeEnabled(!root.commentFadeEnabled)
              }

              SettingsDivider { }

              SettingsSwitchRow {
                label: "Temperature motion"
                description: "A dotted globe or Saturn rings behind the hero."
                checked: root.tempGlobeEnabled
                onToggled: {
                  const enabled = !root.tempGlobeEnabled
                  root.setTempGlobeEnabled(enabled)
                  if (enabled) settingsViewport.revealTempGlobe()
                }
              }

              Item {
                id: tempGlobeOptions

                width: parent.width
                height: root.tempGlobeEnabled
                  ? tempGlobeOptionsBody.implicitHeight : 0
                visible: height > 0.01
                clip: true
                opacity: root.tempGlobeEnabled ? 1 : 0

                Behavior on height {
                  NumberAnimation {
                    duration: Style.duration(260)
                    easing.type: Easing.OutCubic
                  }
                }
                Behavior on opacity {
                  NumberAnimation { duration: Style.duration(200) }
                }

                Column {
                  id: tempGlobeOptionsBody

                  width: parent.width
                  spacing: Style.space(6)

                  Item {
                    width: parent.width
                    height: Style.space(14)

                    Text {
                      anchors.left: parent.left
                      anchors.verticalCenter: parent.verticalCenter
                      textFormat: Text.PlainText
                      text: "STYLE"
                      color: root.mutedInk
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.caption
                      font.bold: true
                      font.letterSpacing: 1.1
                      renderType: Text.NativeRendering
                    }

                    ValueBadge {
                      anchors.right: parent.right
                      anchors.verticalCenter: parent.verticalCenter
                      text: root.tempGlobeStyle === "rings" ? "RINGS" : "GLOBE"
                    }
                  }

                  Row {
                    width: parent.width
                    spacing: Style.space(4)

                    Repeater {
                      model: [
                        { value: "globe", label: "GLOBE" },
                        { value: "rings", label: "RINGS" }
                      ]

                      delegate: Rectangle {
                        id: globeStyleButton

                        required property var modelData

                        readonly property bool selected: root.tempGlobeStyle
                          === globeStyleButton.modelData.value

                        width: (parent.width - parent.spacing) / 2
                        height: Style.space(26)
                        radius: Style.space(8)
                        color: globeStyleButton.selected
                          ? root.activeFill : root.tileFill
                        border.width: 1
                        border.color: globeStyleButton.selected
                          ? root.accent : root.tileBorder

                        Text {
                          anchors.centerIn: parent
                          textFormat: Text.PlainText
                          text: globeStyleButton.modelData.label
                          color: globeStyleButton.selected
                            ? root.accent : root.mutedInk
                          font.family: root.fontFamily
                          font.pixelSize: Style.font.caption
                          font.bold: true
                          font.letterSpacing: 1.0
                          renderType: Text.NativeRendering
                        }

                        MouseArea {
                          anchors.fill: parent
                          cursorShape: Qt.PointingHandCursor
                          onClicked: root.setTempGlobeStyle(
                            globeStyleButton.modelData.value)
                        }
                      }
                    }
                  }

                  SettingsSliderRow {
                    label: "Dots"
                    value: root.tempGlobeCount
                    minimum: 60
                    maximum: 600
                    valueText: Math.round(root.tempGlobeCount).toString()
                    onMoved: function(value) { root.setTempGlobeCount(value) }
                    onCommitted: root.writeSettings()
                  }

                  SettingsSliderRow {
                    label: "Speed"
                    value: root.tempGlobeSpeed
                    minimum: 0
                    maximum: 90
                    valueText: Math.round(root.tempGlobeSpeed) + "\u00b0/s"
                    onMoved: function(value) { root.setTempGlobeSpeed(value) }
                    onCommitted: root.writeSettings()
                  }

                  SettingsSliderRow {
                    label: root.tempGlobeStyle === "rings"
                      ? "Ring size" : "Size"
                    value: root.tempGlobeSize
                    minimum: 75
                    maximum: 180
                    valueText: Math.round(root.tempGlobeSize) + "%"
                    onMoved: function(value) { root.setTempGlobeSize(value) }
                    onCommitted: root.writeSettings()
                  }

                  SettingsSliderRow {
                    label: "Tilt"
                    value: root.tempGlobeTilt
                    minimum: -60
                    maximum: 60
                    valueText: Math.round(root.tempGlobeTilt) + "\u00b0"
                    onMoved: function(value) { root.setTempGlobeTilt(value) }
                    onCommitted: root.writeSettings()
                  }

                  SettingsSliderRow {
                    visible: root.tempGlobeStyle === "rings"
                    label: "Planet size"
                    value: root.tempGlobeCore
                    minimum: 50
                    maximum: 150
                    valueText: Math.round(root.tempGlobeCore) + "%"
                    onMoved: function(value) { root.setTempGlobeCore(value) }
                    onCommitted: root.writeSettings()
                  }

                  SettingsSliderRow {
                    visible: root.tempGlobeStyle === "globe"
                    label: "Limb ring"
                    value: root.tempGlobeRing
                    minimum: 0
                    maximum: 100
                    valueText: Math.round(root.tempGlobeRing) + "%"
                    onMoved: function(value) { root.setTempGlobeRing(value) }
                    onCommitted: root.writeSettings()
                  }

                  Item {
                    width: parent.width
                    height: Style.space(14)

                    Text {
                      anchors.left: parent.left
                      anchors.verticalCenter: parent.verticalCenter
                      textFormat: Text.PlainText
                      text: "DOT COLOUR"
                      color: root.mutedInk
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.caption
                      font.bold: true
                      font.letterSpacing: 1.1
                      renderType: Text.NativeRendering
                    }

                    ValueBadge {
                      anchors.right: parent.right
                      anchors.verticalCenter: parent.verticalCenter
                      text: root.tempGlobeHue < 0
                        ? "AUTO" : Math.round(root.tempGlobeHue) + "\u00b0"
                    }
                  }

                  Rectangle {
                    visible: root.tempGlobeHue >= 0
                    width: parent.width
                    height: Style.space(8)
                    radius: height / 2
                    gradient: Gradient {
                      orientation: Gradient.Horizontal
                      GradientStop { position: 0.0; color: "#ff4d4d" }
                      GradientStop { position: 1 / 6; color: "#ffd24d" }
                      GradientStop { position: 2 / 6; color: "#6bff6b" }
                      GradientStop { position: 3 / 6; color: "#4dd8ff" }
                      GradientStop { position: 4 / 6; color: "#4d7dff" }
                      GradientStop { position: 5 / 6; color: "#d24dff" }
                      GradientStop { position: 1.0; color: "#ff4d4d" }
                    }

                    Rectangle {
                      width: Style.space(12)
                      height: width
                      radius: width / 2
                      y: (parent.height - height) / 2
                      x: Math.max(0, Math.min(parent.width - width,
                        (root.tempGlobeHue / 360) * parent.width - width / 2))
                      color: Qt.hsla(root.tempGlobeHue / 360, 0.72, 0.64, 1)
                      border.width: 2
                      border.color: root.ink
                    }

                    MouseArea {
                      anchors.fill: parent
                      cursorShape: Qt.PointingHandCursor

                      function update(mouseX) {
                        const fraction = Math.max(0,
                          Math.min(1, mouseX / width))
                        root.setTempGlobeHue(fraction * 360)
                      }

                      onPressed: function(mouse) { update(mouse.x) }
                      onPositionChanged: function(mouse) {
                        if (pressed) update(mouse.x)
                      }
                      onReleased: root.writeSettings()
                    }
                  }

                  Row {
                    width: parent.width
                    spacing: Style.space(6)

                    Rectangle {
                      id: globeAutoSwatch

                      readonly property bool selected: root.tempGlobeHue < 0

                      width: Style.space(34)
                      height: Style.space(16)
                      radius: height / 2
                      color: globeAutoSwatch.selected
                        ? root.activeFill : "transparent"
                      border.width: 1
                      border.color: globeAutoSwatch.selected ? root.ink
                        : Commons.Util.alpha(root.ink, 0.20)

                      Text {
                        anchors.centerIn: parent
                        textFormat: Text.PlainText
                        text: "AUTO"
                        color: root.ink
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.caption
                        font.bold: true
                        renderType: Text.NativeRendering
                      }

                      MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                          root.setTempGlobeHue(-1)
                          root.writeSettings()
                        }
                      }
                    }

                    Repeater {
                      model: [0, 45, 120, 200, 280, 325]

                      delegate: Rectangle {
                        required property var modelData

                        readonly property bool selected: root.tempGlobeHue >= 0
                          && root.hueNear(root.tempGlobeHue, modelData)

                        width: Style.space(16)
                        height: width
                        radius: width / 2
                        color: Qt.hsla(modelData / 360, 0.72, 0.64, 1)
                        border.width: selected ? 2 : 1
                        border.color: selected ? root.ink
                          : Commons.Util.alpha(root.ink, 0.20)

                        MouseArea {
                          anchors.fill: parent
                          cursorShape: Qt.PointingHandCursor
                          onClicked: {
                            root.setTempGlobeHue(modelData)
                            root.writeSettings()
                          }
                        }
                      }
                    }
                  }

                  SettingsSliderRow {
                    label: "Accent mix"
                    value: root.tempGlobeAccent
                    minimum: 0
                    maximum: 100
                    valueText: Math.round(root.tempGlobeAccent) + "%"
                    onMoved: function(value) { root.setTempGlobeAccent(value) }
                    onCommitted: root.writeSettings()
                  }

                  SettingsSliderRow {
                    visible: root.tempGlobeStyle === "globe"
                    label: "Opacity"
                    value: root.tempGlobeOpacity
                    minimum: 10
                    maximum: 80
                    valueText: Math.round(root.tempGlobeOpacity) + "%"
                    onMoved: function(value) { root.setTempGlobeOpacity(value) }
                    onCommitted: root.writeSettings()
                  }

                  SettingsSliderRow {
                    visible: root.tempGlobeStyle === "rings"
                    label: "Ring opacity"
                    value: root.tempGlobeRingOpacity
                    minimum: 0
                    maximum: 100
                    valueText: Math.round(root.tempGlobeRingOpacity) + "%"
                    onMoved: function(value) {
                      root.setTempGlobeRingOpacity(value)
                    }
                    onCommitted: root.writeSettings()
                  }

                  SettingsSliderRow {
                    visible: root.tempGlobeStyle === "rings"
                    label: "Globe opacity"
                    value: root.tempGlobeCoreOpacity
                    minimum: 0
                    maximum: 100
                    valueText: Math.round(root.tempGlobeCoreOpacity) + "%"
                    onMoved: function(value) {
                      root.setTempGlobeCoreOpacity(value)
                    }
                    onCommitted: root.writeSettings()
                  }

                  SettingsSliderRow {
                    visible: root.tempGlobeStyle === "rings"
                    label: "Globe border"
                    value: root.tempGlobeBorderOpacity
                    minimum: 0
                    maximum: 100
                    valueText: Math.round(root.tempGlobeBorderOpacity) + "%"
                    onMoved: function(value) {
                      root.setTempGlobeBorderOpacity(value)
                    }
                    onCommitted: root.writeSettings()
                  }
                }
              }
            }
          }

          // --- Location -------------------------------------------------

          Column {
            visible: root.settingsTab === "location"
            width: parent.width
            spacing: Style.space(8)

            SettingsCard {
              title: "Current location"
              cardKey: "current-location"
              subtitle: "Where the weather comes from."
              glyph: "\uf041"
              iconTint: "#ff8f8f"

              Rectangle {
                width: parent.width
                height: currentColumn.implicitHeight + Style.space(14)
                radius: Style.space(10)
                color: root.tileFill
                border.width: 1
                border.color: root.tileBorder

                Column {
                  id: currentColumn

                  anchors.left: parent.left
                  anchors.right: parent.right
                  anchors.verticalCenter: parent.verticalCenter
                  anchors.leftMargin: Style.space(8)
                  anchors.rightMargin: Style.space(8)
                  spacing: Style.space(2)

                  Text {
                    width: parent.width
                    textFormat: Text.PlainText
                    text: root.displayLocation
                    color: root.ink
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.bodySmall
                    font.bold: true
                    elide: Text.ElideRight
                    renderType: Text.NativeRendering
                  }

                  Text {
                    visible: root.locationCoords !== ""
                    width: parent.width
                    textFormat: Text.PlainText
                    text: root.locationCoords
                    color: root.mutedInk
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                    elide: Text.ElideRight
                    renderType: Text.NativeRendering
                  }

                  Text {
                    width: parent.width
                    textFormat: Text.PlainText
                    text: root.locationSourceLabel.toUpperCase()
                    color: root.faintInk
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                    font.bold: true
                    font.letterSpacing: 1.0
                    elide: Text.ElideRight
                    renderType: Text.NativeRendering
                  }
                }
              }

              Row {
                width: parent.width
                spacing: Style.space(6)

                Rectangle {
                  id: detectButton

                  readonly property bool hovered: detectMouse.containsMouse

                  width: root.hasCustomLocation
                    ? (parent.width - parent.spacing) / 2 : parent.width
                  height: Style.space(28)
                  radius: Style.space(8)
                  color: detectButton.hovered
                    ? root.activeFill : root.tileFill
                  border.width: 1
                  border.color: detectButton.hovered
                    ? root.accent : root.tileBorder

                  Text {
                    anchors.centerIn: parent
                    textFormat: Text.PlainText
                    text: root.locationBusy && root.detectMode === "custom"
                      ? "Detecting\u2026" : "Auto-detect"
                    color: detectButton.hovered ? root.accent : root.mutedInk
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                    font.bold: true
                    renderType: Text.NativeRendering
                  }

                  MouseArea {
                    id: detectMouse

                    anchors.fill: parent
                    enabled: !root.locationBusy
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.autoDetectCustomLocation()
                  }
                }

                Rectangle {
                  id: omarchyButton

                  visible: root.hasCustomLocation
                  readonly property bool hovered: omarchyMouse.containsMouse

                  width: (parent.width - parent.spacing) / 2
                  height: Style.space(28)
                  radius: Style.space(8)
                  color: omarchyButton.hovered
                    ? root.activeFill : root.tileFill
                  border.width: 1
                  border.color: omarchyButton.hovered
                    ? root.accent : root.tileBorder

                  Text {
                    anchors.centerIn: parent
                    width: parent.width - Style.space(12)
                    horizontalAlignment: Text.AlignHCenter
                    textFormat: Text.PlainText
                    text: "Use Omarchy location"
                    color: omarchyButton.hovered
                      ? root.accent : root.mutedInk
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                    font.bold: true
                    elide: Text.ElideRight
                    renderType: Text.NativeRendering
                  }

                  MouseArea {
                    id: omarchyMouse

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.clearCustomLocation()
                  }
                }
              }

              Rectangle {
                id: saveFavouriteButton

                readonly property bool saved: root.currentIsFavourite
                readonly property bool hovered: saveFavouriteMouse.containsMouse

                width: parent.width
                height: Style.space(28)
                radius: Style.space(8)
                color: saveFavouriteButton.hovered
                  ? root.activeFill : root.tileFill
                border.width: 1
                border.color: saveFavouriteButton.hovered
                  ? root.accent : root.tileBorder

                Text {
                  anchors.centerIn: parent
                  textFormat: Text.PlainText
                  text: saveFavouriteButton.saved
                    ? "\uf00c  Saved location" : "Save this location"
                  color: saveFavouriteButton.saved
                    ? root.faintInk
                    : saveFavouriteButton.hovered ? root.accent : root.mutedInk
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                  font.bold: true
                  renderType: Text.NativeRendering
                }

                MouseArea {
                  id: saveFavouriteMouse

                  anchors.fill: parent
                  enabled: root.hasCoordinates && !saveFavouriteButton.saved
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: root.addFavourite()
                }
              }
            }

            SettingsCard {
              visible: root.favouritesVisible
              title: "Saved locations"
              cardKey: "saved-locations"
              subtitle: "Tap a place to switch."
              glyph: "\uf005"
              iconTint: "#ffcf7a"

              Flickable {
                id: favouritesFlick

                width: parent.width
                height: Math.min(contentHeight, Style.space(116))
                contentHeight: favouritesColumn.implicitHeight
                contentWidth: width
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                interactive: contentHeight > height

                Rectangle {
                  id: favouritesTrack

                  visible: favouritesFlick.contentHeight > favouritesFlick.height
                  z: 1
                  x: favouritesFlick.width - width - 1
                  y: favouritesFlick.contentY
                  width: 2
                  height: favouritesFlick.height
                  radius: 1
                  color: Commons.Util.alpha(root.ink, 0.10)

                  Rectangle {
                    width: parent.width
                    radius: 1
                    color: Commons.Util.alpha(root.ink, 0.38)
                    height: Math.max(12, favouritesTrack.height
                      * favouritesFlick.height / favouritesFlick.contentHeight)
                    y: (favouritesTrack.height - height)
                      * Math.max(0, Math.min(1, favouritesFlick.contentY
                        / Math.max(1, favouritesFlick.contentHeight
                          - favouritesFlick.height)))
                  }
                }

                Column {
                  id: favouritesColumn

                  width: favouritesFlick.width
                  spacing: Style.space(4)

                  Repeater {
                    model: root.favourites

                    delegate: Rectangle {
                      id: favouriteRow

                      required property var modelData

                      readonly property bool active: root.isActiveFavourite(
                        favouriteRow.modelData)
                      readonly property bool hovered: favouriteMouse.containsMouse

                      width: favouritesColumn.width
                      height: Style.space(36)
                      radius: Style.space(8)
                      color: favouriteRow.active
                        ? root.activeFill
                        : favouriteRow.hovered
                          ? Commons.Util.alpha(root.ink, 0.07) : "transparent"

                      Column {
                        anchors.left: parent.left
                        anchors.right: removeFavouriteButton.left
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: Style.space(8)
                        anchors.rightMargin: Style.space(6)
                        spacing: Style.space(1)

                        Text {
                          width: parent.width
                          textFormat: Text.PlainText
                          text: favouriteRow.modelData.name
                          color: favouriteRow.active ? root.accent : root.ink
                          font.family: root.fontFamily
                          font.pixelSize: Style.font.bodySmall
                          font.bold: true
                          elide: Text.ElideRight
                          renderType: Text.NativeRendering
                        }

                        Text {
                          width: parent.width
                          textFormat: Text.PlainText
                          text: Number(favouriteRow.modelData.latitude).toFixed(2)
                            + ", "
                            + Number(favouriteRow.modelData.longitude).toFixed(2)
                          color: root.mutedInk
                          font.family: root.fontFamily
                          font.pixelSize: Style.font.caption
                          elide: Text.ElideRight
                          renderType: Text.NativeRendering
                        }
                      }

                      Item {
                        id: removeFavouriteButton

                        width: Style.space(26)
                        height: parent.height
                        anchors.right: parent.right

                        Text {
                          anchors.centerIn: parent
                          textFormat: Text.PlainText
                          text: "\uf00d"
                          color: removeFavouriteMouse.containsMouse
                            ? root.accent : root.mutedInk
                          font.family: root.fontFamily
                          font.pixelSize: Style.font.caption
                          renderType: Text.NativeRendering
                        }

                        MouseArea {
                          id: removeFavouriteMouse

                          anchors.fill: parent
                          hoverEnabled: true
                          cursorShape: Qt.PointingHandCursor
                          onClicked: root.removeFavourite(
                            favouriteRow.modelData)
                        }
                      }

                      MouseArea {
                        id: favouriteMouse

                        anchors.fill: parent
                        anchors.rightMargin: removeFavouriteButton.width
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.applyFavourite(favouriteRow.modelData)
                      }
                    }
                  }
                }
              }
            }

            SettingsCard {
              title: "Search"
              cardKey: "search"
              subtitle: "Find a place by name."
              glyph: "\uf002"
              iconTint: "#8fd3ff"

              Row {
                width: parent.width
                spacing: Style.space(6)

                TextField {
                  id: searchField

                  width: parent.width - searchButton.width - parent.spacing
                  height: Style.space(30)
                  foreground: root.ink
                  accent: root.accent
                  placeholderText: "Search for a city\u2026"
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.bodySmall
                  verticalPadding: Style.space(6)
                  onAccepted: root.searchLocation(text)
                  Keys.onEscapePressed: focus = false
                }

                Rectangle {
                  id: searchButton

                  readonly property bool hovered: searchMouse.containsMouse

                  width: Style.space(60)
                  height: Style.space(30)
                  radius: Style.space(8)
                  color: searchButton.hovered
                    ? root.activeFill : root.tileFill
                  border.width: 1
                  border.color: searchButton.hovered
                    ? root.accent : root.tileBorder

                  Text {
                    anchors.centerIn: parent
                    textFormat: Text.PlainText
                    text: "SEARCH"
                    color: searchButton.hovered ? root.accent : root.mutedInk
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                    font.bold: true
                    font.letterSpacing: 1.0
                    renderType: Text.NativeRendering
                  }

                  MouseArea {
                    id: searchMouse

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.searchLocation(searchField.text)
                  }
                }
              }

              Text {
                visible: root.locationError !== "" || root.locationBusy
                width: parent.width
                wrapMode: Text.WordWrap
                textFormat: Text.PlainText
                text: root.locationBusy
                  ? (root.detectMode === "custom"
                    ? "Detecting\u2026" : "Searching\u2026")
                  : root.locationError
                color: root.locationBusy ? root.mutedInk : root.accent
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                renderType: Text.NativeRendering
              }

              Column {
                visible: root.geocodeResults.length > 0
                width: parent.width
                spacing: Style.space(4)

                Repeater {
                  model: root.geocodeResults

                  delegate: Rectangle {
                    id: resultRow

                    required property var modelData

                    readonly property bool hovered: resultMouse.containsMouse

                    width: parent.width
                    height: Style.space(36)
                    radius: Style.space(8)
                    color: resultRow.hovered
                      ? Commons.Util.alpha(root.ink, 0.07) : root.tileFill
                    border.width: 1
                    border.color: resultRow.hovered
                      ? root.accent : root.tileBorder

                    Column {
                      anchors.left: parent.left
                      anchors.right: parent.right
                      anchors.verticalCenter: parent.verticalCenter
                      anchors.leftMargin: Style.space(10)
                      anchors.rightMargin: Style.space(10)
                      spacing: Style.space(1)

                      Text {
                        width: parent.width
                        textFormat: Text.PlainText
                        text: resultRow.modelData.name
                        color: resultRow.hovered ? root.accent : root.ink
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.bodySmall
                        font.bold: true
                        elide: Text.ElideRight
                        renderType: Text.NativeRendering
                      }

                      Text {
                        visible: String(resultRow.modelData.detail || "") !== ""
                        width: parent.width
                        textFormat: Text.PlainText
                        text: String(resultRow.modelData.detail || "")
                        color: root.mutedInk
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.caption
                        elide: Text.ElideRight
                        renderType: Text.NativeRendering
                      }
                    }

                    MouseArea {
                      id: resultMouse

                      anchors.fill: parent
                      hoverEnabled: true
                      cursorShape: Qt.PointingHandCursor
                      onClicked: root.chooseGeocodeResult(resultRow.modelData)
                    }
                  }
                }
              }
            }
          }

          Item { width: 1; height: Style.space(8) }
        }

            WheelHandler {
              acceptedDevices: PointerDevice.Mouse

              onWheel: function(event) {
                const maxY = Math.max(0,
                  settingsFlick.contentHeight - settingsFlick.height)
                const delta = event.pixelDelta.y !== 0
                  ? event.pixelDelta.y : event.angleDelta.y * 0.6
                settingsWheelScroll.to = Math.max(0,
                  Math.min(maxY, settingsFlick.contentY - delta))
                settingsWheelScroll.restart()
                event.accepted = true
              }
            }
          }

          NumberAnimation {
            id: settingsWheelScroll

            target: settingsFlick
            property: "contentY"
            duration: Style.duration(180)
            easing.type: Easing.OutCubic
          }

          NumberAnimation {
            id: settingsScrollTop

            target: settingsFlick
            property: "contentY"
            to: 0
            duration: Style.duration(220)
            easing.type: Easing.OutCubic
          }

          NumberAnimation {
            id: settingsScrollToBottom

            target: settingsFlick
            property: "contentY"
            to: Math.max(0, settingsFlick.contentHeight - settingsFlick.height)
            duration: Style.duration(300)
            easing.type: Easing.OutCubic
          }

          NumberAnimation {
            id: settingsScrollCard

            target: settingsFlick
            property: "contentY"
            duration: Style.duration(220)
            easing.type: Easing.OutCubic
          }

          Connections {
            target: root

            function onSettingsTabChanged() {
              settingsScrollTop.restart()
            }

          }

          Rectangle {
            id: settingsScrollTrack

            visible: settingsFlick.contentHeight > settingsFlick.height + 1
            z: 2
            x: settingsViewport.width - width - 1
            y: 0
            width: 2
            height: settingsViewport.height
            radius: 1
            color: Commons.Util.alpha(root.ink, 0.08)

            Rectangle {
              width: parent.width
              radius: 1
              color: Commons.Util.alpha(root.ink, 0.35)
              height: Math.max(12, settingsScrollTrack.height
                * settingsFlick.height / settingsFlick.contentHeight)
              y: (settingsScrollTrack.height - height)
                * Math.max(0, Math.min(1, settingsFlick.contentY
                  / Math.max(1, settingsFlick.contentHeight
                    - settingsFlick.height)))
            }
          }
        }
      }
    }
  }

  // --- Settings components -----------------------------------------------

  component SettingsIcon: Rectangle {
    id: icon

    property string glyph: ""
    property color tint: root.accent

    width: Style.space(26)
    height: width
    radius: Style.space(8)
    color: Commons.Util.alpha(tint, 0.14)
    border.width: 1
    border.color: Commons.Util.alpha(tint, 0.24)

    Text {
      anchors.centerIn: parent
      textFormat: Text.PlainText
      text: icon.glyph
      color: icon.tint
      font.family: root.fontFamily
      font.pixelSize: Style.font.body
      renderType: Text.NativeRendering
    }
  }

  component SettingsCard: Rectangle {
    id: card

    property string title: ""
    property string subtitle: ""
    property string glyph: ""
    property color iconTint: root.accent
    property string cardKey: ""
    readonly property bool expanded: cardKey !== ""
      && root.activeSettingsCard === cardKey
    default property alias content: body.data

    width: parent ? parent.width : implicitWidth
    implicitHeight: cardLayout.implicitHeight + Style.space(20)
    radius: Style.space(16)
    color: Commons.Util.alpha(root.ink, 0.045)
    border.width: 1
    border.color: card.expanded
      ? Commons.Util.alpha(root.ink, 0.16)
      : Commons.Util.alpha(root.ink, 0.08)

    Behavior on border.color {
      ColorAnimation { duration: Style.duration(160) }
    }

    Column {
      id: cardLayout

      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: parent.top
      anchors.margins: Style.space(10)
      spacing: 0

      Item {
        id: headerArea

        width: parent.width
        implicitHeight: cardHeader.implicitHeight

        Row {
          id: cardHeader

          width: parent.width
          spacing: Style.space(8)

          SettingsIcon { glyph: card.glyph; tint: card.iconTint }

          Column {
            width: parent.width - Style.space(34) - chevron.width
              - Style.space(8)
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(1)

            Text {
              width: parent.width
              textFormat: Text.PlainText
              text: card.title
              color: root.ink
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
              font.bold: true
              elide: Text.ElideRight
              renderType: Text.NativeRendering
            }

            Text {
              visible: card.subtitle !== ""
              width: parent.width
              textFormat: Text.PlainText
              text: card.subtitle
              color: root.mutedInk
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              elide: Text.ElideRight
              renderType: Text.NativeRendering
            }
          }

          Text {
            id: chevron

            anchors.verticalCenter: parent.verticalCenter
            textFormat: Text.PlainText
            text: "\uf054"
            color: headerMouse.containsMouse ? root.ink : root.mutedInk
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            rotation: card.expanded ? 90 : 0
            renderType: Text.NativeRendering

            Behavior on rotation {
              NumberAnimation {
                duration: Style.duration(180)
                easing.type: Easing.OutCubic
              }
            }
          }
        }

        MouseArea {
          id: headerMouse

          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor

          onClicked: {
            if (card.cardKey === "") return
            if (card.expanded) {
              root.activeSettingsCard = ""
              return
            }
            root.activeSettingsCard = card.cardKey
            settingsViewport.revealCard(card)
          }
        }
      }

      Item {
        id: bodyReveal

        width: parent.width
        height: card.expanded
          ? body.implicitHeight + Style.space(8) : 0
        visible: height > 0.5
        clip: true
        opacity: card.expanded ? 1 : 0

        Behavior on height {
          NumberAnimation {
            duration: Style.duration(220)
            easing.type: Easing.OutCubic
          }
        }
        Behavior on opacity {
          NumberAnimation { duration: Style.duration(160) }
        }

        Column {
          id: body

          y: Style.space(8)
          width: parent.width
          spacing: Style.space(8)
        }
      }
    }
  }

  component SettingsSwitchRow: Item {
    id: row

    property string label: ""
    property string description: ""
    property bool checked: false

    signal toggled()

    width: parent ? parent.width : implicitWidth
    implicitHeight: Math.max(textBlock.implicitHeight, toggle.implicitHeight)
      + Style.space(8)

    Column {
      id: textBlock

      anchors.left: parent.left
      anchors.right: toggle.left
      anchors.verticalCenter: parent.verticalCenter
      anchors.rightMargin: Style.space(8)
      spacing: Style.space(1)

      Text {
        width: parent.width
        textFormat: Text.PlainText
        text: row.label
        color: root.ink
        font.family: root.fontFamily
        font.pixelSize: Style.font.bodySmall
        font.bold: true
        elide: Text.ElideRight
        renderType: Text.NativeRendering
      }

      Text {
        visible: row.description !== ""
        width: parent.width
        textFormat: Text.PlainText
        text: row.description
        color: root.mutedInk
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        wrapMode: Text.WordWrap
        renderType: Text.NativeRendering
      }
    }

    ToggleSwitch {
      id: toggle

      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      checked: row.checked
      interactive: false
      foreground: root.ink
      accent: root.accent
    }

    MouseArea {
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: row.toggled()
    }
  }

  component SettingsSliderRow: Item {
    id: row

    property string label: ""
    property real value: 0
    property real minimum: 0
    property real maximum: 100
    property string valueText: ""

    signal moved(real value)
    signal committed()

    width: parent ? parent.width : implicitWidth
    implicitHeight: labelRow.height + Style.space(8) + track.height
      + Style.space(2)

    readonly property real fraction: Math.max(0, Math.min(1,
      (value - minimum) / Math.max(0.001, maximum - minimum)))

    Item {
      id: labelRow

      width: parent.width
      height: Style.space(14)

      Text {
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        textFormat: Text.PlainText
        text: row.label.toUpperCase()
        color: root.mutedInk
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        font.bold: true
        font.letterSpacing: 1.1
        renderType: Text.NativeRendering
      }

      ValueBadge {
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        text: row.valueText
      }
    }

    Rectangle {
      id: track

      y: labelRow.height + Style.space(8)
      width: parent.width
      height: Style.space(6)
      radius: height / 2
      color: Commons.Util.alpha(root.ink, 0.10)

      Rectangle {
        width: track.width * row.fraction
        height: parent.height
        radius: height / 2
        color: Commons.Util.alpha(root.accent, 0.75)
      }

      Rectangle {
        width: Style.space(12)
        height: width
        radius: width / 2
        y: (parent.height - height) / 2
        x: Math.max(0, Math.min(parent.width - width,
          row.fraction * parent.width - width / 2))
        color: root.accent
        border.width: 2
        border.color: root.ink
      }

      MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor

        function update(mouseX) {
          const fraction = Math.max(0, Math.min(1, mouseX / width))
          row.moved(row.minimum + fraction * (row.maximum - row.minimum))
        }

        onPressed: function(mouse) {
          update(mouse.x)
        }
        onPositionChanged: function(mouse) {
          if (pressed) update(mouse.x)
        }
        onReleased: row.committed()
      }
    }
  }

  component SettingsDivider: Rectangle {
    width: parent ? parent.width : implicitWidth
    height: 1
    color: Commons.Util.alpha(root.ink, 0.07)
  }

  component ValueBadge: Rectangle {
    id: badge

    property string text: ""

    width: valueText.implicitWidth + Style.space(12)
    height: Style.space(18)
    radius: Style.space(6)
    color: Commons.Util.alpha(root.accent, 0.10)
    border.width: 1
    border.color: Commons.Util.alpha(root.accent, 0.16)

    Text {
      id: valueText

      anchors.centerIn: parent
      textFormat: Text.PlainText
      text: badge.text
      color: root.accent
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
      font.bold: true
      renderType: Text.NativeRendering
    }
  }

  // --- Stat tile ---------------------------------------------------------

  component StatTile: Rectangle {
    id: tile

    property string value: ""
    property string label: ""

    height: Style.space(56)
    radius: Style.space(12)
    color: root.tileFill
    border.width: 1
    border.color: root.tileBorder

    Column {
      anchors.centerIn: parent
      spacing: Style.space(2)

      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        textFormat: Text.PlainText
        text: tile.value
        color: root.ink
        font.family: root.fontFamily
        font.pixelSize: Style.font.heading
        font.bold: true
        renderType: Text.NativeRendering
      }

      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        textFormat: Text.PlainText
        text: tile.label.toUpperCase()
        color: root.mutedInk
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        font.bold: true
        font.letterSpacing: 1.0
        renderType: Text.NativeRendering
      }
    }
  }

  // --- Acquisition -------------------------------------------------------

  Process {
    id: weatherProc

    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        root.weatherOutput = text
        root.weatherCollected = true
        root.finishWeather()
      }
    }

    onExited: function(exitCode) {
      root.weatherExitOk = exitCode === 0
      root.weatherExited = true
      root.finishWeather()
    }
  }

  Process {
    id: geocodeProc

    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        root.geocodeOutput = text
        const location = Model.parseGeocode(text)
        if (location) {
          root.locationState = location
          if (!root.hasCustomLocation) root.refresh(true)
          return
        }
        if (!root.hasCustomLocation) root.unavailable = true
      }
    }
  }

  Process {
    id: detectProc

    command: ["curl", "-fsS", "--max-time", "4",
      "https://geo.omarchy.org/"]

    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.detectOutput = text
    }

    onExited: function(exitCode) {
      const custom = root.detectMode === "custom"
      root.detectMode = "fallback"
      if (custom) root.locationBusy = false
      const location = Model.parseLocation(root.detectOutput)
      if (exitCode !== 0 || location.latitude === null
          || location.longitude === null) {
        if (custom) root.locationError = "Couldn't detect your location."
        else if (!root.hasCustomLocation) root.unavailable = true
        return
      }
      if (custom) {
        root.setCustomLocation(location.name, location.latitude,
          location.longitude, "auto")
        return
      }
      root.detectedLocation = location
      if (!root.hasCustomLocation) root.refresh(true)
    }
  }

  Process {
    id: searchProc

    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.searchOutput = text
    }

    onExited: function(exitCode) {
      root.locationBusy = false
      if (exitCode !== 0) {
        root.geocodeResults = []
        root.locationError = "Search failed. Check your connection."
        return
      }
      const results = Model.parseGeocodeResults(root.searchOutput)
      root.geocodeResults = results
      root.locationError = results.length === 0 ? "No places found." : ""
    }
  }

  Process {
    id: cacheWrite
  }

  Process {
    id: settingsWrite

    onExited: {
      if (root.settingsPending) {
        root.settingsPending = false
        root.writeSettings()
      }
    }
  }

  Timer {
    id: retryTimer

    interval: 20000
    onTriggered: root.refresh(true)
  }

  Timer {
    id: pendingRefresh

    interval: 0
    onTriggered: root.refresh(false)
  }

  Timer {
    interval: root.refreshMinutes * 60 * 1000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refresh(false)
  }

  Timer {
    interval: 60000
    running: root.opened
    repeat: true
    onTriggered: root.nowMs = Date.now()
  }

  Timer {
    interval: 1500
    running: true
    onTriggered: locationFile.reload()
  }

  FileView {
    id: locationFile

    path: Quickshell.env("HOME")
      + "/.local/state/omarchy/settings/weather.json"
    watchChanges: true
    printErrors: false

    onFileChanged: {
      root.locationAttempted = false
      reload()
    }
    onLoaded: root.applyLocation(text())
    onLoadFailed: root.applyLocation("")
  }

  FileView {
    id: cacheFile

    path: root.cachePath
    printErrors: false
    onLoaded: root.applyCached(text())
  }

  FileView {
    id: settingsFile

    path: root.settingsPath
    watchChanges: true
    printErrors: false

    onFileChanged: reload()
    onLoaded: root.applySettings(text())
    onLoadFailed: root.clearOverrides()
  }

  Component.onCompleted: {
    root.nowMs = Date.now()
    locationFile.reload()
    cacheFile.reload()
    settingsFile.reload()
  }

  onOpenedChanged: {
    if (root.opened) {
      root.nowMs = Date.now()
      root.refresh(true)
      if (root.loaded) root.rerollComment()
    } else {
      root.closeSettings()
    }
  }
}
