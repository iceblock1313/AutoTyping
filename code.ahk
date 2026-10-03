#Requires AutoHotkey v2.0
#SingleInstance Force

; ===== 全局变量 =====
global sendKey := "F7"        ; 发送热键
global stopKey := "F8"        ; 停止热键
global exitKey := "F9"        ; 退出热键
global loopMode := false      ; 循环模式
global sleepTime := 3050      ; 发送间隔（毫秒）
global delimiter := "`n"      ; 分隔符，默认换行
global isRunning := false     ; 是否正在发送
global MyGui := ""            ; 设置窗口对象
global items := []            ; 待发送的内容列表
global idx := 0               ; 当前发送位置

; ===== 开始发送 =====
SendClipboard(*) {
    global isRunning, items, idx, delimiter
    if (isRunning) {
        TrayTip("请等待完成或者按下停止热键", "自动输入进行中", 1)
        return
    }
    text := A_Clipboard
    if (text = "") {
        TrayTip("请先复制要发送的内容", "剪贴板为空", 1)
        return
    }

    ; 拆分并过滤空项
    items := []
    omit := (delimiter = "`n") ? "`r" : ""
    for part in StrSplit(text, delimiter, omit) {
        if (part != "")
            items.Push(part)
    }
    if (items.Length = 0) {
        TrayTip("没有可发送的内容", "发送终止", 1)
        return
    }

    isRunning := true
    idx := 0
    SetTimer(SendNext, -1)    ; 立即发送第一条
}

; ===== 发送下一条（由定时器调用） =====
SendNext() {
    global isRunning, items, idx, loopMode, sleepTime
    if (!isRunning)
        return
    idx++
    if (idx > items.Length)
        idx := 1              ; 仅循环模式会走到这里

    SendInput("{Text}" . items[idx])
    SendInput("{Enter}")

    if (!isRunning)           ; 发送过程中若被停止，不再继续安排
        return
    if (idx = items.Length && !loopMode) {
        FinishSending("已输入完毕", "发送结束")
        return
    }
    SetTimer(SendNext, -sleepTime)
}

; ===== 结束发送 =====
FinishSending(msg, title) {
    global isRunning
    SetTimer(SendNext, 0)
    isRunning := false
    TrayTip(msg, title, 1)
}

; ===== 停止发送 =====
StopSending(*) {
    global isRunning
    if (isRunning)
        FinishSending("手动停止了发送", "发送终止")
    else
        TrayTip("没有需要终止的任务", "未在进行自动输入", 1)
}

; ===== 退出脚本 =====
ExitScript(*) {
    ExitApp
}

; ===== 发送/停止切换（发送键与停止键相同时使用） =====
ToggleSendStop(*) {
    global isRunning
    if (isRunning)
        StopSending()
    else
        SendClipboard()
}

; ===== 注册一组热键，返回错误信息（空字符串表示全部成功） =====
ApplyHotkeys(sKey, tKey, eKey) {
    errors := ""
    if (sKey = tKey) {
        try Hotkey(sKey, ToggleSendStop, "On")
        catch as err
            errors .= "发送与停止热键 (" . sKey . ") 注册失败: " . err.Message . "`n"
    } else {
        try Hotkey(sKey, SendClipboard, "On")
        catch as err
            errors .= "发送热键 (" . sKey . ") 注册失败: " . err.Message . "`n"
        try Hotkey(tKey, StopSending, "On")
        catch as err
            errors .= "停止热键 (" . tKey . ") 注册失败: " . err.Message . "`n"
    }
    try Hotkey(eKey, ExitScript, "On")
    catch as err
        errors .= "退出热键 (" . eKey . ") 注册失败: " . err.Message . "`n"
    return errors
}

; ===== 打开设置菜单 =====
OpenSettings(*) {
    global loopMode, sleepTime, delimiter, sendKey, stopKey, exitKey, MyGui, isRunning
    if (isRunning) {
        TrayTip("请等待完成或者按下停止热键", "自动输入进行中", 1)
        return
    }
    if (MyGui != "") {
        try MyGui.Destroy()
    }

    MyGui := Gui(, "自动输入设置")
    MyGui.SetFont("S10")
    MyGui.MarginX := 20
    MyGui.MarginY := 20

    MyGui.Add("CheckBox", "vLoopMode xm", "循环发送").Value := loopMode

    MyGui.Add("Text", "xm w120", "发送间隔（毫秒）：")
    MyGui.Add("Edit", "vSleepTime x+10 yp w100", sleepTime)

    ; 分隔符：根据当前值设置默认选中
    isNewLine := (delimiter = "`n")
    isSpace := (delimiter = " ")
    isCustom := !isNewLine && !isSpace
    MyGui.Add("Text", "xm w120", "分隔符：")
    MyGui.Add("Radio", "vDelimNewLine x+10 yp", "换行").Value := isNewLine
    MyGui.Add("Radio", "vDelimSpace x+10 yp", "空格").Value := isSpace
    MyGui.Add("Radio", "vDelimCustom x+10 yp", "自定义").Value := isCustom
    MyGui.Add("Edit", "vCustomDelim x+10 yp w50", isCustom ? delimiter : "")

    MyGui.Add("Text", "xm w120", "发送热键：")
    MyGui.Add("Edit", "vSendKey x+10 yp w100", sendKey)

    MyGui.Add("Text", "xm w120", "停止热键：")
    MyGui.Add("Edit", "vStopKey x+10 yp w100", stopKey)

    MyGui.Add("Text", "xm w120", "退出热键：")
    MyGui.Add("Edit", "vExitKey x+10 yp w100", exitKey)

    MyGui.SetFont("S8 cGray")   ; 临时改成 8 号灰色字体
    MyGui.Add("Text", "xm w280", "提示：发送和停止热键现在可以合并为一个热键。")
    MyGui.SetFont("S10 cBlack")

    MyGui.Add("Button", "Default w80 xm", "保存").OnEvent("Click", SaveSettings)
    MyGui.Add("Button", "w80 x+10 yp", "取消").OnEvent("Click", CancelSettings)
    MyGui.OnEvent("Close", CancelSettings)

    MyGui.Show()
}

