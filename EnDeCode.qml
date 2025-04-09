import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import com.directory 1.0
import QtQuick.Dialogs 1.3

Item {
    id: enDeCode
    anchors.fill: parent

    // 文件选择属性
    property int selectIndex: -1
    property string selectName: ""
    property ListModel fileModel: ListModel {}

    // 加密设置
    property int encryptionMethod: 0 // 0 = 传统 XOR, 1 = AES 密码, 2 = RSA, 3 = 混合 AES+RSA

    // 颜色主题
    property color primaryColor: "#3498DB"        // 主色调（蓝色）
    property color accentColor: "#2ECC71"         // 强调色（绿色）
    property color warningColor: "#E74C3C"        // 警告色（红色）
    property color lightBgColor: "#F5F7FA"        // 浅色背景
    property color darkTextColor: "#2C3E50"       // 深色文本
    property color lightTextColor: "#ECF0F1"      // 浅色文本
    property color cardColor: "#FFFFFF"           // 卡片颜色
    property color borderColor: "#E0E6ED"         // 边框颜色
    property color selectedColor: "#D6EAF8"       // 选中颜色
    property color hoverColor: "#EBF5FB"          // 悬停颜色

    // 组件完成后初始化
    Component.onCompleted: {
        refreshFileList()
    }

    // 刷新文件列表
    function refreshFileList() {
        fileModel.clear()
        directoryHandler.listFiles(root.filePath, [".txt", ".jpg", ".png", ".pdf", ".doc", ".docx", ".xls", ".xlsx", ".aes", ".rsa", ".enc", ".xor"])
    }

    // 目录处理器连接
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

    // 文件选择对话框
    FileDialog {
        id: fileDialog
        title: "选择要导入的文件"
        folder: shortcuts.home

        onAccepted: {
            var fileName = fileDialog.fileUrl.toString()
            fileName = fileName.replace(/^(file:\/{3})|(qrc:\/{2})|(http:\/{2})/,"")
            var lastSlash = Math.max(fileName.lastIndexOf('/'), fileName.lastIndexOf('\\'))
            var onlyFileName = fileName.substring(lastSlash + 1)
            var destPath = root.filePath + onlyFileName

            directoryHandler.copyFile(fileName, destPath)
            showStatus("已导入文件: " + onlyFileName)
            refreshFileList()
        }
    }

    // 背景
    Rectangle {
        anchors.fill: parent
        color: lightBgColor
    }

    // 整体布局
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 0
        spacing: 0

        // 顶部导航栏
        Rectangle {
            id: navBar
            Layout.fillWidth: true
            Layout.preferredHeight: 60
            color: primaryColor

            Rectangle {
                width: parent.width
                height: 4
                anchors.bottom: parent.bottom
                color: Qt.darker(primaryColor, 1.2)
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 20
                anchors.rightMargin: 20
                spacing: 15

                Text {
                    text: "高级文件加解密系统"
                    font {
                        pixelSize: 22
                        bold: true
                        family: "Microsoft YaHei UI"
                    }
                    color: lightTextColor
                    Layout.fillWidth: true
                }

                Row {
                    spacing: 10

                    Button {
                        id: importFileBtn
                        width: 120
                        height: 36

                        background: Rectangle {
                            radius: 5
                            color: accentColor

                            Rectangle {
                                width: parent.width
                                height: 2
                                anchors.bottom: parent.bottom
                                color: Qt.darker(accentColor, 1.3)
                                radius: 2
                            }
                        }

                        contentItem: Row {
                            spacing: 6
                            anchors.centerIn: parent

                            Text {
                                text: "导入文件"
                                color: "white"
                                font.pixelSize: 14
                                font.bold: true
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        onClicked: fileDialog.open()

                        ToolTip {
                            text: "导入需要加密或解密的文件"
                            delay: 500
                            timeout: 3000
                            visible: importFileBtn.hovered
                            font.pixelSize: 12
                        }
                    }

                    Button {
                        id: keyManagerBtn
                        width: 120
                        height: 36

                        background: Rectangle {
                            radius: 5
                            color: Qt.darker(primaryColor, 1.1)
                            border.color: lightTextColor
                            border.width: 1
                        }

                        contentItem: Row {
                            spacing: 6
                            anchors.centerIn: parent

                            Text {
                                text: "密钥管理"
                                color: "white"
                                font.pixelSize: 14
                                font.bold: true
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        onClicked: root.showKeyManager()

                        ToolTip {
                            text: "管理加密密钥"
                            delay: 500
                            timeout: 3000
                            visible: keyManagerBtn.hovered
                            font.pixelSize: 12
                        }
                    }

                    Button {
                        id: logoutBtn
                        width: 90
                        height: 36

                        background: Rectangle {
                            radius: 5
                            color: warningColor

                            Rectangle {
                                width: parent.width
                                height: 2
                                anchors.bottom: parent.bottom
                                color: Qt.darker(warningColor, 1.3)
                                radius: 2
                            }
                        }

                        contentItem: Row {
                            spacing: 6
                            anchors.centerIn: parent

                            Text {
                                text: "退出登录"
                                color: "white"
                                font.pixelSize: 14
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        onClicked: root.showLogin()

                        ToolTip {
                            text: "退出当前用户账号"
                            delay: 500
                            timeout: 3000
                            visible: logoutBtn.hovered
                            font.pixelSize: 12
                        }
                    }
                }
            }
        }

        // 主内容区
        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.margins: 15
            spacing: 15

            // 左侧：加密设置面板
            Rectangle {
                Layout.fillHeight: true
                Layout.preferredWidth: parent.width * 0.35
                color: cardColor
                radius: 8

                layer.enabled: true
                layer.effect: DropShadow {
                    horizontalOffset: 0
                    verticalOffset: 1
                    radius: 8.0
                    samples: 17
                    color: "#20000000"
                }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 15
                    spacing: 15

                    // 标题
                    RowLayout {
                        Layout.fillWidth: true

                        Text {
                            text: "加密设置"
                            font {
                                pixelSize: 18
                                bold: true
                                family: "Microsoft YaHei UI"
                            }
                            color: darkTextColor
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            height: 1
                            color: borderColor
                            Layout.alignment: Qt.AlignVCenter
                        }
                    }

                    // 加密方法选择
                    GroupBox {
                        title: "加密方式"
                        Layout.fillWidth: true
                        padding: 10

                        background: Rectangle {
                            color: hoverColor
                            radius: 5
                            border.color: borderColor
                            border.width: 1
                        }

                        label: Text {
                            text: parent.title
                            font.pixelSize: 14
                            font.bold: true
                            color: primaryColor
                        }

                        ColumnLayout {
                            anchors.fill: parent
                            spacing: 8

                            RadioButton {
                                id: legacyXORRadio
                                text: "传统 XOR 加密"
                                checked: encryptionMethod === 0
                                onCheckedChanged: if(checked) encryptionMethod = 0

                                contentItem: Text {
                                    text: legacyXORRadio.text
                                    font.pixelSize: 14
                                    leftPadding: legacyXORRadio.indicator.width + 4
                                    verticalAlignment: Text.AlignVCenter
                                    color: darkTextColor
                                }

                                ToolTip {
                                    text: "简单的异或加密，与旧版本兼容"
                                    delay: 500
                                    timeout: 3000
                                    visible: legacyXORRadio.hovered
                                    font.pixelSize: 12
                                }
                            }

                            RadioButton {
                                id: aesRadio
                                text: "AES 密码加密"
                                checked: encryptionMethod === 1
                                onCheckedChanged: if(checked) encryptionMethod = 1

                                contentItem: Text {
                                    text: aesRadio.text
                                    font.pixelSize: 14
                                    leftPadding: aesRadio.indicator.width + 4
                                    verticalAlignment: Text.AlignVCenter
                                    color: darkTextColor
                                }

                                ToolTip {
                                    text: "使用密码进行高强度AES加密"
                                    delay: 500
                                    timeout: 3000
                                    visible: aesRadio.hovered
                                    font.pixelSize: 12
                                }
                            }

                            RadioButton {
                                id: rsaRadio
                                text: "RSA 公钥加密"
                                checked: encryptionMethod === 2
                                onCheckedChanged: if(checked) encryptionMethod = 2

                                contentItem: Text {
                                    text: rsaRadio.text
                                    font.pixelSize: 14
                                    leftPadding: rsaRadio.indicator.width + 4
                                    verticalAlignment: Text.AlignVCenter
                                    color: darkTextColor
                                }

                                ToolTip {
                                    text: "使用RSA公钥加密，仅适合小文件"
                                    delay: 500
                                    timeout: 3000
                                    visible: rsaRadio.hovered
                                    font.pixelSize: 12
                                }
                            }

                            RadioButton {
                                id: hybridRadio
                                text: "混合 AES+RSA 加密"
                                checked: encryptionMethod === 3
                                onCheckedChanged: if(checked) encryptionMethod = 3

                                contentItem: Text {
                                    text: hybridRadio.text
                                    font.pixelSize: 14
                                    leftPadding: hybridRadio.indicator.width + 4
                                    verticalAlignment: Text.AlignVCenter
                                    color: darkTextColor
                                }

                                ToolTip {
                                    text: "结合AES和RSA的混合加密，高安全性和高性能"
                                    delay: 500
                                    timeout: 3000
                                    visible: hybridRadio.hovered
                                    font.pixelSize: 12
                                }
                            }
                        }
                    }

                    // 密码/密钥输入
                    GroupBox {
                        title: encryptionMethod <= 1 ? "密码设置" : "密钥设置"
                        Layout.fillWidth: true
                        padding: 10

                        background: Rectangle {
                            color: hoverColor
                            radius: 5
                            border.color: borderColor
                            border.width: 1
                        }

                        label: Text {
                            text: parent.title
                            font.pixelSize: 14
                            font.bold: true
                            color: primaryColor
                        }

                        GridLayout {
                            anchors.fill: parent
                            columns: 2
                            rowSpacing: 15
                            columnSpacing: 15

                            // 密码字段 (XOR 和 AES)
                            Text {
                                visible: encryptionMethod <= 1
                                text: "加密密码："
                                font.pixelSize: 14
                                color: darkTextColor
                                Layout.alignment: Qt.AlignRight
                            }

                            TextField {
                                id: passwordField
                                visible: encryptionMethod <= 1
                                Layout.fillWidth: true
                                placeholderText: "请输入密码"
                                echoMode: TextInput.Password
                                selectByMouse: true
                                font.pixelSize: 14
                                height: 36

                                background: Rectangle {
                                    radius: 5
                                    color: cardColor
                                    border.color: passwordField.activeFocus ? primaryColor : borderColor
                                    border.width: passwordField.activeFocus ? 2 : 1
                                }
                            }

                            // RSA 密钥选择
                            Text {
                                visible: encryptionMethod >= 2
                                text: "选择密钥："
                                font.pixelSize: 14
                                color: darkTextColor
                                Layout.alignment: Qt.AlignRight
                            }

                            ComboBox {
                                id: keySelector
                                visible: encryptionMethod >= 2
                                Layout.fillWidth: true
                                model: []
                                textRole: "name"
                                height: 36

                                Component.onCompleted: {
                                    refreshKeyList()
                                }

                                background: Rectangle {
                                    radius: 5
                                    color: cardColor
                                    border.color: keySelector.activeFocus ? primaryColor : borderColor
                                    border.width: keySelector.activeFocus ? 2 : 1
                                }

                                function refreshKeyList() {
                                    var keyList = directoryHandler.getKeyList()
                                    var keys = []

                                    for (var i = 0; i < keyList.length; i++) {
                                        var keyName = keyList[i]
                                        if (keyName.endsWith(".key") || keyName.endsWith(".aeskey")) {
                                            if (keyName.endsWith(".key")) {
                                                keyName = keyName.substring(0, keyName.length - 4)
                                            }
                                        ColumnLayout {
                                            anchors.fill: parent
                                            anchors.margins: 10
                                            spacing: 8

                                            // 文件图标
                                            Item {
                                                Layout.fillWidth: true
                                                Layout.preferredHeight: parent.height * 0.6

                                                Rectangle {
                                                    id: iconBg
                                                    width: 64
                                                    height: 64
                                                    radius: 8
                                                    color: getFileColor(model.name)
                                                    anchors.centerIn: parent

                                                    Text {
                                                        anchors.centerIn: parent
                                                        text: getFileExtension(model.name).toUpperCase()
                                                        font.pixelSize: 16
                                                        font.bold: true
                                                        color: "white"
                                                    }
                                                }
                                            }

                                            // 文件名
                                            Text {
                                                Layout.fillWidth: true
                                                Layout.fillHeight: true
                                                text: model.name
                                                elide: Text.ElideMiddle
                                                wrapMode: Text.Wrap
                                                maximumLineCount: 2
                                                horizontalAlignment: Text.AlignHCenter
                                                font.pixelSize: 12
                                                color: darkTextColor
                                            }
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            onClicked: {
                                                selectIndex = index
                                                selectName = model.name
                                            }

                                            hoverEnabled: true
                                            onEntered: {
                                                if (selectIndex !== index) {
                                                    fileCard.color = hoverColor
                                                }
                                            }
                                            onExited: {
                                                if (selectIndex !== index) {
                                                    fileCard.color = cardColor
                                                }
                                            }
                                        } else if (keyName.endsWith(".aeskey")) {
                                                keyName = keyName.substring(0, keyName.length - 7)
                                            }
                                            keys.push({"name": keyName})
                                        }
                                    }

                                    model = keys
                                }
                            }

                            // RSA 私钥密码
                            Text {
                                visible: encryptionMethod >= 2
                                text: "私钥密码："
                                font.pixelSize: 14
                                color: darkTextColor
                                Layout.alignment: Qt.AlignRight
                            }

                            TextField {
                                id: keyPasswordField
                                visible: encryptionMethod >= 2
                                Layout.fillWidth: true
                                placeholderText: "解密时需要的私钥密码"
                                echoMode: TextInput.Password
                                selectByMouse: true
                                font.pixelSize: 14
                                height: 36

                                background: Rectangle {
                                    radius: 5
                                    color: cardColor
                                    border.color: keyPasswordField.activeFocus ? primaryColor : borderColor
                                    border.width: keyPasswordField.activeFocus ? 2 : 1
                                }
                            }

                            // 输出文件名
                            Text {
                                text: "输出文件名："
                                font.pixelSize: 14
                                color: darkTextColor
                                Layout.alignment: Qt.AlignRight
                            }

                            TextField {
                                id: outputFilename
                                Layout.fillWidth: true
                                placeholderText: "输出文件名 (留空则自动生成)"
                                selectByMouse: true
                                font.pixelSize: 14
                                height: 36

                                background: Rectangle {
                                    radius: 5
                                    color: cardColor
                                    border.color: outputFilename.activeFocus ? primaryColor : borderColor
                                    border.width: outputFilename.activeFocus ? 2 : 1
                                }
                            }
                        }
                    }

                    Item { Layout.fillHeight: true } // 弹性空间

                    // 操作按钮
                    RowLayout {
                        Layout.fillWidth: true
                        height: 50
                        spacing: 15

                        Button {
                            id: encryptBtn
                            Layout.fillWidth: true
                            Layout.preferredHeight: 45

                            background: Rectangle {
                                radius: 6
                                color: accentColor

                                Rectangle {
                                    width: parent.width
                                    height: 3
                                    anchors.bottom: parent.bottom
                                    color: Qt.darker(accentColor, 1.3)
                                    radius: 3
                                }
                            }

                            contentItem: Text {
                                text: "加密文件"
                                color: "white"
                                font.pixelSize: 16
                                font.bold: true
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
                                    var extension = ""
                                    switch (encryptionMethod) {
                                        case 0: extension = ".xor"; break
                                        case 1: extension = ".aes"; break
                                        case 2: extension = ".rsa"; break
                                        case 3: extension = ".enc"; break
                                    }
                                    outputPath = root.filePath + selectName + extension
                                }

                                // 加密方法
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
                                            showStatus("请输入密码")
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
                                            showStatus("请选择密钥")
                                            return
                                        }
                                        directoryHandler.encryptFileHybrid(inputPath, outputPath, keySelector.currentText)
                                        break
                                }
                            }
                        }

                        Button {
                            id: decryptBtn
                            Layout.fillWidth: true
                            Layout.preferredHeight: 45

                            background: Rectangle {
                                radius: 6
                                color: primaryColor

                                Rectangle {
                                    width: parent.width
                                    height: 3
                                    anchors.bottom: parent.bottom
                                    color: Qt.darker(primaryColor, 1.3)
                                    radius: 3
                                }
                            }

                            contentItem: Text {
                                text: "解密文件"
                                color: "white"
                                font.pixelSize: 16
                                font.bold: true
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
                                    var baseName = selectName
                                    if (baseName.indexOf(".xor") > 0) {
                                        baseName = baseName.substring(0, baseName.indexOf(".xor"))
                                    } else if (baseName.indexOf(".aes") > 0) {
                                        baseName = baseName.substring(0, baseName.indexOf(".aes"))
                                    } else if (baseName.indexOf(".rsa") > 0) {
                                        baseName = baseName.substring(0, baseName.indexOf(".rsa"))
                                    } else if (baseName.indexOf(".enc") > 0) {
                                        baseName = baseName.substring(0, baseName.indexOf(".enc"))
                                    }
                                    outputPath = root.filePath + "decrypted_" + baseName
                                }

                                // 解密方法
                                switch (encryptionMethod) {
                                    case 0:  // Legacy XOR
                                        if (passwordField.text.length === 0) {
                                            showStatus("请输入密码")
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
                                            showStatus("请选择密钥")
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
                                            showStatus("请选择密钥")
                                            return
                                        }
                                        if (keyPasswordField.text.length === 0) {
                                            showStatus("请输入私钥密码")
                                            return
                                        }
                                        directoryHandler.decryptFileHybrid(inputPath, outputPath, keySelector.currentText, keyPasswordField.text)
                                        break
                                }
                            }
                        }
                    }
                }
            }

            // 右侧：文件浏览器
            Rectangle {
                Layout.fillHeight: true
                Layout.fillWidth: true
                color: cardColor
                radius: 8

                layer.enabled: true
                layer.effect: DropShadow {
                    horizontalOffset: 0
                    verticalOffset: 1
                    radius: 8.0
                    samples: 17
                    color: "#20000000"
                }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 15
                    spacing: 15

                    // 标题和刷新按钮
                    RowLayout {
                        Layout.fillWidth: true

                        Text {
                            text: "文件浏览"
                            font {
                                pixelSize: 18
                                bold: true
                                family: "Microsoft YaHei UI"
                            }
                            color: darkTextColor
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            height: 1
                            color: borderColor
                            Layout.alignment: Qt.AlignVCenter
                        }

                        Button {
                            id: refreshBtn
                            implicitWidth: 90
                            implicitHeight: 32

                            background: Rectangle {
                                radius: 4
                                color: primaryColor
                            }

                            contentItem: Text {
                                text: "刷新列表"
                                color: "white"
                                font.pixelSize: 12
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }

                            onClicked: {
                                refreshFileList()
                                if (keySelector) {
                                    keySelector.refreshKeyList()
                                }
                            }
                        }

                        Button {
                            id: importBtn
                            implicitWidth: 90
                            implicitHeight: 32

                            background: Rectangle {
                                radius: 4
                                color: accentColor
                            }

                            contentItem: Text {
                                text: "导入文件"
                                color: "white"
                                font.pixelSize: 12
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }

                            onClicked: fileDialog.open()
                        }
                    }

                    // 文件网格
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        color: hoverColor
                        radius: 5
                        border.color: borderColor
                        border.width: 1

                        // 空状态消息
                        Column {
                            anchors.centerIn: parent
                            spacing: 20
                            visible: fileModel.count === 0

                            Text {
                                text: "暂无文件"
                                font.pixelSize: 18
                                font.bold: true
                                color: darkTextColor
                                anchors.horizontalCenter: parent.horizontalCenter
                            }

                            Text {
                                text: "请点击「导入文件」按钮添加需要加解密的文件"
                                font.pixelSize: 14
                                color: darkTextColor
                                anchors.horizontalCenter: parent.horizontalCenter
                            }

                            Button {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "导入文件"
                                width: 150
                                height: 40

                                background: Rectangle {
                                    radius: 5
                                    color: accentColor

                                    Rectangle {
                                        width: parent.width
                                        height: 2
                                        anchors.bottom: parent.bottom
                                        color: Qt.darker(accentColor, 1.3)
                                        radius: 2
                                    }
                                }

                                contentItem: Text {
                                    text: parent.text
                                    color: "white"
                                    font.pixelSize: 14
                                    font.bold: true
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }

                                onClicked: fileDialog.open()
                            }
                        }

                        // 文件列表
                        ScrollView {
                            anchors.fill: parent
                            anchors.margins: 10
                            clip: true
                            visible: fileModel.count > 0

                            GridView {
                                id: gridView
                                anchors.fill: parent
                                clip: true
                                cellWidth: width / 4
                                cellHeight: cellWidth * 1.2
                                model: fileModel

                                delegate: Item {
                                    width: gridView.cellWidth
                                    height: gridView.cellHeight

                                    Rectangle {
                                        id: fileCard
                                        width: gridView.cellWidth * 0.92
                                        height: gridView.cellHeight * 0.92
                                        anchors.centerIn: parent
                                        radius: 8
                                        color: selectIndex === index ? selectedColor : cardColor
                                        border.width: 1
                                        border.color: selectIndex === index ? primaryColor : borderColor

                                        // 文件卡片阴影
                                        layer.enabled: true
                                        layer.effect: DropShadow {
                                            horizontalOffset: 0
                                            verticalOffset: 2
                                            radius: 4.0
                                            samples: 9
                                            color: "#30000000"
                                        }
