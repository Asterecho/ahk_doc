; IntelliSense (based on the v1 script by Rajat)
; https://www.autohotkey.com
; This script watches while you edit an AutoHotkey script.  When it sees you
; type a command followed by a comma or space, it displays that command's
; parameter list to guide you.  In addition, you can press Ctrl+F1 (or
; another hotkey of your choice) to display that command's page in the help
; file. To dismiss the parameter list, press Escape or Enter.

; CONFIGURATION SECTION: Customize the script with the following variables.

; The hotkey below is pressed to display the current command's page in the
; help file:
I_HelpHotkey := "^F1"

; The string below must exist somewhere in the active window's title for
; IntelliSense to be in effect while you're typing.  Make it blank to have
; IntelliSense operate in all windows.  Make it Pad to have it operate in
; editors such as Metapad, Notepad, and Textpad.  Make it .ahk to have it
; operate only when a .ahk file is open in Notepad, Metapad, etc.
I_Editor := "pad"

; If you wish to have a different icon for this script to distinguish it from
; other scripts in the tray, provide the filename below (leave blank to have
; no icon). For example: E:\stuff\Pics\icons\GeoIcons\Information.ico
I_Icon := ""

; END OF CONFIGURATION SECTION (do not make changes below this point unless
; you want to change the basic functionality of the script).

SetKeyDelay 0
#SingleInstance

if I_HelpHotkey != ""
    Hotkey I_HelpHotkey, "I_HelpHotkey"

; Change tray icon (if one was specified in the configuration section above):
if I_Icon != ""
    if FileExist(I_Icon)
        TraySetIcon I_Icon

; Determine AutoHotkey's location:
try
    ahk_dir := RegRead("HKEY_LOCAL_MACHINE\SOFTWARE\AutoHotkey", "InstallDir")
catch  ; Not found, so look for it in some other common locations.
{
    if A_AhkPath
        SplitPath A_AhkPath,, ahk_dir
    else if FileExist("..\..\AutoHotkey.chm")
        ahk_dir := "..\.."
    else if FileExist(A_ProgramFiles "\AutoHotkey\AutoHotkey.chm")
        ahk_dir := A_ProgramFiles "\AutoHotkey"
    else
    {
        MsgBox "Could not find the AutoHotkey folder."
        ExitApp
    }
}

ahk_help_file := ahk_dir "\AutoHotkey.chm"

; Read command syntaxes; can be found in AHK Basic, but it's outdated:
Loop Read, ahk_dir "\Extras\Editors\Syntax\Commands.txt"
{
    I_FullCmd := A_LoopReadLine

    ; Directives have a first space instead of a first comma.
    ; So use whichever comes first as the end of the command name:
    I_cPos := InStr(I_FullCmd, "(")
    I_sPos := InStr(I_FullCmd, "`s")
    if (!I_cPos or (I_cPos > I_sPos and I_sPos))
        I_EndPos := I_sPos
    else
        I_EndPos := I_cPos

    if I_EndPos
        I_CurrCmd := SubStr(I_FullCmd, 1, I_EndPos - 1)
    else  ; This is a directive/command with no parameters.
        I_CurrCmd := A_LoopReadLine
    
    I_CurrCmd := StrReplace(I_CurrCmd, "[")
    I_CurrCmd := StrReplace(I_CurrCmd, "`s")
    I_FullCmd := StrReplace(I_FullCmd, "``n", "`n")
    I_FullCmd := StrReplace(I_FullCmd, "``t", "`t")
    
    ; Make arrays of command names and full cmd syntaxes:
    I_Cmd%A_Index% := I_CurrCmd
    I_FullCmd%A_Index% := I_FullCmd
}

; Use the Input command to watch for commands that the user types:
Loop
{
    ; Editor window check:
    if !WinActive(I_Editor)
    {
        ToolTip
        Sleep 500
        Continue
    }
    
    ; Get all keys till endkey:
    I_Hook := I_Input("V", "{Enter}{Escape}{Space},")
    I_Word := I_Hook.Input
    I_EndKey := I_Hook.EndKey
    
    ; ToolTip is hidden in these cases:
    if I_EndKey = "Enter" or I_EndKey = "Escape"
    {
        ToolTip
        Continue
    }

    ; Editor window check again!
    if !WinActive(I_Editor)
    {
        ToolTip
        Continue
    }

    ; Compensate for any indentation that is present:
    I_Word := StrReplace(I_Word, "`s")
    I_Word := StrReplace(I_Word, "`t")
    if I_Word = ""
        Continue
    
    ; Check for commented line:
    I_Check := SubStr(I_Word, 1, 1)
    if (I_Check = ";" or I_Word = "If")  ; "If" seems a little too annoying to show tooltip for.
        Continue

    ; Match word with command:
    I_Index := ""
    Loop
    {
        ; It helps performance to resolve dynamic variables only once.
        ; In addition, the value put into I_ThisCmd is also used by the
        ; I_HelpHotkey subroutine:
        I_ThisCmd := I_Cmd%A_Index%
        if I_ThisCmd = ""
            break
        if (I_Word = I_ThisCmd)
        {
            I_Index := A_Index
            I_HelpOn := I_ThisCmd
            break
        }
    }
    
    ; If no match then resume watching user input:
    if I_Index = ""
        Continue
    
    ; Show matched command to guide the user:
    I_ThisFullCmd := I_FullCmd%I_Index%
    CaretGetPos I_CaretX, I_CaretY
    ToolTip I_ThisFullCmd, I_CaretX, I_CaretY + 20
}



; This script was originally written for AutoHotkey v1.
; I_Input() is a rough reproduction of the Input command.
I_Input(Options:="", EndKeys:="", MatchList:="") {
    static ih
    if IsSet(ih) && ih.InProgress
        ih.Stop()
    ih := InputHook(Options, EndKeys, MatchList)
    ih.Start()
    ih.Wait()
    return ih
}



I_HelpHotkey:
if !WinActive(I_Editor)
    return

ToolTip  ; Turn off syntax helper since there is no need for it now.

SetTitleMatchMode 1  ; In case it's 3. This setting is in effect only for this thread.
if !WinExist("AutoHotkey Help")
{
    if !FileExist(ahk_help_file)
    {
        MsgBox "Could not find the help file: " ahk_help_file
        return
    }
    Run ahk_help_file
    WinWait "AutoHotkey Help"
}

if I_ThisCmd = ""  ; Instead, use what was most recently typed.
    I_ThisCmd := I_Word

; The above has set the "last found" window which we use below:
WinActivate
WinWaitActive
I_ThisCmd := StrReplace(I_ThisCmd, "#", "{#}")  ; Replace leading #, if any.
Send "!n{home}+{end}" I_HelpOn "{enter}"
return
