pragma Singleton

import QtQuick
import Quickshell
import qs.Common
import qs.Services

Singleton {
    readonly property var structure: [
        {
            "id": "wifi",
            "text": I18n.tr("Wifi"),
            "icon": "wifi",
            "svgIcon": "preferences-wifi.svg",
            "tabIndex": 40,
            "dmsOnly": true
        },
        {
            "id": "bluetooth",
            "text": I18n.tr("Bluetooth"),
            "icon": "bluetooth",
            "svgIcon": "preferences-bluetooth.svg",
            "tabIndex": 28
        },
        {
            "id": "network",
            "text": I18n.tr("Network"),
            "icon": "lan",
            "svgIcon": "preferences-network.svg",
            "dmsOnly": true,
            "tabIndex": 7
        },
        {
            "id": "battery",
            "text": I18n.tr("Battery"),
            "icon": "battery_charging_full",
            "svgIcon": "preferences-battery.svg",
            "tabIndex": 42
        },
        {
            "id": "divider1",
            "separator": true
        },
        {
            "id": "general",
            "text": I18n.tr("General"),
            "icon": "settings",
            "svgIcon": "preferences-general.svg",
            "collapsedByDefault": false,
            "children": [
                {
                    "id": "default_apps",
                    "text": I18n.tr("Default Apps"),
                    "icon": "star",
                    "svgIcon": "preferences-default-applications.svg",
                    "tabIndex": 34
                },
                {
                    "id": "running_apps",
                    "text": I18n.tr("Running Apps"),
                    "icon": "app_registration",
                    "tabIndex": 19,
                    "hyprlandNiriOnly": true
                },
                {
                    "id": "window_rules",
                    "text": I18n.tr("Window Rules"),
                    "icon": "select_window",
                    "tabIndex": 38,
                    "windowRulesCapable": true
                },
                {
                    "id": "locale",
                    "text": I18n.tr("Locale"),
                    "icon": "language",
                    "svgIcon": "preferences-locale.svg",
                    "tabIndex": 30
                },
                {
                    "id": "updater",
                    "text": I18n.tr("System Updater"),
                    "icon": "refresh",
                    "tabIndex": 20,
                    "updaterOnly": true
                },
                {
                    "id": "plugins",
                    "text": I18n.tr("Plugins"),
                    "icon": "extension",
                    "svgIcon": "preferences-plugins.svg",
                    "tabIndex": 12
                },
                {
                    "id": "about",
                    "text": I18n.tr("About"),
                    "icon": "info",
                    "svgIcon": "preferences-about.svg",
                    "tabIndex": 13
                },
                {
                    "id": "multiplexers",
                    "text": I18n.tr("Multiplexers"),
                    "icon": "terminal",
                    "tabIndex": 32
                }
            ]
        },
        {
            "id": "accessibility",
            "text": I18n.tr("Accessibility"),
            "icon": "accessibility",
            "svgIcon": "preferences-accessibility.svg",
            "tabIndex": 49
        },
        {
            "id": "appearance",
            "text": I18n.tr("Appearance"),
            "icon": "palette",
            "svgIcon": "preferences-appearance.svg",
            "children": [
                {
                    "id": "theme",
                    "text": I18n.tr("Theme & Colors"),
                    "icon": "format_paint",
                    "tabIndex": 10
                },
                {
                    "id": "typography",
                    "text": I18n.tr("Typography & Motion"),
                    "icon": "text_fields",
                    "tabIndex": 14
                },
                {
                    "id": "time_weather",
                    "text": I18n.tr("Time & Weather"),
                    "icon": "schedule",
                    "tabIndex": 1
                },
                {
                    "id": "sounds",
                    "text": I18n.tr("Sounds"),
                    "icon": "volume_up",
                    "tabIndex": 15,
                    "soundsOnly": true
                },
                {
                    "id": "compositor_layout",
                    "text": CompositorService.isNiri ? "Niri" : (CompositorService.isHyprland ? "Hyprland" : "MangoWC"),
                    "icon": "layers",
                    "tabIndex": 37,
                    "layoutCapable": true
                }
            ]
        },
        {
            "id": "topbar",
            "text": I18n.tr("TopBar"),
            "icon": "toolbar",
            "svgIcon": "preferences-topbar.svg",
            "children": [
                {
                    "id": "topbar_appearance",
                    "text": I18n.tr("Appearance"),
                    "icon": "palette",
                    "tabIndex": 6
                },
                {
                    "id": "topbar_settings",
                    "text": I18n.tr("General"),
                    "icon": "tune",
                    "tabIndex": 3
                },
                {
                    "id": "topbar_widgets",
                    "text": I18n.tr("Widgets"),
                    "icon": "widgets",
                    "tabIndex": 22
                },
                {
                    "id": "workspaces",
                    "text": I18n.tr("Workspaces"),
                    "icon": "view_module",
                    "tabIndex": 4
                },
                {
                    "id": "frame",
                    "text": I18n.tr("Frame"),
                    "icon": "frame_source",
                    "tabIndex": 33,
                    "frameOnly": true
                },
                {
                    "id": "dank_island",
                    "text": I18n.tr("Island"),
                    "icon": "view_in_ar",
                    "tabIndex": 46,
                    "islandOnly": true
                },
                {
                    "id": "dashboard",
                    "text": I18n.tr("Dashboard"),
                    "icon": "space_dashboard",
                    "tabIndex": 43
                }
            ]
        },
        {
            "id": "desktop_dock",
            "text": I18n.tr("Dock"),
            "icon": "dock_to_bottom",
            "svgIcon": "preferences-dock.svg",
            "tabIndex": 5
        },
        {
            "id": "display",
            "text": I18n.tr("Display"),
            "icon": "monitor",
            "svgIcon": "preferences-display.svg",
            "collapsedByDefault": true,
            "children": [
                {
                    "id": "display_config",
                    "text": I18n.tr("Configuration"),
                    "icon": "display_settings",
                    "tabIndex": 24
                },
                {
                    "id": "display_gamma",
                    "text": I18n.tr("Gamma Control"),
                    "icon": "brightness_6",
                    "tabIndex": 25
                },
                {
                    "id": "display_widgets",
                    "text": I18n.tr("Widgets", "settings_displays"),
                    "icon": "widgets",
                    "tabIndex": 26
                }
            ]
        },
        {
            "id": "spotlight",
            "text": I18n.tr("Spotlight"),
            "icon": "grid_view",
            "svgIcon": "preferences-spotlight.svg",
            "tabIndex": 9
        },
        {
            "id": "wallpaper",
            "text": I18n.tr("Wallpaper"),
            "icon": "wallpaper",
            "svgIcon": "preferences-wallpaper.svg",
            "tabIndex": 0
        },
        {
            "id": "divider_after_wallpaper",
            "separator": true
        },
        {
            "id": "notification",
            "text": I18n.tr("Notification"),
            "icon": "notifications",
            "svgIcon": "preferences-notification.svg",
            "tabIndex": 17
        },
        {
            "id": "sound",
            "text": I18n.tr("Sound"),
            "icon": "volume_up",
            "svgIcon": "preferences-sound.svg",
            "tabIndex": 29
        },
        {
            "id": "focus",
            "text": I18n.tr("Focus"),
            "icon": "do_not_disturb",
            "svgIcon": "preferences-focus.svg",
            "tabIndex": 50
        },
        {
            "id": "media_player",
            "text": I18n.tr("Media Player"),
            "icon": "music_note",
            "svgIcon": "preferences-media-player.svg",
            "tabIndex": 16
        },
        {
            "id": "divider_after_focus",
            "separator": true
        },
        {
            "id": "lock_screen",
            "text": I18n.tr("Lock Screen"),
            "icon": "lock",
            "svgIcon": "preferences-lockscreen.svg",
            "tabIndex": 11
        },
        {
            "id": "power_sleep",
            "text": I18n.tr("Power & Sleep"),
            "icon": "power_settings_new",
            "svgIcon": "preferences-power&sleep.svg",
            "tabIndex": 21
        },
        {
            "id": "privacy_security",
            "text": I18n.tr("Privacy & Security"),
            "icon": "security",
            "svgIcon": "preferences-privacy&security.svg",
            "tabIndex": 52
        },
        {
            "id": "users_groups",
            "text": I18n.tr("Users & Groups"),
            "icon": "manage_accounts",
            "svgIcon": "preferences-users.svg",
            "tabIndex": 35
        },
        {
            "id": "divider_after_users_groups",
            "separator": true
        },
        {
            "id": "widgets_notifications",
            "text": I18n.tr("Widgets & Notifications"),
            "icon": "dashboard",
            "collapsedByDefault": true,
            "children": [
                {
                    "id": "osd",
                    "text": I18n.tr("On-screen Displays"),
                    "icon": "tune",
                    "svgIcon": "preferencs-OSD.svg",
                    "tabIndex": 18
                },
                {
                    "id": "desktop_widgets",
                    "text": I18n.tr("Desktop Widgets"),
                    "icon": "widgets",
                    "tabIndex": 27
                }
            ]
        },
        {
            "id": "dock_launcher",
            "text": I18n.tr("Dock & Launcher"),
            "icon": "shelf_auto_hide",
            "collapsedByDefault": true,
            "children": []
        },
        {
            "id": "keybinds",
            "text": I18n.tr("Keyboard Shortcuts"),
            "icon": "keyboard",
            "tabIndex": 2,
            "shortcutsOnly": true
        },
        {
            "id": "applications",
            "text": I18n.tr("Applications"),
            "icon": "apps",
            "collapsedByDefault": true,
            "children": [
                {
                    "id": "autostart",
                    "text": I18n.tr("Autostart Apps"),
                    "icon": "line_start",
                    "tabIndex": 36,
                    "autostartOnly": true
                }
            ]
        },
        {
            "id": "system",
            "text": I18n.tr("System"),
            "icon": "memory",
            "collapsedByDefault": true,
            "children": [
                {
                    "id": "mouse_touchpad",
                    "text": I18n.tr("Mouse & Touchpad"),
                    "icon": "mouse",
                    "tabIndex": 44,
                    "niriOnly": true
                },
                {
                    "id": "keyboard",
                    "text": I18n.tr("Keyboard"),
                    "icon": "keyboard",
                    "tabIndex": 45,
                    "niriOnly": true
                },
                {
                    "id": "clipboard",
                    "text": I18n.tr("Clipboard"),
                    "icon": "content_paste",
                    "svgIcon": "preferences-clipboard.svg",
                    "tabIndex": 23,
                    "clipboardOnly": true
                },
                {
                    "id": "printers",
                    "text": I18n.tr("Printers"),
                    "icon": "print",
                    "tabIndex": 8,
                    "cupsOnly": true
                }
            ]
        },
        {
            "id": "power_security",
            "text": I18n.tr("Power & Security"),
            "icon": "security",
            "collapsedByDefault": true,
            "children": [
                {
                    "id": "greeter",
                    "text": I18n.tr("Greeter"),
                    "icon": "login",
                    "tabIndex": 31,
                    "greeterOnly": true
                }
            ]
        }
    ]
}