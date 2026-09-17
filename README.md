# Cinematic Windows Workflow

A customizable Windows **Work Mode / Chill Mode** launcher with a full-screen
cinematic boot animation, terminal-style diagnostics, synchronized audio, one
Windows Terminal window with multiple tool tabs, automatic window positioning,
background app minimization, and a one-click shutdown routine.

The project is designed for developers, students, researchers, and anyone who
wants a dramatic—but practical—way to enter a focused workspace.

## What it does

### Work Mode

- Plays a full-screen animated startup sequence with `Esc` to skip.
- Starts one named Windows Terminal window containing six configurable tabs.
- Delays the Feynman tab by 10 seconds after WSL starts.
- Places Windows Terminal on the right and VS Code on the left.
- Starts configurable tray/background applications and keeps them minimized.
- Opens WhatsApp and a music URL in Opera GX after the intro soundtrack ends.
- Optionally records one genuine work session per day in a separate GitHub repo.
- Writes a troubleshooting log without showing a launcher console.

### Chill Mode

- Force-closes every configured Work Mode process.
- Closes the complete Windows Terminal process tree, including CLI children.
- Shuts down all WSL distributions.
- Opens Brave for leisure time.

> **Warning:** Chill Mode force-closes matching processes. Save your VS Code
> work before running it.

## Requirements

- Windows 10 or Windows 11
- Windows PowerShell 5.1
- Windows Terminal
- WSL if you enable Linux commands
- The applications and CLI tools that you configure

Every optional application is checked before launch. Missing applications are
reported in the log instead of being silently invented or downloaded.

## Quick start

1. Clone or download this repository.
2. Open [`config.psd1`](config.psd1) and customize the values.
3. Optionally place a licensed soundtrack in `assets/`.
4. Open PowerShell in the repository directory and run:

   ```powershell
   powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Install-Shortcuts.ps1
   ```

5. Double-click **Start Cinematic Work** on the desktop.
6. Use **Chill Mode** when you want to close the workspace and open Brave.

## Configuration

All ordinary customization lives in [`config.psd1`](config.psd1).

| Setting | Purpose |
| --- | --- |
| `AssistantName` | Name displayed by the cinematic HUD |
| `OperatorName` | Name used in the welcome message |
| `IntroDurationSeconds` | Duration of the animation and soundtrack |
| `SoundFile` | Repository-relative path to an MP3 or WAV file |
| `WslDistribution` | WSL distribution name, such as `Ubuntu` |
| `MimoCommand` | Command for terminal tab 1 |
| `FeynmanLinuxCommand` | Linux path or command used for Feynman |
| `ClaudeCommand` | Command for terminal tab 4 |
| `CodexCommand` | Command for terminal tab 5 |
| `ToofanPath` | Executable used for terminal tab 6 |
| `Apps` | Paths to Terminal, VS Code, tray apps, browsers, and Brave |
| `Urls` | WhatsApp and music pages opened by Opera GX |
| `DailyLearningLog` | Optional daily Git commit and push settings |
| `CloseProcesses` | Process names force-closed by Chill Mode |

Paths may contain environment variables such as `%USERPROFILE%`,
`%LOCALAPPDATA%`, and `%ProgramFiles%`.

### Changing terminal tabs

The default layout is:

1. Mimo
2. WSL
3. Feynman, delayed by 10 seconds
4. Claude
5. Codex
6. Toofan

Change the matching command values in `config.psd1`. For a completely different
number or ordering of tabs, edit the final `Add-PowerShellTab` calls in
[`src/Start-Work.ps1`](src/Start-Work.ps1).

### Adding your own soundtrack

Copy an MP3 or WAV file that you have permission to use into `assets/`, then set:

```powershell
SoundFile = 'assets\startup-sound.mp3'
IntroDurationSeconds = 17.0
```

If the configured file is missing, the project generates a small original
eight-second synthesized fallback track. Personal audio files are ignored by
Git through [`.gitignore`](.gitignore).

Do not publish audio, character voices, movie clips, or music unless you have
the necessary redistribution rights. This repository intentionally includes no
JARVIS, Marvel, movie, or YouTube audio.

### Enabling the daily learning log

The optional updater records the first real Work Mode launch of each day in a
separate Git repository. It commits only when it adds a dated entry—there are no
empty commits—and performs the network work in a hidden background process so
application startup remains fast.

1. Create or clone a learning-log repository containing `Daily-Work-Log.md`.
2. Make sure `git push` works for that repository using your normal GitHub
   authentication.
3. Set `DailyLearningLog.Enabled` to `$true` in `config.psd1`.
4. Set `RepositoryPath`, `RemoteName`, and `BranchName` for your repository.

Check `GitHub-Update.log` after Work Mode starts. A successful entry includes
the pushed commit ID; failures include the exact Git error without interrupting
the rest of Work Mode. GitHub contributions also require the commit email to be
connected to the GitHub account.

## Project structure

```text
Cinematic-Windows-Workflow/
├── assets/
│   └── README.md
├── src/
│   ├── Chill.ps1
│   ├── Start-Work.ps1
│   ├── Update-DailyLearningLog.ps1
│   └── Work-Intro.ps1
├── .gitignore
├── config.psd1
├── Install-Shortcuts.ps1
├── LICENSE
├── Start-Chill-Hidden.vbs
└── Start-Work-Hidden.vbs
```

The VBS launchers prevent PowerShell from becoming an unwanted visible Windows
Terminal tab. Work Mode uses a unique named Terminal window so every configured
tab stays together.

## Testing without launching apps

Validate the animation:

```powershell
powershell.exe -NoProfile -Sta -ExecutionPolicy Bypass -File .\src\Work-Intro.ps1 -Validate
```

Preview Work Mode:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\src\Start-Work.ps1 -Preview -Cinematic
```

Preview Chill Mode:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\src\Chill.ps1 -Preview
```

## Troubleshooting

After a real run, inspect:

- `Start-Work.log`
- `GitHub-Update.log`
- `Work-Intro.log`
- `Chill.log`

Common causes of launch failures are incorrect executable paths, a different WSL
distribution name, or a CLI command that is not available in `PATH`.

## Privacy and safety

- No telemetry or network tracking is included.
- No passwords, tokens, or account credentials are stored.
- The GitHub updater is disabled by default and touches only its configured log
  repository and file.
- The animation can always be dismissed with `Esc`.
- The intro and application launcher run independently, so a visual failure does
  not prevent Work Mode from attempting to start.
- Chill Mode is intentionally aggressive and should be customized carefully.

## License

Released under the [MIT License](LICENSE), allowing people to use, modify, and
redistribute the code. GitHub recommends adding a license when a repository is
intended to be genuinely open source.

Created by [@NasirAldeen](https://github.com/NasirAldeen).
