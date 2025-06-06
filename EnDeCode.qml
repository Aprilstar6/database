import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import Qt.labs.platform 1.1
import com.directory 1.0

Item {
    id: enDeCode
    anchors.fill: parent
    visible: true // 确保可见性

    // 公开给外部的接口
    signal filesCleared() // 文件清除完成后的信号
    
    // 存储最后一次加密/解密的输出文件路径
    property string lastOutputFilePath: ""
    
    // 公开的清除文件方法，允许外部组件调用
    function clearFiles() {
        console.log("EnDeCode: 外部调用clearFiles()方法清除文件列表")
        
        // 清空文件模型 - 这是最关键的一步
        if (fileModel) {
            fileModel.clear()
            console.log("已清空文件模型")
        }
        
        // 重置选择状态
        selectIndex = -1
        selectName = ""
        
        // 清空批量选择状态
        _selectedFilesObj = ({})
        selectedFiles = []
        selectedCount = 0
        batchMode = false
        
        // 清除实际文件
        var success = clearActualFiles()
        
        // 发送信号通知外部组件文件已清除
        filesCleared()
        
        // 刷新UI状态但不加载文件
        initText.visible = false
        
        // 显示状态信息
        showStatus("文件列表已清空" + (success ? "" : "，但实际文件可能未清除"))
        
        return true
    }
    
    // 清除实际的文件系统文件
    function clearActualFiles() {
        console.log("尝试清除实际文件夹中的文件")
        
        try {
            // 检查DirectoryHandler是否支持clearTempFiles方法
            if (directoryHandler) {
                if (typeof directoryHandler.clearTempFiles === "function") {
                    // 如果支持则调用
                    console.log("调用DirectoryHandler.clearTempFiles清除文件")
                    directoryHandler.clearTempFiles(root.filePath)
                    return true
                } else if (typeof directoryHandler.deleteAllFiles === "function") {
                    // 尝试其他可能的方法名
                    console.log("调用DirectoryHandler.deleteAllFiles清除文件")
                    directoryHandler.deleteAllFiles(root.filePath)
                    return true
                } else {
                    // 通过手动删除每个文件来实现清理
                    console.log("DirectoryHandler不支持批量清除方法，尝试使用deleteFile逐个删除")
                    
                    // 先获取所有文件
                    var files = []
                    for (var i = 0; i < fileModel.count; i++) {
                        files.push(fileModel.get(i).name)
                    }
                    
                    // 然后逐个删除
                    for (var j = 0; j < files.length; j++) {
                        var filePath = root.filePath + files[j]
                        console.log("删除文件: " + filePath)
                        directoryHandler.deleteFile(filePath)
                    }
                    
                    return true
                }
            } else {
                console.error("DirectoryHandler未初始化!")
                return false
            }
        } catch(e) {
            console.error("清除实际文件时出错:", e)
            return false
        }
    }
    
    // 清除登录后的文件列表
    function clearFilesAfterLogin() {
        console.log("EnDeCode: 调用clearFilesAfterLogin()方法清除文件列表")
        
        // 清空文件模型
        if (fileModel) {
            fileModel.clear()
            console.log("已清空文件模型")
        } else {
            console.error("clearFilesAfterLogin: fileModel为空!")
            return false
        }
        
        // 重置选择状态
        selectIndex = -1
        selectName = ""
        
        // 清空批量选择状态
        _selectedFilesObj = ({})
        selectedFiles = []
        selectedCount = 0
        batchMode = false
        
        // 尝试清除实际文件
        var success = clearActualFiles()
        
        // 禁止自动刷新文件列表 - 这是关键
        // 避免自动刷新机制重新加载文件
        console.log("文件列表已清除，禁止自动刷新")
        
        // 停止所有可能的自动刷新定时器
        if (refreshTimer.running) {
            refreshTimer.stop()
            console.log("已停止刷新定时器")
        }
        
        // 显示状态消息
        showStatus("文件列表已清空" + (success ? "" : "，但实际文件可能未清除"))
        
        return true
    }

    // 添加加密/解密结果文件到列表
    function addResultFileToList(filePath) {
        if (!filePath || filePath.length === 0) {
            console.log("未提供有效的文件路径，无法添加到列表");
            return false;
        }
        
        console.log("尝试添加结果文件到列表:", filePath);
        
        // 解析文件名和目录
        var lastSlash = Math.max(filePath.lastIndexOf('/'), filePath.lastIndexOf('\\'));
        var fileName = filePath.substring(lastSlash + 1);
        var sourceDir = filePath.substring(0, lastSlash + 1);
        
        // 检查文件是否已经在列表中
        var exists = false;
        for (var i = 0; i < fileModel.count; i++) {
            if (fileModel.get(i).name === fileName && 
                fileModel.get(i).sourceDir === sourceDir) {
                exists = true;
                break;
            }
        }
        
        // 如果不存在则添加
        if (!exists) {
            fileModel.append({
                "name": fileName,
                "time": new Date().getTime() / 1000,
                "sourceDir": sourceDir,
                "fullPath": filePath
            });
            
            console.log("已直接添加结果文件到列表:", fileName);
            return true;
        } else {
            console.log("文件已存在于列表中:", fileName);
            return false;
        }
    }

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

    // 批量操作属性
    property bool batchMode: false
    property var selectedFiles: []
    
    property var _selectedFilesObj: ({}) // 使用对象存储选中状态，避免引用问题
    property int selectedCount: 0 // 添加计数属性用于UI绑定

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

        // 初始化选中文件数组
        selectedFiles = []

        // 清空初始空元素
        fileModel.clear()
        
        // 显示明显的状态指示
        initText.visible = true

        // 先清除文件（如果有）- 不进行刷新
        if (typeof clearFilesAfterLogin === 'function') {
            console.log("Component.onCompleted: 调用clearFilesAfterLogin")
            clearFilesAfterLogin()
            
            // 隐藏初始化文本，显示清空状态
            initText.visible = false
            console.log("已完成文件清理，跳过自动刷新")
        } else {
            // 如果没有清除方法，才自动刷新
            console.log("Component.onCompleted: 启动延迟刷新定时器")
            refreshTimer.start()
        }
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
            
            // 确保初始化后只有在非清除状态下才刷新文件列表
            var lastClearOp = (root.loginAccount !== "" && root.loginPasswd !== "")
            console.log("定时器触发刷新，是否是登录后清除操作:", lastClearOp)
            
            if (!lastClearOp) {
                console.log("正常刷新文件列表")
                refreshFileList(false)
            } else {
                console.log("登录后清除操作，跳过自动刷新文件列表")
                // 将状态设置为空，避免后续触发刷新
                selectIndex = -1
                selectName = ""
            }
        }
    }

    // 刷新文件列表
    function refreshFileList(isClearRefresh) {
        // isClearRefresh参数表示是否是清除后的刷新
        // 如果是清除后的刷新，则避免重新加载文件
        var isAfterClear = isClearRefresh === true
        
        console.log("正在刷新文件列表，路径: " + root.filePath + ", 清除后刷新: " + isAfterClear)

        // 如果是清除后刷新，只更新UI状态，不重新加载文件
        if (isAfterClear) {
            console.log("这是清除后的刷新，只更新UI状态")
            return
        }

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
            
            // 不再自动刷新整个文件列表
            if (success) {
                // 从消息中尝试检测是否需要添加新文件到列表
                if (message.includes("加密") || message.includes("解密")) {
                    // 尝试获取最后一次操作的输出文件路径
                    // 这个信息需要从上下文中获取，假设存储在一个变量里
                    if (lastOutputFilePath && lastOutputFilePath.length > 0) {
                        var lastPath = lastOutputFilePath;
                        var lastSlash = Math.max(lastPath.lastIndexOf('/'), lastPath.lastIndexOf('\\'));
                        var onlyFileName = lastPath.substring(lastSlash + 1);
                        var sourceDir = lastPath.substring(0, lastSlash + 1);
                        
                        console.log("添加新生成文件到列表: " + onlyFileName + ", 源目录: " + sourceDir);
                        
                        // 检查文件是否已经在列表中
                        var exists = false;
                        for (var i = 0; i < fileModel.count; i++) {
                            if (fileModel.get(i).name === onlyFileName && 
                                fileModel.get(i).sourceDir === sourceDir) {
                                exists = true;
                                break;
                            }
                        }
                        
                        // 如果不存在则添加
                        if (!exists) {
                            fileModel.append({
                                "name": onlyFileName,
                                "time": new Date().getTime() / 1000,
                                "sourceDir": sourceDir,
                                "fullPath": lastPath
                            });
                            
                            console.log("已添加新文件到列表");
                        } else {
                            console.log("文件已存在于列表中");
                        }
                    } else {
                        console.log("没有设置输出文件路径，无法添加结果文件到列表");
                    }
                }
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
        fileMode: FileDialog.OpenFiles // 修改为支持多文件选择
        
        onAccepted: {
            // 保存所有需要导入的文件信息
            var filesToImport = [];
            var filesList = fileDialog.files;
            
            // 首先收集所有文件信息
            for (var i = 0; i < filesList.length; i++) {
                var fileName = filesList[i].toString();
                console.log("选择的文件路径: " + fileName);
                
                // 处理文件URL格式，去掉前缀，但保留前导斜杠
                if (fileName.startsWith("file:///")) {
                    fileName = fileName.replace("file:///", "/");
                } else {
                    fileName = fileName.replace(/^(file:\/{2,3})|(qrc:\/{2})|(http:\/{2})/,"");
                }
                
                var lastSlash = Math.max(fileName.lastIndexOf('/'), fileName.lastIndexOf('\\'));
                var onlyFileName = fileName.substring(lastSlash + 1);
                var sourceDir = fileName.substring(0, lastSlash + 1);

                console.log("源路径: " + fileName);
                console.log("源文件目录: " + sourceDir);
                
                // 保存文件信息到数组
                filesToImport.push({
                    fullPath: fileName,
                    name: onlyFileName,
                    sourceDir: sourceDir
                });
                
                // 直接添加到模型中而不复制文件
                fileModel.append({
                    "name": onlyFileName, 
                    "time": new Date().getTime() / 1000, 
                    "sourceDir": sourceDir,
                    "fullPath": fileName
                });
            }
            
            // 如果有文件被导入，选择第一个文件
            if (filesToImport.length > 0 && fileModel.count > 0) {
                selectIndex = 0;
                selectName = filesToImport[0].name;
            }
            
            // 显示导入完成消息
            showStatus("已导入 " + filesToImport.length + " 个文件");
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
                var sourceDir = fileName.substring(0, lastSlash + 1);

                // 直接添加到模型中
                fileModel.append({
                    "name": onlyFileName, 
                    "time": new Date().getTime() / 1000, 
                    "sourceDir": sourceDir,
                    "fullPath": fileName
                });
                
                selectIndex = fileModel.count - 1;
                selectName = onlyFileName;
                
                showStatus("已导入文件: " + onlyFileName);
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
                    // 保存所有需要导入的文件信息
                    var filesToImport = [];
                    
                    // 首先收集所有文件信息
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

                        console.log("源路径: " + fileName);
                        console.log("源文件目录: " + sourceDir);
                        
                        // 保存文件信息到数组
                        filesToImport.push({
                            fullPath: fileName,
                            name: onlyFileName,
                            sourceDir: sourceDir
                        });
                        
                        // 直接添加到模型中而不复制文件
                        fileModel.append({
                            "name": onlyFileName, 
                            "time": new Date().getTime() / 1000, 
                            "sourceDir": sourceDir,
                            "fullPath": fileName
                        });
                    }
                    
                    // 如果有文件被导入，选择第一个文件
                    if (filesToImport.length > 0 && fileModel.count > 0) {
                        selectIndex = fileModel.count - filesToImport.length;
                        selectName = filesToImport[0].name;
                    }
                    
                    // 显示导入完成消息
                    showStatus("已导入 " + filesToImport.length + " 个文件");
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

                        onClicked: {
                            // 退出前清除文件列表
                            clearFilesAfterLogin();
                            
                            // 显示登录界面
                            root.showLogin();
                        }

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
                                height: 50  // 增加高度
                                // 增加委托项
                                delegate: ItemDelegate {
                                    width: keySelector.width
                                    height: 40  // 增加每个选项的高度
                                    
                                    contentItem: Text {
                                        text: modelData.name
                                        font.pixelSize: 14
                                        verticalAlignment: Text.AlignVCenter
                                        horizontalAlignment: Text.AlignLeft
                                        elide: Text.ElideRight  // 文本溢出时显示省略号
                                        leftPadding: 10
                                        rightPadding: 10
                                        wrapMode: Text.NoWrap
                                    }
                                    
                                    highlighted: keySelector.highlightedIndex === index
                                }

                                // 显示当前选中项的文本
                                contentItem: Text {
                                    leftPadding: 10
                                    rightPadding: 20  // 给下拉箭头留空间
                                    text: keySelector.displayText
                                    font.pixelSize: 14
                                    verticalAlignment: Text.AlignVCenter
                                    horizontalAlignment: Text.AlignLeft
                                    elide: Text.ElideRight
                                }

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

                                // 设置下拉列表弹出窗口的样式和行为
                                popup: Popup {
                                    y: keySelector.height
                                    width: keySelector.width
                                    implicitHeight: Math.min(contentItem.implicitHeight, 300) // 最大高度300像素
                                    padding: 1
                                    
                                    contentItem: ListView {
                                        clip: true
                                        implicitHeight: contentHeight
                                        model: keySelector.popup.visible ? keySelector.delegateModel : null
                                        
                                        ScrollIndicator.vertical: ScrollIndicator { }
                                    }
                                    
                                    background: Rectangle {
                                        border.color: keySelector.activeFocus ? primaryColor : borderColor
                                        border.width: 1
                                        radius: 5
                                    }
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

                                var selectedItem = fileModel.get(selectIndex);
                                var inputPath = "";
                                var outputPath = "";
                                var sourceDir = "";
                                
                                // 获取源文件的信息
                                try {
                                    sourceDir = selectedItem.sourceDir;
                                    inputPath = selectedItem.fullPath || (sourceDir + selectedItem.name);
                                    console.log("获取到源文件目录:", sourceDir);
                                    console.log("获取到源文件路径:", inputPath);
                                } catch(e) {
                                    console.log("无法获取源目录，使用默认值:", e);
                                    inputPath = root.filePath + selectName;
                                }
                                
                                // 设置输出目录为源文件目录
                                if (sourceDir && sourceDir.length > 0) {
                                    if (outputFilename.text.length > 0) {
                                        // 自定义输出文件名
                                        outputPath = sourceDir + outputFilename.text;
                                    } else {
                                        // 自动生成输出文件名
                                        var extension = "";
                                        switch (encryptionMethod) {
                                            case 0: extension = ".xor"; break;
                                            case 1: extension = ".aes"; break;
                                            case 2: extension = ".rsa"; break;
                                            case 3: extension = ".enc"; break;
                                        }
                                        outputPath = sourceDir + selectName + extension;
                                    }
                                } else {
                                    // 没有源目录信息，使用当前目录
                                    inputPath = root.filePath + selectName;
                                    
                                    if (outputFilename.text.length > 0) {
                                        outputPath = root.filePath + outputFilename.text;
                                    } else {
                                        var extension = "";
                                        switch (encryptionMethod) {
                                            case 0: extension = ".xor"; break;
                                            case 1: extension = ".aes"; break;
                                            case 2: extension = ".rsa"; break;
                                            case 3: extension = ".enc"; break;
                                        }
                                        outputPath = root.filePath + selectName + extension;
                                    }
                                }
                                
                                console.log("输入文件路径: " + inputPath);
                                console.log("输出文件路径: " + outputPath);
                                
                                // 保存输出路径以便在操作完成后添加到列表
                                lastOutputFilePath = outputPath;

                                // 加密方法
                                switch (encryptionMethod) {
                                    case 0:  // Legacy XOR
                                        if (passwordField.text.length === 0) {
                                            showStatus("请输入密码")
                                            return
                                        }
                                        directoryHandler.enCodeFile(inputPath, outputPath, passwordField.text)
                                        // 直接添加结果文件到列表
                                        addResultFileToList(outputPath)
                                        break

                                    case 1:  // AES
                                        if (keySelector.currentIndex >= 0) {
                                            // 使用选择的AES密钥
                                            var selectedKeyName = keySelector.model[keySelector.currentIndex].name
                                            directoryHandler.encryptFileAES(inputPath, outputPath, selectedKeyName)
                                            // 直接添加结果文件到列表
                                            addResultFileToList(outputPath)
                                        } else if (aesPasswordField.text.length > 0) {
                                            // 使用手动输入的密码
                                            directoryHandler.encryptFileAES(inputPath, outputPath, aesPasswordField.text)
                                            // 直接添加结果文件到列表
                                            addResultFileToList(outputPath)
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
                                        // 直接添加结果文件到列表
                                        addResultFileToList(outputPath)
                                        break

                                    case 3:  // Hybrid
                                        if (keySelector.currentIndex < 0) {
                                            showStatus("请选择密钥")
                                            return
                                        }
                                        directoryHandler.encryptFileHybrid(inputPath, outputPath, keySelector.currentText)
                                        // 直接添加结果文件到列表
                                        addResultFileToList(outputPath)
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

                                var selectedItem = fileModel.get(selectIndex);
                                var inputPath = "";
                                var outputPath = "";
                                var sourceDir = "";
                                
                                // 获取源文件的信息
                                try {
                                    sourceDir = selectedItem.sourceDir;
                                    inputPath = selectedItem.fullPath || (sourceDir + selectedItem.name);
                                    console.log("获取到源文件目录:", sourceDir);
                                    console.log("获取到源文件路径:", inputPath);
                                } catch(e) {
                                    console.log("无法获取源目录，使用默认值:", e);
                                    inputPath = root.filePath + selectName;
                                }
                                
                                // 设置输出目录为源文件目录
                                if (sourceDir && sourceDir.length > 0) {
                                    if (outputFilename.text.length > 0) {
                                        // 自定义输出文件名
                                        outputPath = sourceDir + outputFilename.text;
                                    } else {
                                        // 从文件名中去除加密扩展名
                                        var baseName = selectName;
                                        if (baseName.indexOf(".xor") > 0) {
                                            baseName = baseName.substring(0, baseName.lastIndexOf(".xor"));
                                        } else if (baseName.indexOf(".aes") > 0) {
                                            baseName = baseName.substring(0, baseName.lastIndexOf(".aes"));
                                        } else if (baseName.indexOf(".rsa") > 0) {
                                            baseName = baseName.substring(0, baseName.lastIndexOf(".rsa"));
                                        } else if (baseName.indexOf(".enc") > 0) {
                                            baseName = baseName.substring(0, baseName.lastIndexOf(".enc"));
                                        }
                                        outputPath = sourceDir + "decrypted_" + baseName;
                                    }
                                } else {
                                    // 没有源目录信息，使用当前目录
                                    inputPath = root.filePath + selectName;
                                    
                                    if (outputFilename.text.length > 0) {
                                        outputPath = root.filePath + outputFilename.text;
                                    } else {
                                        var baseName = selectName;
                                        if (baseName.indexOf(".xor") > 0) {
                                            baseName = baseName.substring(0, baseName.lastIndexOf(".xor"));
                                        } else if (baseName.indexOf(".aes") > 0) {
                                            baseName = baseName.substring(0, baseName.lastIndexOf(".aes"));
                                        } else if (baseName.indexOf(".rsa") > 0) {
                                            baseName = baseName.substring(0, baseName.lastIndexOf(".rsa"));
                                        } else if (baseName.indexOf(".enc") > 0) {
                                            baseName = baseName.substring(0, baseName.lastIndexOf(".enc"));
                                        }
                                        outputPath = root.filePath + "decrypted_" + baseName;
                                    }
                                }
                                
                                console.log("输入文件路径: " + inputPath);
                                console.log("输出文件路径: " + outputPath);
                                
                                // 保存输出路径以便在操作完成后添加到列表
                                lastOutputFilePath = outputPath;

                                // 解密方法
                                switch (encryptionMethod) {
                                    case 0:  // Legacy XOR
                                        if (passwordField.text.length === 0) {
                                            showStatus("请输入密码")
                                            return
                                        }
                                        directoryHandler.deCodeFile(inputPath, outputPath, passwordField.text)
                                        // 直接添加结果文件到列表
                                        addResultFileToList(outputPath)
                                        break

                                    case 1:  // AES
                                        if (keySelector.currentIndex >= 0) {
                                            // 使用选择的AES密钥
                                            var selectedKeyName = keySelector.model[keySelector.currentIndex].name
                                            directoryHandler.decryptFileAES(inputPath, outputPath, selectedKeyName)
                                            // 直接添加结果文件到列表
                                            addResultFileToList(outputPath)
                                        } else if (aesPasswordField.text.length > 0) {
                                            // 使用手动输入的密码
                                            directoryHandler.decryptFileAES(inputPath, outputPath, aesPasswordField.text)
                                            // 直接添加结果文件到列表
                                            addResultFileToList(outputPath)
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
                                        // 直接添加结果文件到列表
                                        addResultFileToList(outputPath)
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
                                        // 直接添加结果文件到列表
                                        addResultFileToList(outputPath)
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
                            id: batchModeBtn
                            implicitWidth: 90
                            implicitHeight: 32
                            visible: fileModel.count > 0 // 只在有文件时显示

                            background: Rectangle {
                                radius: 4
                                color: batchMode ? warningColor : Qt.darker(primaryColor, 1.1)
                            }

                            contentItem: Text {
                                text: batchMode ? "退出批量" : "批量操作"
                                color: "white"
                                font.pixelSize: 12
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }

                            onClicked: {
                                // 切换模式前重置所有状态
                                _selectedFilesObj = ({});
                                selectedFiles = [];
                                selectedCount = 0;
                                toggleBatchMode();
                            }
                        }

                        Button {
                            id: checkStatusBtn
                            implicitWidth: 90
                            implicitHeight: 32
                            visible: batchMode // 调试按钮，只在批量模式下显示

                            background: Rectangle {
                                radius: 4
                                color: "#666666"
                            }

                            contentItem: Text {
                                text: "检查状态"
                                color: "white"
                                font.pixelSize: 12
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }

                            onClicked: {
                                // 打印选中状态以便调试
                                console.log("==== 当前选中状态 ====");
                                console.log("selectedCount =", selectedCount);
                                console.log("selectedFiles =", JSON.stringify(selectedFiles));
                                var keysStr = "";
                                for (var key in _selectedFilesObj) {
                                    if (_selectedFilesObj[key] === true) {
                                        keysStr += key + ", ";
                                    }
                                }
                                console.log("选中的键:", keysStr);
                                
                                // 强制重新计算选中数量
                                updateSelectedFilesArray();
                                showStatus("已选中: " + selectedCount + " 个文件");
                            }
                        }

                        Button {
                            id: batchDeleteBtn
                            implicitWidth: 90
                            implicitHeight: 32
                            visible: batchMode && selectedCount > 0 // 使用计数属性

                            background: Rectangle {
                                radius: 4
                                color: warningColor
                            }

                            contentItem: Text {
                                text: "批量删除"
                                color: "white"
                                font.pixelSize: 12
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }

                            onClicked: {
                                console.log("顶部批量删除按钮点击")
                                prepareBatchDelete()
                            }
                        }

                        Button {
                            id: batchEncryptBtn
                            implicitWidth: 90
                            implicitHeight: 32
                            visible: batchMode && selectedCount > 0 // 使用计数属性

                            background: Rectangle {
                                radius: 4
                                color: accentColor
                            }

                            contentItem: Text {
                                text: "批量加密"
                                color: "white"
                                font.pixelSize: 12
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }

                            onClicked: {
                                console.log("批量加密按钮点击")
                                batchEncryptFiles()
                            }
                        }

                        Button {
                            id: batchDecryptBtn
                            implicitWidth: 90
                            implicitHeight: 32
                            visible: batchMode && selectedCount > 0 // 使用计数属性

                            background: Rectangle {
                                radius: 4
                                color: primaryColor
                            }

                            contentItem: Text {
                                text: "批量解密"
                                color: "white"
                                font.pixelSize: 12
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }

                            onClicked: {
                                console.log("批量解密按钮点击")
                                batchDecryptFiles()
                            }
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
                                // 退出批量模式
                                batchMode = false
                                selectedFiles = []
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

                        // 批量模式提示和删除按钮 - 显示在文件列表顶部
                        Rectangle {
                            id: batchModeHeader
                            width: parent.width
                            height: 50
                            color: warningColor.toString().replace("#", "#AA") // 半透明
                            visible: batchMode
                            anchors.top: parent.top
                            radius: 5
                            z: 10 // 确保在顶层
                            
                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 10
                                spacing: 10
                                
                                Text {
                                    text: "<b>批量模式</b>: 点击文件选择要操作的项目"
                                    font.pixelSize: 14
                                    color: "white"
                                }
                                
                                Item { Layout.fillWidth: true }
                                
                                Text {
                                    text: selectedCount > 0 ? 
                                          "已选择 " + selectedCount + " 个文件" : "未选择文件"
                                    font.pixelSize: 14
                                    color: "white"
                                }
                                
                                Button {
                                    text: "批量加密"
                                    enabled: selectedCount > 0
                                    opacity: enabled ? 1.0 : 0.5
                                    implicitWidth: 80
                                    implicitHeight: 30
                                    
                                    background: Rectangle {
                                        radius: 4
                                        color: accentColor
                                        border.color: "white"
                                        border.width: 1
                                    }
                                    
                                    contentItem: Text {
                                        text: parent.text
                                        color: "white"
                                        font.pixelSize: 14
                                        font.bold: true
                                        horizontalAlignment: Text.AlignHCenter
                                        verticalAlignment: Text.AlignVCenter
                                    }
                                    
                                    onClicked: {
                                        batchEncryptFiles()
                                    }
                                }
                                
                                Button {
                                    text: "批量解密"
                                    enabled: selectedCount > 0
                                    opacity: enabled ? 1.0 : 0.5
                                    implicitWidth: 80
                                    implicitHeight: 30
                                    
                                    background: Rectangle {
                                        radius: 4
                                        color: primaryColor
                                        border.color: "white"
                                        border.width: 1
                                    }
                                    
                                    contentItem: Text {
                                        text: parent.text
                                        color: "white"
                                        font.pixelSize: 14
                                        font.bold: true
                                        horizontalAlignment: Text.AlignHCenter
                                        verticalAlignment: Text.AlignVCenter
                                    }
                                    
                                    onClicked: {
                                        batchDecryptFiles()
                                    }
                                }
                                
                                Button {
                                    text: "批量删除"
                                    enabled: selectedCount > 0
                                    opacity: enabled ? 1.0 : 0.5
                                    implicitWidth: 80
                                    implicitHeight: 30
                                    
                                    background: Rectangle {
                                        radius: 4
                                        color: "#cc0000"
                                        border.color: "white"
                                        border.width: 1
                                    }
                                    
                                    contentItem: Text {
                                        text: parent.text
                                        color: "white"
                                        font.pixelSize: 14
                                        font.bold: true
                                        horizontalAlignment: Text.AlignHCenter
                                        verticalAlignment: Text.AlignVCenter
                                    }
                                    
                                    onClicked: {
                                        console.log("中部批量删除按钮点击")
                                        prepareBatchDelete()
                                    }
                                }
                            }
                        }

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
                                        
                                        // 完全重写颜色逻辑，使其更明确地区分两种模式
                                        property bool isInBatchMode: batchMode
                                        property bool isCurrentSelected: selectIndex === index
                                        property bool isBatchSelected: batchMode && isFileSelected(index)
                                        
                                        // 使用属性绑定确保UI状态及时更新
                                        onIsInBatchModeChanged: {
                                            // 当批量模式改变时，强制更新颜色和边框
                                            color = getCardColor();
                                            border.color = getBorderColor();
                                        }
                                        
                                        // 文件卡片颜色计算函数
                                        function getCardColor() {
                                            if (batchMode) {
                                                return isFileSelected(index) ? selectedColor : cardColor;
                                            } else {
                                                return (selectIndex === index) ? selectedColor : cardColor;
                                            }
                                        }
                                        
                                        // 边框颜色计算函数
                                        function getBorderColor() {
                                            if (batchMode) {
                                                return isFileSelected(index) ? accentColor : borderColor;
                                            } else {
                                                return (selectIndex === index) ? primaryColor : borderColor;
                                            }
                                        }
                                        
                                        // 使用计算函数设置颜色
                                        color: getCardColor()
                                        border.width: 1
                                        border.color: getBorderColor()

                                        // 复选框 - 仅在批量模式下显示
                                        Rectangle {
                                            id: checkbox
                                            width: 22
                                            height: 22
                                            radius: 4
                                            
                                            // 添加批量模式变化监听
                                            property bool localBatchMode: batchMode
                                            onLocalBatchModeChanged: {
                                                // 批量模式变化时强制刷新状态
                                                if (localBatchMode) {
                                                    // 进入批量模式时强制设为未选中状态
                                                    color = "white";
                                                    border.color = borderColor;
                                                    console.log("复选框" + index + "进入批量模式时强制重置");
                                                }
                                            }
                                            
                                            // 强制重置函数
                                            function forceReset() {
                                                color = "white";
                                                border.color = borderColor;
                                            }
                                            
                                            // 重新定义颜色绑定，确保只在批量模式下有效
                                            color: {
                                                // 只有在批量模式下才可能是选中色
                                                if (!batchMode) return "white";
                                                // 批量模式下根据选中状态决定颜色
                                                return isFileSelected(index) ? accentColor : "white";
                                            }
                                            border.width: 2
                                            border.color: {
                                                // 只有在批量模式下才可能是选中色
                                                if (!batchMode) return borderColor;
                                                // 批量模式下根据选中状态决定边框颜色
                                                return isFileSelected(index) ? accentColor : borderColor;
                                            }
                                            anchors.left: parent.left
                                            anchors.top: parent.top
                                            anchors.leftMargin: 8
                                            anchors.topMargin: 8
                                            visible: batchMode
                                            z: 3
                                            
                                            Text {
                                                anchors.centerIn: parent
                                                text: "✓"
                                                font.pixelSize: 16
                                                font.bold: true
                                                color: "white"
                                                // 确保勾选标记只在批量模式且被选中时显示
                                                visible: batchMode && isFileSelected(index)
                                            }
                                            
                                            // 单独的复选框鼠标区域
                                            MouseArea {
                                                anchors.fill: parent
                                                anchors.margins: -5 // 稍微扩大点击区域
                                                onClicked: {
                                                    if (batchMode) {
                                                        // 记录旧状态
                                                        var oldSelected = isFileSelected(index);
                                                        
                                                        // 切换选择状态
                                                        toggleSelection(index);
                                                        
                                                        // 获取新状态
                                                        var newSelected = isFileSelected(index);
                                                        
                                                        console.log("复选框点击: 项目 " + index + 
                                                                   " 从 " + oldSelected + " 改为 " + newSelected);
                                                        
                                                        // 直接更新UI状态
                                                        checkbox.color = newSelected ? accentColor : "white";
                                                        checkbox.border.color = newSelected ? accentColor : borderColor;
                                                        fileCard.color = newSelected ? selectedColor : cardColor;
                                                        fileCard.border.color = newSelected ? accentColor : borderColor;
                                                    } else {
                                                        selectIndex = index;
                                                        selectName = model.name;
                                                    }
                                                }
                                            }
                                        }

                                        // 删除按钮 - 不在批量模式时显示
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
                                                    deleteConfirmDialog.isBatchDelete = false
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
                                                if (batchMode) {
                                                    // 记录旧状态
                                                    var oldSelected = isFileSelected(index);
                                                    
                                                    // 切换选择状态
                                                    toggleSelection(index);
                                                    
                                                    // 获取新状态
                                                    var newSelected = isFileSelected(index);
                                                    
                                                    console.log("文件卡片点击: 项目 " + index + 
                                                               " 从 " + oldSelected + " 改为 " + newSelected);
                                                    
                                                    // 直接更新UI状态
                                                    if (checkbox) {
                                                        checkbox.color = newSelected ? accentColor : "white";
                                                        checkbox.border.color = newSelected ? accentColor : borderColor;
                                                    }
                                                    
                                                    fileCard.color = newSelected ? selectedColor : cardColor;
                                                    fileCard.border.color = newSelected ? accentColor : borderColor;
                                                } else {
                                                    selectIndex = index;
                                                    selectName = model.name;
                                                }
                                            }

                                            hoverEnabled: true
                                            onEntered: {
                                                if (!batchMode && selectIndex !== index) {
                                                    fileCard.color = hoverColor
                                                }
                                                if (!batchMode) {
                                                    deleteButton.visible = true
                                                }
                                            }
                                            onExited: {
                                                if (!batchMode && selectIndex !== index) {
                                                    fileCard.color = cardColor
                                                }
                                                if (!batchMode) {
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

    // 当批量模式改变时触发
    onBatchModeChanged: {
        console.log("批量模式变更为: " + batchMode);
        
        if (batchMode) {
            // 进入批量模式时重置选中状态
            clearAllSelections();
            console.log("进入批量模式，已重置选中状态");
        } else {
            // 退出批量模式时清空选择
            clearAllSelections();
            // 确保UI已更新
            Qt.callLater(function() {
                for (var i = 0; i < fileModel.count; i++) {
                    forceUIRefresh(i);
                }
                console.log("已强制刷新所有文件项UI");
            });
            console.log("退出批量模式，已清空选中状态");
        }
    }
    
    // 清除所有文件选择状态
    function clearAllSelections() {
        console.log("清除所有文件选择状态 - 开始");
        
        // 保存当前选择状态
        var hadSelections = false;
        for (var key in _selectedFilesObj) {
            if (_selectedFilesObj[key] === true) {
                hadSelections = true;
                break;
            }
        }
        
        // 彻底清除选中对象 - 创建新对象而非修改
        _selectedFilesObj = {};
        
        // 创建新数组
        selectedFiles = [];
        selectedCount = 0;
        
        // 清除单个选择状态
        selectIndex = -1;
        selectName = "";
        
        console.log("选择状态已全部重置");
        
        // 只有当之前有选择时才强制刷新
        if (hadSelections) {
            console.log("检测到之前有选择，开始强制刷新UI");
            
            // 强制GridView重新布局
            if (gridView) {
                gridView.forceLayout();
                
                // 遍历所有可能的索引
                for (var i = 0; i < fileModel.count; i++) {
                    // 使所有文件项都强制刷新
                    var key = "idx_" + i;
                    console.log("强制刷新文件项: " + i);
                    forceUIRefresh(i);
                }
                
                // 请求重绘
                gridView.update();
            }
            
            // 延迟执行另一次刷新，确保状态更新
            Qt.callLater(function() {
                if (gridView) {
                    // 再次强制刷新所有可见项
                    for (var i = 0; i < fileModel.count; i++) {
                        forceUIRefresh(i);
                    }
                    
                    // 再次请求重绘
                    gridView.update();
                    console.log("延迟刷新完成");
                }
            });
        }
        
        console.log("清除所有文件选择状态 - 完成");
    }
    
    // 切换批量模式
    function toggleBatchMode() {
        console.log("切换批量模式 - 开始");
        
        if (batchMode) {
            // 退出批量模式
            console.log("准备退出批量模式");
            
            // 先强制清除所有选择状态
            _selectedFilesObj = {};
            selectedFiles = [];
            selectedCount = 0;
            
            console.log("已重置选择状态数据");
            
            // 延迟一点执行模式切换，确保数据状态先清除
            var oldBatchMode = batchMode;
            batchMode = false;
            
            // 手动触发每个文件卡片的状态更新
            if (gridView && gridView.contentItem) {
                for (var i = 0; i < gridView.contentItem.children.length; i++) {
                    var item = gridView.contentItem.children[i];
                    if (item && item.GridView && item.GridView.view === gridView) {
                        var fileCard = item.children[0]; // fileCard
                        if (fileCard) {
                            // 强制更新卡片状态
                            if (fileCard.isInBatchMode !== batchMode) {
                                fileCard.isInBatchMode = batchMode;
                            }
                            fileCard.color = fileCard.getCardColor();
                            fileCard.border.color = fileCard.getBorderColor();
                        }
                    }
                }
                gridView.forceLayout();
                gridView.update();
            }
            
            // 再次强制刷新所有项
            for (var j = 0; j < fileModel.count; j++) {
                forceUIRefresh(j);
            }
            
            console.log("批量模式已切换: " + oldBatchMode + " -> " + batchMode);
            
            // 延迟执行最后一次刷新
            Qt.callLater(function() {
                for (var i = 0; i < fileModel.count; i++) {
                    forceUIRefresh(i);
                }
                console.log("退出批量模式后的延迟刷新完成");
            });
            
        } else {
            // 进入批量模式前先清除所有状态
            // 彻底清除选择状态 - 创建全新对象
            _selectedFilesObj = {};
            selectedFiles = [];
            selectedCount = 0;
            
            console.log("准备进入批量模式，已完全重置选择状态");
            
            // 然后切换模式
            batchMode = true;
            
            // 强制刷新所有可能的项
            if (gridView) {
                gridView.forceLayout();
                
                // 先刷新可见项
                for (var k = 0; k < gridView.contentItem.children.length; k++) {
                    var item = gridView.contentItem.children[k];
                    if (item && item.GridView && item.GridView.view === gridView) {
                        if (item.GridView.indexInModel !== undefined) {
                            var index = item.GridView.indexInModel;
                            // 确保复选框显示为未选中状态
                            var fileCard = item.children[0]; // fileCard
                            if (fileCard) {
                                // 查找复选框并重置其状态
                                for (var c = 0; c < fileCard.children.length; c++) {
                                    var child = fileCard.children[c];
                                    if (child.width === 22 && child.height === 22 && child.radius === 4) {
                                        // 这很可能是复选框
                                        child.color = "white";
                                        child.border.color = borderColor;
                                        console.log("已重置复选框 " + index + " 的状态");
                                    }
                                }
                            }
                            
                            // 调用常规刷新
                            forceUIRefresh(index);
                        }
                    }
                }
                
                // 然后刷新所有项
                for (var m = 0; m < fileModel.count; m++) {
                    forceUIRefresh(m);
                }
                
                gridView.update();
            }
            
            // 再次延迟执行刷新
            Qt.callLater(function() {
                // 再次确保所有选择状态被清除
                _selectedFilesObj = {};
                selectedFiles = [];
                selectedCount = 0;
                
                // 再次刷新所有项
                for (var i = 0; i < fileModel.count; i++) {
                    forceUIRefresh(i);
                }
                
                console.log("进入批量模式后的延迟刷新完成");
            });
            
            console.log("已进入批量模式");
        }
        
        console.log("切换批量模式 - 完成: 当前模式 = " + batchMode);
    }
    
    // 获取选中的文件总数
    function getSelectedCount() {
        return selectedCount;
    }
    
    // 检查文件是否被选中
    function isFileSelected(index) {
        var key = "idx_" + index;
        var selected = _selectedFilesObj[key] === true;
        // console.log("检查选中状态: " + key + " = " + selected);
        return selected;
    }
    
    // 强制刷新特定索引的文件项UI
    function forceUIRefresh(index) {
        // 触发每个相关元素的刷新
        if (index >= 0 && index < fileModel.count) {
            // 获取选中状态
            var isSelected = isFileSelected(index);
            
            // 查找对应的GridView代理项强制更新
            var found = false;
            
            // 尝试找到对应的可视项
            for (var i = 0; i < gridView.contentItem.children.length; i++) {
                var item = gridView.contentItem.children[i];
                if (item && item.GridView && item.GridView.view === gridView) {
                    // 检查这个代理项是否对应我们要找的索引
                    if (item.GridView.indexInModel === index) {
                        var fileCard = item.children[0]; // fileCard
                        
                        // 查找复选框并直接操作
                        if (fileCard) {
                            for (var c = 0; c < fileCard.children.length; c++) {
                                var child = fileCard.children[c];
                                if (child.width === 22 && child.height === 22 && child.radius === 4) {
                                    // 这很可能是复选框
                                    var checkbox = child;
                                    
                                    // 检查是否有forceReset函数，如果有就调用
                                    if (checkbox.forceReset) {
                                        checkbox.forceReset();
                                        console.log("已调用复选框 " + index + " 的forceReset函数");
                                    } else {
                                        // 否则直接设置属性
                                        if (batchMode) {
                                            checkbox.color = isSelected ? accentColor : "white";
                                            checkbox.border.color = isSelected ? accentColor : borderColor;
                                        } else {
                                            checkbox.color = "white";
                                            checkbox.border.color = borderColor;
                                        }
                                    }
                                    
                                    break; // 找到复选框后退出循环
                                }
                            }
                            
                            // 更新文件卡片状态
                            if (!batchMode) {
                                fileCard.color = (selectIndex === index) ? selectedColor : cardColor;
                                fileCard.border.color = (selectIndex === index) ? primaryColor : borderColor;
                            } else {
                                fileCard.color = isSelected ? selectedColor : cardColor;
                                fileCard.border.color = isSelected ? accentColor : borderColor;
                            }
                        }
                        
                        found = true;
                        break;
                    }
                }
            }
            
            // 如果未找到可视项，标记网格视图需要重新加载
            if (!found && gridView) {
                gridView.forceLayout();
            }
        }
    }
    
    // 更新选中文件数组，用于批量操作
    function updateSelectedFilesArray() {
        selectedFiles = [];
        var count = 0;
        
        for (var key in _selectedFilesObj) {
            if (_selectedFilesObj[key] === true) {
                // 提取索引数字
                var idxStr = key.replace("idx_", "");
                var idx = parseInt(idxStr);
                if (!isNaN(idx)) {
                    selectedFiles.push(idx);
                    count++;
                }
            }
        }
        
        // 更新计数属性
        selectedCount = count;
        
        // 更新批量删除按钮的可见性
        if (batchDeleteBtn) {
            batchDeleteBtn.visible = batchMode && selectedCount > 0;
        }
        
        console.log("更新选中文件状态: 总数=" + selectedCount + 
                   ", 选中项=" + JSON.stringify(selectedFiles));
    }
    
    // 准备批量删除
    function prepareBatchDelete() {
        // 先强制更新选中文件状态
        updateSelectedFilesArray();
        
        console.log("准备批量删除，当前选中: " + selectedCount + " 个文件", "选中ID:", JSON.stringify(selectedFiles));
        
        // 确认批量删除
        deleteConfirmDialog.fileNames = [];
        deleteConfirmDialog.fileIndices = [];
        
        // 如果没有选中文件，直接返回
        if (selectedCount === 0) {
            showStatus("请先选择要删除的文件");
            console.log("无选中文件，取消批量删除");
            return;
        }
        
        // 按照索引从大到小排序，以便从后向前删除
        var sortedIndices = selectedFiles.slice().sort(function(a, b) { return b - a });
        console.log("待删除文件索引(已排序): " + JSON.stringify(sortedIndices));
        
        for (var i = 0; i < sortedIndices.length; i++) {
            var idx = sortedIndices[i];
            if (idx >= 0 && idx < fileModel.count) {
                try {
                    var fileName = fileModel.get(idx).name;
                    deleteConfirmDialog.fileNames.push(fileName);
                    deleteConfirmDialog.fileIndices.push(idx);
                    console.log("添加到删除列表: 索引=" + idx + ", 文件名=" + fileName);
                } catch (e) {
                    console.error("获取文件信息出错: " + e);
                }
            }
        }
        
        // 再次确认文件数量正确
        var fileCount = deleteConfirmDialog.fileIndices.length;
        deleteConfirmDialog.fileCount = fileCount;
        console.log("确认对话框: 选中文件数=" + fileCount + ", 数组长度=" + deleteConfirmDialog.fileIndices.length);
        
        if (fileCount > 0) {
            // 显示提示信息
            showStatus("正在打开删除确认对话框，选中了 " + fileCount + " 个文件");
            
            // 设置批量删除标志
            deleteConfirmDialog.isBatchDelete = true;
            
            // 打开确认对话框
            deleteConfirmDialog.open();
        } else {
            console.log("没有有效文件可删除");
            showStatus("没有有效的文件可删除");
        }
    }

    // 文件删除确认对话框
    Window {
        id: deleteConfirmDialog
        width: 400
        height: 220 // 增加一点高度，显示更多信息
        flags: Qt.Dialog | Qt.WindowCloseButtonHint
        modality: Qt.ApplicationModal
        visible: false
        title: "确认删除"
        x: root && root.width ? (root.width - width) / 2 : 0
        y: root && root.height ? (root.height - height) / 2 : 0

        property string fileName: ""
        property int fileIndex: -1
        property bool isBatchDelete: false
        property var fileNames: []
        property var fileIndices: []
        property int fileCount: 0 // 添加一个属性来保存文件数量

        function open() {
            // 更新文件计数
            fileCount = fileIndices.length;
            console.log("打开删除确认对话框: " + (isBatchDelete ? "批量删除 " + fileCount + " 个文件" : "单文件删除"));
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
                text: deleteConfirmDialog.isBatchDelete ? 
                      "确定要删除选中的 " + deleteConfirmDialog.fileCount + " 个文件吗？\n此操作不可撤销。" :
                      "确定要删除文件 \"" + deleteConfirmDialog.fileName + "\" 吗？\n此操作不可撤销。"
                wrapMode: Text.WordWrap
                font.pixelSize: 16
                color: "#394149"
            }

            // 显示文件列表
            Rectangle {
                Layout.fillWidth: true
                visible: deleteConfirmDialog.isBatchDelete && deleteConfirmDialog.fileCount > 0
                height: deleteConfirmDialog.fileCount > 3 ? 60 : 30
                color: "#F5F7FA"
                
                ScrollView {
                    anchors.fill: parent
                    clip: true
                    
                    Text {
                        text: {
                            if (!deleteConfirmDialog.isBatchDelete) return "";
                            
                            var files = [];
                            for (var i = 0; i < Math.min(deleteConfirmDialog.fileCount, 5); i++) {
                                if (i < deleteConfirmDialog.fileNames.length) {
                                    files.push(deleteConfirmDialog.fileNames[i]);
                                }
                            }
                            
                            if (deleteConfirmDialog.fileCount > 5) {
                                files.push("以及其他 " + (deleteConfirmDialog.fileCount - 5) + " 个文件");
                            }
                            
                            return files.join("\n");
                        }
                        font.pixelSize: 12
                        color: "#666666"
                        padding: 5
                    }
                }
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
                        console.log("删除确认: " + (deleteConfirmDialog.isBatchDelete ? "批量删除 " + deleteConfirmDialog.fileCount + " 个文件" : "单文件删除"))
                        
                        if (deleteConfirmDialog.isBatchDelete) {
                            // 批量删除
                            var count = deleteConfirmDialog.fileIndices.length
                            console.log("开始批量删除 " + count + " 个文件条目")
                            
                            // 记录删除的文件索引，从大到小排序以防止删除过程中索引变化
                            var deletedIndices = deleteConfirmDialog.fileIndices.slice().sort(function(a, b) { return b - a });
                            
                            // 从模型中删除（从大到小删除避免索引变化）
                            for (var j = 0; j < deletedIndices.length; j++) {
                                var index = deletedIndices[j];
                                if (index >= 0 && index < fileModel.count) {
                                    console.log("从列表中移除索引: " + index);
                                    fileModel.remove(index);
                                }
                            }
                            
                            // 重置选择并退出批量模式
                            batchMode = false;
                            clearAllSelections();
                            
                            // 显示状态消息
                            showStatus("已从列表中移除 " + count + " 个文件");
                            console.log("批量删除完成，已从列表中移除 " + count + " 个文件");
                        } else {
                            // 单个文件删除
                            if (deleteConfirmDialog.fileIndex >= 0 && deleteConfirmDialog.fileIndex < fileModel.count) {
                                // 从模型中删除
                                try {
                                    console.log("从列表中移除文件索引: " + deleteConfirmDialog.fileIndex);
                                    fileModel.remove(deleteConfirmDialog.fileIndex);
                                } catch (e) {
                                    console.error("从模型移除文件失败: " + e);
                                }
                                
                                // 如果删除的是当前选中的文件，重置选择
                                if (deleteConfirmDialog.fileIndex === selectIndex) {
                                    selectIndex = -1;
                                    selectName = "";
                                    console.log("已重置文件选择");
                                } else if (deleteConfirmDialog.fileIndex < selectIndex) {
                                    // 如果删除的文件在当前选中文件之前，调整选择索引
                                    selectIndex--;
                                    console.log("调整选择索引为: " + selectIndex);
                                }
                            }
                        }
                        
                        // 关闭对话框
                        deleteConfirmDialog.close();
                    }
                }
            }
        }
    }

    // 切换单个文件的选中状态
    function toggleSelection(index) {
        // 使用字符串键，避免JavaScript自动转换带来的问题
        var key = "idx_" + index;
        var oldSelected = _selectedFilesObj[key] === true;
        
        // 取反选择状态
        _selectedFilesObj[key] = !oldSelected;
        
        console.log((oldSelected ? "取消选择: " : "添加选择: ") + key + 
                   ", 新状态: " + _selectedFilesObj[key]);
        
        // 更新选中文件数组和计数
        updateSelectedFilesArray();
        
        // 找到对应的GridView代理项强制更新
        if (gridView && gridView.contentItem) {
            for (var i = 0; i < gridView.contentItem.children.length; i++) {
                var item = gridView.contentItem.children[i];
                if (item && item.GridView && item.GridView.view === gridView) {
                    if (item.GridView.indexInModel === index) {
                        var fileCard = item.children[0]; // fileCard
                        
                        // 查找复选框并直接操作
                        if (fileCard) {
                            for (var c = 0; c < fileCard.children.length; c++) {
                                var child = fileCard.children[c];
                                if (child.width === 22 && child.height === 22 && child.radius === 4) {
                                    // 这很可能是复选框
                                    var checkbox = child;
                                    var isSelected = _selectedFilesObj[key] === true;
                                    
                                    // 直接更新复选框状态
                                    checkbox.color = isSelected ? accentColor : "white";
                                    checkbox.border.color = isSelected ? accentColor : borderColor;
                                    
                                    // 更新文本可见性
                                    for (var t = 0; t < checkbox.children.length; t++) {
                                        var textItem = checkbox.children[t];
                                        if (textItem.text === "✓") {
                                            textItem.visible = isSelected;
                                            break;
                                        }
                                    }
                                    
                                    console.log("已直接更新复选框 " + index + " 的状态");
                                    break;
                                }
                            }
                            
                            // 更新文件卡片状态
                            fileCard.color = _selectedFilesObj[key] ? selectedColor : cardColor;
                            fileCard.border.color = _selectedFilesObj[key] ? accentColor : borderColor;
                        }
                        
                        break;
                    }
                }
            }
        }
    }
    
    // 批量加密文件
    function batchEncryptFiles() {
        // 更新选中文件列表
        updateSelectedFilesArray();
        
        if (selectedCount === 0) {
            showStatus("请先选择要加密的文件");
            return;
        }
        
        console.log("开始批量加密 " + selectedCount + " 个文件");
        
        // 检查加密参数
        if (encryptionMethod === 0 && passwordField.text.length === 0) {
            showStatus("请输入密码");
            return;
        }
        
        if ((encryptionMethod === 1) && 
            (keySelector.currentIndex < 0 && aesPasswordField.text.length === 0)) {
            showStatus("请选择密钥或输入密码");
            return;
        }
        
        if ((encryptionMethod === 2 || encryptionMethod === 3) && 
            keySelector.currentIndex < 0) {
            showStatus("请选择密钥");
            return;
        }
        
        var processedCount = 0;
        var errorCount = 0;
        var processedFiles = []; // 存储成功处理的文件信息
        
        // 处理所有选中的文件
        for (var i = 0; i < selectedFiles.length; i++) {
            var index = selectedFiles[i];
            if (index >= 0 && index < fileModel.count) {
                var selectedItem = fileModel.get(index);
                var fileName = selectedItem.name;
                var sourceDir = "";
                var inputPath = "";
                
                // 获取源文件目录和完整路径
                try {
                    sourceDir = selectedItem.sourceDir;
                    inputPath = selectedItem.fullPath || (sourceDir + fileName);
                    console.log("获取到源文件目录:", sourceDir);
                    console.log("获取到源文件路径:", inputPath);
                } catch(e) {
                    console.log("无法获取源目录，使用默认值:", e);
                    sourceDir = "";
                    inputPath = root.filePath + fileName;
                }
                
                var outputPath = "";
                
                // 设置输出路径
                if (sourceDir && sourceDir.length > 0) {
                    // 使用源目录作为输出目录
                    var extension = "";
                    switch (encryptionMethod) {
                        case 0: extension = ".xor"; break;
                        case 1: extension = ".aes"; break;
                        case 2: extension = ".rsa"; break;
                        case 3: extension = ".enc"; break;
                    }
                    outputPath = sourceDir + fileName + extension;
                } else {
                    // 使用当前目录
                    var extension = "";
                    switch (encryptionMethod) {
                        case 0: extension = ".xor"; break;
                        case 1: extension = ".aes"; break;
                        case 2: extension = ".rsa"; break;
                        case 3: extension = ".enc"; break;
                    }
                    outputPath = root.filePath + fileName + extension;
                }
                
                console.log("批量加密文件: " + inputPath + " -> " + outputPath);
                
                // 保存最后一个输出路径
                lastOutputFilePath = outputPath;
                
                var success = false;
                // 执行加密
                switch (encryptionMethod) {
                    case 0:  // Legacy XOR
                        directoryHandler.enCodeFile(inputPath, outputPath, passwordField.text);
                        success = true;
                        break;
                        
                    case 1:  // AES
                        if (keySelector.currentIndex >= 0) {
                            // 使用选择的AES密钥
                            var selectedKeyName = keySelector.model[keySelector.currentIndex].name;
                            success = directoryHandler.encryptFileAES(inputPath, outputPath, selectedKeyName);
                        } else if (aesPasswordField.text.length > 0) {
                            // 使用手动输入的密码
                            success = directoryHandler.encryptFileAES(inputPath, outputPath, aesPasswordField.text);
                        }
                        break;
                        
                    case 2:  // RSA
                        success = directoryHandler.encryptFileRSA(inputPath, outputPath, keySelector.currentText);
                        break;
                        
                    case 3:  // Hybrid
                        success = directoryHandler.encryptFileHybrid(inputPath, outputPath, keySelector.currentText);
                        break;
                }
                
                if (success) {
                    processedCount++;
                    
                    // 将处理成功的文件信息存储起来
                    processedFiles.push({
                        path: outputPath,
                        name: fileName + extension,
                        sourceDir: sourceDir
                    });
                    
                    // 直接添加到文件列表
                    addResultFileToList(outputPath);
                } else {
                    errorCount++;
                    console.log("加密文件失败: " + fileName);
                }
            }
        }
        
        // 将所有处理成功的文件添加到列表
        for (var j = 0; j < processedFiles.length; j++) {
            var fileInfo = processedFiles[j];
            
            // 检查文件是否已经在列表中
            var exists = false;
            for (var k = 0; k < fileModel.count; k++) {
                if (fileModel.get(k).name === fileInfo.name && 
                    fileModel.get(k).sourceDir === fileInfo.sourceDir) {
                    exists = true;
                    break;
                }
            }
            
            // 如果不存在则添加
            if (!exists) {
                fileModel.append({
                    "name": fileInfo.name,
                    "time": new Date().getTime() / 1000,
                    "sourceDir": fileInfo.sourceDir,
                    "fullPath": fileInfo.path
                });
                
                console.log("已添加新文件到列表: " + fileInfo.name);
            }
        }
        
        // 显示结果
        if (errorCount > 0) {
            showStatus("批量加密完成: " + processedCount + " 个成功，" + errorCount + " 个失败");
        } else {
            showStatus("批量加密完成: " + processedCount + " 个文件");
        }
        
        // 退出批量模式 - 使用toggleBatchMode确保一致性
        if (batchMode) {
            toggleBatchMode();
        } else {
            // 以防万一，直接清除选择状态
            clearAllSelections();
        }
    }
    
    // 批量解密文件
    function batchDecryptFiles() {
        // 更新选中文件列表
        updateSelectedFilesArray();
        
        if (selectedCount === 0) {
            showStatus("请先选择要解密的文件");
            return;
        }
        
        console.log("开始批量解密 " + selectedCount + " 个文件");
        
        // 检查解密参数
        if (encryptionMethod === 0 && passwordField.text.length === 0) {
            showStatus("请输入密码");
            return;
        }
        
        if ((encryptionMethod === 1) && 
            (keySelector.currentIndex < 0 && aesPasswordField.text.length === 0)) {
            showStatus("请选择密钥或输入密码");
            return;
        }
        
        if (encryptionMethod === 2 || encryptionMethod === 3) {
            if (keySelector.currentIndex < 0) {
                showStatus("请选择密钥");
                return;
            }
            if (keyPasswordField.text.length === 0) {
                showStatus("请输入私钥密码");
                return;
            }
        }
        
        var processedCount = 0;
        var errorCount = 0;
        var processedFiles = []; // 存储成功处理的文件信息
        
        // 处理所有选中的文件
        for (var i = 0; i < selectedFiles.length; i++) {
            var index = selectedFiles[i];
            if (index >= 0 && index < fileModel.count) {
                var selectedItem = fileModel.get(index);
                var fileName = selectedItem.name;
                var sourceDir = "";
                var inputPath = "";
                
                // 获取源文件目录和完整路径
                try {
                    sourceDir = selectedItem.sourceDir;
                    inputPath = selectedItem.fullPath || (sourceDir + fileName);
                    console.log("获取到源文件目录:", sourceDir);
                    console.log("获取到源文件路径:", inputPath);
                } catch(e) {
                    console.log("无法获取源目录，使用默认值:", e);
                    sourceDir = "";
                    inputPath = root.filePath + fileName;
                }
                
                var outputPath = "";
                var outputFileName = "";
                
                // 设置输出路径
                if (sourceDir && sourceDir.length > 0) {
                    // 使用源目录作为输出目录
                    var baseName = fileName;
                    if (baseName.indexOf(".xor") > 0) {
                        baseName = baseName.substring(0, baseName.lastIndexOf(".xor"));
                    } else if (baseName.indexOf(".aes") > 0) {
                        baseName = baseName.substring(0, baseName.lastIndexOf(".aes"));
                    } else if (baseName.indexOf(".rsa") > 0) {
                        baseName = baseName.substring(0, baseName.lastIndexOf(".rsa"));
                    } else if (baseName.indexOf(".enc") > 0) {
                        baseName = baseName.substring(0, baseName.lastIndexOf(".enc"));
                    }
                    outputFileName = "decrypted_" + baseName;
                    outputPath = sourceDir + outputFileName;
                } else {
                    // 使用当前目录
                    var baseName = fileName;
                    if (baseName.indexOf(".xor") > 0) {
                        baseName = baseName.substring(0, baseName.lastIndexOf(".xor"));
                    } else if (baseName.indexOf(".aes") > 0) {
                        baseName = baseName.substring(0, baseName.lastIndexOf(".aes"));
                    } else if (baseName.indexOf(".rsa") > 0) {
                        baseName = baseName.substring(0, baseName.lastIndexOf(".rsa"));
                    } else if (baseName.indexOf(".enc") > 0) {
                        baseName = baseName.substring(0, baseName.lastIndexOf(".enc"));
                    }
                    outputFileName = "decrypted_" + baseName;
                    outputPath = root.filePath + outputFileName;
                }
                
                console.log("批量解密文件: " + inputPath + " -> " + outputPath);
                
                // 保存最后一个输出路径
                lastOutputFilePath = outputPath;
                
                var success = false;
                // 执行解密
                switch (encryptionMethod) {
                    case 0:  // Legacy XOR
                        directoryHandler.deCodeFile(inputPath, outputPath, passwordField.text);
                        success = true;
                        break;
                        
                    case 1:  // AES
                        if (keySelector.currentIndex >= 0) {
                            // 使用选择的AES密钥
                            var selectedKeyName = keySelector.model[keySelector.currentIndex].name;
                            success = directoryHandler.decryptFileAES(inputPath, outputPath, selectedKeyName);
                        } else if (aesPasswordField.text.length > 0) {
                            // 使用手动输入的密码
                            success = directoryHandler.decryptFileAES(inputPath, outputPath, aesPasswordField.text);
                        }
                        break;
                        
                    case 2:  // RSA
                        success = directoryHandler.decryptFileRSA(inputPath, outputPath, keySelector.currentText, keyPasswordField.text);
                        break;
                        
                    case 3:  // Hybrid
                        success = directoryHandler.decryptFileHybrid(inputPath, outputPath, keySelector.currentText, keyPasswordField.text);
                        break;
                }
                
                if (success) {
                    processedCount++;
                    
                    // 将处理成功的文件信息存储起来
                    processedFiles.push({
                        path: outputPath,
                        name: outputFileName,
                        sourceDir: sourceDir
                    });
                    
                    // 直接添加到文件列表
                    addResultFileToList(outputPath);
                } else {
                    errorCount++;
                    console.log("解密文件失败: " + fileName);
                }
            }
        }
        
        // 将所有处理成功的文件添加到列表
        for (var j = 0; j < processedFiles.length; j++) {
            var fileInfo = processedFiles[j];
            
            // 检查文件是否已经在列表中
            var exists = false;
            for (var k = 0; k < fileModel.count; k++) {
                if (fileModel.get(k).name === fileInfo.name && 
                    fileModel.get(k).sourceDir === fileInfo.sourceDir) {
                    exists = true;
                    break;
                }
            }
            
            // 如果不存在则添加
            if (!exists) {
                fileModel.append({
                    "name": fileInfo.name,
                    "time": new Date().getTime() / 1000,
                    "sourceDir": fileInfo.sourceDir,
                    "fullPath": fileInfo.path
                });
                
                console.log("已添加新文件到列表: " + fileInfo.name);
            }
        }
        
        // 显示结果
        if (errorCount > 0) {
            showStatus("批量解密完成: " + processedCount + " 个成功，" + errorCount + " 个失败");
        } else {
            showStatus("批量解密完成: " + processedCount + " 个文件");
        }
        
        // 退出批量模式 - 使用toggleBatchMode确保一致性
        if (batchMode) {
            toggleBatchMode();
        } else {
            // 以防万一，直接清除选择状态
            clearAllSelections();
        }
    }
}
