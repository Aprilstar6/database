import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import com.directory 1.0

Item {
    id: keyManager
    anchors.fill: parent

    property ListModel keyModel: ListModel {
        // Will be populated dynamically
    }

    // Signal to refresh the key list
    signal refreshKeys()

    DirectoryHandler {
        id: directoryHandler

        onOperationComplete: {
            root.showStatus(message)
            refreshKeyList()
        }
    }

    // Back button to return to encryption screen
    Rectangle {
        width: 120
        height: 40
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 20
        radius: 5
        color: "#E74C3C"

        Text {
            anchors.centerIn: parent
            text: "返回"
            font.pixelSize: 16
            color: "white"
        }

        MouseArea {
            anchors.fill: parent
            onClicked: {
                root.showEnDeCode()
            }
        }
    }

    Component.onCompleted: {
        refreshKeyList()
    }

    onRefreshKeys: {
        refreshKeyList()
    }

    function refreshKeyList() {
        keyModel.clear()
        var keys = directoryHandler.getKeyList()
        for (var i = 0; i < keys.length; i++) {
            var keyName = keys[i]
            if (keyName.endsWith(".key")) {
                keyName = keyName.substring(0, keyName.length - 4)
            }
            keyModel.append({"name": keyName})
        }
    }

    Image {
        // Background image
        anchors.fill: parent
        source: "qrc:/img/bg.jpg"
        fillMode: Image.PreserveAspectCrop
    }

    Rectangle {
        // Semi-transparent overlay
        anchors.fill: parent
        color: "#172227"
        opacity: 0.7
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 20

        Rectangle {
            Layout.fillWidth: true
            height: 60
            color: "#5FAAE3"
            radius: 10

            Text {
                anchors.centerIn: parent
                text: "密钥管理"
                font.pixelSize: 26
                font.bold: true
                color: "white"
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: parent.height - 80
            spacing: 20

            // Left side - Key list
            Rectangle {
                Layout.preferredWidth: parent.width * 0.4
                Layout.fillHeight: true
                color: "#FFFFFF"
                opacity: 0.9
                radius: 10

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 10

                    Text {
                        text: "密钥列表"
                        font.pixelSize: 20
                        font.bold: true
                        color: "#394149"
                    }

                    ListView {
                        id: keyListView
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        model: keyModel
                        clip: true

                        delegate: Rectangle {
                            width: keyListView.width
                            height: 60
                            color: ListView.isCurrentItem ? "#E0F4FF" : "transparent"
                            border.width: 1
                            border.color: "#ECECED"
                            radius: 5

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 10
                                spacing: 10

                                Image {
                                    Layout.preferredWidth: 40
                                    Layout.preferredHeight: 40
                                    source: "qrc:/img/ic_lock.png"
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: model.name
                                    font.pixelSize: 16
                                    color: "#394149"
                                    elide: Text.ElideRight
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                onClicked: {
                                    keyListView.currentIndex = index
                                }
                            }
                        }
                    }
                }
            }

            // Right side - Key operations
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: "#FFFFFF"
                opacity: 0.9
                radius: 10

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 20
                    spacing: 20

                    Text {
                        text: "密钥操作"
                        font.pixelSize: 20
                        font.bold: true
                        color: "#394149"
                    }

                    // Generate new key section
                    GroupBox {
                        Layout.fillWidth: true
                        title: "生成新RSA密钥对"

                        ColumnLayout {
                            anchors.fill: parent
                            spacing: 10

                            TextField {
                                id: newKeyName
                                Layout.fillWidth: true
                                placeholderText: "密钥名称"
                                font.pixelSize: 16
                                selectByMouse: true
                                background: Rectangle {
                                    radius: 5
                                    border.width: 1
                                    border.color: "#ECECED"
                                }
                            }

                            TextField {
                                id: newKeyPassword
                                Layout.fillWidth: true
                                placeholderText: "密码 (用于保护私钥)"
                                font.pixelSize: 16
                                selectByMouse: true
                                echoMode: TextInput.Password
                                background: Rectangle {
                                    radius: 5
                                    border.width: 1
                                    border.color: "#ECECED"
                                }
                            }

                            TextField {
                                id: confirmKeyPassword
                                Layout.fillWidth: true
                                placeholderText: "确认密码"
                                font.pixelSize: 16
                                selectByMouse: true
                                echoMode: TextInput.Password
                                background: Rectangle {
                                    radius: 5
                                    border.width: 1
                                    border.color: "#ECECED"
                                }
                            }

                            Button {
                                Layout.fillWidth: true
                                text: "生成密钥"
                                font.pixelSize: 16
                                height: 40

                                background: Rectangle {
                                    radius: 5
                                    gradient: Gradient {
                                        orientation: Gradient.Horizontal
                                        GradientStop { position: 0.0; color: "#02C783"}
                                        GradientStop { position: 1.0; color: "#31D7A9" }
                                    }
                                }

                                contentItem: Text {
                                    text: parent.text
                                    font: parent.font
                                    color: "white"
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }

                                onClicked: {
                                    if (newKeyName.text.length === 0) {
                                        showStatus("请输入密钥名称")
                                        return
                                    }

                                    if (newKeyPassword.text.length === 0) {
                                        showStatus("请输入密码")
                                        return
                                    }

                                    if (newKeyPassword.text !== confirmKeyPassword.text) {
                                        showStatus("两次输入的密码不一致")
                                        return
                                    }

                                    directoryHandler.generateRSAKeyPair(newKeyName.text, newKeyPassword.text)
                                    newKeyName.text = ""
                                    newKeyPassword.text = ""
                                    confirmKeyPassword.text = ""
                                }
                            }
                        }
                    }

                    // Key actions section
                    GroupBox {
                        Layout.fillWidth: true
                        title: "操作选定的密钥"
                        enabled: keyListView.currentIndex >= 0

                        ColumnLayout {
                            anchors.fill: parent
                            spacing: 10

                            Text {
                                text: keyListView.currentIndex >= 0 ?
                                      "当前选择: " + keyModel.get(keyListView.currentIndex).name :
                                      "未选择密钥"
                                font.pixelSize: 16
                                color: "#394149"
                            }

                            TextField {
                                id: exportPath
                                Layout.fillWidth: true
                                placeholderText: "导出路径 (包含文件名)"
                                font.pixelSize: 16
                                selectByMouse: true
                                background: Rectangle {
                                    radius: 5
                                    border.width: 1
                                    border.color: "#ECECED"
                                }
                            }

                            TextField {
                                id: exportPassword
                                Layout.fillWidth: true
                                placeholderText: "导出密码"
                                font.pixelSize: 16
                                selectByMouse: true
                                echoMode: TextInput.Password
                                background: Rectangle {
                                    radius: 5
                                    border.width: 1
                                    border.color: "#ECECED"
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 10

                                Button {
                                    Layout.fillWidth: true
                                    text: "导出密钥"
                                    font.pixelSize: 16
                                    height: 40

                                    background: Rectangle {
                                        radius: 5
                                        color: "#5FAAE3"
                                    }

                                    contentItem: Text {
                                        text: parent.text
                                        font: parent.font
                                        color: "white"
                                        horizontalAlignment: Text.AlignHCenter
                                        verticalAlignment: Text.AlignVCenter
                                    }

                                    onClicked: {
                                        if (keyListView.currentIndex < 0) {
                                            showStatus("请先选择一个密钥")
                                            return
                                        }

                                        if (exportPath.text.length === 0) {
                                            showStatus("请输入导出路径")
                                            return
                                        }

                                        if (exportPassword.text.length === 0) {
                                            showStatus("请输入导出密码")
                                            return
                                        }

                                        var keyName = keyModel.get(keyListView.currentIndex).name
                                        directoryHandler.exportKey(keyName, exportPath.text, exportPassword.text)
                                        exportPath.text = ""
                                        exportPassword.text = ""
                                    }
                                }

                                Button {
                                    Layout.fillWidth: true
                                    text: "删除密钥"
                                    font.pixelSize: 16
                                    height: 40

                                    background: Rectangle {
                                        radius: 5
                                        color: "#E74C3C"
                                    }

                                    contentItem: Text {
                                        text: parent.text
                                        font: parent.font
                                        color: "white"
                                        horizontalAlignment: Text.AlignHCenter
                                        verticalAlignment: Text.AlignVCenter
                                    }

                                    onClicked: {
                                        if (keyListView.currentIndex < 0) {
                                            showStatus("请先选择一个密钥")
                                            return
                                        }

                                        deleteConfirmDialog.keyName = keyModel.get(keyListView.currentIndex).name
                                        deleteConfirmDialog.open()
                                    }
                                }
                            }
                        }
                    }

                    // Import key section
                    GroupBox {
                        Layout.fillWidth: true
                        title: "导入密钥"

                        ColumnLayout {
                            anchors.fill: parent
                            spacing: 10

                            TextField {
                                id: importFilePath
                                Layout.fillWidth: true
                                placeholderText: "密钥文件路径"
                                font.pixelSize: 16
                                selectByMouse: true
                                background: Rectangle {
                                    radius: 5
                                    border.width: 1
                                    border.color: "#ECECED"
                                }
                            }

                            TextField {
                                id: importFilePassword
                                Layout.fillWidth: true
                                placeholderText: "密钥密码"
                                font.pixelSize: 16
                                selectByMouse: true
                                echoMode: TextInput.Password
                                background: Rectangle {
                                    radius: 5
                                    border.width: 1
                                    border.color: "#ECECED"
                                }
                            }

                            Button {
                                Layout.fillWidth: true
                                text: "导入密钥"
                                font.pixelSize: 16
                                height: 40

                                background: Rectangle {
                                    radius: 5
                                    gradient: Gradient {
                                        orientation: Gradient.Horizontal
                                        GradientStop { position: 0.0; color: "#1AB3F7"}
                                        GradientStop { position: 1.0; color: "#6069FF" }
                                    }
                                }

                                contentItem: Text {
                                    text: parent.text
                                    font: parent.font
                                    color: "white"
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }

                                onClicked: {
                                    if (importFilePath.text.length === 0) {
                                        showStatus("请输入密钥文件路径")
                                        return
                                    }

                                    if (importFilePassword.text.length === 0) {
                                        showStatus("请输入密钥密码")
                                        return
                                    }

                                    directoryHandler.importKey(importFilePath.text, importFilePassword.text)
                                    importFilePath.text = ""
                                    importFilePassword.text = ""
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // Use the main window's status popup instead
    function showStatus(message) {
        root.showStatus(message)
    }

    // Delete confirmation dialog
    Dialog {
        id: deleteConfirmDialog
        anchors.centerIn: parent
        width: 400
        height: 200
        modal: true
        title: "确认删除"

        property string keyName: ""

        contentItem: ColumnLayout {
            anchors.fill: parent
            anchors.margins: 20
            spacing: 20

            Text {
                Layout.fillWidth: true
                text: "确定要删除密钥 \"" + deleteConfirmDialog.keyName + "\" 吗？此操作不可撤销。"
                wrapMode: Text.WordWrap
                font.pixelSize: 16
                color: "#394149"
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                Button {
                    Layout.fillWidth: true
                    text: "取消"
                    font.pixelSize: 16

                    onClicked: {
                        deleteConfirmDialog.close()
                    }
                }

                Button {
                    Layout.fillWidth: true
                    text: "删除"
                    font.pixelSize: 16

                    background: Rectangle {
                        radius: 5
                        color: "#E74C3C"
                    }

                    contentItem: Text {
                        text: parent.text
                        font: parent.font
                        color: "white"
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }

                    onClicked: {
                        directoryHandler.deleteKey(deleteConfirmDialog.keyName)
                        deleteConfirmDialog.close()
                    }
                }
            }
        }
    }
}
