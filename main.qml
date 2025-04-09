import QtQuick 2.15
import QtQuick.Window 2.15
import QtQuick.Controls 2.15
import QtQuick.LocalStorage 2.0
import "database.js" as DB

Window {
    id: root
    width: 1280
    height: 800
    visible: true
    title: qsTr("高级文件加解密系统")
    color: "#F7F9FC"

    // Global properties
    property string loginAccount: ""
    property string loginPasswd: ""
    property string filePath: "./"
    property string tipTitle: ""

    // Each screen is a separate Loader
    Loader {
        id: loginLoader
        anchors.fill: parent
        source: "Login.qml"
        active: true
    }

    Loader {
        id: endeCodeLoader
        anchors.fill: parent
        source: "EnDeCode.qml"
        active: false
        asynchronous: false
        onLoaded: {
            console.log("EnDeCode界面加载完成")
            if (item) {
                console.log("EnDeCode.item 存在，设置visible为true")
                item.visible = true
                // 强制刷新一次
                if (item.refreshFileList) {
                    console.log("调用EnDeCode.refreshFileList()刷新文件列表")
                    item.refreshFileList()
                } else {
                    console.log("错误: EnDeCode.refreshFileList 方法不存在")
                }
            } else {
                console.log("错误: EnDeCode.item 为null")
            }
        }
        onActiveChanged: {
            console.log("EnDeCode界面激活状态变为: " + active)
            if (active) {
                console.log("显式关闭login界面")
                loginLoader.active = false
            }
        }
        onStatusChanged: {
            var statusStr = "未知";
            if (status === Loader.Null) statusStr = "Null";
            else if (status === Loader.Ready) statusStr = "Ready";
            else if (status === Loader.Loading) statusStr = "Loading";
            else if (status === Loader.Error) statusStr = "Error";
            console.log("EnDeCode加载状态变化: " + statusStr);

            if (status === Loader.Error) {
                console.log("EnDeCode加载错误");
            } else if (status === Loader.Ready) {
                console.log("EnDeCode已准备就绪");
            }
        }
    }

    Loader {
        id: keyManagerLoader
        anchors.fill: parent
        source: "KeyManager.qml"
        active: false
    }

    // Global Status/Message Popup
    Popup {
        id: statusPopup
        anchors.centerIn: parent
        width: 500
        height: 220
        modal: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        z: 1000 // 确保在其他元素上方显示

        background: Rectangle {
            radius: 12
            color: "#FFFFFF"
            border.width: 1
            border.color: "#ECECED"
        }

        contentItem: Item {
            anchors.fill: parent

            Text {
                anchors.centerIn: parent
                width: parent.width - 40
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                wrapMode: Text.WordWrap
                font.pixelSize: 24
                color: "#101828"
                text: tipTitle
            }

            Button {
                width: 120
                height: 44
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 20

                background: Rectangle {
                    radius: 8
                    color: "#5FAAE3"
                }

                contentItem: Text {
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    font.pixelSize: 16
                    color: "white"
                    text: "确定"
                }

                onClicked: {
                    console.log("关闭状态提示框")
                    statusPopup.close()
                }
            }
        }

        // 自动关闭定时器
        Timer {
            id: autoCloseTimer
            interval: 3000
            running: statusPopup.visible
            repeat: false
            onTriggered: {
                console.log("自动关闭状态提示框")
                statusPopup.close()
            }
        }
    }

    Component.onCompleted: {
        // Initialize database
        DB.openDB()
        DB.initDBUserInfo()

        // Check if user exists, set default if not
        var result = DB.readDBUserInfo()
        if (result.rows.length === 0) {
            loginAccount = "admin"
            loginPasswd = "admin"
            DB.storeDBUserInfo("admin", "admin")
        } else {
            loginAccount = result.rows.item(0).name
            loginPasswd = result.rows.item(0).passwd
        }
    }

    // Function to update user credentials
    function updateUser(name, passwd) {
        DB.updateDBUserInfo(1, name, passwd)
    }

    // Function to show status message
    function showStatus(message) {
        console.log("显示状态: " + message)
        tipTitle = message
        statusPopup.open()
    }

    // Navigation functions using Loaders instead of visibility
    function showLogin() {
        loginLoader.active = true
        endeCodeLoader.active = false
        keyManagerLoader.active = false
    }

    function showEnDeCode() {
        console.log("正在切换到EnDeCode界面");

        // 先关闭其他界面，然后再激活EnDeCode
        loginLoader.active = false;
        keyManagerLoader.active = false;

        // 延迟激活EnDeCode，给UI线程一点时间清理其他界面
        Qt.callLater(function() {
            console.log("开始激活EnDeCode界面");
            endeCodeLoader.active = true;

            // 如果加载器已经是Ready状态，直接刷新
            if (endeCodeLoader.status === Loader.Ready) {
                console.log("EnDeCode已经是Ready状态，直接刷新");
                if (endeCodeLoader.item && endeCodeLoader.item.refreshFileList) {
                    endeCodeLoader.item.refreshFileList();
                }
            }
        });
    }

    function showKeyManager() {
        loginLoader.active = false
        endeCodeLoader.active = false
        keyManagerLoader.active = true

        // Trigger refresh if needed
        if (keyManagerLoader.item) {
            keyManagerLoader.item.refreshKeys()
        }
    }

    // Function to reload the app
    function reload() {
        // 强制卸载所有加载器
        loginLoader.active = false
        endeCodeLoader.active = false
        keyManagerLoader.active = false

        // 等待一下后重新加载登录界面
        Qt.callLater(function() {
            console.log("重新加载界面");
            loginLoader.active = true;
        });
    }
}
