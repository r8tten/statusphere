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
// forecast, and a personality. Data comes from Open-Meteo; the location is
// shared with the rest of Omarchy through weather.json.
Panel {
  id: root

  moduleName: "naoko.statusphere"
  ipcTarget: "naoko.statusphere"
  manageIpc: false

  // --- State -------------------------------------------------------------

  property var weather: null
  property var locationState: ({ name: "", latitude: null, longitude: null })
  property var detectedLocation: ({ name: "", latitude: null, longitude: null })
  property bool locationAttempted: false
  property bool loaded: false
  property bool unavailable: false
  property bool stale: false
  property double lastUpdated: 0
  property double nowMs: Date.now()
  property string comment: ""
  property bool unitOverride: false
  property int retryCount: 0
  property bool refreshPending: false
  property string weatherOutput: ""
  property bool weatherCollected: false
  property bool weatherExited: false
  property bool weatherExitOk: false
  property string geocodeOutput: ""
  property string detectOutput: ""
  property string pendingLocationName: ""

  readonly property string cachePath: Quickshell.env("HOME")
    + "/.cache/naoko.statusphere/report.json"
  readonly property string settingsPath: Quickshell.env("HOME")
    + "/.local/state/naoko.statusphere/settings.json"
  readonly property var toneChoices: [
    { value: "friendly", label: "Friendly" },
    { value: "snarky", label: "Snarky" },
    { value: "unhinged", label: "Unhinged" }
  ]
  readonly property var currentWeather: root.weather ? root.weather.current : null
  readonly property var forecast: root.weather
    && Array.isArray(root.weather.daily) ? root.weather.daily : []
  readonly property var effectiveLocation: {
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
    const configured = root.locationState
      ? String(root.locationState.name || "").trim() : ""
    const detected = root.detectedLocation
      ? String(root.detectedLocation.name || "").trim() : ""
    return configured || detected || "Your location"
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
  readonly property bool useImperial: root.unitOverride
    ? !root.baseImperial : root.baseImperial
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
  readonly property real heroHue: (root.accent.hslHue + root.mood.hue + 1) % 1
  readonly property real heroSat: Math.min(1, Math.max(0,
    root.accent.hslSaturation * root.mood.sat))
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
      description: root.currentWeather.description
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

  function setTone(value) {
    const tone = root.validTone(value)
    if (tone === "") return
    const changed = tone !== root.activeTone || root.toneOverride !== tone
    root.toneOverride = tone
    root.rerollComment()
    if (changed) root.writeSettings()
  }

  function applySettings(raw) {
    try {
      const data = JSON.parse(String(raw || ""))
      if (!data || typeof data !== "object") return
      const tone = root.validTone(data.tone)
      if (tone === "" || tone === root.toneOverride) return
      root.toneOverride = tone
      if (root.loaded) root.rerollComment()
    } catch (error) {
    }
  }

  function clearToneOverride() {
    if (root.toneOverride === "") return
    root.toneOverride = ""
    if (root.loaded) root.rerollComment()
  }

  function writeSettings() {
    if (settingsWrite.running || root.toneOverride === "") return
    const payload = JSON.stringify({ tone: root.toneOverride })
    settingsWrite.command = ["/bin/sh", "-c",
      "mkdir -p \"$(dirname \"$1\")\" && printf '%s' \"$2\" > \"$1.tmp\""
        + " && mv \"$1.tmp\" \"$1\"",
      "sh", root.settingsPath, payload]
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
      root.refresh(true)
      return
    }
    if (root.locationAttempted) return
    root.locationAttempted = true
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
    detectProc.running = true
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

    contentWidth: panel.fittedContentWidth(Style.space(344))
    contentHeight: panel.fittedContentHeight(panel.loadedContentHeight,
      Style.space(640))

    content: PanelKeyCatcher {
      id: keyCatcher

      anchors.fill: parent
      implicitHeight: contentColumn.implicitHeight

      onCloseRequested: root.close()
      onReturnRequested: root.rerollComment()
      onTabRequested: function(direction) { root.switchPanel(direction) }

      // One atmospheric wash for the whole card. It extends under the panel
      // padding; the card clips it to the rounded corners, and the alpha lets
      // the card background and border show through.
      Rectangle {
        anchors.fill: parent
        anchors.margins: -panel.padding
        radius: Style.cornerRadius
        gradient: Gradient {
          orientation: Gradient.Vertical
          GradientStop { position: 0.0; color: root.heroTop }
          GradientStop { position: 0.45; color: root.heroMid }
          GradientStop { position: 1.0; color: root.heroEnd }
        }
      }

      Column {
        id: contentColumn

        width: parent.width
        spacing: Style.space(10)

        // --- Location + close -------------------------------------------

        Item {
          width: parent.width
          implicitHeight: Math.max(locationLabel.implicitHeight,
            closeButton.height)

          Text {
            id: locationLabel

            anchors.centerIn: parent
            width: Math.min(implicitWidth,
              parent.width - closeButton.width - Style.space(18))
            textFormat: Text.PlainText
            text: root.displayLocation
            elide: Text.ElideRight
            color: root.ink
            font.family: root.fontFamily
            font.pixelSize: Style.font.title
            font.bold: true
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
              text: "\udb80\udc56"
              color: closeButton.hasCursor ? root.ink : root.mutedInk
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
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

        // --- Loading / empty state --------------------------------------

        Column {
          visible: !root.loaded
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

          visible: root.loaded
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
          visible: root.loaded
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

        // --- Comment tone ----------------------------------------------

        Row {
          id: toneRow

          visible: root.loaded
          width: parent.width
          height: Style.space(24)
          spacing: Style.space(8)

          Text {
            id: toneLabel

            anchors.verticalCenter: parent.verticalCenter
            textFormat: Text.PlainText
            text: "TONE"
            color: root.mutedInk
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            font.bold: true
            font.letterSpacing: 1.2
            renderType: Text.NativeRendering
          }

          Row {
            id: toneButtons

            anchors.verticalCenter: parent.verticalCenter
            width: toneRow.width - toneLabel.implicitWidth - toneRow.spacing
            spacing: Style.space(6)

            Repeater {
              model: root.toneChoices

              delegate: Rectangle {
                id: toneButton

                required property var modelData

                readonly property bool selected: root.activeTone
                  === String(toneButton.modelData.value)
                readonly property bool hovered: toneMouse.containsMouse

                width: (toneButtons.width - toneButtons.spacing * 2) / 3
                height: toneRow.height
                radius: Style.space(8)
                color: toneButton.selected ? root.activeFill
                  : toneButton.hovered
                    ? Commons.Util.alpha(root.ink, 0.09) : root.tileFill
                border.width: 1
                border.color: toneButton.selected
                  ? root.accent : root.tileBorder

                Text {
                  anchors.centerIn: parent
                  textFormat: Text.PlainText
                  text: toneButton.modelData.label
                  color: toneButton.selected ? root.accent
                    : toneButton.hovered ? root.ink : root.mutedInk
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                  font.bold: true
                  renderType: Text.NativeRendering
                }

                MouseArea {
                  id: toneMouse

                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: root.setTone(toneButton.modelData.value)
                }
              }
            }
          }
        }

        // --- Current details -------------------------------------------

        Row {
          id: statsRow

          visible: root.loaded
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
          visible: root.loaded && root.forecast.length > 0
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
          visible: root.loaded
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
              - refreshButton.width - unitButton.width - parent.spacing * 2)
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
              text: "\udb80\udc10"
              color: refreshButton.hasCursor ? root.ink : root.mutedInk
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
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

          CursorSurface {
            id: unitButton

            width: Style.space(34)
            height: Style.space(22)
            anchors.verticalCenter: parent.verticalCenter
            hasCursor: unitArea.containsMouse
            foreground: root.ink
            accent: root.accent

            Text {
              anchors.centerIn: parent
              textFormat: Text.PlainText
              text: root.useImperial ? "\u00b0F" : "\u00b0C"
              color: unitButton.hasCursor ? root.accent : root.mutedInk
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
              renderType: Text.NativeRendering
            }

            MouseArea {
              id: unitArea

              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: root.unitOverride = !root.unitOverride
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
          root.refresh(true)
          return
        }
        root.unavailable = true
      }
    }
  }

  Process {
    id: detectProc

    command: ["curl", "-fsS", "--max-time", "4",
      "https://geo.omarchy.org/"]

    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        root.detectOutput = text
        const location = Model.parseLocation(text)
        if (location.latitude !== null && location.longitude !== null) {
          root.detectedLocation = location
          root.refresh(true)
          return
        }
        root.unavailable = true
      }
    }
  }

  Process {
    id: cacheWrite
  }

  Process {
    id: settingsWrite
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
    onLoadFailed: root.clearToneOverride()
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
    }
  }
}
