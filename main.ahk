#Requires AutoHotkey v2.0

if A_Args.Length = 0 {
    TrayTip "文本编号", "请选中文本后双击 Ctrl+C 触发本脚本", "Iconi"
    ExitApp 0
}
paramsPath := A_Args[1]

jsonText := FileRead(paramsPath, "UTF-8")
if !jsonText {
    ExitApp 1
}

userText := ExtractJsonText(jsonText)
if (userText = "") {
    TrayTip "文本编号", "未检测到选中文本", "Iconi"
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
    TrayTip "文本编号", "选中的文本为空", "Iconi"
    ExitApp 0
}

formatType := ShowFormatGui(nonEmptyCount)
if (formatType = 0) {
    ExitApp 0
}

numberedText := NumberLines(lines, formatType)

A_Clipboard := ""
A_Clipboard := numberedText
if !ClipWait(0.5) {
    TrayTip "文本编号", "剪贴板操作失败", "Iconi"
    ExitApp 1
}

TrayTip "文本编号", "编号完成，结果已复制到剪贴板", "Iconi"

q := Chr(34)
formatNames := Map(
    1, "1 2 3", 2, "01 02 03", 3, "(1) (2) (3)",
    4, "（1）（2）（3）", 5, "[1] [2] [3]", 6, "【1】【2】【3】",
    7, "1. 2. 3.", 8, "a b c", 9, "A B C",
    10, "① ② ③", 11, "i ii iii", 12, "I II III",
    13, "一 二 三", 14, "壹 贰 叁")
output := "{" . q . "summary" . q . ":" . q . "编号完成: " . nonEmptyCount . " 行" . q . ","
    . q . "details" . q . ":{" . q . "total_lines" . q . ":" . lines.Length . ","
    . q . "numbered_lines" . q . ":" . nonEmptyCount . ","
    . q . "format" . q . ":" . q . formatNames[formatType] . q . "}}"
try {
    FileAppend output, "*"
}
ExitApp 0


ExtractJsonText(json) {
    for key in ["text", "content"] {
        keyMarker := Chr(34) . key . Chr(34) . ":"
        start := InStr(json, keyMarker)
        if !start {
            continue
        }
        start += StrLen(keyMarker)
        while (start <= StrLen(json)) {
            ch := SubStr(json, start, 1)
            if (ch != " " && ch != "`t" && ch != "`n" && ch != "`r") {
                break
            }
            start++
        }
        firstChar := SubStr(json, start, 1)
        if (firstChar = "[") {
            return ExtractJsonArray(json, start)
        }
        if (firstChar = Chr(34)) {
            return ExtractJsonString(json, start + 1)
        }
    }
    return ""
}

ExtractJsonString(json, start) {
    result := ""
    i := start
    while (i <= StrLen(json)) {
        ch := SubStr(json, i, 1)
        if (ch = Chr(34)) {
            break
        }
        if (ch = "\") {
            i++
            nextCh := SubStr(json, i, 1)
            if (nextCh = Chr(34)) {
                result .= Chr(34)
            } else if (nextCh = "n") {
                result .= "`n"
            } else if (nextCh = "r") {
                result .= "`r"
            } else if (nextCh = "t") {
                result .= "`t"
            } else if (nextCh = "\") {
                result .= "\"
            } else if (nextCh = "/") {
                result .= "/"
            } else if (nextCh = "u") {
                hexStr := SubStr(json, i + 1, 4)
                result .= Chr(Integer("0x" . hexStr))
                i += 4
            } else {
                result .= "\"
            }
            i++
            continue
        }
        result .= ch
        i++
    }
    return result
}

ExtractJsonArray(json, start) {
    parts := []
    i := start + 1
    while (i <= StrLen(json)) {
        ch := SubStr(json, i, 1)
        if (ch = Chr(34)) {
            part := ExtractJsonString(json, i + 1)
            parts.Push(part)
            seek := i + 1
            while (seek <= StrLen(json)) {
                sc := SubStr(json, seek, 1)
                if (sc = Chr(34)) {
                    bc := 0
                    bk := seek - 1
                    while (bk >= 1 && SubStr(json, bk, 1) = "\") {
                        bc++
                        bk--
                    }
                    if (Mod(bc, 2) = 0) {
                        i := seek + 1
                        break
                    }
                }
                seek++
            }
            continue
        }
        if (ch = "]") {
            break
        }
        i++
    }
    out := ""
    for p in parts {
        if out != "" {
            out .= "`n"
        }
        out .= p
    }
    return out
}

ShowFormatGui(lineCount) {
    result := 0
    myGui := Gui("+AlwaysOnTop +ToolWindow", "文本编号")
    myGui.SetFont("s9", "Microsoft YaHei UI")
    myGui.Add("Text", "w360", "已获取 " . lineCount . " 行文本，请选择编号格式：")

    myGui.Add("Radio", "vFmt1 Checked Group", "1 2 3  (纯数字)")
    myGui.Add("Radio", "vFmt2", "01 02 03  (前导零)")
    myGui.Add("Radio", "vFmt3", "(1) (2) (3)  (半角括号)")
    myGui.Add("Radio", "vFmt4", "（1）（2）（3）(全角括号)")
    myGui.Add("Radio", "vFmt5", "[1] [2] [3]  (方括号)")
    myGui.Add("Radio", "vFmt6", "【1】【2】【3】(空心括号)")
    myGui.Add("Radio", "vFmt7", "1. 2. 3.  (数字加点)")
    myGui.Add("Radio", "vFmt8", "a b c  (小写字母)")
    myGui.Add("Radio", "vFmt9", "A B C  (大写字母)")
    myGui.Add("Radio", "vFmt10", "① ② ③  (带圈数字)")
    myGui.Add("Radio", "vFmt11", "i ii iii  (小写罗马)")
    myGui.Add("Radio", "vFmt12", "I II III  (大写罗马)")
    myGui.Add("Radio", "vFmt13", "一 二 三  (中文小写)")
    myGui.Add("Radio", "vFmt14", "壹 贰 叁  (中文大写)")

    myGui.Add("Button", "Default w80 xm", "确定").OnEvent("Click", OkBtn)
    myGui.Add("Button", "x+m w80", "取消").OnEvent("Click", CancelBtn)
    myGui.OnEvent("Escape", CancelBtn)
    myGui.Show()
    WinWaitClose(myGui)
    return result

    OkBtn(*) {
        sub := myGui.Submit()
        if sub.Fmt1
            result := 1
        else if sub.Fmt2
            result := 2
        else if sub.Fmt3
            result := 3
        else if sub.Fmt4
            result := 4
        else if sub.Fmt5
            result := 5
        else if sub.Fmt6
            result := 6
        else if sub.Fmt7
            result := 7
        else if sub.Fmt8
            result := 8
        else if sub.Fmt9
            result := 9
        else if sub.Fmt10
            result := 10
        else if sub.Fmt11
            result := 11
        else if sub.Fmt12
            result := 12
        else if sub.Fmt13
            result := 13
        else if sub.Fmt14
            result := 14
        myGui.Destroy()
    }

    CancelBtn(*) {
        result := 0
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
