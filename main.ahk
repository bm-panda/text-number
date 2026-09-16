#Requires AutoHotkey v2.0
#Include "JSON.ahk"

if A_Args.Length = 0 {
    TrayTip "文本编号", "请选中文本后双击 Ctrl+C 触发本脚本", "Iconi"
    ExitApp 0
}
paramsPath := A_Args[1]

try payload := JSON.parse(FileRead(paramsPath, "UTF-8"))
catch {
    TrayTip "文本编号", "参数解析失败", "Iconi"
    ExitApp 1
}

env := payload.Has("environment") ? payload["environment"] : Map()
apiBase := env.Has("api_base") ? env["api_base"] : ""

data := payload.Has("data") ? payload["data"] : Map()
userText := (data.Has("text") && data["text"].Length) ? data["text"][1] : ""
if (userText = "") {
    Notify(apiBase, "请选中文本后双击 Ctrl+C 唤醒脚本", "info")
    ExitApp 0
}

lines := StrSplit(userText, "`n", "`r")
nonEmptyCount := 0
for line in lines {
    if Trim(line) != "" {
        nonEmptyCount++
    }
}

if (nonEmptyCount = 0) {
    Notify(apiBase, "选中的文本为空", "info")
    ExitApp 0
}

targetHwnd := WinExist("A")

choice := ShowFormatGui(nonEmptyCount)
if (choice[1] = 0) {
    ExitApp 0
}
formatType := choice[1]
autoPaste := choice[2]

numberedText := NumberLines(lines, formatType)

A_Clipboard := ""
A_Clipboard := numberedText
if !ClipWait(0.5) {
    Notify(apiBase, "剪贴板操作失败", "error")
    ExitApp 1
}

pasted := false
if (autoPaste && targetHwnd && WinExist(targetHwnd) && WinGetClass(targetHwnd) != "ConsoleWindowClass") {
    WinActivate(targetHwnd)
    Sleep 100
    Send("^v")
    pasted := true
}

Notify(apiBase, pasted ? "编号完成，已替换选中文本" : "编号完成，结果已复制到剪贴板", "success")
ExitApp 0

BoxNotify(apiBase, notifyType, message) {
    try {
        body := JSON.stringify(Map("notify_type", notifyType, "message", message, "duration", 3000), , "")
        whr := ComObject("WinHttp.WinHttpRequest.5.1")
        whr.Open("POST", apiBase . "/api/notify", false)
        whr.SetRequestHeader("Content-Type", "application/json")
        whr.Send(body)
        return true
    }
    return false
}

Notify(apiBase, message, notifyType) {
    if (apiBase != "" && BoxNotify(apiBase, notifyType, message))
        return
    TrayTip "文本编号", message, "Iconi"
}

ShowFormatGui(lineCount) {
    result := 0
    autoPaste := true
    myGui := Gui("+AlwaysOnTop +ToolWindow", "文本编号")
    myGui.SetFont("s9", "Microsoft YaHei UI")
    myGui.Add("Text", "w430", "已获取 " . lineCount . " 行文本，请选择编号格式：")

    fmtDefs := [
        "1 2 3  (纯数字)",
        "01 02 03  (前导零)",
        "(1) (2) (3)  (半角括号)",
        "（1）（2）（3）(全角括号)",
        "[1] [2] [3]  (方括号)",
        "【1】【2】【3】(空心括号)",
        "1. 2. 3.  (数字加点)",
        "a b c  (小写字母)",
        "A B C  (大写字母)",
        "① ② ③  (带圈数字)",
        "i ii iii  (小写罗马)",
        "I II III  (大写罗马)",
        "一 二 三  (中文小写)",
        "壹 贰 叁  (中文大写)"
    ]
    for i, fmt in fmtDefs {
        row := Mod(i - 1, 7) + 1
        col := (i <= 7) ? 1 : 2
        opts := "vFmt" . i
        if i = 1
            opts .= " Checked Group"
        opts .= " x" . ((col = 1) ? 12 : 225) . " y" . (40 + (row - 1) * 26)
        myGui.Add("Radio", opts, fmt)
    }

    myGui.Add("CheckBox", "vAutoPaste Checked", "编号后自动粘贴替换选中文本")
    myGui.Add("Button", "Default w80 xm", "确定").OnEvent("Click", OkBtn)
    myGui.Add("Button", "x+m w80", "取消").OnEvent("Click", CancelBtn)
    myGui.OnEvent("Escape", CancelBtn)
    myGui.Show()
    WinWaitClose(myGui)
    return [result, autoPaste]

    OkBtn(*) {
        sub := myGui.Submit()
        result := 0
        loop 14 {
            if sub.%("Fmt" . A_Index)% {
                result := A_Index
                break
            }
        }
        autoPaste := sub.AutoPaste
        myGui.Destroy()
    }

    CancelBtn(*) {
        result := 0
        autoPaste := false
        myGui.Destroy()
    }
}

