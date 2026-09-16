Option Explicit

Dim shell, fileSystem, projectDirectory, chillPath, command
Set shell = CreateObject("WScript.Shell")
Set fileSystem = CreateObject("Scripting.FileSystemObject")

projectDirectory = fileSystem.GetParentFolderName(WScript.ScriptFullName)
chillPath = projectDirectory & "\src\Chill.ps1"
command = "powershell.exe -NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File """ & chillPath & """"

shell.Run command, 0, False
