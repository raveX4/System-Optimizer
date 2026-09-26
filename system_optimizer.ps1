# Hide PowerShell Host Console Window Immediately
$Win32Console = Add-Type -MemberDefinition @"
    [DllImport("user32.dll")]
    public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
    [DllImport("kernel32.dll")]
    public static extern IntPtr GetConsoleWindow();
"@ -Name "Win32ConsoleUtils" -Namespace "SystemOptimizer" -PassThru -ErrorAction SilentlyContinue

try {
    if ($Win32Console) {
        $hwnd = [SystemOptimizer.Win32ConsoleUtils]::GetConsoleWindow()
        if ($hwnd -ne [IntPtr]::Zero) {
            [SystemOptimizer.Win32ConsoleUtils]::ShowWindow($hwnd, 0)
        }
    }
} catch {}

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

# Native Win32 API for safe memory working set optimization
$Win32Mem = Add-Type -MemberDefinition @"
    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern bool SetProcessWorkingSetSize(IntPtr hProcess, IntPtr dwMinimumWorkingSetSize, IntPtr dwMaximumWorkingSetSize);
    [DllImport("psapi.dll")]
    public static extern bool EmptyWorkingSet(IntPtr hProcess);
"@ -Name "Win32MemUtils" -Namespace "SystemOptimizer" -PassThru -ErrorAction SilentlyContinue

function Test-IsAdmin {
    try {
        $identity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
        $principal = New-Object System.Security.Principal.WindowsPrincipal($identity)
        return $principal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)
    }
    catch {
        return $false
    }
}

$isAdmin = Test-IsAdmin
$script:initialPowerScheme = $null
$script:boostApplied = $false
$script:stoppedServices = New-Object System.Collections.Generic.List[string]

$form = New-Object System.Windows.Forms.Form
$form.Text = "System Optimizer"
$form.Size = New-Object System.Drawing.Size(650, 680)
$form.StartPosition = 'CenterScreen'
$form.BackColor = [System.Drawing.Color]::FromArgb(245, 245, 245)
$form.FormBorderStyle = 'FixedDialog'
$form.MaximizeBox = $false
$form.Font = New-Object System.Drawing.Font("Segoe UI", 9)

# System Tray (NotifyIcon) Setup
$notifyIcon = New-Object System.Windows.Forms.NotifyIcon

