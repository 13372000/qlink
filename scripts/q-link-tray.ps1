param(
  [string]$AppDir = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
)

$ErrorActionPreference = "Stop"

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$script:AppDir = (Resolve-Path $AppDir).Path
$script:DataDir = Join-Path $script:AppDir "data"
$script:LogDir = Join-Path $script:AppDir "logs"
$script:PidFile = Join-Path $script:DataDir "qlink.pid"
$script:TrayPidFile = Join-Path $script:DataDir "qlink-tray.pid"
$script:OutLog = Join-Path $script:LogDir "qlink.out.log"
$script:ErrLog = Join-Path $script:LogDir "qlink.err.log"
$script:IconPath = Join-Path $script:AppDir "assets\qlink.ico"
$script:LastStartedPid = $null
$script:ActionInProgress = $false

New-Item -ItemType Directory -Force -Path $script:DataDir, $script:LogDir | Out-Null
[System.IO.File]::WriteAllText($script:TrayPidFile, [string]$PID)

function Get-QLinkIcon {
  if (Test-Path $script:IconPath) {
    return New-Object System.Drawing.Icon($script:IconPath)
  }

  return [System.Drawing.SystemIcons]::Application
}

function Get-QLinkProcess {
  if (-not (Test-Path $script:PidFile)) {
    if ($script:LastStartedPid) {
      return Get-Process -Id $script:LastStartedPid -ErrorAction SilentlyContinue
    }

    return $null
  }

  try {
    $pidValue = [int](Get-Content -LiteralPath $script:PidFile -Raw)
    return Get-Process -Id $pidValue -ErrorAction SilentlyContinue
  } catch {
    return $null
  }
}

function Show-Balloon([string]$Title, [string]$Text, [System.Windows.Forms.ToolTipIcon]$Icon = [System.Windows.Forms.ToolTipIcon]::Info) {
  $script:NotifyIcon.BalloonTipTitle = $Title
  $script:NotifyIcon.BalloonTipText = $Text
  $script:NotifyIcon.BalloonTipIcon = $Icon
  $script:NotifyIcon.ShowBalloonTip(2500)
}

function Update-TrayState {
  $process = Get-QLinkProcess
  if ($process) {
    $script:NotifyIcon.Icon = $script:AppIcon
    $script:NotifyIcon.Text = "Q-Link running (PID $($process.Id))"
    $script:StartItem.Enabled = $false
    $script:StopItem.Enabled = $true
    $script:RestartItem.Enabled = $true
    $script:StatusItem.Text = "Status: running"
  } else {
    $script:NotifyIcon.Icon = $script:AppIcon
    $script:NotifyIcon.Text = "Q-Link stopped"
    $script:StartItem.Enabled = $true
    $script:StopItem.Enabled = $false
    $script:RestartItem.Enabled = $true
    $script:StatusItem.Text = "Status: stopped"
  }
}

function Set-TrayBusy([string]$Status) {
  $script:NotifyIcon.Text = "Q-Link $Status"
  $script:StatusItem.Text = "Status: $Status"
  $script:StartItem.Enabled = $false
  $script:StopItem.Enabled = $false
  $script:RestartItem.Enabled = $false
}

function Invoke-TrayAction([scriptblock]$Action) {
  if ($script:ActionInProgress) {
    Show-Balloon "Q-Link" "Another tray action is already running."
    return
  }

  $script:ActionInProgress = $true
  try {
    & $Action
  } finally {
    $script:ActionInProgress = $false
    Update-TrayState
  }
}

