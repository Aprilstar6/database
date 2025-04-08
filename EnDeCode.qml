import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import com.directory 1.0

Item {
    id: enDeCode
    anchors.fill: parent

    // File selection properties
    property int selectIndex: -1
    property string selectName: ""
    property ListModel fileModel: ListModel {
        // Will be populated dynamically
    }

    // Encryption settings
    property int encryptionMethod: 0 // 0 = Legacy XOR, 1 = AES Password, 2 = RSA, 3 = Hybrid AES+RSA

    Component.onCompleted: {
        refreshFileList()
    }

    function refreshFileList() {
        fileModel.clear()
        directoryHandler.listFiles(root.filePath, [".txt", ".jpg", ".png", ".pdf", ".doc", ".docx", ".xls", ".xlsx", ".aes", ".rsa", ".enc"])
    }

    Connections {
        target: directoryHandler

        function onFileNameSignal(name, time) {
            fileModel.append({"name": name, "time": time})
        }

        function onOperationComplete(success, message) {
            showStatus(message)

            if (success) {
                refreshFileList()
            }
        }
    }

    DirectoryHandler {
        id: directoryHandler
    }

    MouseArea {
        anchors.fill: parent
        // Empty mouse area to prevent clicks from passing through
    }

    Image {
        anchors.fill: parent
        source: "qrc:/img/codebg.jpg"
        fillMode: Image.PreserveAspectCrop
    }

    Rectangle {
        anchors.fill: parent
        color: "#172227"
        opacity: 0.5
    }

    // Top bar with encryption settings
    Rectangle {
        id: topBar
        width: parent.width
        height: parent.height * 0.15
        color: "transparent"

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 10
            spacing: 10

            // Title and navigation
            RowLayout {
                Layout.fillWidth: true
                height: 40
                spacing: 10

                Text {
                    Layout.fillWidth: true
                    text: "文件加解密"
                    font.pixelSize: 26
                    font.bold: true
                    color: "white"
                }

                Button {
                    text: "密钥管理"
                    font.pixelSize: 16

                    background: Rectangle {
                        radius: 5
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0.0; color: "#5FAAE3"}
                            GradientStop { position: 1.0; color: "#3498DB" }
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
                        root.showKeyManager()
                    }
                }

                Button {
                    text: "退出登录"
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
                        root.showLogin()
                    }
                }
            }

            // Encryption settings
            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 20

                // Encryption method selection
                GroupBox {
                    title: "加密方式"
                    Layout.preferredWidth: parent.width * 0.3
                    Layout.fillHeight: true

                    ColumnLayout {
                        anchors.fill: parent
                        spacing: 5

                        RadioButton {
                            id: legacyXORRadio
                            text: "传统 XOR 加密 (兼容旧版)"
                            checked: encryptionMethod === 0
                            onCheckedChanged: if(checked) encryptionMethod = 0
                        }

                        RadioButton {
                            id: aesRadio
                            text: "AES 密码加密 (高安全性)"
                            checked: encryptionMethod === 1
                            onCheckedChanged: if(checked) encryptionMethod = 1
                        }

                        RadioButton {
                            id: rsaRadio
                            text: "RSA 公钥加密 (适合小文件)"
                            checked: encryptionMethod === 2
                            onCheckedChanged: if(checked) encryptionMethod = 2
                        }

                        RadioButton {
                            id: hybridRadio
                            text: "混合 AES+RSA 加密 (高安全性+高性能)"
                            checked: encryptionMethod === 3
                            onCheckedChanged: if(checked) encryptionMethod = 3
                        }
                    }
                }

                // Key/Password input
                GroupBox {
                    title: encryptionMethod <= 1 ? "密码" : "密钥设置"
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    GridLayout {
                        anchors.fill: parent
                        columns: 2
                        rowSpacing: 10
                        columnSpacing: 10

                        // Password field (for XOR and AES)
                        Text {
                            visible: encryptionMethod <= 1
                            text: "加密密码："
                            font.pixelSize: 16
                            color: "#FFFFFF"
                            Layout.alignment: Qt.AlignRight
                        }

                        TextField {
                            id: passwordField
                            visible: encryptionMethod <= 1
                            Layout.fillWidth: true
                            placeholderText: "请输入密码"
                            echoMode: TextInput.Password
                            selectByMouse: true
                            font.pixelSize: 16

                            background: Rectangle {
                                radius: 5
                                color: "#FFFFFF"
                                border.color: "#CCCCCC"
                                border.width: 1
                            }
                        }

                        // RSA Key Selection (for RSA and Hybrid)
                        Text {
                            visible: encryptionMethod >= 2
                            text: "选择密钥："
                            font.pixelSize: 16
                            color: "#FFFFFF"
                            Layout.alignment: Qt.AlignRight
                        }

                        ComboBox {
                            id: keySelector
                            visible: encryptionMethod >= 2
                            Layout.fillWidth: true
                            model: []
                            textRole: "name"

                            background: Rectangle {
                                radius: 5
                                color: "#FFFFFF"
                                border.color: "#CCCCCC"
                                border.width: 1
                            }

                            Component.onCompleted: {
                                refreshKeyList()
                            }

                            function refreshKeyList() {
                                var keyList = directoryHandler.getKeyList()
                                var keys = []

                                for (var i = 0; i < keyList.length; i++) {
                                    var keyName = keyList[i]
                                    if (keyName.endsWith(".key")) {
                                        keyName = keyName.substring(0, keyName.length - 4)
                                    }
                                    keys.push({"name": keyName})
                                }

                                model = keys
                            }
                        }

                        // RSA Private Key Password (for decryption)
                        Text {
                            visible: encryptionMethod >= 2
                            text: "私钥密码："
                            font.pixelSize: 16
                            color: "#FFFFFF"
                            Layout.alignment: Qt.AlignRight
                        }

                        TextField {
                            id: keyPasswordField
                            visible: encryptionMethod >= 2
                            Layout.fillWidth: true
                            placeholderText: "解密时需要的私钥密码"
                            echoMode: TextInput.Password
                            selectByMouse: true
                            font.pixelSize: 16

                            background: Rectangle {
                                radius: 5
                                color: "#FFFFFF"
                                border.color: "#CCCCCC"
                                border.width: 1
                            }
                        }

                        // Output filename
                        Text {
                            text: "输出文件名："
                            font.pixelSize: 16
                            color: "#FFFFFF"
                            Layout.alignment: Qt.AlignRight
                        }

                        TextField {
                            id: outputFilename
                            Layout.fillWidth: true
                            placeholderText: "输出文件名 (留空则自动生成)"
                            selectByMouse: true
                            font.pixelSize: 16

                            background: Rectangle {
                                radius: 5
                                color: "#FFFFFF"
                                border.color: "#CCCCCC"
                                border.width: 1
                            }
                        }
                    }
                }
            }
        }
    }

    // File browser and action buttons
    Item {
        anchors.top: topBar.bottom
        width: parent.width
        height: parent.height - topBar.height

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 10
            spacing: 10

            // File browser title
            Text {
                text: "文件浏览"
                font.pixelSize: 20
                font.bold: true
                color: "white"
            }

            // File grid
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: "#FFFFFF"
                opacity: 0.9
                radius: 10

                GridView {
                    id: gridView
                    anchors.fill: parent
                    anchors.margins: 10
                    clip: true
                    cellWidth: width / 6
                    cellHeight: cellWidth * 1.2
                    model: fileModel

                    delegate: Item {
                        width: gridView.cellWidth
                        height: gridView.cellHeight

                        Rectangle {
                            width: gridView.cellWidth * 0.9
                            height: gridView.cellHeight * 0.9
                            anchors.centerIn: parent
                            radius: 10
                            color: selectIndex === index ? "#FFD7A9" : "#F5F5F5"
                            border.width: 1
                            border.color: selectIndex === index ? "#E67E22" : "#ECECED"

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 5
                                spacing: 5

                                // File icon
                                Item {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: parent.height * 0.6

                                    Image {
                                        anchors.centerIn: parent
                                        width: parent.width * 0.8
                                        height: parent.height * 0.8
                                        source: "qrc:/img/file.jpg"
                                        fillMode: Image.PreserveAspectFit
                                    }
                                }

                                // File name
                                Text {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    text: model.name
                                    elide: Text.ElideRight
                                    wrapMode: Text.Wrap
                                    horizontalAlignment: Text.AlignHCenter
                                    font.pixelSize: 14
                                    color: "#394149"
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                onClicked: {
                                    selectIndex = index
                                    selectName = model.name
                                }
                            }
                        }
                    }
                }
            }

            // Action buttons
            RowLayout {
                Layout.fillWidth: true
                height: 60
                spacing: 20

                Item { Layout.fillWidth: true }  // Spacer

                Button {
                    text: "加密"
                    font.pixelSize: 20
                    font.bold: true
                    width: 150
                    height: 50

                    background: Rectangle {
                        radius: 10
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0.0; color: "#4FC5A0"}
                            GradientStop { position: 1.0; color: "#44E7BA" }
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
                        if (selectIndex === -1) {
                            showStatus("请选择要加密的文件")
                            return
                        }

                        var inputPath = root.filePath + selectName
                        var outputPath = ""

                        if (outputFilename.text.length > 0) {
                            outputPath = root.filePath + outputFilename.text
                        } else {
                            // Auto-generate name based on encryption method
                            var extension = ""
                            switch (encryptionMethod) {
                                case 0: extension = ".xor"; break
                                case 1: extension = ".aes"; break
                                case 2: extension = ".rsa"; break
                                case 3: extension = ".enc"; break
                            }
                            outputPath = root.filePath + selectName + extension
                        }

                        // Encrypt based on selected method
                        switch (encryptionMethod) {
                            case 0:  // Legacy XOR
                                if (passwordField.text.length === 0) {
                                    showStatus("请输入密码")
                                    return
                                }
                                directoryHandler.enCodeFile(inputPath, outputPath, passwordField.text)
                                break

                            case 1:  // AES
                                if (passwordField.text.length === 0) {
                                    statusText.text = "请输入密码"
                                    statusPopup.open()
                                    return
                                }
                                directoryHandler.encryptFileAES(inputPath, outputPath, passwordField.text)
                                break

                            case 2:  // RSA
                                if (keySelector.currentIndex < 0) {
                                    showStatus("请选择密钥")
                                    return
                                }
                                directoryHandler.encryptFileRSA(inputPath, outputPath, keySelector.currentText)
                                break

                            case 3:  // Hybrid
                                if (keySelector.currentIndex < 0) {
                                    statusText.text = "请选择密钥"
                                    statusPopup.open()
                                    return
                                }
                                directoryHandler.encryptFileHybrid(inputPath, outputPath, keySelector.currentText)
                                break
                        }
                    }
                }

                Button {
                    text: "解密"
                    font.pixelSize: 20
                    font.bold: true
                    width: 150
                    height: 50

                    background: Rectangle {
                        radius: 10
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0.0; color: "#3498DB"}
                            GradientStop { position: 1.0; color: "#2980B9" }
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
                        if (selectIndex === -1) {
                            showStatus("请选择要解密的文件")
                            return
                        }

                        var inputPath = root.filePath + selectName
                        var outputPath = ""

                        if (outputFilename.text.length > 0) {
                            outputPath = root.filePath + outputFilename.text
                        } else {
                            // Auto-generate name based on encryption method
                            outputPath = root.filePath + "decrypted_" + selectName.replace(/\.(xor|aes|rsa|enc)$/, "")
                        }

                        // Decrypt based on selected method
                        switch (encryptionMethod) {
                            case 0:  // Legacy XOR
                                if (passwordField.text.length === 0) {
                                    statusText.text = "请输入密码"
                                    statusPopup.open()
                                    return
                                }
                                directoryHandler.deCodeFile(inputPath, outputPath, passwordField.text)
                                break

                            case 1:  // AES
                                if (passwordField.text.length === 0) {
                                    showStatus("请输入密码")
                                    return
                                }
                                directoryHandler.decryptFileAES(inputPath, outputPath, passwordField.text)
                                break

                            case 2:  // RSA
                                if (keySelector.currentIndex < 0) {
                                    statusText.text = "请选择密钥"
                                    statusPopup.open()
                                    return
                                }
                                if (keyPasswordField.text.length === 0) {
                                    showStatus("请输入私钥密码")
                                    return
                                }
                                directoryHandler.decryptFileRSA(inputPath, outputPath, keySelector.currentText, keyPasswordField.text)
                                break

                            case 3:  // Hybrid
                                if (keySelector.currentIndex < 0) {
                                    statusText.text = "请选择密钥"
                                    statusPopup.open()
                                    return
                                }
                                if (keyPasswordField.text.length === 0) {
                                    statusText.text = "请输入私钥密码"
                                    statusPopup.open()
                                    return
                                }
                                directoryHandler.decryptFileHybrid(inputPath, outputPath, keySelector.currentText, keyPasswordField.text)
                                break
                        }
                    }
                }

                Item { Layout.fillWidth: true }  // Spacer
            }
        }
    }

    // Use main window's status popup instead of local one
    function showStatus(message) {
        root.showStatus(message)
    }
}