# Use shell32 icon #238 (computer/settings icon) for better Windows 11 tray visibility
try {
    $shell32 = "$env:SystemRoot\System32\shell32.dll"
    $notifyIcon.Icon = [System.Drawing.Icon]::ExtractAssociatedIcon($shell32)
} catch {
    try {
        $notifyIcon.Icon = [System.Drawing.SystemIcons]::Application
    } catch {
        $notifyIcon.Icon = [System.Drawing.Icon]::ExtractAssociatedIcon(
            [System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName
        )
    }
}

$notifyIcon.Text = "System Optimizer"
$notifyIcon.Visible = $false  # Start hidden, only show when minimized

# Use ContextMenuStrip (modern API, better Windows 11 support)
$trayMenuStrip = New-Object System.Windows.Forms.ContextMenuStrip
$menuOpen = New-Object System.Windows.Forms.ToolStripMenuItem
$menuOpen.Text = "Ac / Goster"
$menuExit = New-Object System.Windows.Forms.ToolStripMenuItem
$menuExit.Text = "Cikis (Kapat ve Varsayilana Don)"

$restoreForm = {
    $notifyIcon.Visible = $false
    $form.ShowInTaskbar = $true
    $form.WindowState = [System.Windows.Forms.FormWindowState]::Normal
    $form.Activate()
}

$menuOpen.Add_Click($restoreForm)
$menuExit.Add_Click({ $form.Close() })

$trayMenuStrip.Items.Add($menuOpen) | Out-Null
$trayMenuStrip.Items.Add($menuExit) | Out-Null
$notifyIcon.ContextMenuStrip = $trayMenuStrip

$notifyIcon.Add_MouseClick({
    param($s, $e)
    if ($e.Button -eq [System.Windows.Forms.MouseButtons]::Left) {
        & $restoreForm
    }
})
$notifyIcon.Add_DoubleClick($restoreForm)

$script:formShown = $false

$form.Add_Shown({
    $script:formShown = $true
})

$form.Add_Resize({
    if ($script:formShown -and $form.WindowState -eq [System.Windows.Forms.FormWindowState]::Minimized) {
        # Form gorev cubugunda kalmaya devam eder (ShowInTaskbar degistirme)
        # Ek olarak tray'de de gozukur
        $notifyIcon.Visible = $true
        try {
            $notifyIcon.ShowBalloonTip(2000, "System Optimizer", "Arka planda calisiyor. Tray ikonuna tiklayin.", [System.Windows.Forms.ToolTipIcon]::Info)
        } catch {}
    } elseif ($script:formShown -and $form.WindowState -eq [System.Windows.Forms.FormWindowState]::Normal) {
        $notifyIcon.Visible = $false
    }
})

$tabControl = New-Object System.Windows.Forms.TabControl
$tabControl.Dock = 'Fill'
$tabControl.Padding = New-Object System.Drawing.Point(15, 8)
$form.Controls.Add($tabControl)

# TAB 1: PERFORMANS AYARLARI
$tabOpt = New-Object System.Windows.Forms.TabPage
$tabOpt.Text = "Performans Ayarları"
$tabOpt.BackColor = [System.Drawing.Color]::FromArgb(245, 245, 245)
$tabControl.TabPages.Add($tabOpt)

$grpProfile = New-Object System.Windows.Forms.GroupBox
$grpProfile.Text = "Optimizasyon Profilleri"
$grpProfile.Size = New-Object System.Drawing.Size(590, 60)
$grpProfile.Location = New-Object System.Drawing.Point(15, 10)
$tabOpt.Controls.Add($grpProfile)

$radBalanced = New-Object System.Windows.Forms.RadioButton
$radBalanced.Text = "Dengeli (Günlük)"
$radBalanced.Location = New-Object System.Drawing.Point(20, 24)
$radBalanced.Size = New-Object System.Drawing.Size(150, 20)
$grpProfile.Controls.Add($radBalanced)

$radGaming = New-Object System.Windows.Forms.RadioButton
$radGaming.Text = "Performans (Oyun)"
$radGaming.Location = New-Object System.Drawing.Point(200, 24)
$radGaming.Size = New-Object System.Drawing.Size(160, 20)
$radGaming.Checked = $true
$grpProfile.Controls.Add($radGaming)

$radExtreme = New-Object System.Windows.Forms.RadioButton
$radExtreme.Text = "Maksimum (Extreme)"
$radExtreme.Location = New-Object System.Drawing.Point(390, 24)
$radExtreme.Size = New-Object System.Drawing.Size(180, 20)
$grpProfile.Controls.Add($radExtreme)

$grpConfig = New-Object System.Windows.Forms.GroupBox
$grpConfig.Text = "Gelişmiş Sistem Yapılandırmaları"
$grpConfig.Size = New-Object System.Drawing.Size(590, 355)
$grpConfig.Location = New-Object System.Drawing.Point(15, 75)
$tabOpt.Controls.Add($grpConfig)

$checkedList = New-Object System.Windows.Forms.CheckedListBox
$checkedList.Size = New-Object System.Drawing.Size(550, 315)
$checkedList.Location = New-Object System.Drawing.Point(20, 25)
$checkedList.BackColor = [System.Drawing.Color]::White
$checkedList.BorderStyle = 'FixedSingle'
$checkedList.CheckOnClick = $true

$script:OPT_POWER        = "Nihai Performans (Ultimate) Güç Planını Etkinleştir"
$script:OPT_NETWORK      = "DNS Önbelleğini Temizle ve TCP/IP Yığını Sıfırla"
$script:OPT_SERVICES     = "Gereksiz Arka Plan ve Telemetri Hizmetlerini Kapat"
$script:OPT_TEMP         = "Windows Temp ve Önbellek Dosyalarını Güvenle Temizle"
$script:OPT_VISUAL       = "Masaüstü Görsel Efektlerini En İyi Performansa Ayarla"
$script:OPT_GAMEMODE     = "Windows Oyun Modunu Zorla ve Xbox DVR Devre Dışı Bırak"
$script:OPT_RAM          = "Sistem Belleği (RAM Working Set) Güvenli Temizliği"
$script:OPT_CPU          = "İşlemci Önceliği (Win32PrioritySeparation) Ayarı"
$script:OPT_NAGLE        = "TCP Nagle Algoritmasını Kapat (Daha Düşük Oyun Ping / Gecikme)"
$script:OPT_NETTHROTTLE  = "Ağ Kısıtlaması (Network Throttling) Devre Dışı Bırak (Maks Bant Genişliği)"
$script:OPT_POWERTHROTTLE= "Windows Power Throttling (Arka Plan Kısıtlaması) Kapat"
$script:OPT_GPU_SCHED    = "Donanım Hızlandırmalı GPU Zamanlamasını (HAGS) Etkinleştir"
$script:OPT_STANDBY      = "Standby (Önbellek) RAM Yükünü Temizle ve Boşalt"
$script:OPT_SYSMAIN      = "SysMain (Superfetch) ve Windows Search İndekslemeyi Optimize Et"
$script:OPT_FULLSCREEN   = "Tam Ekran İyileştirmelerini (Fullscreen Optimizations) Kapat"
$script:OPT_TIMER        = "Yüksek Çözünürlüklü Sistem Zamanlayıcısı (HPET ve Low Latency Tick) Ayarı"

$opts = @(
    $script:OPT_POWER,
    $script:OPT_NETWORK,
    $script:OPT_SERVICES,
    $script:OPT_TEMP,
    $script:OPT_VISUAL,
    $script:OPT_GAMEMODE,
    $script:OPT_RAM,
    $script:OPT_CPU,
    $script:OPT_NAGLE,
    $script:OPT_NETTHROTTLE,
    $script:OPT_POWERTHROTTLE,
    $script:OPT_GPU_SCHED,
    $script:OPT_STANDBY,
    $script:OPT_SYSMAIN,
    $script:OPT_FULLSCREEN,
    $script:OPT_TIMER
)
foreach($o in $opts) { $checkedList.Items.Add($o, $false) | Out-Null }
$grpConfig.Controls.Add($checkedList)

$script:updatingProfile = $false
function Update-Profile {
    if ($script:updatingProfile) { return }
    $script:updatingProfile = $true
    try {
        if ($radBalanced.Checked) {
            $balancedIndices = @(1, 3, 5, 6, 12)
            for ($i = 0; $i -lt $checkedList.Items.Count; $i++) {
                $checkedList.SetItemChecked($i, ($balancedIndices -contains $i))
            }
        }
        elseif ($radGaming.Checked) {
            $gamingIndices = @(0, 1, 2, 3, 5, 6, 7, 8, 9, 11, 12, 14)
            for ($i = 0; $i -lt $checkedList.Items.Count; $i++) {
                $checkedList.SetItemChecked($i, ($gamingIndices -contains $i))
            }
        }
        elseif ($radExtreme.Checked) {
            for ($i = 0; $i -lt $checkedList.Items.Count; $i++) {
                $checkedList.SetItemChecked($i, $true)
            }
        }
    }
    finally {
        $script:updatingProfile = $false
    }
}
$radBalanced.Add_CheckedChanged({ if ($radBalanced.Checked) { Update-Profile } })
$radGaming.Add_CheckedChanged({ if ($radGaming.Checked) { Update-Profile } })
$radExtreme.Add_CheckedChanged({ if ($radExtreme.Checked) { Update-Profile } })
Update-Profile

$grpApp = New-Object System.Windows.Forms.GroupBox
$grpApp.Text = "Hedef Uygulama Optimizasyonu (İsteğe Bağlı)"
$grpApp.Size = New-Object System.Drawing.Size(590, 80)
$grpApp.Location = New-Object System.Drawing.Point(15, 437)
$tabOpt.Controls.Add($grpApp)

$appDesc = New-Object System.Windows.Forms.Label
$appDesc.Text = "Seçilen uygulamanın CPU önceliğini Yüksek yapar ve Tam Ekran İyileştirmelerini kapatır."
$appDesc.AutoSize = $true
$appDesc.Location = New-Object System.Drawing.Point(20, 20)
$appDesc.ForeColor = [System.Drawing.Color]::DimGray
$grpApp.Controls.Add($appDesc)

$appTextBox = New-Object System.Windows.Forms.TextBox
$appTextBox.Size = New-Object System.Drawing.Size(440, 25)
$appTextBox.Location = New-Object System.Drawing.Point(20, 42)
$appTextBox.ReadOnly = $true
$appTextBox.BackColor = [System.Drawing.Color]::White
$grpApp.Controls.Add($appTextBox)

$btnBrowse = New-Object System.Windows.Forms.Button
$btnBrowse.Text = "Gözat..."
$btnBrowse.Size = New-Object System.Drawing.Size(90, 25)
$btnBrowse.Location = New-Object System.Drawing.Point(470, 41)
$btnBrowse.UseVisualStyleBackColor = $true
$btnBrowse.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$grpApp.Controls.Add($btnBrowse)

$btnBrowse.Add_Click({
    $dialog = New-Object System.Windows.Forms.OpenFileDialog
    $dialog.Filter = "Çalıştırılabilir Dosyalar (*.exe)|*.exe"
    $dialog.Title = "Hedef Oyun veya Uygulamayı Seçin"
    if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $appTextBox.Text = $dialog.FileName
    }
})

