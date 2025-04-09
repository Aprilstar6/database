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
                    statusPopup.close()
                }
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
        loginLoader.active = false
        endeCodeLoader.active = true
        keyManagerLoader.active = false

        // Trigger refresh if needed
        if (endeCodeLoader.item) {
            endeCodeLoader.item.refreshFileList()
        }
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
}
