import QtQuick

// Weather particles for the Statusphere popup. Snow uses a Nerd Font glyph
// with varied sizes; rain, fog, and stars are plain rectangles so their sizes
// and opacities stay exact. The caller clips this layer and owns `active`, so
// nothing animates while the popup is closed or the settings page is open.
Item {
  id: root

  property string kind: ""
  property bool active: false
  property color tint: "#ffffff"
  property color flashColor: "#ffffff"
  property string fontFamily: "monospace"

  readonly property int snowCount: 26
  readonly property int rainCount: 30
  readonly property int starCount: 20
  readonly property int fogCount: 6
  readonly property int fireworkCount: 7

  visible: active && kind !== ""
  clip: true

  // --- Snow --------------------------------------------------------------

  Repeater {
    model: root.kind === "snow" ? root.snowCount : 0

    delegate: Text {
      id: flake

      readonly property real size: 6 + Math.random() * 8
      readonly property real baseX: Math.random() * Math.max(1,
        root.width - size)
      readonly property real sway: 4 + Math.random() * 10
      readonly property real speed: 4200 + Math.random() * 5200
      readonly property real delay: Math.random() * 3200

      text: "\uf2dc"
      color: root.tint
      opacity: 0.35 + Math.random() * 0.55
      font.family: root.fontFamily
      font.pixelSize: size
      renderType: Text.NativeRendering
      x: baseX
      y: -size

      SequentialAnimation on y {
        running: root.active
        loops: Animation.Infinite
        PauseAnimation { duration: flake.delay }
        NumberAnimation {
          from: -flake.size
          to: root.height + flake.size
          duration: flake.speed
        }
      }

      SequentialAnimation on x {
        running: root.active
        loops: Animation.Infinite
        NumberAnimation {
          from: flake.baseX - flake.sway
          to: flake.baseX + flake.sway
          duration: 2200 + Math.random() * 1800
          easing.type: Easing.InOutSine
        }
        NumberAnimation {
          from: flake.baseX + flake.sway
          to: flake.baseX - flake.sway
          duration: 2200 + Math.random() * 1800
          easing.type: Easing.InOutSine
        }
      }
    }
  }

  // --- Rain and storms ---------------------------------------------------

  Repeater {
    model: root.kind === "rain" || root.kind === "storm" ? root.rainCount : 0

    delegate: Rectangle {
      id: drop

      readonly property real dropHeight: 5 + Math.random() * 8
      readonly property real speed: 650 + Math.random() * 650

      width: 1
      height: dropHeight
      x: Math.random() * Math.max(1, root.width)
      y: -dropHeight
      color: root.tint
      opacity: 0.18 + Math.random() * 0.28
      rotation: 9 + Math.random() * 5

      SequentialAnimation on y {
        running: root.active
        loops: Animation.Infinite
        PauseAnimation { duration: Math.random() * 1200 }
        NumberAnimation {
          from: -drop.dropHeight
          to: root.height + drop.dropHeight
          duration: drop.speed
        }
      }
    }
  }

  // --- Fog ---------------------------------------------------------------

  Repeater {
    model: root.kind === "fog" ? root.fogCount : 0

    delegate: Rectangle {
      id: puff

      readonly property real puffWidth: 70 + Math.random() * 90
      readonly property real puffHeight: 24 + Math.random() * 36
      readonly property real speed: 14000 + Math.random() * 9000

      width: puffWidth
      height: puffHeight
      radius: height / 2
      x: -puffWidth
      y: Math.random() * Math.max(1, root.height - puffHeight)
      color: root.tint
      opacity: 0.03 + Math.random() * 0.04

      NumberAnimation on x {
        running: root.active
        loops: Animation.Infinite
        from: -puff.puffWidth
        to: root.width + puff.puffWidth
        duration: puff.speed
      }
    }
  }

  // --- Clear-night stars -------------------------------------------------

  Repeater {
    model: root.kind === "stars" ? root.starCount : 0

    delegate: Rectangle {
      id: star

      readonly property real size: 1.2 + Math.random() * 1.6
      readonly property real baseOpacity: 0.3 + Math.random() * 0.5

      width: size
      height: size
      radius: width / 2
      x: Math.random() * Math.max(1, root.width)
      y: Math.random() * Math.max(1, root.height)
      color: root.tint
      opacity: baseOpacity

      SequentialAnimation on opacity {
        running: root.active
        loops: Animation.Infinite
        NumberAnimation {
          to: 0.15
          duration: 1800 + Math.random() * 2600
          easing.type: Easing.InOutSine
        }
        NumberAnimation {
          to: star.baseOpacity
          duration: 1800 + Math.random() * 2600
          easing.type: Easing.InOutSine
        }
      }
    }
  }

  // --- Fireworks (New Year's Day, Bonfire Night) --------------------------

  Repeater {
    model: root.kind === "fireworks" ? root.fireworkCount : 0

    delegate: Item {
      id: burst

      readonly property var palette: [
        root.flashColor, "#ffd166", "#ff6b6b", "#4cc9f0",
        "#b388ff", "#7bed9f"
      ]
      readonly property color color: palette[
        Math.floor(Math.random() * palette.length)]
      readonly property real burstX: 0.12 + Math.random() * 0.76
      readonly property real burstY: 0.10 + Math.random() * 0.36
      readonly property real delay: Math.random() * 1800
      readonly property real cooldown: 900 + Math.random() * 1500
      readonly property real rise: 0.22
      readonly property real spread: Math.max(0,
        (life - rise) / (1 - rise))

      property real life: 0

      x: burstX * root.width
      y: burstY * root.height

      // The burst: sparks fly out, droop, and fade.
      Repeater {
        model: 20

        delegate: Rectangle {
          id: spark

          readonly property real angle: (index / 20) * Math.PI * 2
            + Math.random() * 0.3
          readonly property real distance: 34 + Math.random() * 46

          width: 1.5 + Math.random() * 1.2
          height: 3 + Math.random() * 4
          radius: width / 2
          rotation: angle * 180 / Math.PI + 90
          x: Math.cos(angle) * distance * burst.spread - width / 2
          y: Math.sin(angle) * distance * burst.spread
            + 16 * burst.spread * burst.spread - height / 2
          color: burst.color
          opacity: burst.spread <= 0 ? 0
            : Math.min(1, (1 - burst.spread) * 1.2)
          visible: burst.life > burst.rise
        }
      }

      SequentialAnimation on life {
        running: root.active
        loops: Animation.Infinite
        PauseAnimation { duration: burst.delay }
        NumberAnimation { from: 0; to: 1; duration: 1800 }
        PauseAnimation { duration: burst.cooldown }
      }
    }
  }

  // --- Thunder flash -----------------------------------------------------

  Rectangle {
    id: flash

    anchors.fill: parent
    color: root.flashColor
    opacity: 0
    visible: root.kind === "storm" && root.active
  }

  Timer {
    id: flashTimer

    running: root.active && root.kind === "storm"
    repeat: true
    interval: 7000 + Math.random() * 8000
    onTriggered: flashAnim.restart()
  }

  SequentialAnimation {
    id: flashAnim

    NumberAnimation { target: flash; property: "opacity"; to: 0.16; duration: 60 }
    NumberAnimation { target: flash; property: "opacity"; to: 0; duration: 130 }
    NumberAnimation { target: flash; property: "opacity"; to: 0.10; duration: 70 }
    NumberAnimation { target: flash; property: "opacity"; to: 0; duration: 200 }
  }
}