function Write-Log {
    param([string]$msg)
}

# Helper for Safe Registry Key Modifications using Native PowerShell Provider
function Set-RegProperty {
    param(
        [string]$HivePath,
        [string]$ValueName,
        [object]$ValueData,
        [string]$PropertyType = "DWord"
    )
    try {
        if (-not (Test-Path $HivePath)) {
            New-Item -Path $HivePath -Force -ErrorAction Stop | Out-Null
        }
        Set-ItemProperty -Path $HivePath -Name $ValueName -Value $ValueData -Type $PropertyType -Force -ErrorAction Stop
        return $true
    }
    catch {
        return $false
    }
}

$progressBar = New-Object System.Windows.Forms.ProgressBar
$progressBar.Size = New-Object System.Drawing.Size(380, 28)
$progressBar.Location = New-Object System.Drawing.Point(15, 529)
$tabOpt.Controls.Add($progressBar)

$btnApply = New-Object System.Windows.Forms.Button
$btnApply.Text = "Yapılandırmayı Uygula"
$btnApply.Size = New-Object System.Drawing.Size(195, 28)
$btnApply.Location = New-Object System.Drawing.Point(410, 529)
$btnApply.UseVisualStyleBackColor = $true
$btnApply.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$tabOpt.Controls.Add($btnApply)