; ===== 取消设置 =====
CancelSettings(*) {
    global MyGui
    if (MyGui != "") {
        MyGui.Destroy()
        MyGui := ""
    }
}

; ===== 保存设置 =====
SaveSettings(*) {
    global loopMode, sleepTime, delimiter, sendKey, stopKey, exitKey, MyGui
    saved := MyGui.Submit(false)   ; false：不隐藏窗口，验证失败时用户还能继续修改

    ; 验证发送间隔
    if (!IsNumber(saved.SleepTime) || saved.SleepTime < 0) {
        MsgBox("发送间隔必须是非负数字", "错误", "Icon!")
        return
    }

    ; 处理分隔符
    if (saved.DelimNewLine)
        newDelim := "`n"
    else if (saved.DelimSpace)
        newDelim := " "
    else if (saved.DelimCustom) {
        if (StrLen(saved.CustomDelim) != 1) {
            MsgBox("自定义分隔符必须是单个字符", "错误", "Icon!")
            return
        }
        newDelim := saved.CustomDelim
    } else {
        newDelim := "`n"
    }

    ; 验证热键
    newSendKey := Trim(saved.SendKey)
    newStopKey := Trim(saved.StopKey)
    newExitKey := Trim(saved.ExitKey)
    if (newSendKey = "" || newStopKey = "" || newExitKey = "") {
        MsgBox("热键不能为空", "错误", "Icon!")
        return
    }
    if (newSendKey = "F10" || newStopKey = "F10" || newExitKey = "F10") {
        MsgBox("热键不能设置为 F10，因为 F10 是设置菜单热键。", "错误", "Icon!")
        return
    }
    if (newSendKey = newExitKey || newStopKey = newExitKey) {
        MsgBox("退出热键不能与发送热键或停止热键相同", "错误", "Icon!")
        return
    }

    ; 关闭旧热键，尝试注册新热键
    for k in [sendKey, stopKey, exitKey]
        try Hotkey(k, "Off")

    errors := ApplyHotkeys(newSendKey, newStopKey, newExitKey)

    if (errors != "") {
        ; ---- 回滚：先关掉新热键，再恢复旧热键 ----
        for k in [newSendKey, newStopKey, newExitKey]
            try Hotkey(k, "Off")
        ApplyHotkeys(sendKey, stopKey, exitKey)
        MsgBox("设置未保存，已恢复原有热键。`n`n" . errors, "热键注册失败", "Icon!")
        return   ; 窗口保留，用户可以直接修改
    }

    ; 全部成功才更新全局变量
    loopMode := saved.LoopMode ? true : false
    sleepTime := Integer(saved.SleepTime)
    delimiter := newDelim
    sendKey := newSendKey
    stopKey := newStopKey
    exitKey := newExitKey
    UpdateTrayMenu()
    MyGui.Destroy()
    MyGui := ""
    TrayTip("热键和参数已更新", "设置已保存", 1)
}

; ===== 更新托盘菜单 =====
UpdateTrayMenu() {
    try {
        A_TrayMenu.Delete()   ; 删除默认菜单项
        if (sendKey = stopKey) {
            A_TrayMenu.Add("发送/停止`t" . sendKey, (*) => ToggleSendStop())
        } else {
            A_TrayMenu.Add("发送`t" . sendKey, (*) => SendClipboard())
            A_TrayMenu.Add("停止`t" . stopKey, (*) => StopSending())
            A_TrayMenu.Add()      ; 分隔线
        }
        A_TrayMenu.Add("设置`tF10", (*) => OpenSettings())
        A_TrayMenu.Add()      ; 分隔线
        A_TrayMenu.Add("退出`t" . exitKey, (*) => ExitApp())
    }
    catch as err {
        MsgBox("啊哦，托盘菜单更新失败: " . err.Message . "`n建议使用热键退出程序并重启", "错误", "Icon!")
    }
}

; ===== 初始化托盘菜单 =====
SetupTrayMenu() {
    UpdateTrayMenu()
    A_IconTip := "自动打字机"
}

; ===== 固定热键：F10 打开设置 =====
F10:: OpenSettings()

; ===== 初始化注册默认热键 =====
initErrors := ApplyHotkeys(sendKey, stopKey, exitKey)
if (initErrors != "")
    MsgBox("以下热键注册失败：`n`n" . initErrors, "热键注册错误", "Icon!")
SetupTrayMenu()
