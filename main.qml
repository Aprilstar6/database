import QtQuick 2.15
import QtQuick.Window 2.15
import QtQuick.Controls 2.15
import "./" as Qml
import "database.js" as DB
import QtQuick.LocalStorage 2.0

Window {
    id: root
    width: 1280
    height: 800
    visible: true
    title: qsTr("高级文件加解密系统")
    color: "#172227"

    // Global properties
    property string loginAccount: ""
    property string loginPasswd: ""
    property string filePath: "./"  // Path for encryption/decryption files
    property string tipTitle: ""   // Title for status messages

    // Background image
    Image {
        anchors.fill: parent
        source: "qrc:/img/bg.jpg"
        fillMode: Image.PreserveAspectCrop
    }

    // Main components - only one visible at a time
    Qml.Login {
        id: login
        visible: true
        opacity: 0.95
    }

    Qml.EnDeCode {
        id: enDeCode
        visible: false
    }

    Qml.KeyManager {
        id: keyManager
        visible: false
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

    // Navigation functions
    function showLogin() {
        login.visible = true
        enDeCode.visible = false
        keyManager.visible = false
    }

    function showEnDeCode() {
        login.visible = false
        enDeCode.visible = true
        keyManager.visible = false
    }

    function showKeyManager() {
        login.visible = false
        enDeCode.visible = false
        keyManager.visible = true
        keyManager.refreshKeys()
    }
}
