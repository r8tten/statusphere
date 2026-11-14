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
  property string locationSource: ""
  property bool settingsOpen: false
  property string settingsTab: "general"
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
  property bool gradientSeeded: false
  property bool gradientDragging: false
  property bool effectsEnabled: true

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
  readonly property string effectKind: root.holidayEffect !== ""
    ? root.holidayEffect
    : root.currentWeather
      ? Model.effectForCode(root.currentWeather.code, root.currentWeather.isDay)
      : ""
  readonly property bool effectsActive: root.effectsEnabled && root.opened
    && root.loaded && !root.unavailable && !root.settingsOpen
    && root.effectKind !== ""
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
      return root.locationSource === "auto" ? "Auto-detected" : "Custom location"
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
  readonly property color heroTop: Qt.hsla(root.heroHue, root.heroSat,
    root.accent.hslLightness, 0.32)
  readonly property color heroMid: Qt.hsla(root.heroHue, root.heroSat,
    root.accent.hslLightness, 0.13)
  readonly property color heroEnd: Qt.hsla(root.heroHue, root.heroSat,
    root.accent.hslLightness, 0.0)
  readonly property color tempGlow: Qt.hsla(root.heroHue, root.heroSat,
    Math.min(0.8, root.accent.hslLightness + 0.18), 1.0)

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

  function setGradientSat(value) {
    const sat = Number(value)
    if (!isFinite(sat)) return
    root.gradientSat = Math.max(0, Math.min(100, sat))
    root.gradientSeeded = true
  }

  function setEffectsEnabled(value) {
    const enabled = value === true
    if (enabled === root.effectsEnabled) return
    root.effectsEnabled = enabled
    root.writeSettings()
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
          root.effectsEnabled = appearance.effects !== false
        } else {
          root.effectsEnabled = true
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
    root.gradientMode = "weather"
    root.gradientHue = 0
    root.gradientSat = 0
    root.gradientSeeded = false
    root.effectsEnabled = true
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
      effects: root.effectsEnabled
    }
    if (root.gradientSeeded) {
      appearance.hue = Math.round(root.gradientHue)
      appearance.sat = Math.round(root.gradientSat)
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
    root.locationError = ""
    root.geocodeResults = []
  }

  function closeSettings() {
    root.settingsOpen = false
    root.settingsTab = "general"
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
              anchors.centerIn: parent
              textFormat: Text.PlainText
              text: "\uf00d"
              color: closeButton.hasCursor ? root.ink : root.mutedInk
              font.family: root.fontFamily
              font.pixelSize: Style.font.title
              renderType: Text.NativeRendering
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

        Row {
          id: tabBar

          visible: root.settingsOpen
          width: parent.width
          height: Style.space(26)
          spacing: Style.space(6)

          Repeater {
            model: root.settingsTabChoices

            delegate: Rectangle {
              id: tabButton

              required property var modelData

              readonly property bool selected: root.settingsTab
                === tabButton.modelData.value
              readonly property bool hovered: tabMouse.containsMouse

              width: (tabBar.width - tabBar.spacing
                * (root.settingsTabChoices.length - 1))
                / root.settingsTabChoices.length
              height: tabBar.height
              radius: Style.space(8)
              color: tabButton.selected ? root.activeFill
                : tabButton.hovered
                  ? Commons.Util.alpha(root.ink, 0.09) : root.tileFill
              border.width: 1
              border.color: tabButton.selected
                ? root.accent : root.tileBorder

              Text {
                anchors.centerIn: parent
                textFormat: Text.PlainText
                text: tabButton.modelData.label
                color: tabButton.selected ? root.accent
                  : tabButton.hovered ? root.ink : root.mutedInk
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                font.bold: true
                font.letterSpacing: 1.1
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
          width: parent.width
          implicitHeight: Math.max(heroRow.implicitHeight + Style.space(30),
            Style.space(150))

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
            text: root.comment
            color: commentArea.containsMouse ? root.accent : root.ink
            font.family: root.fontFamily
            font.pixelSize: Style.font.subtitle
            renderType: Text.NativeRendering

            Behavior on color {
              ColorAnimation { duration: Style.duration(120) }
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

        Column {
          id: settingsBody

          visible: root.settingsOpen
          width: parent.width
          spacing: Style.space(10)

          // --- General --------------------------------------------------

          Column {
            visible: root.settingsTab === "general"
            width: parent.width
            spacing: Style.space(6)

            Text {
              textFormat: Text.PlainText
              text: "PERSONALITY"
              color: root.mutedInk
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
              font.letterSpacing: 1.2
              renderType: Text.NativeRendering
            }

            Column {
              width: parent.width
              spacing: Style.space(5)

              Repeater {
                model: root.toneChoices

                delegate: Rectangle {
                  id: toneCard

                  required property var modelData

                  readonly property bool selected: root.activeTone
                    === String(toneCard.modelData.value)
                  readonly property bool hovered: toneCardMouse.containsMouse

                  width: parent.width
                  height: Style.space(42)
                  radius: Style.space(8)
                  color: toneCard.selected ? root.activeFill
                    : toneCard.hovered
                      ? Commons.Util.alpha(root.ink, 0.07) : root.tileFill
                  border.width: 1
                  border.color: toneCard.selected
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
                      text: toneCard.modelData.label
                      color: toneCard.selected ? root.accent : root.ink
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.bodySmall
                      font.bold: true
                      elide: Text.ElideRight
                      renderType: Text.NativeRendering
                    }

                    Text {
                      width: parent.width
                      textFormat: Text.PlainText
                      text: toneCard.modelData.description
                      color: root.mutedInk
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.caption
                      elide: Text.ElideRight
                      renderType: Text.NativeRendering
                    }
                  }

                  MouseArea {
                    id: toneCardMouse

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.setTone(toneCard.modelData.value)
                  }
                }
              }
            }

            Item { width: 1; height: Style.space(2) }

            Text {
              textFormat: Text.PlainText
              text: "UNITS"
              color: root.mutedInk
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
              font.letterSpacing: 1.2
              renderType: Text.NativeRendering
            }

            Row {
              id: unitRow

              width: parent.width
              spacing: Style.space(6)

              Repeater {
                model: root.unitChoices

                delegate: Rectangle {
                  id: unitPill

                  required property var modelData

                  readonly property bool selected: root.unitOverride
                    === String(unitPill.modelData.value)
                  readonly property bool hovered: unitMouse.containsMouse

                  width: (unitRow.width - unitRow.spacing * 2) / 3
                  height: Style.space(28)
                  radius: Style.space(8)
                  color: unitPill.selected ? root.activeFill
                    : unitPill.hovered
                      ? Commons.Util.alpha(root.ink, 0.09) : root.tileFill
                  border.width: 1
                  border.color: unitPill.selected
                    ? root.accent : root.tileBorder

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

          // --- Appearance ------------------------------------------------

          Column {
            visible: root.settingsTab === "appearance"
            width: parent.width
            spacing: Style.space(6)

            Text {
              textFormat: Text.PlainText
              text: "GRADIENT"
              color: root.mutedInk
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
              font.letterSpacing: 1.2
              renderType: Text.NativeRendering
            }

            Rectangle {
              width: parent.width
              height: Style.space(44)
              radius: Style.space(10)
              color: "transparent"
              border.width: 1
              border.color: root.tileBorder

              Rectangle {
                anchors.fill: parent
                anchors.margins: 1
                radius: Style.space(9)
                gradient: Gradient {
                  orientation: Gradient.Vertical
                  GradientStop { position: 0.0; color: root.heroTop }
                  GradientStop { position: 0.45; color: root.heroMid }
                  GradientStop { position: 1.0; color: root.heroEnd }
                }
              }
            }

            Row {
              id: gradientModeRow

              width: parent.width
              spacing: Style.space(6)

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
                  height: Style.space(28)
                  radius: Style.space(8)
                  color: gradientModePill.selected ? root.activeFill
                    : gradientModePill.hovered
                      ? Commons.Util.alpha(root.ink, 0.09) : root.tileFill
                  border.width: 1
                  border.color: gradientModePill.selected
                    ? root.accent : root.tileBorder

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

            Column {
              visible: root.gradientMode === "custom"
              width: parent.width
              spacing: Style.space(4)

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

                Text {
                  anchors.right: parent.right
                  anchors.verticalCenter: parent.verticalCenter
                  textFormat: Text.PlainText
                  text: Math.round(root.gradientHue) + "\u00b0"
                  color: root.mutedInk
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                  renderType: Text.NativeRendering
                }
              }

              Rectangle {
                id: hueStrip

                width: parent.width
                height: Style.space(14)
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
                  width: Style.space(16)
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

                Text {
                  anchors.right: parent.right
                  anchors.verticalCenter: parent.verticalCenter
                  textFormat: Text.PlainText
                  text: Math.round(root.gradientSat) + "%"
                  color: root.mutedInk
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                  renderType: Text.NativeRendering
                }
              }

              Rectangle {
                id: vividStrip

                width: parent.width
                height: Style.space(14)
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
                  width: Style.space(16)
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
            }

            Item { width: 1; height: Style.space(2) }

            Text {
              textFormat: Text.PlainText
              text: "EFFECTS"
              color: root.mutedInk
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
              font.letterSpacing: 1.2
              renderType: Text.NativeRendering
            }

            Toggle {
              width: parent.width
              label: "Weather effects"
              description: "Snow, rain, storms, fog, and night stars."
              checked: root.effectsEnabled
              foreground: root.ink
              accent: root.accent
              fontFamily: root.fontFamily
              titleSize: Style.font.bodySmall
              descriptionSize: Style.font.caption
              onClicked: root.setEffectsEnabled(!root.effectsEnabled)
            }
          }

          // --- Location -------------------------------------------------

          Column {
            visible: root.settingsTab === "location"
            width: parent.width
            spacing: Style.space(7)

            Text {
              textFormat: Text.PlainText
              text: "CURRENT LOCATION"
              color: root.mutedInk
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
              font.letterSpacing: 1.2
              renderType: Text.NativeRendering
            }

            Rectangle {
              width: parent.width
              height: currentColumn.implicitHeight + Style.space(18)
              radius: Style.space(10)
              color: root.tileFill
              border.width: 1
              border.color: root.tileBorder

              Column {
                id: currentColumn

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: Style.space(10)
                anchors.rightMargin: Style.space(10)
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

            Item { width: 1; height: Style.space(2) }

            Text {
              textFormat: Text.PlainText
              text: "SEARCH"
              color: root.mutedInk
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
              font.letterSpacing: 1.2
              renderType: Text.NativeRendering
            }

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
                    ? Commons.Util.alpha(root.ink, 0.09) : root.tileFill
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
      }
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
