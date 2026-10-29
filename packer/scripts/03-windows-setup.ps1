# 03-windows-setup.ps1
# Базовая настройка Windows для серверной роли в инфраструктуре

$ErrorActionPreference = "Stop"
Write-Host "=== Windows base configuration ===" -ForegroundColor Cyan

# ── WinRM — убедиться что настроен правильно для Ansible ─────────────────────
Write-Host "Configuring WinRM for Ansible..."
winrm quickconfig -force
winrm set winrm/config '@{MaxTimeoutms="1800000"}'
winrm set winrm/config/service '@{AllowUnencrypted="true"}'
winrm set winrm/config/service/auth '@{Basic="true"}'
winrm set winrm/config/client '@{AllowUnencrypted="true"}'
winrm set winrm/config/client/auth '@{Basic="true"}'
winrm set winrm/config/listener?Address=*+Transport=HTTP '@{Port="5985"}'

# Firewall: открыть WinRM HTTP (5985) и HTTPS (5986)
netsh advfirewall firewall add rule name="WinRM HTTP"  protocol=TCP dir=in localport=5985 action=allow
netsh advfirewall firewall add rule name="WinRM HTTPS" protocol=TCP dir=in localport=5986 action=allow
# Открыть RDP (удобно для диагностики)
netsh advfirewall firewall add rule name="RDP" protocol=TCP dir=in localport=3389 action=allow

# ── Отключить лишнее ──────────────────────────────────────────────────────────
Write-Host "Disabling unnecessary services..."

# Windows Update автозапуск (управлять через Ansible/WSUS)
Set-Service wuauserv -StartupType Disabled -ErrorAction SilentlyContinue

# Windows Defender Real-time (опционально для серверов без GUI)
# Set-MpPreference -DisableRealtimeMonitoring $true

# Hibernate
powercfg /hibernate off

# ── PowerShell настройки ──────────────────────────────────────────────────────
Set-ExecutionPolicy Unrestricted -Scope LocalMachine -Force

# Включить PowerShell remoting (нужен для Ansible)
Enable-PSRemoting -Force -SkipNetworkProfileCheck

# ── Часовой пояс (UTC для серверов) ──────────────────────────────────────────
Set-TimeZone -Id "UTC"

# ── Отключить IE Enhanced Security (мешает скачивать файлы в GUI) ─────────────
$adminKey = "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A7-37EF-4b3f-8CFC-4F3A74704073}"
$userKey  = "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A8-37EF-4b3f-8CFC-4F3A74704073}"
Set-ItemProperty -Path $adminKey -Name "IsInstalled" -Value 0 -ErrorAction SilentlyContinue
Set-ItemProperty -Path $userKey  -Name "IsInstalled" -Value 0 -ErrorAction SilentlyContinue

# ── Оптимизация для виртуальных машин ────────────────────────────────────────
# Отключить дефрагментацию (бесполезна на thin-provisioned дисках)
Get-ScheduledTask -TaskName "ScheduledDefrag" -ErrorAction SilentlyContinue | Disable-ScheduledTask

# ── Очистка WinSxS и временных файлов (уменьшить размер шаблона) ─────────────
Write-Host "Cleaning up to reduce template size..."
& dism /online /Cleanup-Image /StartComponentCleanup /ResetBase 2>&1 | Out-Null
Remove-Item "C:\Windows\Temp\*"   -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item "C:\Windows\Prefetch\*" -Force -ErrorAction SilentlyContinue
Remove-Item "$env:TEMP\*"         -Recurse -Force -ErrorAction SilentlyContinue

Write-Host "=== Windows base configuration done ===" -ForegroundColor Green
