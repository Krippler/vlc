
/*****************************************************************************
 * Copyright (C) 2023 VLC authors and VideoLAN
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * ( at your option ) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston MA 02110-1301, USA.
 *****************************************************************************/
import QtQuick
import QtQuick.Templates as T
import QtQuick.Layouts
import QtQml.Models


import VLC.MainInterface
import VLC.Style
import VLC.Player
import VLC.Widgets as Widgets
import VLC.Util
import VLC.Dialogs

ColumnLayout {
    id: root

    readonly property ColorContext colorContext: ColorContext {
        id: theme

        colorSet: ColorContext.View
    }

    //FIXME make TrackMenuController a proper type (see TrackMenu)
    required property QtObject trackMenuController

    // the tracks are presented as a compact card, with one tab per track category
    property int preferredWidth: VLCStyle.dp(400, VLCStyle.scale)

    spacing: 0

    focus: true

    onActiveFocusChanged: if (activeFocus) tabBar.forceActiveFocus()

    // Tabs

    Widgets.NavigableRow {
        id: tabBar

        // index of the displayed tab
        property int selectedIndex: 0

        Layout.fillWidth: true

        focus: true

        Navigation.parentItem: root
        Navigation.downItem: stack.children[tabBar.selectedIndex]

        TrackTabButton {
            index: 0
            iconTxt: VLCIcons.audiosub
            text: qsTr("Subtitles")
        }

        TrackTabButton {
            index: 1
            iconTxt: VLCIcons.topbar_music
            text: qsTr("Audio")
        }

        TrackTabButton {
            index: 2
            iconTxt: VLCIcons.topbar_video
            text: qsTr("Video")
        }
    }

    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: VLCStyle.border

        color: theme.separator
    }

    // Pages

    StackLayout {
        id: stack

        Layout.fillWidth: true
        Layout.fillHeight: true

        currentIndex: tabBar.selectedIndex

        TrackList {
            title: qsTr("Subtitle")
            tracksModel: Player.subtitleTracks
            menuIcon: VLCIcons.expand
            menuText: qsTr("Menu")
            onMenuAction: (menuPos)  => {
                menuSubtitle.popup(menuPos)
            }
        }

        TrackList {
            title: qsTr("Audio")
            tracksModel: Player.audioTracks
            menuIcon: VLCIcons.expand
            menuText: qsTr("Menu")
            onMenuAction: (menuPos)  => {
                menuAudio.popup(menuPos)
            }
        }

        TrackList {
            title: qsTr("Video Tracks")
            tracksModel: Player.videoTracks
            menuIcon: VLCIcons.add
            menuText: qsTr("Add")
            onMenuAction: (menuPos) => {
                DialogsProvider.loadVideoFile()
            }
        }
    }

    // Footer

    Widgets.ButtonExt {
        id: playbackBtn

        Layout.fillWidth: true
        Layout.margins: VLCStyle.margin_xsmall

        text: qsTr("Playback Speed: %1x").arg(+Player.rate.toFixed(2))

        onClicked: {
            trackMenuController.requestPlaybackSpeedPage()
        }

        Navigation.parentItem: root
        Navigation.upItem: stack.children[tabBar.selectedIndex]

        background: Rectangle {
            radius: VLCStyle.button_radius

            color: (playbackBtn.hovered || playbackBtn.visualFocus) ? Qt.alpha(theme.fg.primary, 0.1)
                                                                    : Qt.alpha(theme.fg.primary, 0.05)

            border.color: playbackBtn.visualFocus ? theme.visualFocus : "transparent"
        }
    }

    component TrackTabButton: T.TabButton {
        id: tabButton

        required property int index
        property string iconTxt: ""

        implicitWidth: Math.max(implicitBackgroundWidth + leftInset + rightInset,
                                implicitContentWidth + leftPadding + rightPadding)
        implicitHeight: Math.max(implicitBackgroundHeight + topInset + bottomInset,
                                 implicitContentHeight + topPadding + bottomPadding)

        width: tabBar.width / 3

        padding: VLCStyle.margin_small

        checked: (tabBar.selectedIndex === index)
        focusPolicy: Qt.StrongFocus

        Accessible.role: Accessible.PageTab
        Accessible.name: text

        onClicked: tabBar.selectedIndex = index

        Keys.priority: Keys.AfterItem
        Keys.onPressed: (event) => Navigation.defaultKeyAction(event)

        Navigation.parentItem: tabBar

        readonly property ColorContext colorContext: ColorContext {
            id: tabTheme

            colorSet: ColorContext.TabButton

            focused: tabButton.visualFocus
            hovered: tabButton.hovered
            pressed: tabButton.down
            enabled: tabButton.enabled
        }

        background: Item {
            Rectangle {
                anchors.fill: parent

                radius: VLCStyle.button_radius

                color: tabTheme.bg.primary
                border.color: tabButton.visualFocus ? tabTheme.visualFocus : "transparent"
            }

            // underline of the current tab
            Rectangle {
                anchors.bottom: parent.bottom
                anchors.horizontalCenter: parent.horizontalCenter

                width: parent.width - 2 * VLCStyle.margin_small
                height: VLCStyle.heightBar_xxxsmall

                visible: tabButton.checked

                color: tabTheme.accent
            }
        }

        contentItem: Item {
            implicitWidth: tabRow.implicitWidth
            implicitHeight: tabRow.implicitHeight

            Row {
                id: tabRow

                anchors.centerIn: parent

                spacing: VLCStyle.margin_xsmall

                Widgets.IconLabel {
                    anchors.verticalCenter: parent.verticalCenter

                    text: tabButton.iconTxt
                    color: tabButton.checked ? tabTheme.accent : tabTheme.fg.primary

                    font.pixelSize: VLCStyle.icon_track
                }

                Widgets.ListLabel {
                    anchors.verticalCenter: parent.verticalCenter

                    text: tabButton.text
                    color: tabButton.checked ? tabTheme.fg.secondary : tabTheme.fg.primary

                    // button text is already exposed
                    Accessible.ignored: true
                }
            }
        }
    }

    component TrackList: T.Container {
        // wrap the contentItem i.e Column into Container
        // so that we can get focusReason, also Container
        // is a FocusScope
        id: tracksListContainer

        required property string title
        required property var tracksModel
        required property string menuIcon
        required property string menuText

        signal menuAction(point position)

        focus: true

        onActiveFocusChanged: if (activeFocus) tracksList.forceActiveFocus(focusReason)

        // this is required to initialize attached Navigation property
        Navigation.parentItem: root
        Navigation.upItem: tabBar
        Navigation.downItem: playbackBtn

        contentItem: Column {
            focus: true

            Accessible.role: Accessible.Pane
            Accessible.name: tracksListContainer.title

            Item {
                id: header

                width: tracksListContainer.width
                height: Math.max(caption.implicitHeight, button.implicitHeight) + VLCStyle.margin_xsmall * 2

                Widgets.CaptionLabel {
                    id: caption

                    anchors.left: parent.left
                    anchors.leftMargin: VLCStyle.margin_normal
                    anchors.verticalCenter: parent.verticalCenter

                    text: qsTr("Embedded Tracks")
                    color: theme.fg.secondary
                }

                Widgets.IconTrackButton {
                    id: button

                    anchors.right: parent.right
                    anchors.rightMargin: VLCStyle.margin_xsmall
                    anchors.verticalCenter: parent.verticalCenter

                    font.pixelSize: VLCStyle.icon_track

                    focus: true

                    description: tracksListContainer.menuText
                    text: tracksListContainer.menuIcon

                    Navigation.parentItem: tracksListContainer
                    Navigation.downItem: tracksList

                    onClicked: {
                        tracksListContainer.menuAction(mapToGlobal(0, height))
                    }
                }
            }

            Widgets.ListViewExt {
                id: tracksList

                model: tracksListContainer.tracksModel
                width: tracksListContainer.width
                height: tracksListContainer.height - header.height
                focus: true
                clip: !fadingEdge.implicitClipping && (height < contentHeight)

                fadingEdge.backgroundColor: "transparent"

                Accessible.role: Accessible.List
                Accessible.name: qsTr("Track list")

                Navigation.parentItem: tracksListContainer
                Navigation.upItem: button
                Keys.priority: Keys.AfterItem
                Keys.onPressed: (event) => Navigation.defaultKeyAction(event)

                delegate: Widgets.CheckedDelegate {
                    readonly property bool isModelChecked: model.checked
                    clip: true

                    focus: true
                    text: model.display
                    width: tracksList.width
                    height: VLCStyle.dp(40, VLCStyle.scale)
                    leftPadding: VLCStyle.margin_normal
                    font.pixelSize: VLCStyle.fontSize_normal
                    checkColor: theme.accent
                    opacity: hovered || activeFocus || checked ? 1 : .7

                    onIsModelCheckedChanged: {
                        if (model.checked !== checked)
                            checked = model.checked
                    }

                    onCheckedChanged: {
                        if (model.checked !== checked)
                            model.checked = checked
                    }

                    onClicked: {
                        tracksList.currentIndex = index
                        tracksList.setCurrentItemFocus(Qt.MouseFocusReason)
                    }

                    Navigation.parentItem: tracksList
                }

                Widgets.ListLabel {
                    anchors.left: parent.left
                    anchors.leftMargin: VLCStyle.margin_normal
                    anchors.top: parent.top
                    anchors.topMargin: VLCStyle.margin_small

                    visible: (tracksList.count === 0)

                    text: qsTr("No tracks")
                    color: theme.fg.secondary
                }
            }
        }
    }

    QmlSubtitleMenu {
        id: menuSubtitle

        player: Player
        ctx: MainCtx

        onTriggered: {
            if (action === QmlSubtitleMenu.Open) {
                DialogsProvider.loadSubtitlesFile()
            }
            else if (action === QmlSubtitleMenu.Synchronize) {
                trackMenuController.requestSubtitlePage()
            }
            else if (action === QmlSubtitleMenu.Download) {
                Player.openVLsub()
            }
        }
    }

    QmlAudioMenu {
        id: menuAudio

        ctx: MainCtx

        onTriggered: {
            if (action === QmlSubtitleMenu.Open) {
                DialogsProvider.loadAudioFile()
            }
            else if (action === QmlSubtitleMenu.Synchronize) {
                trackMenuController.requestAudioPage()
            }
        }
    }
}
