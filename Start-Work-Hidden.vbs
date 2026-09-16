Option Explicit

Dim shell, fileSystem, projectDirectory, introPath, workPath, introCommand, workCommand
Set shell = CreateObject("WScript.Shell")
Set fileSystem = CreateObject("Scripting.FileSystemObject")

projectDirectory = fileSystem.GetParentFolderName(WScript.ScriptFullName)
introPath = projectDirectory & "\src\Work-Intro.ps1"
workPath = projectDirectory & "\src\Start-Work.ps1"

introCommand = "powershell.exe -NoProfile -NonInteractive -Sta -WindowStyle Hidden -ExecutionPolicy Bypass -File """ & introPath & """"
workCommand = "powershell.exe -NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File """ & workPath & """ -Cinematic"

shell.Run introCommand, 0, False
WScript.Sleep 350
shell.Run workCommand, 0, False