function Start-QLink {
  try {
    $process = Get-QLinkProcess
    if ($process) {
      Show-Balloon "Q-Link" "Q-Link already running. PID=$($process.Id)"
      return
    }

    Set-TrayBusy "starting"
    New-Item -ItemType Directory -Force -Path $script:DataDir, $script:LogDir | Out-Null
    $process = Start-Process `
      -WindowStyle Hidden `
      -FilePath "node" `
      -ArgumentList @("qlink.js") `
      -WorkingDirectory $script:AppDir `
      -RedirectStandardOutput $script:OutLog `
      -RedirectStandardError $script:ErrLog `
      -PassThru
    $script:LastStartedPid = $process.Id
    Show-Balloon "Q-Link" "Q-Link starting. PID=$($process.Id)"
  } catch {
    Show-Balloon "Q-Link error" $_.Exception.Message ([System.Windows.Forms.ToolTipIcon]::Error)
  }
}

function Stop-QLink {
  try {
    $process = Get-QLinkProcess
    if (-not $process) {
      Remove-Item -LiteralPath $script:PidFile -Force -ErrorAction SilentlyContinue
      $script:LastStartedPid = $null
      Show-Balloon "Q-Link" "Q-Link is not running."
      return
    }

    Set-TrayBusy "stopping"
    Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $script:PidFile -Force -ErrorAction SilentlyContinue
    $script:LastStartedPid = $null
    Show-Balloon "Q-Link" "Q-Link stopped. PID=$($process.Id)"
  } catch {
    Show-Balloon "Q-Link error" $_.Exception.Message ([System.Windows.Forms.ToolTipIcon]::Error)
  }
}

function Restart-QLink {
  Stop-QLink
  Start-Sleep -Milliseconds 300
  Start-QLink
}

function Open-Logs {
  New-Item -ItemType Directory -Force -Path $script:LogDir | Out-Null
  Start-Process explorer.exe $script:LogDir
}

function Open-Readme {
  $readme = Join-Path $script:AppDir "README.md"
  if (Test-Path $readme) {
    Start-Process $readme
  } else {
    Start-Process explorer.exe $script:AppDir
  }
}

function Exit-Tray {
  Stop-QLink
  $script:Timer.Stop()
  $script:NotifyIcon.Visible = $false
  $script:NotifyIcon.Dispose()
  if ($script:AppIcon -and $script:AppIcon -ne [System.Drawing.SystemIcons]::Application) {
    $script:AppIcon.Dispose()
  }
  Remove-Item -LiteralPath $script:TrayPidFile -Force -ErrorAction SilentlyContinue
  [System.Windows.Forms.Application]::Exit()
}

$script:AppIcon = Get-QLinkIcon
$script:NotifyIcon = New-Object System.Windows.Forms.NotifyIcon
$script:NotifyIcon.Text = "Q-Link starting"
$script:NotifyIcon.Icon = $script:AppIcon
$script:NotifyIcon.Visible = $true

$menu = New-Object System.Windows.Forms.ContextMenuStrip
$script:StatusItem = $menu.Items.Add("Status: starting")
$script:StatusItem.Enabled = $false
$script:StartItem = $menu.Items.Add("Start Q-Link")
$script:RestartItem = $menu.Items.Add("Restart Q-Link")
$script:StopItem = $menu.Items.Add("Stop Q-Link")
$menu.Items.Add("-") | Out-Null
$logsItem = $menu.Items.Add("Open Logs")
$readmeItem = $menu.Items.Add("Open README")
$menu.Items.Add("-") | Out-Null
$exitItem = $menu.Items.Add("Exit")

$script:StartItem.Add_Click({ Invoke-TrayAction { Start-QLink } })
$script:RestartItem.Add_Click({ Invoke-TrayAction { Restart-QLink } })
$script:StopItem.Add_Click({ Invoke-TrayAction { Stop-QLink } })
$logsItem.Add_Click({ Open-Logs })
$readmeItem.Add_Click({ Open-Readme })
$exitItem.Add_Click({ Exit-Tray })
$script:NotifyIcon.ContextMenuStrip = $menu
$script:NotifyIcon.Add_DoubleClick({ Open-Logs })

$script:Timer = New-Object System.Windows.Forms.Timer
$script:Timer.Interval = 2000
$script:Timer.Add_Tick({ Update-TrayState })
$script:Timer.Start()

Invoke-TrayAction { Start-QLink }
Update-TrayState
[System.Windows.Forms.Application]::Run()
