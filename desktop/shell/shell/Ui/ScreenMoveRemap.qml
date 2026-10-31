import QtQuick

// Hyprland leaves an already-mapped layer surface at its old global position
// when its monitor moves within the layout: undocking disables the internal
// panel, the external monitor shifts to x=0, and long-lived surfaces such as
// the bar and background keep rendering at the old offset — or entirely
// off-screen — until they are unmapped and remapped. Watch the screen's
// origin and pulse remapping when it moves; the owning window folds that
// into its visible binding so the compositor re-places the surface at the
// monitor's new origin.
Item {
  id: root

  required property var window
  readonly property var screen: window ? window.screen : null

  // ShellScreen's x, y, width and height share geometryChanged. A size-only
  // rotation therefore also invokes onXChanged/onYChanged. Compare the actual
  // origin before remapping, or a quarter-turn destroys the native panels.
  property var observedScreen: null
  property int observedX: 0
  property int observedY: 0

  function checkOrigin() {
    var current = root.screen
    if (!current) { root.observedScreen = null; return }
    var x = current.x
    var y = current.y
    if (current !== root.observedScreen) {
      root.observedScreen = current
      root.observedX = x
      root.observedY = y
      return
    }
    if (x === root.observedX && y === root.observedY) return
    root.observedX = x
    root.observedY = y
    settleTimer.restart()
  }
  onScreenChanged: checkOrigin()
  Component.onCompleted: checkOrigin()

  // Fold into the window's binding: visible: <shown> && !guard.remapping
  property bool remapping: false

  visible: false

  // A layout reshuffle can move the monitor more than once before it lands.
  // Let the positions settle before the single remap pulse.
  Timer {
    id: settleTimer
    interval: 200
    onTriggered: root.remapping = true
  }

  // Hold the surface unmapped for a beat so the compositor processes the
  // unmap before the remap instead of coalescing them into a no-op.
  Timer {
    interval: 50
    running: root.remapping
    onTriggered: root.remapping = false
  }

  Connections {
    target: root.screen
    function onXChanged() { root.checkOrigin() }
    function onYChanged() { root.checkOrigin() }
  }
}
