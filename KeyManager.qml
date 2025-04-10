import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import Qt.labs.platform 1.1
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
    Button {
        id: backButton
        width: 120
        height: 40
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 20
        text: "返回"
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
            // Fixed navigation back to EnDeCode screen
            root.showEnDeCode()
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
            var keyType = ""

            if (keyName.endsWith(".key")) {
                keyName = keyName.substring(0, keyName.length - 4)
                keyType = "RSA"
            } else if (keyName.endsWith(".aeskey")) {
                keyName = keyName.substring(0, keyName.length - 7)
                keyType = "AES"
            }

            keyModel.append({"name": keyName, "type": keyType})
        }
    }

    // Main content without background image
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
                border.width: 1
                border.color: "#ECECED"
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

                                Column {
                                    Layout.fillWidth: true
                                    spacing: 4

                                    Text {
                                        width: parent.width
                                        text: model.name
                                        font.pixelSize: 16
                                        color: "#394149"
                                        elide: Text.ElideRight
                                    }

                                    Text {
                                        width: parent.width
                                        text: "类型: " + model.type
                                        font.pixelSize: 12
                                        color: "#626E7B"
                                        elide: Text.ElideRight
                                    }
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
                border.width: 1
                border.color: "#ECECED"
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

                    // Tab bar for key types
                    TabBar {
                        id: keyTypeTab
                        Layout.fillWidth: true

                        TabButton {
                            text: "RSA 密钥"
                            width: implicitWidth
                        }
                        TabButton {
                            text: "AES 密钥"
                            width: implicitWidth
                        }
                    }

                    StackLayout {
                        Layout.fillWidth: true
                        currentIndex: keyTypeTab.currentIndex

                        // RSA Key Generation
                        ColumnLayout {
                            spacing: 10

                            GroupBox {
                                Layout.fillWidth: true
                                title: "生成新RSA密钥对"

                                ColumnLayout {
                                    anchors.fill: parent
                                    spacing: 10

                                    TextField {
                                        id: newRsaKeyName
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
                                        id: newRsaKeyPassword
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
                                        id: confirmRsaKeyPassword
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
                                        text: "生成RSA密钥"
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
                                            if (newRsaKeyName.text.length === 0) {
                                                showStatus("请输入密钥名称")
                                                return
                                            }

                                            if (newRsaKeyPassword.text.length === 0) {
                                                showStatus("请输入密码")
                                                return
                                            }

                                            if (newRsaKeyPassword.text !== confirmRsaKeyPassword.text) {
                                                showStatus("两次输入的密码不一致")
                                                return
                                            }

                                            directoryHandler.generateRSAKeyPair(newRsaKeyName.text, newRsaKeyPassword.text)
                                            newRsaKeyName.text = ""
                                            newRsaKeyPassword.text = ""
                                            confirmRsaKeyPassword.text = ""
                                        }
                                    }
                                }
                            }
                        }

                        // AES Key Generation
                        ColumnLayout {
                            spacing: 10

                            GroupBox {
                                Layout.fillWidth: true
                                title: "生成新AES密钥"

                                ColumnLayout {
                                    anchors.fill: parent
                                    spacing: 10

                                    TextField {
                                        id: newAesKeyName
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
                                        id: newAesKeyPassword
                                        Layout.fillWidth: true
                                        placeholderText: "密码"
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
                                        id: confirmAesKeyPassword
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
                                        text: "生成AES密钥"
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
                                            if (newAesKeyName.text.length === 0) {
                                                showStatus("请输入密钥名称")
                                                return
                                            }

                                            if (newAesKeyPassword.text.length === 0) {
                                                showStatus("请输入密码")
                                                return
                                            }

                                            if (newAesKeyPassword.text !== confirmAesKeyPassword.text) {
                                                showStatus("两次输入的密码不一致")
                                                return
                                            }

                                            // Store AES key - we'll need to add this function to the CryptoManager
                                            directoryHandler.generateAESKey(newAesKeyName.text, newAesKeyPassword.text)
                                            newAesKeyName.text = ""
                                            newAesKeyPassword.text = ""
                                            confirmAesKeyPassword.text = ""
                                        }
                                    }
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

                            // Added file dialog for export path
                            FileDialog {
                                id: exportKeyDialog
                                title: "选择密钥导出位置"
                                folder: "file:///home"
                                nameFilters: ["Key files (*.key)"]
                                fileMode: FileDialog.SaveFile

                                onAccepted: {
                                    var path = file.toString();
                                    console.log("导出密钥 - 原始路径: " + path);
                                    
                                    if (path.startsWith("file:///")) {
                                        path = path.replace("file:///", "/");
                                    } else {
                                        path = path.replace(/^(file:\/{2,3})|(qrc:\/{2})|(http:\/{2})/,"");
                                    }
                                    
                                    console.log("导出密钥 - 处理后路径: " + path);
                                    exportPath.text = path
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true

                                TextField {
                                    id: exportPath
                                    Layout.fillWidth: true
                                    placeholderText: "密钥导出路径"
                                    font.pixelSize: 16
                                    selectByMouse: true
                                    background: Rectangle {
                                        radius: 5
                                        border.width: 1
                                        border.color: "#ECECED"
                                    }
                                }

                                Button {
                                    text: "浏览"
                                    onClicked: exportKeyDialog.open()
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

                            // Added file dialog for import path
                            FileDialog {
                                id: importKeyDialog
                                title: "选择要导入的密钥文件"
                                folder: "file:///home"
                                nameFilters: ["Key files (*.key)"]
                                fileMode: FileDialog.OpenFile

                                onAccepted: {
                                    var path = file.toString();
                                    console.log("导入密钥 - 原始路径: " + path);
                                    
                                    if (path.startsWith("file:///")) {
                                        path = path.replace("file:///", "/");
                                    } else {
                                        path = path.replace(/^(file:\/{2,3})|(qrc:\/{2})|(http:\/{2})/,"");
                                    }
                                    
                                    console.log("导入密钥 - 处理后路径: " + path);
                                    importFilePath.text = path
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true

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

                                Button {
                                    text: "浏览"
                                    onClicked: importKeyDialog.open()
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
    Window {
        id: deleteConfirmDialog
        width: 400
        height: 200
        flags: Qt.Dialog | Qt.WindowCloseButtonHint
        modality: Qt.ApplicationModal
        visible: false
        title: "确认删除"
        x: parent ? (parent.width - width) / 2 : 0
        y: parent ? (parent.height - height) / 2 : 0

        property string keyName: ""

        function open() {
            visible = true;
        }

        function close() {
            visible = false;
        }

        ColumnLayout {
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
