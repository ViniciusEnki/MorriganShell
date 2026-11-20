pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.Common
import qs.Modules.Settings.Widgets
import qs.Modals.Common
import qs.Modals.FileBrowser
import qs.Services
import qs.Widgets

Item {
    id: root

    LayoutMirroring.enabled: I18n.isRtl
    LayoutMirroring.childrenInherit: true

    Component.onCompleted: {
        NetworkService.addRef();
    }

    Component.onDestruction: {
        NetworkService.removeRef();
    }

    property string expandedEthDevice: ""
    property string expandedVpnUuid: ""

    readonly property var preferenceValues: {
        const values = ["auto", "ethernet", "wifi"];
        if ((NetworkService.cellularDevices?.length ?? 0) > 0)
            values.push("cellular");
        return values;
    }
    readonly property var labelsByValue: ({
        "auto": I18n.tr("Auto"),
        "ethernet": I18n.tr("Ethernet"),
        "wifi": I18n.tr("WiFi"),
        "cellular": I18n.tr("Cellular")
    })

    function openVpnFileBrowser() {
        vpnFileBrowserLoader.active = true;
        if (vpnFileBrowserLoader.item)
            vpnFileBrowserLoader.item.open();
    }

    property var vpnFileBrowserLoader: LazyLoader {
        active: false

        FileBrowserModal {
            browserTitle: I18n.tr("Import VPN")
            browserIcon: "vpn_key"
            browserType: "vpn"
            fileExtensions: VPNService.getFileFilter()

            onFileSelected: path => {
                VPNService.importVpn(path.replace("file://", ""));
            }
        }
    }

    property var deleteVpnConfirm: ConfirmModal {}

    DankFlickable {
        anchors.fill: parent
        clip: true
        contentHeight: mainColumn.height + Theme.spacingXL
        contentWidth: width

        Column {
            id: mainColumn

            topPadding: 4
            width: Math.min(600, parent.width - Theme.spacingL * 2)
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Theme.spacingL

            // Status Section
            SettingsCard {
                id: statusCard
                title: I18n.tr("Status")
                iconName: "lan"
                settingKey: "networkStatus"
                tags: ["status", "network", "connectivity", "internet"]
                width: parent.width

                Column {
                    id: overviewSection
                    width: parent.width
                    spacing: Theme.spacingM

                    StyledText {
                        text: I18n.tr("Overview of your network connections")
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceVariantText
                        width: parent.width
                        horizontalAlignment: Text.AlignLeft
                    }

                    Rectangle {
                        width: parent.width
                        height: 1
                        color: Theme.outlineStrong
                    }

                    Grid {
                        columns: 2
                        columnSpacing: Theme.spacingL
                        rowSpacing: Theme.spacingS
                        width: parent.width

                        StyledText {
                            text: I18n.tr("Backend")
                            font.pixelSize: Theme.fontSizeMedium
                            color: Theme.surfaceVariantText
                        }
                        StyledText {
                            text: NetworkService.backend || I18n.tr("Unknown")
                            font.pixelSize: Theme.fontSizeMedium
                            color: Theme.surfaceText
                            font.weight: Font.Medium
                        }

                        StyledText {
                            text: I18n.tr("Status")
                            font.pixelSize: Theme.fontSizeMedium
                            color: Theme.surfaceVariantText
                        }
                        Row {
                            spacing: Theme.spacingS

                            Rectangle {
                                width: 8
                                height: 8
                                radius: 4
                                anchors.verticalCenter: parent.verticalCenter
                                color: {
                                    switch (NetworkService.networkStatus) {
                                    case "ethernet":
                                    case "wifi":
                                    case "cellular":
                                        return Theme.success;
                                    case "disconnected":
                                        return Theme.error;
                                    default:
                                        return Theme.warning;
                                    }
                                }
                            }

                            StyledText {
                                text: {
                                    switch (NetworkService.networkStatus) {
                                    case "ethernet":
                                        return I18n.tr("Ethernet");
                                    case "wifi":
                                        return I18n.tr("WiFi");
                                    case "cellular":
                                        return I18n.tr("Cellular");
                                    case "disconnected":
                                        return I18n.tr("Disconnected");
                                    default:
                                        return NetworkService.networkStatus || I18n.tr("Unknown");
                                    }
                                }
                                font.pixelSize: Theme.fontSizeMedium
                                color: Theme.surfaceText
                                font.weight: Font.Medium
                            }
                        }

                        StyledText {
                            text: I18n.tr("Primary", "primary network connection label", true)
                            font.pixelSize: Theme.fontSizeMedium
                            color: Theme.surfaceVariantText
                            visible: NetworkService.primaryConnection.length > 0
                        }
                        StyledText {
                            text: NetworkService.primaryConnection || "-"
                            font.pixelSize: Theme.fontSizeMedium
                            color: Theme.surfaceText
                            elide: Text.ElideRight
                            visible: NetworkService.primaryConnection.length > 0
                        }
                    }

                    Row {
                        width: parent.width
                        spacing: Theme.spacingM
                        visible: NetworkService.backend === "networkmanager" && [NetworkService.ethernetConnected, NetworkService.wifiConnected, NetworkService.cellularConnected].filter(v => v).length > 1

                        StyledText {
                            text: I18n.tr("Preference")
                            font.pixelSize: Theme.fontSizeMedium
                            color: Theme.surfaceVariantText
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Item {
                            width: parent.width - preferenceLabel.width - preferenceButtons.width - Theme.spacingM * 2
                            height: 1
                        }

                        DankButtonGroup {
                            id: preferenceButtons
                            model: preferenceValues.map(v => labelsByValue[v] || v)
                            currentIndex: Math.max(0, preferenceValues.indexOf(NetworkService.userPreference))
                            onSelectionChanged: (index, selected) => {
                                if (!selected)
                                    return;
                                NetworkService.setNetworkPreference(preferenceValues[index] || "auto");
                            }
                        }
                    }

                    StyledText {
                        id: preferenceLabel
                        visible: false
                        text: I18n.tr("Preference")
                    }
                }
            }

            // Ethernet Section
            SettingsCard {
                id: ethernetCard
                title: I18n.tr("Ethernet")
                iconName: "settings_ethernet"
                settingKey: "networkEthernet"
                tags: ["ethernet", "wired", "network", "adapters", "connection"]
                width: parent.width

                Column {
                    id: ethernetSection
                    width: parent.width
                    spacing: Theme.spacingM

                    StyledText {
                        text: {
                            const devices = NetworkService.ethernetDevices;
                            const connected = devices.filter(d => d.connected).length;
                            if (devices.length === 0)
                                return I18n.tr("No adapters");
                            if (connected === 0)
                                return devices.length === 1 ? I18n.tr("%1 adapter, none connected").arg(devices.length) : I18n.tr("%1 adapters, none connected").arg(devices.length);
                            return I18n.tr("%1 connected").arg(connected);
                        }
                        font.pixelSize: Theme.fontSizeSmall
                        color: NetworkService.ethernetConnected ? Theme.primary : Theme.surfaceVariantText
                        width: parent.width
                        horizontalAlignment: Text.AlignLeft
                    }

                    Rectangle {
                        width: parent.width
                        height: 1
                        color: Theme.outlineStrong
                    }

                    Column {
                        width: parent.width
                        spacing: Theme.spacingXS
                        visible: NetworkService.ethernetDevices.length > 0

                        StyledText {
                            text: I18n.tr("Adapters")
                            font.pixelSize: Theme.fontSizeMedium
                            font.weight: Font.Medium
                            color: Theme.surfaceText
                            width: parent.width
                            horizontalAlignment: Text.AlignLeft
                        }

                        Repeater {
                            model: NetworkService.ethernetDevices

                            delegate: Rectangle {
                                id: ethDeviceDelegate
                                required property var modelData
                                required property int index

                                readonly property bool isConnected: modelData.connected || false
                                readonly property bool isExpanded: root.expandedEthDevice === modelData.name

                                width: parent.width
                                height: isExpanded ? 56 + ethExpandedContent.height : 56
                                radius: Theme.cornerRadius
                                color: ethDeviceMouseArea.containsMouse ? Theme.primaryHoverLight : Theme.surfaceLight
                                border.width: isConnected ? 2 : 0
                                border.color: Theme.primary
                                clip: true

                                Behavior on height {
                                    NumberAnimation {
                                        duration: 150
                                        easing.type: Easing.OutQuad
                                    }
                                }

                                Column {
                                    anchors.fill: parent
                                    spacing: 0

                                    Item {
                                        width: parent.width
                                        height: 56

                                        Row {
                                            anchors.left: parent.left
                                            anchors.leftMargin: Theme.spacingM
                                            anchors.verticalCenter: parent.verticalCenter
                                            anchors.right: ethDeviceActions.left
                                            anchors.rightMargin: Theme.spacingS
                                            spacing: Theme.spacingS

                                            DankIcon {
                                                name: "lan"
                                                size: 20
                                                color: isConnected ? Theme.primary : Theme.surfaceText
                                                anchors.verticalCenter: parent.verticalCenter
                                            }

                                            Column {
                                                anchors.verticalCenter: parent.verticalCenter
                                                spacing: Theme.spacingXXS
                                                width: parent.width - 20 - Theme.spacingS

                                                StyledText {
                                                    text: modelData.name || I18n.tr("Unknown")
                                                    font.pixelSize: Theme.fontSizeMedium
                                                    color: isConnected ? Theme.primary : Theme.surfaceText
                                                    font.weight: isConnected ? Font.Medium : Font.Normal
                                                    elide: Text.ElideRight
                                                    width: parent.width
                                                    horizontalAlignment: Text.AlignLeft
                                                }

                                                Row {
                                                    anchors.left: parent.left
                                                    spacing: Theme.spacingXS

                                                    StyledText {
                                                        text: {
                                                            switch (modelData.state) {
                                                            case "activated":
                                                                return I18n.tr("Connected");
                                                            case "disconnected":
                                                                return I18n.tr("Disconnected");
                                                            case "unavailable":
                                                                return I18n.tr("Unavailable");
                                                            default:
                                                                return modelData.state || I18n.tr("Unknown");
                                                            }
                                                        }
                                                        font.pixelSize: Theme.fontSizeSmall
                                                        color: isConnected ? Theme.primary : Theme.surfaceVariantText
                                                    }

                                                    StyledText {
                                                        text: "•"
                                                        font.pixelSize: Theme.fontSizeSmall
                                                        color: Theme.surfaceVariantText
                                                        visible: (modelData.ip || "").length > 0
                                                    }

                                                    StyledText {
                                                        text: modelData.ip || ""
                                                        font.pixelSize: Theme.fontSizeSmall
                                                        color: Theme.surfaceVariantText
                                                        visible: (modelData.ip || "").length > 0
                                                    }
                                                }
                                            }
                                        }

                                        Row {
                                            id: ethDeviceActions
                                            anchors.right: parent.right
                                            anchors.rightMargin: Theme.spacingS
                                            anchors.verticalCenter: parent.verticalCenter
                                            spacing: Theme.spacingXS

                                            Rectangle {
                                                width: 28
                                                height: 28
                                                radius: 14
                                                color: ethExpandBtn.containsMouse ? Theme.surfacePressed : Theme.withAlpha(Theme.surfacePressed, 0)
                                                visible: isConnected

                                                DankIcon {
                                                    anchors.centerIn: parent
                                                    name: isExpanded ? "expand_less" : "expand_more"
                                                    size: 18
                                                    color: Theme.surfaceText
                                                }

                                                MouseArea {
                                                    id: ethExpandBtn
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: {
                                                        if (isExpanded) {
                                                            root.expandedEthDevice = "";
                                                        } else {
                                                            root.expandedEthDevice = modelData.name;
                                                            NetworkService.fetchWiredNetworkInfo(NetworkService.ethernetConnectionUuid);
                                                        }
                                                    }
                                                }
                                            }

                                            Rectangle {
                                                width: 28
                                                height: 28
                                                radius: 14
                                                color: ethDisconnectBtn.containsMouse ? Theme.errorHover : Theme.withAlpha(Theme.errorHover, 0)
                                                visible: isConnected

                                                DankIcon {
                                                    anchors.centerIn: parent
                                                    name: "link_off"
                                                    size: 18
                                                    color: ethDisconnectBtn.containsMouse ? Theme.error : Theme.surfaceVariantText
                                                }

                                                MouseArea {
                                                    id: ethDisconnectBtn
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: NetworkService.disconnectEthernetDevice(modelData.name)
                                                }
                                            }
                                        }

                                        MouseArea {
                                            id: ethDeviceMouseArea
                                            anchors.fill: parent
                                            anchors.rightMargin: ethDeviceActions.width + Theme.spacingM
                                            hoverEnabled: true
                                        }
                                    }

                                    Column {
                                        id: ethExpandedContent
                                        width: parent.width
                                        visible: isExpanded

                                        Rectangle {
                                            width: parent.width - Theme.spacingM * 2
                                            height: 1
                                            x: Theme.spacingM
                                            color: Theme.outlineLight
                                        }

                                        Item {
                                            width: parent.width
                                            height: ethDetailsColumn.implicitHeight + Theme.spacingM * 2

                                            Column {
                                                id: ethDetailsColumn
                                                anchors.fill: parent
                                                anchors.margins: Theme.spacingM
                                                spacing: Theme.spacingS

                                                Flow {
                                                    width: parent.width
                                                    spacing: Theme.spacingXS

                                                    Repeater {
                                                        model: {
                                                            const fields = [];
                                                            const dev = modelData;
                                                            if (!dev)
                                                                return fields;

                                                            if (dev.ip)
                                                                fields.push({
                                                                    label: I18n.tr("IP"),
                                                                    value: dev.ip
                                                                });
                                                            if (dev.speed && dev.speed > 0)
                                                                fields.push({
                                                                    label: I18n.tr("Speed"),
                                                                    value: dev.speed + " Mbps"
                                                                });
                                                            if (dev.hwAddress)
                                                                fields.push({
                                                                    label: I18n.tr("MAC"),
                                                                    value: dev.hwAddress
                                                                });
                                                            if (dev.driver)
                                                                fields.push({
                                                                    label: I18n.tr("Driver"),
                                                                    value: dev.driver
                                                                });
                                                            fields.push({
                                                                label: I18n.tr("State"),
                                                                value: dev.state || I18n.tr("Unknown")
                                                            });

                                                            return fields;
                                                        }

                                                        delegate: Rectangle {
                                                            required property var modelData
                                                            required property int index

                                                            width: ethFieldContent.width + Theme.spacingM * 2
                                                            height: 32
                                                            radius: Theme.cornerRadius - 2
                                                            color: Theme.floatingWindowFieldColor
                                                            border.width: 1
                                                            border.color: Theme.floatingWindowFieldBorderColor

                                                            Row {
                                                                id: ethFieldContent
                                                                anchors.centerIn: parent
                                                                spacing: Theme.spacingXS

                                                                StyledText {
                                                                    text: modelData.label + ":"
                                                                    font.pixelSize: Theme.fontSizeSmall
                                                                    color: Theme.surfaceVariantText
                                                                    anchors.verticalCenter: parent.verticalCenter
                                                                }

                                                                StyledText {
                                                                    text: modelData.value
                                                                    font.pixelSize: Theme.fontSizeSmall
                                                                    color: Theme.surfaceText
                                                                    font.weight: Font.Medium
                                                                    anchors.verticalCenter: parent.verticalCenter
                                                                }
                                                            }
                                                        }
                                                    }
                                                }

                                                Item {
                                                    width: parent.width
                                                    height: NetworkService.networkWiredInfoLoading ? 40 : 0
                                                    visible: NetworkService.networkWiredInfoLoading

                                                    DankSpinner {
                                                        anchors.centerIn: parent
                                                        size: 20
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Column {
                        width: parent.width
                        spacing: Theme.spacingS
                        visible: NetworkService.wiredConnections.length > 0

                        Rectangle {
                            width: parent.width
                            height: 1
                            color: Theme.outlineStrong
                        }

                        StyledText {
                            text: I18n.tr("Saved Configurations")
                            font.pixelSize: Theme.fontSizeMedium
                            font.weight: Font.Medium
                            color: Theme.surfaceText
                            width: parent.width
                            horizontalAlignment: Text.AlignLeft
                        }

                        Repeater {
                            model: NetworkService.wiredConnections

                            delegate: Rectangle {
                                required property var modelData
                                required property int index

                                width: parent.width
                                height: 48
                                radius: Theme.cornerRadius
                                color: wiredMouseArea.containsMouse ? Theme.primaryHoverLight : Theme.surfaceLight
                                border.width: modelData.isActive ? 2 : 0
                                border.color: Theme.primary

                                Row {
                                    anchors.left: parent.left
                                    anchors.leftMargin: Theme.spacingM
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: Theme.spacingS

                                    DankIcon {
                                        name: "lan"
                                        size: 20
                                        color: modelData.isActive ? Theme.primary : Theme.surfaceText
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                    Column {
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: Theme.spacingXXS

                                        StyledText {
                                            text: modelData.id || I18n.tr("Unknown")
                                            font.pixelSize: Theme.fontSizeMedium
                                            color: modelData.isActive ? Theme.primary : Theme.surfaceText
                                            font.weight: modelData.isActive ? Font.Medium : Font.Normal
                                        }

                                        StyledText {
                                            text: modelData.isActive ? I18n.tr("Active") : ""
                                            font.pixelSize: Theme.fontSizeSmall
                                            color: Theme.primary
                                            visible: modelData.isActive
                                        }
                                    }
                                }

                                MouseArea {
                                    id: wiredMouseArea

                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (!modelData.isActive) {
                                            NetworkService.connectToSpecificWiredConfig(modelData.uuid);
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // VPN Section
            SettingsCard {
                id: vpnCard
                title: I18n.tr("VPN")
                iconName: "vpn_key"
                settingKey: "networkVpn"
                tags: ["vpn", "network", "profiles", "import", "openvpn", "wireguard"]
                width: parent.width

                Column {
                    id: vpnSection
                    width: parent.width
                    spacing: Theme.spacingM

                    StyledText {
                        text: I18n.tr("Unavailable")
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceVariantText
                        width: parent.width
                        horizontalAlignment: Text.AlignLeft
                        visible: !DMSNetworkService.vpnAvailable
                    }

                    Row {
                        width: parent.width
                        spacing: Theme.spacingM
                        visible: DMSNetworkService.vpnAvailable

                        StyledText {
                            text: {
                                if (!DMSNetworkService.connected)
                                    return I18n.tr("Disconnected");
                                const names = DMSNetworkService.activeNames || [];
                                if (names.length <= 1)
                                    return names[0] || I18n.tr("Connected");
                                return names[0] + " +" + (names.length - 1);
                            }
                            font.pixelSize: Theme.fontSizeSmall
                            color: DMSNetworkService.connected ? Theme.primary : Theme.surfaceVariantText
                            width: parent.width - vpnHeaderControls.width - Theme.spacingM
                            horizontalAlignment: Text.AlignLeft
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Row {
                            id: vpnHeaderControls
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Theme.spacingS

                            Rectangle {
                                height: 28
                                radius: 14
                                width: importVpnRow.width + Theme.spacingM * 2
                                color: importVpnArea.containsMouse ? Theme.primaryHoverLight : Theme.surfaceLight
                                opacity: VPNService.importing ? 0.5 : 1.0

                                Row {
                                    id: importVpnRow
                                    anchors.centerIn: parent
                                    spacing: Theme.spacingXS

                                    DankIcon {
                                        name: VPNService.importing ? "sync" : "add"
                                        size: Theme.fontSizeSmall
                                        color: Theme.primary
                                    }

                                    StyledText {
                                        text: I18n.tr("Import")
                                        font.pixelSize: Theme.fontSizeSmall
                                        color: Theme.primary
                                        font.weight: Font.Medium
                                    }
                                }

                                MouseArea {
                                    id: importVpnArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: VPNService.importing ? Qt.BusyCursor : Qt.PointingHandCursor
                                    enabled: !VPNService.importing
                                    onClicked: root.openVpnFileBrowser()
                                }
                            }

                            Rectangle {
                                height: 28
                                radius: 14
                                width: disconnectAllRow.width + Theme.spacingM * 2
                                color: disconnectAllArea.containsMouse ? Theme.errorHover : Theme.surfaceLight
                                visible: DMSNetworkService.connected
                                opacity: DMSNetworkService.isBusy ? 0.5 : 1.0

                                Row {
                                    id: disconnectAllRow
                                    anchors.centerIn: parent
                                    spacing: Theme.spacingXS

                                    DankIcon {
                                        name: "link_off"
                                        size: Theme.fontSizeSmall
                                        color: Theme.surfaceText
                                    }

                                    StyledText {
                                        text: I18n.tr("Disconnect")
                                        font.pixelSize: Theme.fontSizeSmall
                                        color: Theme.surfaceText
                                        font.weight: Font.Medium
                                    }
                                }

                                MouseArea {
                                    id: disconnectAllArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: DMSNetworkService.isBusy ? Qt.BusyCursor : Qt.PointingHandCursor
                                    enabled: !DMSNetworkService.isBusy
                                    onClicked: DMSNetworkService.disconnectAllActive()
                                }
                            }
                        }
                    }

                    Rectangle {
                        width: parent.width
                        height: 1
                        color: Theme.outlineStrong
                        visible: DMSNetworkService.vpnAvailable
                    }

                    Item {
                        width: parent.width
                        height: 100
                        visible: DMSNetworkService.vpnAvailable && DMSNetworkService.profiles.length === 0

                        Column {
                            anchors.centerIn: parent
                            spacing: Theme.spacingS

                            DankIcon {
                                name: "vpn_key_off"
                                size: 36
                                color: Theme.surfaceVariantText
                                anchors.horizontalCenter: parent.horizontalCenter
                            }

                            StyledText {
                                text: I18n.tr("No VPN profiles")
                                font.pixelSize: Theme.fontSizeMedium
                                color: Theme.surfaceVariantText
                                anchors.horizontalCenter: parent.horizontalCenter
                            }

                            StyledText {
                                text: I18n.tr("Click Import to add a .ovpn or .conf")
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceVariantText
                                anchors.horizontalCenter: parent.horizontalCenter
                            }
                        }
                    }

                    Column {
                        width: parent.width
                        spacing: Theme.spacingXS
                        visible: DMSNetworkService.vpnAvailable && DMSNetworkService.profiles.length > 0

                        Repeater {
                            model: DMSNetworkService.profiles

                            delegate: Rectangle {
                                id: vpnProfileRow
                                required property var modelData
                                required property int index

                                readonly property bool isActive: DMSNetworkService.isActiveVpnUuid(modelData.uuid)
                                readonly property bool isTransient: !!modelData.transient
                                readonly property bool canExpand: modelData.canExpand !== false
                                readonly property bool canDelete: modelData.canDelete !== false
                                readonly property bool isExpanded: root.expandedVpnUuid === modelData.uuid
                                readonly property var configData: (!isTransient && isExpanded) ? VPNService.editConfig : null

                                width: parent.width
                                height: isExpanded ? 56 + vpnExpandedContent.height : 56
                                radius: Theme.cornerRadius
                                color: vpnRowArea.containsMouse ? Theme.primaryHoverLight : (isActive ? Theme.primaryPressed : Theme.surfaceLight)
                                border.width: isActive ? 2 : 0
                                border.color: Theme.primary
                                opacity: DMSNetworkService.isBusy ? 0.6 : 1.0
                                clip: true

                                Behavior on height {
                                    NumberAnimation {
                                        duration: 150
                                        easing.type: Easing.OutQuad
                                    }
                                }

                                MouseArea {
                                    id: vpnRowArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: DMSNetworkService.isBusy ? Qt.BusyCursor : Qt.PointingHandCursor
                                    enabled: !DMSNetworkService.isBusy
                                    onClicked: DMSNetworkService.toggle(modelData.uuid)
                                }

                                Column {
                                    anchors.fill: parent
                                    anchors.margins: Theme.spacingS
                                    spacing: Theme.spacingS

                                    Row {
                                        width: parent.width
                                        height: 56 - Theme.spacingS * 2
                                        spacing: Theme.spacingS

                                        DankIcon {
                                            name: isActive ? "vpn_lock" : "vpn_key_off"
                                            size: 20
                                            color: isActive ? Theme.primary : Theme.surfaceText
                                            anchors.verticalCenter: parent.verticalCenter
                                        }

                                        Column {
                                            spacing: Theme.spacingXXS
                                            anchors.verticalCenter: parent.verticalCenter
                                            width: parent.width - 20 - ((canExpand ? 28 : 0) + (canDelete ? 28 : 0)) - Theme.spacingS * 4

                                            StyledText {
                                                text: modelData.name
                                                font.pixelSize: Theme.fontSizeMedium
                                                color: isActive ? Theme.primary : Theme.surfaceText
                                                elide: Text.ElideRight
                                                width: parent.width
                                                horizontalAlignment: Text.AlignLeft
                                            }

                                            StyledText {
                                                text: VPNService.getVpnTypeFromProfile(modelData)
                                                font.pixelSize: Theme.fontSizeSmall
                                                color: Theme.surfaceVariantText
                                                anchors.left: parent.left
                                            }
                                        }

                                        Item {
                                            width: Theme.spacingXS
                                            height: 1
                                        }

                                        Rectangle {
                                            width: 28
                                            height: 28
                                            radius: 14
                                            color: vpnExpandBtn.containsMouse ? Theme.surfacePressed : Theme.withAlpha(Theme.surfacePressed, 0)
                                            anchors.verticalCenter: parent.verticalCenter
                                            visible: canExpand

                                            DankIcon {
                                                anchors.centerIn: parent
                                                name: isExpanded ? "expand_less" : "expand_more"
                                                size: 18
                                                color: Theme.surfaceText
                                            }

                                            MouseArea {
                                                id: vpnExpandBtn
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    if (isExpanded) {
                                                        root.expandedVpnUuid = "";
                                                    } else {
                                                        root.expandedVpnUuid = modelData.uuid;
                                                        VPNService.getConfig(modelData.uuid);
                                                    }
                                                }
                                            }
                                        }

                                        Rectangle {
                                            width: 28
                                            height: 28
                                            radius: 14
                                            color: vpnDeleteBtn.containsMouse ? Theme.errorHover : Theme.withAlpha(Theme.errorHover, 0)
                                            anchors.verticalCenter: parent.verticalCenter
                                            visible: canDelete

                                            DankIcon {
                                                anchors.centerIn: parent
                                                name: "delete"
                                                size: 18
                                                color: vpnDeleteBtn.containsMouse ? Theme.error : Theme.surfaceVariantText
                                            }

                                            MouseArea {
                                                id: vpnDeleteBtn
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    root.deleteVpnConfirm.showWithOptions({
                                                        title: I18n.tr("Delete VPN"),
                                                        message: I18n.tr("Delete \"%1\"?").arg(modelData.name),
                                                        confirmText: I18n.tr("Delete"),
                                                        confirmColor: Theme.error,
                                                        onConfirm: () => VPNService.deleteVpn(modelData.uuid)
                                                    });
                                                }
                                            }
                                        }
                                    }

                                    Column {
                                        id: vpnExpandedContent
                                        width: parent.width
                                        spacing: Theme.spacingXS
                                        visible: !isTransient && isExpanded

                                        Rectangle {
                                            width: parent.width
                                            height: 1
                                            color: Theme.outlineLight
                                        }

                                        Item {
                                            width: parent.width
                                            height: VPNService.configLoading ? 40 : 0
                                            visible: VPNService.configLoading

                                            DankSpinner {
                                                anchors.centerIn: parent
                                                size: 20
                                            }
                                        }

                                        Flow {
                                            width: parent.width
                                            spacing: Theme.spacingXS
                                            visible: !VPNService.configLoading && configData

                                            Repeater {
                                                model: {
                                                    if (!configData)
                                                        return [];
                                                    const fields = [];
                                                    const data = configData.data || {};

                                                    if (data.remote)
                                                        fields.push({
                                                            label: I18n.tr("Server"),
                                                            value: data.remote
                                                        });
                                                    if (configData.username || data.username)
                                                        fields.push({
                                                            label: I18n.tr("Username"),
                                                            value: configData.username || data.username
                                                        });
                                                    if (data.cipher)
                                                        fields.push({
                                                            label: I18n.tr("Cipher"),
                                                            value: data.cipher
                                                        });
                                                    if (data.auth)
                                                        fields.push({
                                                            label: I18n.tr("Auth"),
                                                            value: data.auth
                                                        });
                                                    if (data["proto-tcp"] === "yes" || data["proto-tcp"] === "no")
                                                        fields.push({
                                                            label: I18n.tr("Protocol"),
                                                            value: data["proto-tcp"] === "yes" ? "TCP" : "UDP"
                                                        });
                                                    if (data["tunnel-mtu"])
                                                        fields.push({
                                                            label: I18n.tr("MTU"),
                                                            value: data["tunnel-mtu"]
                                                        });
                                                    if (data["connection-type"])
                                                        fields.push({
                                                            label: I18n.tr("Auth Type"),
                                                            value: data["connection-type"]
                                                        });
                                                    return fields;
                                                }

                                                delegate: Rectangle {
                                                    required property var modelData
                                                    required property int index

                                                    width: vpnFieldContent.width + Theme.spacingM * 2
                                                    height: 32
                                                    radius: Theme.cornerRadius - 2
                                                    color: Theme.floatingWindowFieldColor
                                                    border.width: 1
                                                    border.color: Theme.floatingWindowFieldBorderColor

                                                    Row {
                                                        id: vpnFieldContent
                                                        anchors.centerIn: parent
                                                        spacing: Theme.spacingXS

                                                        StyledText {
                                                            text: modelData.label + ":"
                                                            font.pixelSize: Theme.fontSizeSmall
                                                            color: Theme.surfaceVariantText
                                                            anchors.verticalCenter: parent.verticalCenter
                                                        }

                                                        StyledText {
                                                            text: modelData.value
                                                            font.pixelSize: Theme.fontSizeSmall
                                                            color: Theme.surfaceText
                                                            font.weight: Font.Medium
                                                            anchors.verticalCenter: parent.verticalCenter
                                                        }
                                                    }
                                                }
                                            }
                                        }

                                        DankToggle {
                                            width: parent.width
                                            text: I18n.tr("Autoconnect")
                                            checked: configData ? (configData.autoconnect || false) : false
                                            visible: !VPNService.configLoading && configData !== null
                                            onToggled: checked => {
                                                VPNService.updateConfig(modelData.uuid, {
                                                    autoconnect: checked
                                                });
                                            }
                                        }

                                        Item {
                                            width: 1
                                            height: Theme.spacingXS
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // Cellular Section
            SettingsCard {
                id: cellularCard
                title: I18n.tr("Cellular")
                iconName: "network_cell"
                settingKey: "networkCellular"
                tags: ["cellular", "mobile", "modem", "wwan", "lte", "gsm", "cdma", "network"]
                width: parent.width
                visible: (NetworkService.cellularDevices?.length ?? 0) > 0

                Column {
                    width: parent.width
                    spacing: Theme.spacingM

                    Row {
                        width: parent.width
                        spacing: Theme.spacingM

                        StyledText {
                            text: {
                                if (!NetworkService.cellularHardwareEnabled)
                                    return I18n.tr("Unavailable");
                                if (NetworkService.cellularToggling)
                                    return NetworkService.cellularEnabled ? I18n.tr("Disabling cellular...") : I18n.tr("Enabling cellular...");
                                if (!NetworkService.cellularEnabled)
                                    return I18n.tr("Disabled");
                                const devices = NetworkService.cellularDevices || [];
                                const connected = devices.filter(d => d.connected).length;
                                if (devices.length === 0)
                                    return I18n.tr("No devices found");
                                if (connected === 0)
                                    return I18n.tr("Disconnected");
                                return I18n.tr("%1 connected").arg(connected);
                            }
                            font.pixelSize: Theme.fontSizeSmall
                            color: NetworkService.cellularConnected ? Theme.primary : Theme.surfaceVariantText
                            width: parent.width - cellularControls.width - Theme.spacingM
                            horizontalAlignment: Text.AlignLeft
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Row {
                            id: cellularControls
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Theme.spacingS

                            DankToggle {
                                checked: NetworkService.cellularEnabled
                                enabled: NetworkService.cellularHardwareEnabled && !NetworkService.cellularToggling
                                onToggled: NetworkService.toggleCellularRadio()
                            }
                        }
                    }

                    Rectangle {
                        width: parent.width
                        height: 1
                        color: Theme.outlineStrong
                    }

                    Column {
                        width: parent.width
                        spacing: 4
                        visible: NetworkService.cellularEnabled && (NetworkService.cellularDevices?.length ?? 0) > 0

                        StyledText {
                            text: I18n.tr("Adapters")
                            font.pixelSize: Theme.fontSizeMedium
                            font.weight: Font.Medium
                            color: Theme.surfaceText
                            width: parent.width
                            horizontalAlignment: Text.AlignLeft
                        }

                        Repeater {
                            model: NetworkService.cellularDevices || []

                            delegate: Rectangle {
                                id: modemDelegate
                                required property var modelData

                                readonly property bool isConnected: modelData.connected || false

                                width: parent.width
                                height: 56
                                radius: Theme.cornerRadius
                                color: modemMouseArea.containsMouse ? Theme.primaryHoverLight : Theme.surfaceLight
                                border.width: isConnected ? 2 : 0
                                border.color: Theme.primary

                                Row {
                                    anchors.left: parent.left
                                    anchors.leftMargin: Theme.spacingM
                                    anchors.right: modemActions.left
                                    anchors.rightMargin: Theme.spacingS
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: Theme.spacingS

                                    DankIcon {
                                        name: "network_cell"
                                        size: 20
                                        color: modemDelegate.isConnected ? Theme.primary : Theme.surfaceText
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                    Column {
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 2
                                        width: parent.width - 20 - Theme.spacingS

                                        StyledText {
                                            text: modelData.name || I18n.tr("Unknown")
                                            font.pixelSize: Theme.fontSizeMedium
                                            color: modemDelegate.isConnected ? Theme.primary : Theme.surfaceText
                                            font.weight: modemDelegate.isConnected ? Font.Medium : Font.Normal
                                            elide: Text.ElideRight
                                            width: parent.width
                                            horizontalAlignment: Text.AlignLeft
                                        }

                                        StyledText {
                                            text: {
                                                const state = modelData.state || I18n.tr("Unknown");
                                                const ip = modelData.ip || "";
                                                return ip.length > 0 ? state + " • " + ip : state;
                                            }
                                            font.pixelSize: Theme.fontSizeSmall
                                            color: Theme.surfaceVariantText
                                            elide: Text.ElideRight
                                            width: parent.width
                                            horizontalAlignment: Text.AlignLeft
                                        }
                                    }
                                }

                                Row {
                                    id: modemActions
                                    anchors.right: parent.right
                                    anchors.rightMargin: Theme.spacingS
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: Theme.spacingXS

                                    Rectangle {
                                        width: 28
                                        height: 28
                                        radius: 14
                                        color: modemActionBtn.containsMouse ? (modemDelegate.isConnected ? Theme.errorHover : Theme.primaryHover) : "transparent"

                                        DankIcon {
                                            anchors.centerIn: parent
                                            name: modemDelegate.isConnected ? "link_off" : "link"
                                            size: 18
                                            color: modemActionBtn.containsMouse ? (modemDelegate.isConnected ? Theme.error : Theme.primary) : Theme.surfaceVariantText
                                        }

                                        MouseArea {
                                            id: modemActionBtn
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                if (modemDelegate.isConnected)
                                                    NetworkService.disconnectCellularDevice(modelData.name);
                                                else
                                                    NetworkService.connectCellular();
                                            }
                                        }
                                    }
                                }

                                MouseArea {
                                    id: modemMouseArea
                                    anchors.fill: parent
                                    anchors.rightMargin: modemActions.width + Theme.spacingM
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (modemDelegate.isConnected)
                                            NetworkService.disconnectCellularDevice(modelData.name);
                                        else
                                            NetworkService.connectCellular();
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // Cellular Saved Configurations
            SettingsCard {
                title: I18n.tr("Saved Configurations")
                iconName: "sim_card"
                settingKey: "networkCellularProfiles"
                tags: ["cellular", "mobile", "profile", "apn", "sim"]
                width: parent.width
                visible: NetworkService.cellularEnabled && (NetworkService.cellularConnections?.length ?? 0) > 0

                Column {
                    width: parent.width
                    spacing: 4

                    Repeater {
                        model: NetworkService.cellularConnections || []

                        delegate: Rectangle {
                            id: profileDelegate
                            required property var modelData

                            readonly property bool isActive: modelData.isActive || false

                            width: parent.width
                            height: 56
                            radius: Theme.cornerRadius
                            color: profileMouseArea.containsMouse ? Theme.primaryHoverLight : Theme.surfaceLight
                            border.color: isActive ? Theme.primary : Theme.outlineLight
                            border.width: isActive ? 2 : 1

                            Row {
                                anchors.left: parent.left
                                anchors.leftMargin: Theme.spacingM
                                anchors.right: profileAction.left
                                anchors.rightMargin: Theme.spacingS
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: Theme.spacingS

                                DankIcon {
                                    name: "sim_card"
                                    size: 20
                                    color: profileDelegate.isActive ? Theme.primary : Theme.surfaceText
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                Column {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: parent.width - 20 - Theme.spacingS
                                    spacing: 2

                                    StyledText {
                                        text: modelData.id || I18n.tr("Unknown")
                                        font.pixelSize: Theme.fontSizeMedium
                                        color: profileDelegate.isActive ? Theme.primary : Theme.surfaceText
                                        font.weight: profileDelegate.isActive ? Font.Medium : Font.Normal
                                        elide: Text.ElideRight
                                        width: parent.width
                                        horizontalAlignment: Text.AlignLeft
                                    }

                                    StyledText {
                                        text: profileDelegate.isActive ? I18n.tr("Connected") : (modelData.type || I18n.tr("Available"))
                                        font.pixelSize: Theme.fontSizeSmall
                                        color: Theme.surfaceVariantText
                                        width: parent.width
                                        horizontalAlignment: Text.AlignLeft
                                    }
                                }
                            }

                            DankActionButton {
                                id: profileAction
                                anchors.right: parent.right
                                anchors.rightMargin: Theme.spacingS
                                anchors.verticalCenter: parent.verticalCenter
                                iconName: profileDelegate.isActive ? "link_off" : "link"
                                buttonSize: 28
                                iconSize: 18
                                iconColor: profileDelegate.isActive ? Theme.error : Theme.primary
                                onClicked: {
                                    if (profileDelegate.isActive)
                                        NetworkService.toggleNetworkConnection("cellular");
                                    else
                                        NetworkService.connectToSpecificCellularConfig(modelData.uuid);
                                }
                            }

                            MouseArea {
                                id: profileMouseArea
                                anchors.fill: parent
                                anchors.rightMargin: profileAction.width + Theme.spacingS
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (!profileDelegate.isActive)
                                        NetworkService.connectToSpecificCellularConfig(modelData.uuid);
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}