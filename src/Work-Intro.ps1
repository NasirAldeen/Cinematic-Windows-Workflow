# Work-Intro.ps1
# Configurable cinematic overlay used by the Work Mode launcher.

param([switch]$Validate)

$ErrorActionPreference = 'Stop'
$ProjectRoot = Split-Path -Parent $PSScriptRoot
$ConfigPath = Join-Path $ProjectRoot 'config.psd1'
if (-not (Test-Path -LiteralPath $ConfigPath)) { throw "Configuration not found: $ConfigPath" }
$Config = Import-PowerShellDataFile -LiteralPath $ConfigPath

$AssistantName = [string]$Config.AssistantName
$OperatorName = [string]$Config.OperatorName
$PrototypeDurationSeconds = [double]$Config.IntroDurationSeconds
$AssetsDirectory = Join-Path $ProjectRoot 'assets'
$ConfiguredSoundPath = Join-Path $ProjectRoot $Config.SoundFile
$GeneratedSoundPath = Join-Path $AssetsDirectory 'generated-intro.wav'
$ErrorLogPath = Join-Path $ProjectRoot 'Work-Intro.log'
$ActiveMarkerPath = Join-Path $ProjectRoot 'cinematic-intro.active'

try {
    Add-Type -AssemblyName PresentationCore
    Add-Type -AssemblyName PresentationFramework
    Add-Type -AssemblyName WindowsBase
    Add-Type -AssemblyName System.Xaml

    Add-Type -TypeDefinition @"
using System;
using System.IO;
using System.Text;

public static class CinematicIntroAudio {
    public static void Build(string path) {
        const int sampleRate = 44100;
        const int seconds = 8;
        const short channels = 1;
        const short bitsPerSample = 16;
        int sampleCount = sampleRate * seconds;

        Directory.CreateDirectory(Path.GetDirectoryName(path));
        using (var stream = File.Create(path))
        using (var writer = new BinaryWriter(stream)) {
            int dataSize = sampleCount * channels * (bitsPerSample / 8);
            writer.Write(Encoding.ASCII.GetBytes("RIFF"));
            writer.Write(36 + dataSize);
            writer.Write(Encoding.ASCII.GetBytes("WAVE"));
            writer.Write(Encoding.ASCII.GetBytes("fmt "));
            writer.Write(16);
            writer.Write((short)1);
            writer.Write(channels);
            writer.Write(sampleRate);
            writer.Write(sampleRate * channels * (bitsPerSample / 8));
            writer.Write((short)(channels * (bitsPerSample / 8)));
            writer.Write(bitsPerSample);
            writer.Write(Encoding.ASCII.GetBytes("data"));
            writer.Write(dataSize);

            var random = new Random(7730);
            double[] pingTimes = { 0.45, 1.10, 2.05, 3.25, 4.55, 5.85, 6.65 };
            double[] pingNotes = { 220.0, 329.63, 440.0, 293.66, 523.25, 392.0, 659.25 };

            for (int i = 0; i < sampleCount; i++) {
                double t = i / (double)sampleRate;
                double fadeIn = Math.Min(1.0, t / 0.35);
                double fadeOut = Math.Min(1.0, (seconds - t) / 0.9);
                double envelope = Math.Max(0.0, Math.Min(fadeIn, fadeOut));

                double lowPad =
                    0.090 * Math.Sin(2.0 * Math.PI * 55.0 * t) +
                    0.045 * Math.Sin(2.0 * Math.PI * 82.41 * t) +
                    0.025 * Math.Sin(2.0 * Math.PI * 110.0 * t);

                double pulsePhase = t % 0.80;
                double pulse = pulsePhase < 0.17
                    ? 0.075 * Math.Exp(-pulsePhase * 18.0) * Math.Sin(2.0 * Math.PI * 73.42 * t)
                    : 0.0;

                double pings = 0.0;
                for (int p = 0; p < pingTimes.Length; p++) {
                    double age = t - pingTimes[p];
                    if (age >= 0.0 && age < 0.65) {
                        pings += 0.105 * Math.Exp(-age * 7.5) *
                            Math.Sin(2.0 * Math.PI * pingNotes[p] * age);
                    }
                }

                double riser = 0.0;
                if (t > 4.7 && t < 7.25) {
                    double r = (t - 4.7) / 2.55;
                    double frequency = 120.0 + 520.0 * r * r;
                    riser = 0.035 * r * Math.Sin(2.0 * Math.PI * frequency * t);
                    riser += 0.008 * r * ((random.NextDouble() * 2.0) - 1.0);
                }

                double finalHitAge = t - 7.05;
                double finalHit = finalHitAge >= 0.0
                    ? 0.16 * Math.Exp(-finalHitAge * 4.2) * Math.Sin(2.0 * Math.PI * 65.41 * finalHitAge)
                    : 0.0;

                double sample = envelope * (lowPad + pulse + pings + riser + finalHit);
                sample = Math.Max(-0.70, Math.Min(0.70, sample));
                writer.Write((short)(sample * short.MaxValue));
            }
        }
    }
}
"@

    $xamlText = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        x:Name="IntroWindow"
        Title="__ASSISTANT__ Work Mode"
        WindowStyle="None"
        ResizeMode="NoResize"
        WindowState="Maximized"
        Topmost="True"
        ShowInTaskbar="False"
        AllowsTransparency="True"
        Background="Transparent"
        Foreground="#D8F9FF"
        FontFamily="Consolas"
        Opacity="0">
    <Grid x:Name="RootGrid">
        <Grid.Background>
            <RadialGradientBrush Center="0.50,0.46" GradientOrigin="0.50,0.46" RadiusX="0.78" RadiusY="0.92">
                <GradientStop Color="#FF08232B" Offset="0"/>
                <GradientStop Color="#FF031016" Offset="0.44"/>
                <GradientStop Color="#FF020509" Offset="1"/>
            </RadialGradientBrush>
        </Grid.Background>

        <!-- Fine grid -->
        <Grid Opacity="0.16">
            <Grid.Background>
                <DrawingBrush TileMode="Tile" Viewport="0,0,38,38" ViewportUnits="Absolute">
                    <DrawingBrush.Drawing>
                        <GeometryDrawing Brush="Transparent">
                            <GeometryDrawing.Pen><Pen Brush="#5A37D8EE" Thickness="0.55"/></GeometryDrawing.Pen>
                            <GeometryDrawing.Geometry><RectangleGeometry Rect="0,0,38,38"/></GeometryDrawing.Geometry>
                        </GeometryDrawing>
                    </DrawingBrush.Drawing>
                </DrawingBrush>
            </Grid.Background>
        </Grid>

        <!-- Scan line -->
        <Rectangle x:Name="ScanLine" Height="3" VerticalAlignment="Top" Opacity="0.55">
            <Rectangle.Fill>
                <LinearGradientBrush StartPoint="0,0" EndPoint="1,0">
                    <GradientStop Color="#0034E9FF" Offset="0"/>
                    <GradientStop Color="#CC63F2FF" Offset="0.5"/>
                    <GradientStop Color="#0034E9FF" Offset="1"/>
                </LinearGradientBrush>
            </Rectangle.Fill>
            <Rectangle.Effect><DropShadowEffect Color="#46E9FF" BlurRadius="18" ShadowDepth="0"/></Rectangle.Effect>
        </Rectangle>

        <Grid Margin="48,34,48,36">
            <Grid.RowDefinitions>
                <RowDefinition Height="70"/>
                <RowDefinition Height="*"/>
                <RowDefinition Height="94"/>
            </Grid.RowDefinitions>

            <!-- Header -->
            <Grid Grid.Row="0">
                <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
                    <Border Width="12" Height="12" BorderBrush="#5EF4FF" BorderThickness="2" Margin="0,0,14,0">
                        <Border.Effect><DropShadowEffect Color="#5EF4FF" BlurRadius="12" ShadowDepth="0"/></Border.Effect>
                    </Border>
                    <StackPanel>
                        <TextBlock Text="__ASSISTANT__ SYSTEMS" FontSize="24" FontWeight="SemiBold" Foreground="#E8FDFF"/>
                        <TextBlock Text="ENGINEERING WORKSPACE // CINEMATIC BOOT PROTOTYPE" FontSize="10" Foreground="#6AB9C6"/>
                    </StackPanel>
                </StackPanel>
                <StackPanel HorizontalAlignment="Right" VerticalAlignment="Center">
                    <TextBlock x:Name="ClockText" Text="00:00:00" FontSize="19" HorizontalAlignment="Right" Foreground="#89F6FF"/>
                    <TextBlock Text="LOCAL NODE: __ASSISTANT__ // OPERATOR: __OPERATOR__" FontSize="10" Foreground="#527D86"/>
                </StackPanel>
            </Grid>

            <!-- Main dashboard -->
            <Grid Grid.Row="1" Margin="0,18,0,20">
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="1.05*"/>
                    <ColumnDefinition Width="1.25*"/>
                    <ColumnDefinition Width="1.05*"/>
                </Grid.ColumnDefinitions>

                <!-- Terminal -->
                <Border Grid.Column="0" BorderBrush="#2D7583" BorderThickness="1" CornerRadius="4" Background="#B2050B10" Padding="18">
                    <Border.Effect><DropShadowEffect Color="#113E49" BlurRadius="20" ShadowDepth="0"/></Border.Effect>
                    <Grid>
                        <Grid.RowDefinitions>
                            <RowDefinition Height="34"/>
                            <RowDefinition Height="*"/>
                        </Grid.RowDefinitions>
                        <Grid Grid.Row="0">
                            <TextBlock Text="TERMINAL // BOOT SEQUENCE" FontSize="11" Foreground="#78ECF8" VerticalAlignment="Top"/>
                            <StackPanel Orientation="Horizontal" HorizontalAlignment="Right">
                                <Ellipse Width="7" Height="7" Fill="#FF5E6B" Margin="4"/>
                                <Ellipse Width="7" Height="7" Fill="#FFC85B" Margin="4"/>
                                <Ellipse Width="7" Height="7" Fill="#55E59B" Margin="4"/>
                            </StackPanel>
                        </Grid>
                        <ScrollViewer x:Name="TerminalScroll" Grid.Row="1" VerticalScrollBarVisibility="Hidden">
                            <TextBlock x:Name="TerminalOutput" Text="&gt; awaiting operator handshake_" FontSize="13" LineHeight="22" Foreground="#9FF8D4" TextWrapping="Wrap"/>
                        </ScrollViewer>
                    </Grid>
                </Border>

                <!-- Center HUD -->
                <Grid Grid.Column="1" Margin="34,0">
                    <Ellipse Width="430" Height="430" Stroke="#173F49" StrokeThickness="1"/>
                    <Ellipse x:Name="OuterRing" Width="386" Height="386" Stroke="#3AD7E8" StrokeThickness="2" StrokeDashArray="3 8" Opacity="0.78" RenderTransformOrigin="0.5,0.5">
                        <Ellipse.RenderTransform><RotateTransform Angle="0"/></Ellipse.RenderTransform>
                    </Ellipse>
                    <Ellipse x:Name="InnerRing" Width="308" Height="308" Stroke="#D2973B" StrokeThickness="2" StrokeDashArray="1 6" Opacity="0.75" RenderTransformOrigin="0.5,0.5">
                        <Ellipse.RenderTransform><RotateTransform Angle="0"/></Ellipse.RenderTransform>
                    </Ellipse>
                    <Ellipse x:Name="PulseCore" Width="226" Height="226" Stroke="#66F2FF" StrokeThickness="1" Fill="#170ED3E8" Opacity="0.75">
                        <Ellipse.Effect><DropShadowEffect Color="#49E5F3" BlurRadius="36" ShadowDepth="0"/></Ellipse.Effect>
                    </Ellipse>
                    <StackPanel HorizontalAlignment="Center" VerticalAlignment="Center">
                        <TextBlock Text="__ASSISTANT__" FontSize="58" FontWeight="Light" Foreground="#F0FEFF" HorizontalAlignment="Center"/>
                        <TextBlock Text="W O R K   M O D E" FontSize="16" FontWeight="SemiBold" Foreground="#E0A64C" HorizontalAlignment="Center" Margin="0,4,0,13"/>
                        <TextBlock x:Name="CenterPercent" Text="000%" FontSize="30" Foreground="#77F1FF" HorizontalAlignment="Center"/>
                        <TextBlock x:Name="CenterStatus" Text="INITIALIZING" FontSize="10" Foreground="#6EABB4" HorizontalAlignment="Center"/>
                    </StackPanel>
                </Grid>

                <!-- Telemetry -->
                <Border Grid.Column="2" BorderBrush="#765A2D" BorderThickness="1" CornerRadius="4" Background="#B2090B0D" Padding="18">
                    <Grid>
                        <Grid.RowDefinitions>
                            <RowDefinition Height="34"/>
                            <RowDefinition Height="*"/>
                        </Grid.RowDefinitions>
                        <TextBlock Text="LIVE TELEMETRY // LOCAL NODE" FontSize="11" Foreground="#F1BE67"/>
                        <Grid Grid.Row="1">
                            <TextBlock x:Name="DataRain" FontSize="12" LineHeight="19" Foreground="#598A91" Opacity="0.8" TextWrapping="Wrap"/>
                            <StackPanel VerticalAlignment="Bottom">
                                <TextBlock Text="SUBSYSTEM READINESS" FontSize="10" Foreground="#9EB7B9" Margin="0,0,0,8"/>
                                <Grid Margin="0,4"><TextBlock Text="AI TOOLCHAIN" FontSize="10"/><ProgressBar x:Name="BarAI" Height="5" Value="0" Maximum="100" Margin="115,3,0,0" Foreground="#50DFEF" Background="#19282D"/></Grid>
                                <Grid Margin="0,4"><TextBlock Text="LINUX BRIDGE" FontSize="10"/><ProgressBar x:Name="BarWSL" Height="5" Value="0" Maximum="100" Margin="115,3,0,0" Foreground="#50DFEF" Background="#19282D"/></Grid>
                                <Grid Margin="0,4"><TextBlock Text="DEV ENVIRONMENT" FontSize="10"/><ProgressBar x:Name="BarDev" Height="5" Value="0" Maximum="100" Margin="115,3,0,0" Foreground="#D8A047" Background="#2C251B"/></Grid>
                                <Grid Margin="0,4"><TextBlock Text="FOCUS PROTOCOL" FontSize="10"/><ProgressBar x:Name="BarFocus" Height="5" Value="0" Maximum="100" Margin="115,3,0,0" Foreground="#D8A047" Background="#2C251B"/></Grid>
                            </StackPanel>
                        </Grid>
                    </Grid>
                </Border>
            </Grid>

            <!-- Footer progress -->
            <Grid Grid.Row="2">
                <Grid.RowDefinitions><RowDefinition Height="28"/><RowDefinition Height="18"/><RowDefinition Height="28"/></Grid.RowDefinitions>
                <TextBlock x:Name="FooterStatus" Text="ESTABLISHING SECURE WORKSPACE..." FontSize="11" Foreground="#91CFD7"/>
                <TextBlock Text="ESC TO SKIP" FontSize="10" Foreground="#526E73" HorizontalAlignment="Right"/>
                <Border x:Name="ProgressTrack" Grid.Row="1" Background="#17272B" Height="4" VerticalAlignment="Center">
                    <Border x:Name="ProgressFill" Width="0" Background="#61EFFB" HorizontalAlignment="Left">
                        <Border.Effect><DropShadowEffect Color="#61EFFB" BlurRadius="12" ShadowDepth="0"/></Border.Effect>
                    </Border>
                </Border>
                <Grid Grid.Row="2">
                    <TextBlock Text="SYS/BOOT/AI-LAB" FontSize="9" Foreground="#405E65" VerticalAlignment="Bottom"/>
                    <TextBlock x:Name="FooterPercent" Text="0.0%" FontSize="10" Foreground="#D9F9FC" HorizontalAlignment="Right" VerticalAlignment="Bottom"/>
                </Grid>
            </Grid>
        </Grid>

        <Border BorderBrush="#245866" BorderThickness="1" Margin="18" IsHitTestVisible="False"/>
    </Grid>
</Window>
'@

    $xamlText = $xamlText.Replace('__ASSISTANT__', [Security.SecurityElement]::Escape($AssistantName))
    $xamlText = $xamlText.Replace('__OPERATOR__', [Security.SecurityElement]::Escape($OperatorName))
    [xml]$xaml = $xamlText
    $xmlReader = New-Object System.Xml.XmlNodeReader $xaml
    $window = [Windows.Markup.XamlReader]::Load($xmlReader)

    $controlNames = @(
        'ScanLine','ClockText','TerminalScroll','TerminalOutput','OuterRing','InnerRing',
        'PulseCore','CenterPercent','CenterStatus','DataRain','BarAI','BarWSL','BarDev',
        'BarFocus','FooterStatus','ProgressTrack','ProgressFill','FooterPercent'
    )
    $controls = @{}
    foreach ($controlName in $controlNames) {
        $controls[$controlName] = $window.FindName($controlName)
        if ($null -eq $controls[$controlName]) { throw "Missing XAML control: $controlName" }
    }

    if ($Validate) {
        Write-Host 'Intro validation passed: WPF layout, controls, and soundtrack player loaded.' -ForegroundColor Green
        exit 0
    }

    if (Test-Path -LiteralPath $ConfiguredSoundPath) {
        $SoundPath = $ConfiguredSoundPath
    }
    else {
        if (-not (Test-Path -LiteralPath $GeneratedSoundPath)) {
            [CinematicIntroAudio]::Build($GeneratedSoundPath)
        }
        $SoundPath = $GeneratedSoundPath
    }

    $mediaPlayer = New-Object System.Windows.Media.MediaPlayer
    $mediaPlayer.Volume = 0.82
    $mediaPlayer.Open([Uri]$SoundPath)

    $outerAnimation = New-Object Windows.Media.Animation.DoubleAnimation
    $outerAnimation.From = 0
    $outerAnimation.To = 360
    $outerAnimation.Duration = [Windows.Duration]::new([TimeSpan]::FromSeconds(7.2))
    $outerAnimation.RepeatBehavior = [Windows.Media.Animation.RepeatBehavior]::Forever
    $controls.OuterRing.RenderTransform.BeginAnimation([Windows.Media.RotateTransform]::AngleProperty, $outerAnimation)

    $innerAnimation = New-Object Windows.Media.Animation.DoubleAnimation
    $innerAnimation.From = 360
    $innerAnimation.To = 0
    $innerAnimation.Duration = [Windows.Duration]::new([TimeSpan]::FromSeconds(4.8))
    $innerAnimation.RepeatBehavior = [Windows.Media.Animation.RepeatBehavior]::Forever
    $controls.InnerRing.RenderTransform.BeginAnimation([Windows.Media.RotateTransform]::AngleProperty, $innerAnimation)

    $pulseAnimation = New-Object Windows.Media.Animation.DoubleAnimation
    $pulseAnimation.From = 0.38
    $pulseAnimation.To = 0.92
    $pulseAnimation.Duration = [Windows.Duration]::new([TimeSpan]::FromMilliseconds(820))
    $pulseAnimation.AutoReverse = $true
    $pulseAnimation.RepeatBehavior = [Windows.Media.Animation.RepeatBehavior]::Forever
    $controls.PulseCore.BeginAnimation([Windows.UIElement]::OpacityProperty, $pulseAnimation)

    $fadeIn = New-Object Windows.Media.Animation.DoubleAnimation
    $fadeIn.From = 0
    $fadeIn.To = 1
    $fadeIn.Duration = [Windows.Duration]::new([TimeSpan]::FromMilliseconds(420))
    $window.BeginAnimation([Windows.UIElement]::OpacityProperty, $fadeIn)

    $bootMessages = @(
        '[00:00:00.013] operator signature ............ VERIFIED',
        '[00:00:00.221] local compute fabric ........... ONLINE',
        '[00:00:00.487] memory map ..................... STABLE',
        '[00:00:00.814] local AI toolchain ............. LINKED',
        '[00:00:01.106] Windows Terminal gateway ....... READY',
        '[00:00:01.433] Ubuntu bridge .................. NEGOTIATING',
        '[00:00:01.821] Feynman research core .......... STANDBY',
        '[00:00:02.174] Claude interface ................ STANDBY',
        '[00:00:02.518] Codex engineering node ......... STANDBY',
        '[00:00:02.891] Toofan command layer ............ STANDBY',
        '[00:00:03.246] editor workspace ................ RESTORING',
        '[00:00:03.618] ambient audio channel ........... ARMED',
        '[00:00:04.037] focus protocol .................. ENGAGED',
        '[00:00:04.492] final integrity check ........... PASS',
        '[00:00:05.061] all engineering systems ........ NOMINAL',
        '[00:00:05.704] WORK MODE AUTHORIZED'
    )

    $random = New-Object System.Random
    $alphabet = '01ABCDEF<>[]{}:/\\|+-*#@'
    $stopwatch = [Diagnostics.Stopwatch]::StartNew()
    $messageIndex = 0
    $fadeStarted = $false

    $timer = New-Object Windows.Threading.DispatcherTimer
    $timer.Interval = [TimeSpan]::FromMilliseconds(55)
    $timer.Add_Tick({
        $elapsed = $stopwatch.Elapsed.TotalSeconds
        $progress = [Math]::Min(100.0, ($elapsed / $PrototypeDurationSeconds) * 100.0)

        # Apps initialize behind the overlay during integrated Work Mode.
        # Reclaim focus only when needed so Escape always remains available.
        if (-not $window.IsActive) {
            $window.Activate() | Out-Null
            $window.Focus() | Out-Null
        }

        $controls.ClockText.Text = (Get-Date).ToString('HH:mm:ss')
        $controls.CenterPercent.Text = ('{0:000}%' -f [int]$progress)
        $controls.FooterPercent.Text = ('{0:0.0}%' -f $progress)
        $controls.ProgressFill.Width = [Math]::Max(0, $controls.ProgressTrack.ActualWidth * ($progress / 100.0))
        $controls.ScanLine.Margin = New-Object Windows.Thickness(0, (($elapsed * 190) % [Math]::Max(1, $window.ActualHeight)), 0, 0)

        $controls.BarAI.Value = [Math]::Min(100, $progress * 1.42)
        $controls.BarWSL.Value = [Math]::Min(100, [Math]::Max(0, ($progress - 10) * 1.48))
        $controls.BarDev.Value = [Math]::Min(100, [Math]::Max(0, ($progress - 22) * 1.55))
        $controls.BarFocus.Value = [Math]::Min(100, [Math]::Max(0, ($progress - 38) * 1.75))

        while ($messageIndex -lt $bootMessages.Count -and $elapsed -ge (0.55 + ($messageIndex * 0.73))) {
            if ($messageIndex -eq 0) { $controls.TerminalOutput.Text = '' }
            $controls.TerminalOutput.Text += $bootMessages[$messageIndex] + [Environment]::NewLine
            $controls.TerminalScroll.ScrollToEnd()
            $messageIndex++
        }

        if (([int]($elapsed * 8)) % 2 -eq 0) {
            $rainLines = New-Object System.Collections.Generic.List[string]
            for ($line = 0; $line -lt 13; $line++) {
                $chars = New-Object char[] 28
                for ($column = 0; $column -lt $chars.Length; $column++) {
                    $chars[$column] = $alphabet[$random.Next(0, $alphabet.Length)]
                }
                $rainLines.Add((-join $chars))
            }
            $controls.DataRain.Text = $rainLines -join [Environment]::NewLine
        }

        if ($progress -lt 22) {
            $controls.CenterStatus.Text = 'INITIALIZING'
            $controls.FooterStatus.Text = 'ESTABLISHING SECURE WORKSPACE...'
        }
        elseif ($progress -lt 55) {
            $controls.CenterStatus.Text = 'LINKING SYSTEMS'
            $controls.FooterStatus.Text = 'SYNCHRONIZING AI TOOLCHAIN...'
        }
        elseif ($progress -lt 86) {
            $controls.CenterStatus.Text = 'ARMING WORKSPACE'
            $controls.FooterStatus.Text = 'RESTORING ENGINEERING ENVIRONMENT...'
        }
        else {
            $controls.CenterStatus.Text = 'SYSTEMS ONLINE'
            $controls.FooterStatus.Text = "WELCOME BACK, $($OperatorName.ToUpperInvariant())."
        }

        if (-not $fadeStarted -and $elapsed -ge ($PrototypeDurationSeconds - 0.65)) {
            $fadeStarted = $true
            $fadeOut = New-Object Windows.Media.Animation.DoubleAnimation
            $fadeOut.From = 1
            $fadeOut.To = 0
            $fadeOut.Duration = [Windows.Duration]::new([TimeSpan]::FromMilliseconds(620))
            $fadeOut.Add_Completed({ $window.Close() })
            $window.BeginAnimation([Windows.UIElement]::OpacityProperty, $fadeOut)
        }
    })

    $window.Add_KeyDown({
        if ($_.Key -eq [Windows.Input.Key]::Escape) { $window.Close() }
    })

    $window.Add_ContentRendered({
        $window.Activate() | Out-Null
        $window.Focus() | Out-Null
        $mediaPlayer.Play()
        $timer.Start()
    })

    $window.Add_Closed({
        $timer.Stop()
        $stopwatch.Stop()
        try { $mediaPlayer.Stop(); $mediaPlayer.Close() } catch { }
        try { Remove-Item -LiteralPath $ActiveMarkerPath -Force -ErrorAction SilentlyContinue } catch { }
    })

    Set-Content -LiteralPath $ActiveMarkerPath -Value $PID
    $window.ShowDialog() | Out-Null
}
catch {
    try { Remove-Item -LiteralPath $ActiveMarkerPath -Force -ErrorAction SilentlyContinue } catch { }
    $details = $_ | Out-String
    Set-Content -LiteralPath $ErrorLogPath -Value $details
    if (-not $Validate) {
        try {
            Add-Type -AssemblyName PresentationFramework -ErrorAction SilentlyContinue
            [System.Windows.MessageBox]::Show(
                "The $AssistantName intro could not start. Details were saved to:`n$ErrorLogPath",
                "$AssistantName Work Mode",
                'OK',
                'Error'
            ) | Out-Null
        }
        catch { }
    }
    throw
}
