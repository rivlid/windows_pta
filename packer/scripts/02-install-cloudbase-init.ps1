# 02-install-cloudbase-init.ps1
# Cloudbase-init = аналог cloud-init для Windows
# Позволяет Terraform через initialization{} задавать:
#   - имя компьютера
#   - пароль Administrator
#   - сетевые настройки (IP, gateway, DNS)
#   - SSH ключи (через user_data)

$ErrorActionPreference = "Stop"
Write-Host "=== Installing Cloudbase-Init ===" -ForegroundColor Cyan

$installerUrl  = "https://www.cloudbase.it/downloads/CloudbaseInitSetup_Stable_x64.msi"
$installerPath = "C:\Windows\Temp\cloudbase-init.msi"

# Скачать
Write-Host "Downloading Cloudbase-Init..."
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Invoke-WebRequest -Uri $installerUrl -OutFile $installerPath -UseBasicParsing

# Установить в тихом режиме
# USERNAME=Admin — имя локального пользователя для cloudbase-init service
Write-Host "Installing Cloudbase-Init..."
$args = @(
    "/i", $installerPath,
    "/qn",
    "/norestart",
    "USERNAME=Admin",
    "LOGGINGLEVEL=DEBUG"
)
$proc = Start-Process msiexec -ArgumentList $args -Wait -PassThru
if ($proc.ExitCode -notin @(0, 3010)) {
    throw "Cloudbase-Init installation failed with exit code: $($proc.ExitCode)"
}

# Настроить cloudbase-init.conf
$confPath = "C:\Program Files\Cloudbase Solutions\Cloudbase-Init\conf\cloudbase-init.conf"
$conf = @"
[DEFAULT]
username=Admin
groups=Administrators
inject_user_password=true
config_drive_raw_hhd=true
config_drive_cdrom=true
config_drive_vfat=true
bsdtar_path=C:\Program Files\Cloudbase Solutions\Cloudbase-Init\bin\bsdtar.exe
mtools_path=C:\Program Files\Cloudbase Solutions\Cloudbase-Init\bin\
verbose=true
debug=true
logdir=C:\Program Files\Cloudbase Solutions\Cloudbase-Init\log\
logfile=cloudbase-init.log
default_log_levels=comtypes=INFO,suds=INFO,iso8601=WARN,requests=WARN
logging_serial_port_settings=
mtu_use_dhcp_config=true
ntp_use_dhcp_config=true
local_scripts_path=C:\Program Files\Cloudbase Solutions\Cloudbase-Init\LocalScripts\
check_latest_version=false
"@
Set-Content -Path $confPath -Value $conf -Encoding UTF8

# Настроить cloudbase-init-unattend.conf (для первой загрузки после sysprep)
$unattendConf = "C:\Program Files\Cloudbase Solutions\Cloudbase-Init\conf\cloudbase-init-unattend.conf"
$unattend = @"
[DEFAULT]
username=Admin
groups=Administrators
inject_user_password=true
config_drive_raw_hhd=true
config_drive_cdrom=true
config_drive_vfat=true
bsdtar_path=C:\Program Files\Cloudbase Solutions\Cloudbase-Init\bin\bsdtar.exe
mtools_path=C:\Program Files\Cloudbase Solutions\Cloudbase-Init\bin\
verbose=true
debug=true
logdir=C:\Program Files\Cloudbase Solutions\Cloudbase-Init\log\
logfile=cloudbase-init-unattend.log
default_log_levels=comtypes=INFO,suds=INFO,iso8601=WARN,requests=WARN
logging_serial_port_settings=
mtu_use_dhcp_config=true
ntp_use_dhcp_config=true
local_scripts_path=C:\Program Files\Cloudbase Solutions\Cloudbase-Init\LocalScripts\
check_latest_version=false
first_logon_behaviour=no
"@
Set-Content -Path $unattendConf -Value $unattend -Encoding UTF8

Remove-Item $installerPath -Force -ErrorAction SilentlyContinue
Write-Host "=== Cloudbase-Init installed ===" -ForegroundColor Green