$btnApply.Add_Click({
    $total = $checkedList.CheckedItems.Count
    if ($appTextBox.Text -ne "") { $total++ }
    if ($total -eq 0) {
        [System.Windows.Forms.MessageBox]::Show(
            "Lütfen uygulanacak en az bir optimizasyon ayarı seçin.",
            "Uyarı",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Warning
        )
        return
    }

    # Save initial active power scheme
    $rawScheme = (powercfg /getactivescheme 2>$null) -join " "
    $match = [regex]::Match($rawScheme, "([a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12})")
    if ($match.Success) {
        $script:initialPowerScheme = $match.Groups[1].Value
    }

    $btnApply.Enabled = $false
    $checkedList.Enabled = $false
    $grpProfile.Enabled = $false
    $btnBrowse.Enabled = $false
    $progressBar.Value = 0

    $step = 0
    foreach ($item in $checkedList.CheckedItems) {
        $step++

        if ($item -eq $script:OPT_POWER) {
            Start-Process "powercfg" -ArgumentList "-duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61" -NoNewWindow -Wait -ErrorAction SilentlyContinue
            Start-Process "powercfg" -ArgumentList "-setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c" -NoNewWindow -Wait -ErrorAction SilentlyContinue
        }
        elseif ($item -eq $script:OPT_NETWORK) {
            Start-Process "ipconfig" -ArgumentList "/flushdns" -NoNewWindow -Wait -ErrorAction SilentlyContinue
            Start-Process "netsh" -ArgumentList "winsock reset" -NoNewWindow -Wait -ErrorAction SilentlyContinue
            Start-Process "netsh" -ArgumentList "int ip reset" -NoNewWindow -Wait -ErrorAction SilentlyContinue
        }
        elseif ($item -eq $script:OPT_SERVICES -or $item -eq $script:OPT_SYSMAIN) {
            $svcs = @("SysMain", "DiagTrack", "WSearch")
            foreach ($s in $svcs) {
                Stop-Service -Name $s -Force -ErrorAction SilentlyContinue
                if (-not $script:stoppedServices.Contains($s)) {
                    $script:stoppedServices.Add($s)
                }
            }
        }
        elseif ($item -eq $script:OPT_TEMP) {
            $dirs = @($env:TEMP, $env:TMP, "C:\Windows\Temp")
            foreach ($d in $dirs) {
                if ($d -and (Test-Path $d)) {
                    Get-ChildItem -Path $d -Recurse -File -ErrorAction SilentlyContinue | ForEach-Object {
                        Remove-Item $_.FullName -Force -ErrorAction SilentlyContinue
                    }
                }
            }
        }
        elseif ($item -eq $script:OPT_VISUAL) {
            Set-RegProperty -HivePath "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects" -ValueName "VisualFXSetting" -ValueData 2 -PropertyType "DWord" | Out-Null
        }
        elseif ($item -eq $script:OPT_GAMEMODE) {
            Set-RegProperty -HivePath "HKCU:\Software\Microsoft\GameBar" -ValueName "AllowAutoGameMode" -ValueData 1 | Out-Null
            Set-RegProperty -HivePath "HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR" -ValueName "AppCaptureEnabled" -ValueData 0 | Out-Null
            Set-RegProperty -HivePath "HKCU:\System\GameConfigStore" -ValueName "GameDVR_Enabled" -ValueData 0 | Out-Null
        }
        elseif ($item -eq $script:OPT_RAM -or $item -eq $script:OPT_STANDBY) {
            [System.GC]::Collect()
            [System.GC]::WaitForPendingFinalizers()
            [System.GC]::Collect()

            try {
                if ($Win32Mem) {
                    $procs = Get-Process -ErrorAction SilentlyContinue
                    foreach ($p in $procs) {
                        if ($p.HandleCount -gt 0 -and $p.Id -ne $PID) {
                            [SystemOptimizer.Win32MemUtils]::EmptyWorkingSet($p.Handle) | Out-Null
                        }
                    }
                }
            } catch {}
        }
        elseif ($item -eq $script:OPT_CPU) {
            if ($isAdmin) {
                Set-RegProperty -HivePath "HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl" -ValueName "Win32PrioritySeparation" -ValueData 38 | Out-Null
            }
        }
        elseif ($item -eq $script:OPT_NAGLE) {
            try {
                $interfaces = Get-ChildItem "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces" -ErrorAction SilentlyContinue
                foreach ($i in $interfaces) {
                    Set-RegProperty -HivePath $i.PSPath -ValueName "TcpAckFrequency" -ValueData 1 | Out-Null
                    Set-RegProperty -HivePath $i.PSPath -ValueName "TCPNoDelay" -ValueData 1 | Out-Null
                }
            } catch {}
        }
        elseif ($item -eq $script:OPT_NETTHROTTLE) {
            Set-RegProperty -HivePath "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" -ValueName "NetworkThrottlingIndex" -ValueData 4294967295 | Out-Null
            Set-RegProperty -HivePath "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" -ValueName "SystemResponsiveness" -ValueData 0 | Out-Null
        }
        elseif ($item -eq $script:OPT_POWERTHROTTLE) {
            Set-RegProperty -HivePath "HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerThrottling" -ValueName "PowerThrottlingOff" -ValueData 1 | Out-Null
        }
        elseif ($item -eq $script:OPT_GPU_SCHED) {
            Set-RegProperty -HivePath "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" -ValueName "HwSchMode" -ValueData 2 | Out-Null
        }
        elseif ($item -eq $script:OPT_FULLSCREEN) {
            Set-RegProperty -HivePath "HKCU:\System\GameConfigStore" -ValueName "GameDVR_FSEBehaviorMode" -ValueData 2 | Out-Null
        }
        elseif ($item -eq $script:OPT_TIMER) {
            Start-Process "bcdedit" -ArgumentList "/set useplatformclock false" -NoNewWindow -Wait -ErrorAction SilentlyContinue
            Start-Process "bcdedit" -ArgumentList "/set disabledynamictick yes" -NoNewWindow -Wait -ErrorAction SilentlyContinue
        }

        $pct = [math]::Min(100, [math]::Max(0, [int][math]::Round(($step / $total) * 100)))
        $progressBar.Value = $pct
        [System.Windows.Forms.Application]::DoEvents()
    }

    if ($appTextBox.Text -ne "") {
        $step++
        $appName = [System.IO.Path]::GetFileName($appTextBox.Text)
        $appPath = $appTextBox.Text
        if ($isAdmin) {
            $keyPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\$appName\PerfOptions"
            Set-RegProperty -HivePath $keyPath -ValueName "CpuPriorityClass" -ValueData 3 | Out-Null
        }
        Set-RegProperty -HivePath "HKCU:\Software\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Layers" -ValueName $appPath -ValueData "~ DISABLEDXMAXIMIZEDWINDOWEDMODE" -PropertyType "String" | Out-Null
        $progressBar.Value = 100
    }

    $script:boostApplied = $true
    $btnApply.Text = "Optimizasyon Aktif"
    $btnApply.Enabled = $false

    [System.Windows.Forms.MessageBox]::Show(
        "Sistem başarıyla optimizasyon moduna alındı!`n`nOptimizasyon ve performans ayarları pencere kapatılana kadar aktif kalacaktır.`nPencere kapatıldığında durdurulan hizmetler ve varsayılan ayarlar otomatik geri yüklenecektir.",
        "Optimizasyon Aktif",
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Information
    )
})

