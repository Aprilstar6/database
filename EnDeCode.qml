import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import Qt.labs.platform 1.1
import com.directory 1.0

Item {
    id: enDeCode
    anchors.fill: parent
    visible: true // 确保可见性

    // 调试使用，可以看到组件是否加载
    Rectangle {
        anchors.fill: parent
        color: "#F7F9FC" // 浅灰背景色
        z: -10 // 确保在最底层
    }

    // 文件选择属性
    property int selectIndex: -1
    property string selectName: ""
    property ListModel fileModel: ListModel {
        // 添加额外属性用于存储源目录
        ListElement { 
            name: "" 
            time: 0
            sourceDir: ""
        }
    }

    // 加密设置
    property int encryptionMethod: 0 // 0 = 传统 XOR, 1 = AES 密码, 2 = RSA, 3 = 混合 AES+RSA
    onEncryptionMethodChanged: {
        // 当加密方式改变时，刷新密钥列表
        if (keySelector && typeof keySelector.refreshKeyList === 'function') {
            keySelector.refreshKeyList();
        }
    }

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
        console.log("EnDeCode界面已加载")

        // 清空初始空元素
        fileModel.clear()
        
        // 显示明显的状态指示
        initText.visible = true

        // 延迟半秒后刷新文件列表，给UI线程时间更新显示
        refreshTimer.start()
    }

    // 初始化提示文本
    Text {
        id: initText
        anchors.centerIn: parent
        text: "正在加载文件列表..."
        font.pixelSize: this ? 24 : 0 // 避免绑定循环警告
        color: "#3498DB"
        visible: false
        z: 1000

        Rectangle {
            anchors.fill: parent
            anchors.margins: -20
            color: "#F7F9FC"
            z: -1
            radius: 10
            border.width: 1
            border.color: "#E0E6ED"
        }
    }

    // 延迟刷新定时器
    Timer {
        id: refreshTimer
        interval: 500
        repeat: false
        onTriggered: {
            initText.visible = false
            refreshFileList()
        }
    }

    // 刷新文件列表
    function refreshFileList() {
        console.log("正在刷新文件列表，路径: " + root.filePath)

        // 确保文件模型已清空
        if (fileModel) {
            fileModel.clear()
        } else {
            console.error("fileModel为空！")
            return
        }

        // 确保directoryHandler已初始化
        if (!directoryHandler) {
            console.error("DirectoryHandler未初始化！")
            return
        }

        try {
            // 列出指定后缀的文件
            directoryHandler.listFiles(root.filePath, [".txt", ".jpg", ".png", ".pdf", ".doc", ".docx", ".xls", ".xlsx", ".aes", ".rsa", ".enc", ".xor"])
            console.log("已调用listFiles方法")
        } catch (e) {
            console.error("刷新文件列表出错:", e)
            // 在界面上显示错误
            initText.text = "加载文件列表失败:\n" + e
            initText.visible = true
        }
    }

    // 目录处理器
    DirectoryHandler {
        id: directoryHandler
        // 在目录处理器初始化后添加控制台输出
        Component.onCompleted: {
            console.log("DirectoryHandler已成功初始化")
        }
    }

    // 目录处理器连接
    Connections {
        target: directoryHandler
        enabled: directoryHandler !== null

        function onFileNameSignal(name, time) {
            console.log("接收到文件信号:", name)
            fileModel.append({"name": name, "time": time, "sourceDir": ""})
        }

        function onOperationComplete(success, message) {
            console.log("操作完成:", success, message)
            showStatus(message)
            if (success) {
                refreshFileList()
            }
        }

        function onProgressUpdate(percentage) {
            console.log("进度更新:", percentage)
        }
    }

    // 替代文件选择对话框的简单实现
    // 我们将使用系统命令或其他方式选择文件
    function openFileSelector() {
        console.log("调用文件选择功能");
        // 使用FileDialog代替输入框
        fileDialog.open();
    }

    // 添加FileDialog组件
    FileDialog {
        id: fileDialog
        title: "选择文件"
        folder: "file:///home"
        nameFilters: ["所有文件 (*.*)"]
        
        onAccepted: {
            var fileName = fileDialog.file.toString();
            console.log("原始文件路径: " + fileName);
            
            // 处理文件URL格式，去掉前缀，但保留前导斜杠
            if (fileName.startsWith("file:///")) {
                fileName = fileName.replace("file:///", "/");
            } else {
                fileName = fileName.replace(/^(file:\/{2,3})|(qrc:\/{2})|(http:\/{2})/,"");
            }
            
            console.log("处理后文件路径: " + fileName);
            
            var lastSlash = Math.max(fileName.lastIndexOf('/'), fileName.lastIndexOf('\\'));
            var onlyFileName = fileName.substring(lastSlash + 1);
            var sourceDir = fileName.substring(0, lastSlash + 1);
            var destPath = root.filePath + onlyFileName;

            console.log("源路径: " + fileName);
            console.log("源文件目录: " + sourceDir);
            console.log("目标路径: " + destPath);

            // 将源文件目录保存到文件模型中，以便后续使用
            directoryHandler.copyFile(fileName, destPath);
            
            // 导入后自动选择该文件
            refreshFileList();
            // 等待文件列表刷新后再选择
            Qt.callLater(function() {
                for(var i=0; i < fileModel.count; i++) {
                    if(fileModel.get(i).name === onlyFileName) {
                        selectIndex = i;
                        selectName = onlyFileName;
                        // 保存源文件目录路径
                        fileModel.setProperty(i, "sourceDir", sourceDir);
                        console.log("已保存源目录: " + sourceDir + " 到文件: " + onlyFileName);
                        break;
                    }
                }
            });
            
            showStatus("已导入文件: " + onlyFileName);
        }
        
        onRejected: {
            console.log("文件选择已取消");
        }
    }

    // 保留原来的对话框作为备用
    Window {
        id: fileInputDialog
        title: "输入文件路径"
        width: 500
        height: 200
        flags: Qt.Dialog | Qt.WindowCloseButtonHint
        modality: Qt.ApplicationModal
        visible: false

        function open() {
            visible = true;
        }

        function close() {
            visible = false;
        }

        function accept() {
            if (filePathInput.text.length > 0) {
                var fileName = filePathInput.text;
                var lastSlash = Math.max(fileName.lastIndexOf('/'), fileName.lastIndexOf('\\'));
                var onlyFileName = fileName.substring(lastSlash + 1);
                var destPath = root.filePath + onlyFileName;

                directoryHandler.copyFile(fileName, destPath);
                showStatus("已导入文件: " + onlyFileName);
                refreshFileList();
            }
            filePathInput.text = "";
            close();
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 20
            spacing: 20

            Text {
                text: "请输入文件的完整路径:"
                font.pixelSize: 14
            }

            TextField {
                id: filePathInput
                Layout.fillWidth: true
                placeholderText: "例如: /home/user/documents/file.txt"
                selectByMouse: true
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 10
                Layout.alignment: Qt.AlignRight

                Button {
                    text: "取消"
                    onClicked: fileInputDialog.close()
                }

                Button {
                    text: "确定"
                    onClicked: fileInputDialog.accept()
                }
            }
        }
    }

    // 背景
    Rectangle {
        anchors.fill: parent
        color: lightBgColor
        
        // 添加拖放区域
        DropArea {
            id: dropArea
            anchors.fill: parent
            keys: ["text/uri-list"]

            onEntered: {
                dropAreaIndicator.visible = true
            }
            
            onExited: {
                dropAreaIndicator.visible = false
            }
            
            onDropped: {
                dropAreaIndicator.visible = false
                
                if (drop.hasUrls) {
                    for (var i = 0; i < drop.urls.length; i++) {
                        var fileName = drop.urls[i].toString();
                        console.log("拖放文件路径: " + fileName);
                        
                        // 处理文件URL格式，去掉前缀，但保留前导斜杠
                        if (fileName.startsWith("file:///")) {
                            fileName = fileName.replace("file:///", "/");
                        } else {
                            fileName = fileName.replace(/^(file:\/{2,3})|(qrc:\/{2})|(http:\/{2})/,"");
                        }
                        
                        var lastSlash = Math.max(fileName.lastIndexOf('/'), fileName.lastIndexOf('\\'));
                        var onlyFileName = fileName.substring(lastSlash + 1);
                        var sourceDir = fileName.substring(0, lastSlash + 1);
                        var destPath = root.filePath + onlyFileName;

                        console.log("源路径: " + fileName);
                        console.log("源文件目录: " + sourceDir);
                        console.log("目标路径: " + destPath);

                        // 将源文件目录保存到文件模型中，以便后续使用
                        directoryHandler.copyFile(fileName, destPath);
                        
                        // 导入后自动选择该文件
                        refreshFileList();
                        // 等待文件列表刷新后再选择
                        Qt.callLater(function() {
                            for(var j=0; j < fileModel.count; j++) {
                                if(fileModel.get(j).name === onlyFileName) {
                                    selectIndex = j;
                                    selectName = onlyFileName;
                                    // 保存源文件目录路径
                                    fileModel.setProperty(j, "sourceDir", sourceDir);
                                    console.log("已保存源目录: " + sourceDir + " 到文件: " + onlyFileName);
                                    break;
                                }
                            }
                        });
                        
                        showStatus("已导入文件: " + onlyFileName);
                    }
                }
            }
        }
    }

    // 拖放区域指示器
    Rectangle {
        id: dropAreaIndicator
        anchors.fill: parent
        color: "#3498DB"
        opacity: 0.3
        visible: false
        radius: 10
        border.width: 4
        border.color: "#2980B9"
        z: 9000
        
        Text {
            anchors.centerIn: parent
            text: "释放鼠标导入文件"
            font.pixelSize: 24
            font.bold: true
            color: "#FFFFFF"
        }
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

                        onClicked: openFileSelector()

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
                border.width: 1
                border.color: borderColor

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
                        title: "密钥设置"
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

                            // AES和RSA加密都可以使用预生成的密钥
                            Text {
                                text: "选择密钥："
                                font.pixelSize: 14
                                color: darkTextColor
                                Layout.alignment: Qt.AlignRight
                            }

                            ComboBox {
                                id: keySelector
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
                                        var isRSAKey = keyName.endsWith(".key")
                                        var isAESKey = keyName.endsWith(".aeskey")
                                        var displayName = ""
                                        
                                        // 根据加密方式筛选密钥类型
                                        if (encryptionMethod === 0) {
                                            // XOR不使用密钥管理器的密钥，使用直接输入的密码
                                            continue
                                        } else if (encryptionMethod === 1 && isAESKey) {
                                            // AES加密模式 - 只显示AES密钥
                                            displayName = keyName.substring(0, keyName.length - 7)
                                            keys.push({"name": displayName, "fullName": keyName, "type": "AES"})
                                        } else if ((encryptionMethod === 2 || encryptionMethod === 3) && isRSAKey) {
                                            // RSA或混合加密模式 - 只显示RSA密钥
                                            displayName = keyName.substring(0, keyName.length - 4)
                                            keys.push({"name": displayName, "fullName": keyName, "type": "RSA"})
                                        }
                                    }

                                    model = keys
                                }
                            }

                            // XOR加密的密码输入
                            Text {
                                visible: encryptionMethod === 0
                                text: "加密密码："
                                font.pixelSize: 14
                                color: darkTextColor
                                Layout.alignment: Qt.AlignRight
                            }

                            TextField {
                                id: passwordField
                                visible: encryptionMethod === 0
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

                            // AES手动输入密码选项
                            Text {
                                visible: encryptionMethod === 1
                                text: "或输入密码："
                                font.pixelSize: 14
                                color: darkTextColor
                                Layout.alignment: Qt.AlignRight
                            }

                            TextField {
                                id: aesPasswordField
                                visible: encryptionMethod === 1
                                Layout.fillWidth: true
                                placeholderText: "可直接输入密码(不使用密钥)"
                                echoMode: TextInput.Password
                                selectByMouse: true
                                font.pixelSize: 14
                                height: 36

                                background: Rectangle {
                                    radius: 5
                                    color: cardColor
                                    border.color: aesPasswordField.activeFocus ? primaryColor : borderColor
                                    border.width: aesPasswordField.activeFocus ? 2 : 1
                                }
                            }

                            // RSA/混合加密的私钥密码
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
                                var sourceDir = ""
                                
                                // 获取源文件的真实目录
                                try {
                                    sourceDir = fileModel.get(selectIndex).sourceDir
                                    console.log("获取到源文件目录:", sourceDir)
                                } catch(e) {
                                    console.log("无法获取源目录，使用默认目录:", e)
                                }
                                
                                // 如果有源目录信息，则使用源目录作为输出目录
                                if (sourceDir && sourceDir.length > 0) {
                                    inputPath = root.filePath + selectName  // 输入仍然从当前目录
                                    
                                    if (outputFilename.text.length > 0) {
                                        // 自定义输出文件名
                                        outputPath = sourceDir + outputFilename.text
                                    } else {
                                        // 自动生成输出文件名
                                        var extension = ""
                                        switch (encryptionMethod) {
                                            case 0: extension = ".xor"; break
                                            case 1: extension = ".aes"; break
                                            case 2: extension = ".rsa"; break
                                            case 3: extension = ".enc"; break
                                        }
                                        outputPath = sourceDir + selectName + extension
                                    }
                                } else {
                                    // 没有源目录信息，使用当前目录
                                    inputPath = root.filePath + selectName
                                    
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
                                }
                                
                                console.log("输入文件路径: " + inputPath)
                                console.log("输出文件路径: " + outputPath)

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
                                        if (keySelector.currentIndex >= 0) {
                                            // 使用选择的AES密钥
                                            var selectedKeyName = keySelector.model[keySelector.currentIndex].name
                                            directoryHandler.encryptFileAES(inputPath, outputPath, selectedKeyName)
                                        } else if (aesPasswordField.text.length > 0) {
                                            // 使用手动输入的密码
                                            directoryHandler.encryptFileAES(inputPath, outputPath, aesPasswordField.text)
                                        } else {
                                            showStatus("请选择密钥或输入密码")
                                            return
                                        }
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
                                var sourceDir = ""
                                
                                // 获取源文件的真实目录
                                try {
                                    sourceDir = fileModel.get(selectIndex).sourceDir
                                    console.log("获取到源文件目录:", sourceDir)
                                } catch(e) {
                                    console.log("无法获取源目录，使用默认目录:", e)
                                }
                                
                                // 如果有源目录信息，则使用源目录作为输出目录
                                if (sourceDir && sourceDir.length > 0) {
                                    inputPath = root.filePath + selectName  // 输入仍然从当前目录
                                    
                                    if (outputFilename.text.length > 0) {
                                        // 自定义输出文件名
                                        outputPath = sourceDir + outputFilename.text
                                    } else {
                                        // 从文件名中去除加密扩展名
                                        var baseName = selectName
                                        if (baseName.indexOf(".xor") > 0) {
                                            baseName = baseName.substring(0, baseName.lastIndexOf(".xor"))
                                        } else if (baseName.indexOf(".aes") > 0) {
                                            baseName = baseName.substring(0, baseName.lastIndexOf(".aes"))
                                        } else if (baseName.indexOf(".rsa") > 0) {
                                            baseName = baseName.substring(0, baseName.lastIndexOf(".rsa"))
                                        } else if (baseName.indexOf(".enc") > 0) {
                                            baseName = baseName.substring(0, baseName.lastIndexOf(".enc"))
                                        }
                                        outputPath = sourceDir + "decrypted_" + baseName
                                    }
                                } else {
                                    // 没有源目录信息，使用当前目录
                                    inputPath = root.filePath + selectName
                                    
                                    if (outputFilename.text.length > 0) {
                                        outputPath = root.filePath + outputFilename.text
                                    } else {
                                        var baseName = selectName
                                        if (baseName.indexOf(".xor") > 0) {
                                            baseName = baseName.substring(0, baseName.lastIndexOf(".xor"))
                                        } else if (baseName.indexOf(".aes") > 0) {
                                            baseName = baseName.substring(0, baseName.lastIndexOf(".aes"))
                                        } else if (baseName.indexOf(".rsa") > 0) {
                                            baseName = baseName.substring(0, baseName.lastIndexOf(".rsa"))
                                        } else if (baseName.indexOf(".enc") > 0) {
                                            baseName = baseName.substring(0, baseName.lastIndexOf(".enc"))
                                        }
                                        outputPath = root.filePath + "decrypted_" + baseName
                                    }
                                }
                                
                                console.log("输入文件路径: " + inputPath)
                                console.log("输出文件路径: " + outputPath)

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
                                        if (keySelector.currentIndex >= 0) {
                                            // 使用选择的AES密钥
                                            var selectedKeyName = keySelector.model[keySelector.currentIndex].name
                                            directoryHandler.decryptFileAES(inputPath, outputPath, selectedKeyName)
                                        } else if (aesPasswordField.text.length > 0) {
                                            // 使用手动输入的密码
                                            directoryHandler.decryptFileAES(inputPath, outputPath, aesPasswordField.text)
                                        } else {
                                            showStatus("请选择密钥或输入密码")
                                            return
                                        }
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
                border.width: 1
                border.color: borderColor

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

                            onClicked: openFileSelector()
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

                                onClicked: openFileSelector()
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

                                        // 删除按钮
                                        Rectangle {
                                            id: deleteButton
                                            width: 24
                                            height: 24
                                            radius: 12
                                            color: "#E74C3C"
                                            anchors.right: parent.right
                                            anchors.top: parent.top
                                            anchors.rightMargin: 5
                                            anchors.topMargin: 5
                                            opacity: 0.8
                                            visible: false
                                            z: 2

                                            Text {
                                                anchors.centerIn: parent
                                                text: "×"
                                                font.pixelSize: 18
                                                font.bold: true
                                                color: "white"
                                            }

                                            MouseArea {
                                                anchors.fill: parent
                                                onClicked: {
                                                    // 确认删除
                                                    deleteConfirmDialog.fileName = model.name
                                                    deleteConfirmDialog.fileIndex = index
                                                    deleteConfirmDialog.open()
                                                }
                                            }
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
                                                deleteButton.visible = true
                                            }
                                            onExited: {
                                                if (selectIndex !== index) {
                                                    fileCard.color = cardColor
                                                }
                                                deleteButton.visible = false
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // 辅助函数：获取文件扩展名
    function getFileExtension(filename) {
        if (filename.lastIndexOf(".") === -1) return "";
        return filename.slice(filename.lastIndexOf(".") + 1);
    }

    // 辅助函数：根据文件类型获取颜色
    function getFileColor(filename) {
        var ext = getFileExtension(filename).toLowerCase();

        if (ext === "txt") return "#2980B9"; // 蓝色
        if (ext === "pdf") return "#C0392B"; // 红色
        if (ext === "doc" || ext === "docx") return "#2C3E50"; // 深蓝色
        if (ext === "xls" || ext === "xlsx") return "#27AE60"; // 绿色
        if (ext === "jpg" || ext === "png") return "#8E44AD"; // 紫色
        if (ext === "aes") return "#D35400"; // 橙色
        if (ext === "rsa") return "#16A085"; // 青色
        if (ext === "enc") return "#F39C12"; // 黄色
        if (ext === "xor") return "#7F8C8D"; // 灰色

        return primaryColor; // 默认颜色
    }

    // 显示状态消息
    function showStatus(message) {
        root.showStatus(message)
    }

    // 状态栏（已不使用，但保留以避免引用错误）
    Rectangle {
        id: statusBar
        property string message: ""

        width: parent.width * 0.8
        height: 50
        color: Qt.rgba(0, 0, 0, 0.7)
        radius: 5
        visible: false  // 设置为永不可见

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 20

        Text {
            anchors.centerIn: parent
            text: statusBar.message
            color: "white"
            font.pixelSize: 14
        }

        Timer {
            id: statusTimer
            interval: 3000
            onTriggered: statusBar.visible = false
        }
    }

    // 辅助函数：返回常用色彩
    function getDefaultColor() {
        return "#34495E"; // 深蓝灰色
    }

    // 文件删除确认对话框
    Window {
        id: deleteConfirmDialog
        width: 400
        height: 200
        flags: Qt.Dialog | Qt.WindowCloseButtonHint
        modality: Qt.ApplicationModal
        visible: false
        title: "确认删除"
        x: root && root.width ? (root.width - width) / 2 : 0
        y: root && root.height ? (root.height - height) / 2 : 0

        property string fileName: ""
        property int fileIndex: -1

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
                text: "确定要删除文件 \"" + deleteConfirmDialog.fileName + "\" 吗？此操作不可撤销。"
                wrapMode: Text.WordWrap
                font.pixelSize: 16
                color: "#394149"
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 10
                Layout.alignment: Qt.AlignRight | Qt.AlignBottom

                Button {
                    text: "取消"
                    implicitWidth: 100
                    implicitHeight: 40
                    font.pixelSize: 14

                    onClicked: {
                        deleteConfirmDialog.close()
                    }
                }

                Button {
                    text: "删除"
                    implicitWidth: 100
                    implicitHeight: 40
                    font.pixelSize: 14

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
                        // 执行删除
                        if (deleteConfirmDialog.fileIndex >= 0 && deleteConfirmDialog.fileIndex < fileModel.count) {
                            var filePath = root.filePath + deleteConfirmDialog.fileName;
                            directoryHandler.deleteFile(filePath);
                            fileModel.remove(deleteConfirmDialog.fileIndex);
                            
                            // 如果删除的是当前选中的文件，重置选择
                            if (deleteConfirmDialog.fileIndex === selectIndex) {
                                selectIndex = -1;
                                selectName = "";
                            } else if (deleteConfirmDialog.fileIndex < selectIndex) {
                                // 如果删除的文件在当前选中文件之前，调整选择索引
                                selectIndex--;
                            }
                        }
                        deleteConfirmDialog.close();
                    }
                }
            }
        }
    }
}
