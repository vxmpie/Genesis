' --- Genesis Silent Launcher ---
Option Explicit

Dim fso, shell, scriptDir, batPath, cmd
Set fso = CreateObject("Scripting.FileSystemObject")
Set shell = CreateObject("WScript.Shell")

scriptDir = fso.GetParentFolderName(WScript.ScriptFullName)
batPath = fso.BuildPath(scriptDir, "start.bat")

If fso.FileExists(batPath) Then
    cmd = "cmd.exe /c """"" & batPath & """ --silent"""
    shell.Run cmd, 0, False
End If