# Automatic Restore on Form Close
$form.Add_FormClosing({
    if ($script:boostApplied) {
        foreach ($s in $script:stoppedServices) {
            Start-Service -Name $s -ErrorAction SilentlyContinue
        }
        if ($script:initialPowerScheme) {
            Start-Process "powercfg" -ArgumentList "-setactive $($script:initialPowerScheme)" -NoNewWindow -Wait -ErrorAction SilentlyContinue
        }
    }
})

# TAB 2: SİSTEM ANALİZİ
$tabAnalysis = New-Object System.Windows.Forms.TabPage
$tabAnalysis.Text = "Sistem Analizi"
$tabAnalysis.BackColor = [System.Drawing.Color]::FromArgb(245, 245, 245)
$tabControl.TabPages.Add($tabAnalysis)

$grpCpu = New-Object System.Windows.Forms.GroupBox
$grpCpu.Text = "İşlemci Bilgileri (CPU)"
$grpCpu.Size = New-Object System.Drawing.Size(590, 110)
$grpCpu.Location = New-Object System.Drawing.Point(15, 15)
$tabAnalysis.Controls.Add($grpCpu)

$lblCpuModel = New-Object System.Windows.Forms.Label
$lblCpuModel.Text = "Model: Yükleniyor..."
$lblCpuModel.Location = New-Object System.Drawing.Point(20, 28)
$lblCpuModel.AutoSize = $true
$grpCpu.Controls.Add($lblCpuModel)