NumberLines(lines, formatType) {
    result := ""
    idx := 0
    for line in lines {
        trimmed := Trim(line)
        if (trimmed = "") {
            if (result != "") {
                result .= "`n"
            }
            continue
        }
        idx++
        prefix := GetPrefix(idx, formatType)
        result .= prefix . " " . line . "`n"
    }
    return RTrim(result, "`n")
}

GetPrefix(index, formatType) {
    switch formatType {
        case 1:  return index                              ; 1 2 3
        case 2:  return (index < 10) ? "0" . index : index ; 01 02 03
        case 3:  return "(" . index . ")"                   ; (1) (2) (3)
        case 4:  return "（" . index . "）"                  ; （1）（2）（3）
        case 5:  return "[" . index . "]"                   ; [1] [2] [3]
        case 6:  return "【" . index . "】"                  ; 【1】【2】【3】
        case 7:  return index . "."                         ; 1. 2. 3.
        case 8:  return (index > 26) ? index : Chr(96 + index)  ; a b c
        case 9:  return (index > 26) ? index : Chr(64 + index)  ; A B C
        case 10: return IntToCircled(index)                 ; ① ② ③
        case 11: return StrLower(IntToRoman(index))         ; i ii iii
        case 12: return IntToRoman(index)                   ; I II III
        case 13: return IntToChinese(index)                 ; 一 二 三
        case 14: return IntToChineseFinancial(index)        ; 壹 贰 叁
    }
    return index
}

IntToRoman(n) {
    values := [1000, 900, 500, 400, 100, 90, 50, 40, 10, 9, 5, 4, 1]
    numerals := ["M", "CM", "D", "CD", "C", "XC", "L", "XL", "X", "IX", "V", "IV", "I"]
    result := ""
    for i, v in values {
        while (n >= v) {
            result .= numerals[i]
            n -= v
        }
    }
    return result
}

IntToCircled(n) {
    if (n < 1 || n > 20)
        return n
    return Chr(0x245F + n)
}

IntToChinese(n) {
    if (n = 0)
        return "零"
    digits := ["零", "一", "二", "三", "四", "五", "六", "七", "八", "九"]
    if (n <= 10)
        return (n = 10) ? "十" : digits[n + 1]
    result := ""
    units := ["", "十", "百", "千"]
    pos := 0
    needZero := false
    while n > 0 {
        d := Mod(n, 10)
        n := Floor(n / 10)
        if d > 0 {
            if needZero {
                result := "零" . result
                needZero := false
            }
            result := digits[d + 1] . units[pos + 1] . result
        } else if result != "" {
            needZero := true
        }
        pos++
    }
    if (SubStr(result, 1, 2) = "一十")
        result := SubStr(result, 2)
    return result
}

IntToChineseFinancial(n) {
    ch := IntToChinese(n)
    ch := StrReplace(ch, "一", "壹")
    ch := StrReplace(ch, "二", "贰")
    ch := StrReplace(ch, "三", "叁")
    ch := StrReplace(ch, "四", "肆")
    ch := StrReplace(ch, "五", "伍")
    ch := StrReplace(ch, "六", "陆")
    ch := StrReplace(ch, "七", "柒")
    ch := StrReplace(ch, "八", "捌")
    ch := StrReplace(ch, "九", "玖")
    ch := StrReplace(ch, "十", "拾")
    ch := StrReplace(ch, "百", "佰")
    ch := StrReplace(ch, "千", "仟")
    return ch
}