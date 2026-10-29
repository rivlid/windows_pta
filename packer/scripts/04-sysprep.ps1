# 04-sysprep.ps1
# ДОЛЖЕН БЫТЬ ПОСЛЕДНИМ provisioner'ом!
# Генерализирует образ: сбрасывает SID, имя компьютера, сетевые настройки.
# После sysprep VM выключается — Packer сохраняет её как шаблон.

$ErrorActionPreference = "Stop"
Write-Host "=== Running Sysprep ===" -ForegroundColor Yellow
Write-Host "VM will shut down after sysprep. This is expected." -ForegroundColor Yellow

# Проверить что cloudbase-init установлен
$cloudbaseInitPath = "C:\Program Files\Cloudbase Solutions\Cloudbase-Init"
if (-not (Test-Path $cloudbaseInitPath)) {
    throw "Cloudbase-Init not found! Run 02-install-cloudbase-init.ps1 first."
}

# Путь к unattend.xml от cloudbase-init (используется при первом старте клона)
$unattendXml = "$cloudbaseInitPath\conf\Unattend.xml"

# Создать Unattend.xml для sysprep (cloudbase-init предоставляет свой)
$sysprepUnattend = @"
<?xml version="1.0" encoding="utf-8"?>
<unattend xmlns="urn:schemas-microsoft-com:unattend">
  <settings pass="generalize">
    <component name="Microsoft-Windows-PnpSysprep"
               processorArchitecture="amd64"
               publicKeyToken="31bf3856ad364e35"
               language="neutral"
               versionScope="nonSxS">
      <PersistAllDeviceInstalls>true</PersistAllDeviceInstalls>
      <DoNotCleanUpNonPresentDevices>true</DoNotCleanUpNonPresentDevices>
    </component>
  </settings>
  <settings pass="specialize">
    <component name="Microsoft-Windows-Shell-Setup"
               processorArchitecture="amd64"
               publicKeyToken="31bf3856ad364e35"
               language="neutral"
               versionScope="nonSxS">
      <TimeZone>UTC</TimeZone>
    </component>
  </settings>
  <settings pass="oobeSystem">
    <component name="Microsoft-Windows-Shell-Setup"
               processorArchitecture="amd64"
               publicKeyToken="31bf3856ad364e35"
               language="neutral"
               versionScope="nonSxS">
      <OOBE>
        <HideEULAPage>true</HideEULAPage>
        <HideLocalAccountScreen>true</HideLocalAccountScreen>
        <HideOnlineAccountScreens>true</HideOnlineAccountScreens>
        <HideWirelessSetupInOOBE>true</HideWirelessSetupInOOBE>
        <SkipMachineOOBE>true</SkipMachineOOBE>
        <SkipUserOOBE>true</SkipUserOOBE>
        <NetworkLocation>Work</NetworkLocation>
        <ProtectYourPC>3</ProtectYourPC>
      </OOBE>
    </component>
    <component name="Microsoft-Windows-International-Core"
               processorArchitecture="amd64"
               publicKeyToken="31bf3856ad364e35"
               language="neutral"
               versionScope="nonSxS">
      <InputLocale>en-US</InputLocale>
      <SystemLocale>en-US</SystemLocale>
      <UILanguage>en-US</UILanguage>
      <UserLocale>en-US</UserLocale>
    </component>
  </settings>
</unattend>
"@

$sysprepUnattendPath = "C:\Windows\Temp\sysprep-unattend.xml"
Set-Content -Path $sysprepUnattendPath -Value $sysprepUnattend -Encoding UTF8

# Запустить sysprep
# /generalize — сбросить SID и специфику машины
# /oobe       — при следующем старте показать (но cloudbase-init перехватит)
# /shutdown   — выключить после завершения (Packer ждёт этого)
# /unattend   — использовать наш unattend.xml
Write-Host "Starting Sysprep /generalize /oobe /shutdown..."
& C:\Windows\System32\Sysprep\Sysprep.exe /generalize /oobe /shutdown /unattend:$sysprepUnattendPath

# Эта строка не выполнится — VM выключится во время sysprep
Write-Host "Sysprep complete."