$lblCpuCores = New-Object System.Windows.Forms.Label
$lblCpuCores.Text = "Çekirdekler: Yükleniyor..."
$lblCpuCores.Location = New-Object System.Drawing.Point(20, 48)
$lblCpuCores.AutoSize = $true
$grpCpu.Controls.Add($lblCpuCores)

$lblCpuLoad = New-Object System.Windows.Forms.Label
$lblCpuLoad.Text = "Anlık Yük: %0"
$lblCpuLoad.Location = New-Object System.Drawing.Point(20, 75)
$lblCpuLoad.Size = New-Object System.Drawing.Size(120, 15)
$grpCpu.Controls.Add($lblCpuLoad)

$pbCpu = New-Object System.Windows.Forms.ProgressBar
$pbCpu.Location = New-Object System.Drawing.Point(150, 72)
$pbCpu.Size = New-Object System.Drawing.Size(420, 18)
$grpCpu.Controls.Add($pbCpu)

$grpRam = New-Object System.Windows.Forms.GroupBox
$grpRam.Text = "Bellek Bilgileri (RAM)"
$grpRam.Size = New-Object System.Drawing.Size(590, 110)
$grpRam.Location = New-Object System.Drawing.Point(15, 135)
$tabAnalysis.Controls.Add($grpRam)

