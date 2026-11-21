import QtQuick
import Quickshell.Widgets
import qs.DankCommon.Widgets as DankCommon
import qs.Common

Item {
    id: root

    property string svgSource: ""
    property string fallbackIcon: ""
    property int size: isChild ? 24 : 30
    property color activeColor: Theme.buttonText
    property color inactiveColor: Theme.surfaceText
    property color childInactiveColor: Theme.surfaceVariantText
    property bool isActive: false
    property bool isChild: false

    readonly property string resolvedSvgSource: {
        if (!svgSource)
            return "";
        if (svgSource.startsWith("file://") || svgSource.startsWith("qrc:"))
            return svgSource;
        return "file://" + Theme.shellDir + "/assets/icons/" + svgSource;
    }

    readonly property bool hasSvg: resolvedSvgSource !== ""
    readonly property color currentColor: isActive ? activeColor : (isChild ? childInactiveColor : inactiveColor)

    // Image.Ready = 1 (from Qt Quick Image component status enum)
    readonly property int imageReadyStatus: 1

    implicitWidth: size
    implicitHeight: size

    DankCommon.DankSVGIcon {
        id: svgIcon
        anchors.fill: parent
        visible: hasSvg && status === imageReadyStatus
        source: resolvedSvgSource
        size: root.size
        colorOverride: "transparent"
    }

    DankCommon.DankIcon {
        id: fallbackIconItem
        anchors.fill: parent
        visible: !hasSvg || svgIcon.status !== imageReadyStatus
        name: fallbackIcon
        size: root.size
        color: currentColor

        Behavior on color {
            ColorAnimation {
                duration: Anims.settingsNavigationStateDuration
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Anims.expressiveEffects
            }
        }
    }
}