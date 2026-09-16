@{
    # Identity shown by the cinematic overlay.
    AssistantName = 'ORION'
    OperatorName  = 'YOUR NAME'

    # Intro length should match your custom soundtrack.
    IntroDurationSeconds = 8.0
    SoundFile             = 'assets\startup-sound.mp3'

    # Commands used for the six Windows Terminal tabs.
    WslDistribution    = 'Ubuntu'
    MimoCommand        = 'mimo'
    FeynmanLinuxCommand = '/home/YOUR_LINUX_USER/.local/bin/feynman'
    ClaudeCommand      = 'claude'
    CodexCommand       = 'codex'
    ToofanPath         = '%USERPROFILE%\bin\toofan.exe'

    # Windows application paths. Environment variables are expanded at runtime.
    Apps = @{
        WindowsTerminal = '%LOCALAPPDATA%\Microsoft\WindowsApps\wt.exe'
        VSCode          = '%LOCALAPPDATA%\Programs\Microsoft VS Code\Code.exe'
        KeyboardSounds  = '%LOCALAPPDATA%\Programs\kbs\Keyboard Sounds.exe'
        Handy           = '%LOCALAPPDATA%\Handy\handy.exe'
        Rovyl           = '%LOCALAPPDATA%\Programs\Rovyl\Rovyl.exe'
        OperaGX         = '%LOCALAPPDATA%\Programs\Opera GX\opera.exe'
        Brave           = '%ProgramFiles%\BraveSoftware\Brave-Browser\Application\brave.exe'
    }

    Urls = @{
        WhatsApp = 'https://web.whatsapp.com/'
        Music    = 'https://www.youtube.com/'
    }

    # Chill Mode force-closes every process with these names.
    CloseProcesses = @(
        'toofan',
        'Keyboard Sounds',
        'handy',
        'Rovyl',
        'opera',
        'opera_crashreporter',
        'Code',
        'WindowsTerminal'
    )
}