$lblRamTotal = New-Object System.Windows.Forms.Label
$lblRamTotal.Text = "Toplam Bellek: Yükleniyor..."
$lblRamTotal.Location = New-Object System.Drawing.Point(20, 28)
$lblRamTotal.AutoSize = $true
$grpRam.Controls.Add($lblRamTotal)

$lblRamFree = New-Object System.Windows.Forms.Label
$lblRamFree.Text = "Boşta Olan: Yükleniyor..."
$lblRamFree.Location = New-Object System.Drawing.Point(20, 48)
$lblRamFree.AutoSize = $true
$grpRam.Controls.Add($lblRamFree)

$lblRamUsed = New-Object System.Windows.Forms.Label
$lblRamUsed.Text = "Kullanılan: 0 GB"
$lblRamUsed.Location = New-Object System.Drawing.Point(20, 75)
$lblRamUsed.Size = New-Object System.Drawing.Size(120, 15)
$grpRam.Controls.Add($lblRamUsed)

$pbRam = New-Object System.Windows.Forms.ProgressBar
$pbRam.Location = New-Object System.Drawing.Point(150, 72)
$pbRam.Size = New-Object System.Drawing.Size(420, 18)
$grpRam.Controls.Add($pbRam)

$grpGpu = New-Object System.Windows.Forms.GroupBox
$grpGpu.Text = "Grafik Birimi (GPU)"
$grpGpu.Size = New-Object System.Drawing.Size(590, 70)
$grpGpu.Location = New-Object System.Drawing.Point(15, 255)
$tabAnalysis.Controls.Add($grpGpu)

$lblGpuModel = New-Object System.Windows.Forms.Label
$lblGpuModel.Text = "Model: Yükleniyor..."
$lblGpuModel.Location = New-Object System.Drawing.Point(20, 30)
$lblGpuModel.AutoSize = $true
$grpGpu.Controls.Add($lblGpuModel)

$grpSys = New-Object System.Windows.Forms.GroupBox
$grpSys.Text = "Sistem Durumu"
$grpSys.Size = New-Object System.Drawing.Size(590, 90)
$grpSys.Location = New-Object System.Drawing.Point(15, 335)
$tabAnalysis.Controls.Add($grpSys)

$lblProcs = New-Object System.Windows.Forms.Label
$lblProcs.Text = "Çalışan İşlem Sayısı: Yükleniyor..."
$lblProcs.Location = New-Object System.Drawing.Point(20, 30)
$lblProcs.AutoSize = $true
$grpSys.Controls.Add($lblProcs)

