import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Item {
    id: login
    property int passwordMode: 1 // 1 = Password hidden, 0 = Password visible
    property int funType: 0 // 0 = Login, 1 = Update Account
    property string titleStr: funType ? "设置账号" : "用户登录"
    property string btnStr: funType ? "修改" : "登录"
    
    // 密码复杂度验证函数
    function validatePassword(password) {
        // 检查是否包含至少一个大写字母
        var hasUpperCase = /[A-Z]/.test(password);
        // 检查是否包含至少一个小写字母
        var hasLowerCase = /[a-z]/.test(password);
        // 检查是否包含至少一个数字
        var hasDigit = /[0-9]/.test(password);
        // 检查是否包含至少一个特殊符号
        var hasSpecial = /[!@#$%^&*()_+\-=\[\]{};':"\\|,.<>\/?]/.test(password);
        
        // 所有条件都必须满足
        return hasUpperCase && hasLowerCase && hasDigit && hasSpecial;
    }
    
    // 密码复杂度提示文本
    property string passwordRequirements: "密码必须包含：大写字母、小写字母、数字和特殊符号"

    anchors.fill: parent

    // Prevent clicks from passing through
    MouseArea {
        anchors.fill: parent
    }

    // Login form with plain background
    Rectangle {
        id: loginContainer
        width: 680
        height: 450
        x: parent.width / 2 - width / 2
        y: parent.height / 2 - height / 2
        color: "#FFFFFF"
        radius: 10
        border.width: 1
        border.color: "#ECECED"

        // Title
        Label {
            width: parent.width
            height: 40
            y: 83
            verticalAlignment: Label.AlignVCenter
            horizontalAlignment: Label.AlignHCenter
            font.pixelSize: 28
            font.bold: true
            color: "#394149"
            text: titleStr
        }

        // Username input
        Rectangle {
            x: 136
            y: 150
            width: 410
            height: 50
            color: "#DDEEF4"
            radius: 5

            Image {
                x: 12
                y: 10
                source: "qrc:/img/ic_user.png"
            }

            TextField {
                id: accountText
                x: 53
                height: parent.height
                width: 410 - 53*2
                verticalAlignment: Label.AlignVCenter
                font.pixelSize: 20
                font.family: "微软雅黑"
                maximumLength: 50
                color: "#394149"
                text: ""
                placeholderText: "请输入账号"
                placeholderTextColor: "#626E7B"
                cursorVisible: false
                activeFocusOnPress: true
                selectByMouse: true

                background: Rectangle {
                    anchors.fill: parent
                    color: "transparent"
                }
            }
        }

        // Password input
        Rectangle {
            x: 136
            y: 231
            width: 410
            height: 50
            color: "#DDEEF4"
            radius: 5

            Image {
                x: 12
                y: 10
                source: "qrc:/img/ic_lock.png"
            }

            TextField {
                id: passwordText
                x: 53
                height: parent.height
                width: 410 - 53*2
                verticalAlignment: Label.AlignVCenter
                font.pixelSize: 20
                font.family: "微软雅黑"
                color: "#394149"
                text: ""
                placeholderText: "输入密码"
                placeholderTextColor: "#626E7B"
                maximumLength: 50
                echoMode: passwordMode ? TextInput.Password : TextInput.Normal
                cursorVisible: false
                activeFocusOnPress: true
                selectByMouse: true

                background: Rectangle {
                    anchors.fill: parent
                    color: "transparent"
                }
                
                // 添加密码验证反馈
                onTextChanged: {
                    if (funType === 1 && text.length > 0) {
                        var valid = validatePassword(text);
                        passwordHint.visible = !valid;
                        passwordRequirementsText.visible = true;
                    } else {
                        passwordHint.visible = false;
                        passwordRequirementsText.visible = funType === 1;
                    }
                }
            }

            // Toggle password visibility
            Image {
                x: 359
                anchors.verticalCenter: parent.verticalCenter
                source: passwordMode ? "qrc:/img/ic_eye.png" : "qrc:/img/ic_eye_open.png"

                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        passwordMode = !passwordMode
                    }
                }
            }
        }
        
        // 密码复杂度要求文本
        Text {
            id: passwordRequirementsText
            x: 136
            y: 285
            width: 410
            text: passwordRequirements
            font.pixelSize: 12
            color: "#626E7B"
            visible: funType === 1
        }
        
        // 密码不符合要求提示
        Rectangle {
            id: passwordHint
            x: 136
            y: 285
            width: 410
            height: 25
            color: "#FFEDED"
            visible: false
            radius: 3
            
            Text {
                anchors.centerIn: parent
                text: "密码不符合复杂度要求"
                font.pixelSize: 12
                color: "#EB1C24"
            }
        }

        // Login/Update button
        Rectangle {
            x: 136
            y: 345
            width: 410
            height: 47
            radius: 180
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: "#02C783" }
                GradientStop { position: 1.0; color: "#31D7A9" }
            }

            Text {
                anchors.centerIn: parent
                text: btnStr
                font.pixelSize: 20
                color: "white"
            }

            MouseArea {
                anchors.fill: parent
                onClicked: {
                    if (funType === 1) {
                        // Update account
                        if (accountText.text.length !== 0 && passwordText.text.length !== 0) {
                            // 添加密码复杂度检查
                            if (!validatePassword(passwordText.text)) {
                                root.showStatus("密码不符合复杂度要求")
                                return
                            }
                            
                            root.updateUser(accountText.text, passwordText.text)
                            root.loginAccount = accountText.text
                            root.loginPasswd = passwordText.text
                            console.log(funType, accountText.text, passwordText.text, root.loginAccount, root.loginPasswd)

                            funType = 0
                            accountText.text = ""
                            passwordText.text = ""
                            passwordText.color = "#394149"
                            accountText.color = "#394149"

                            root.showStatus("账号修改成功")
                        } else {
                            root.showStatus("账号和密码不能为空")
                        }
                    } else {
                        // Login
                        console.log("尝试登录", funType, accountText.text, passwordText.text, root.loginAccount, root.loginPasswd)
                        if (root.loginAccount === accountText.text && root.loginPasswd === passwordText.text) {
                            console.log("登录成功，准备显示主界面")

                            // 显示登录成功消息
                            root.showStatus("登录成功，正在清理文件列表...");
                            
                            // 延迟一点时间让UI线程有机会更新
                            var timer = Qt.createQmlObject("import QtQuick 2.15; Timer {}", login);
                            timer.interval = 600; // 稍微延长时间，让状态消息显示完整
                            timer.repeat = false;
                            timer.triggered.connect(function() {
                                // 调用showEnDeCode切换到主界面
                                console.log("登录成功，调用showEnDeCode进入主界面并清除文件");
                                root.showEnDeCode();
                            });
                            timer.start();
                            console.log("登录成功定时器已启动");
                        } else {
                            passwordText.color = "#EB1C24"
                            accountText.color = "#EB1C24"
                            root.showStatus("用户名或密码错误")
                        }
                    }
                }
            }
        }

        // Toggle between login and account creation
        Label {
            visible: funType ? false : true
            x: 136
            y: 290
            color: "#394149"
            text: "设置账号"
            font.pixelSize: 20

            MouseArea {
                anchors.fill: parent
                onClicked: {
                    funType = 1
                    accountText.text = ""
                    passwordText.text = ""
                    passwordText.color = "#394149"
                    accountText.color = "#394149"
                    // 显示密码要求
                    passwordRequirementsText.visible = true
                }
            }
        }
    }
}