$lblPower = New-Object System.Windows.Forms.Label
$lblPower.Text = "Etkin Güç Planı: Yükleniyor..."
$lblPower.Location = New-Object System.Drawing.Point(20, 55)
$lblPower.AutoSize = $true
$grpSys.Controls.Add($lblPower)

$script:staticDataLoaded = $false
$script:totalRam = 0

function Load-StaticData {
    try {
        $cpuInfo = Get-CimInstance -ClassName Win32_Processor -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($cpuInfo) {
            $lblCpuModel.Text = "Model: $($cpuInfo.Name.Trim())"
            $lblCpuCores.Text = "Çekirdek Sayısı: $($cpuInfo.NumberOfCores) Fiziksel, $($cpuInfo.NumberOfLogicalProcessors) Mantıksal"
        }

        $osInfo = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction SilentlyContinue
        if ($osInfo) {
            $script:totalRam = [math]::Round($osInfo.TotalVisibleMemorySize / 1024 / 1024, 2)
            $lblRamTotal.Text = "Toplam Bellek: $($script:totalRam) GB"
        }

        $gpuInfo = Get-CimInstance -ClassName Win32_VideoController -ErrorAction SilentlyContinue
        if ($gpuInfo) {
            $names = ($gpuInfo | Where-Object { $_.Name } | ForEach-Object { $_.Name.Trim() }) -join " / "
            $lblGpuModel.Text = "Model: $names"
        }

        $powerRaw = (powercfg /getactivescheme 2>$null) -join " "
        $powerMatch = [regex]::Match($powerRaw, "\(([^)]+)\)")
        $powerPlan = if ($powerMatch.Success) { $powerMatch.Groups[1].Value.Trim() } else { "Dengeli / Özel" }
        $lblPower.Text = "Etkin Güç Planı: $powerPlan"

        $script:staticDataLoaded = $true
    }
    catch { }
}

$sysTimer = New-Object System.Windows.Forms.Timer
$sysTimer.Interval = 2000
$sysTimer.Add_Tick({
    try {
        $perfCpu = Get-CimInstance -ClassName Win32_PerfFormattedData_PerfOS_Processor -Filter "Name='_Total'" -ErrorAction SilentlyContinue
        if ($perfCpu -and $null -ne $perfCpu.PercentProcessorTime) {
            $load = [int]$perfCpu.PercentProcessorTime
            $lblCpuLoad.Text = "Anlık Yük: %$load"
            $pbCpu.Value = [math]::Max(0, [math]::Min(100, $load))
        }

        $osInfo = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction SilentlyContinue
        if ($script:totalRam -gt 0 -and $osInfo) {
            $freeRam = [math]::Round($osInfo.FreePhysicalMemory / 1024 / 1024, 2)
            $usedRam = [math]::Round([math]::Max(0, $script:totalRam - $freeRam), 2)
            $lblRamFree.Text = "Boşta Olan: $freeRam GB"
            $lblRamUsed.Text = "Kullanılan: $usedRam GB"
            $ramPercent = [int][math]::Round(($usedRam / $script:totalRam) * 100)
            $pbRam.Value = [math]::Max(0, [math]::Min(100, $ramPercent))
        }

        $lblProcs.Text = "Çalışan İşlem Sayısı: $((Get-Process -ErrorAction SilentlyContinue).Count)"
    }
    catch { }
})

$tabControl.Add_SelectedIndexChanged({
    if ($tabControl.SelectedTab -eq $tabAnalysis) {
        if (-not $script:staticDataLoaded) { Load-StaticData }
        $sysTimer.Start()
    }
    else {
        $sysTimer.Stop()
    }
})

$form.Add_FormClosed({
    $sysTimer.Stop()
    $sysTimer.Dispose()
    $notifyIcon.Visible = $false
    $notifyIcon.Dispose()
})

$form.ShowDialog() | Out-Null
