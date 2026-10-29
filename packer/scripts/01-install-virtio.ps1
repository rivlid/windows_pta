# 01-install-virtio.ps1
# Устанавливает все VirtIO драйверы из ISO (диск E:)
# Запускается Packer'ом после первого входа в систему

$ErrorActionPreference = "Stop"
Write-Host "=== Installing VirtIO drivers ===" -ForegroundColor Cyan

# Найти букву диска с VirtIO ISO
$virtioDrive = (Get-Volume | Where-Object { $_.FileSystemLabel -like "virtio*" }).DriveLetter
if (-not $virtioDrive) {
    # Попробовать стандартные буквы
    foreach ($letter in @("E","F","D")) {
        if (Test-Path "${letter}:\viostor") { $virtioDrive = $letter; break }
    }
}
if (-not $virtioDrive) { throw "VirtIO ISO not found! Check VIRTIO_ISO path." }

Write-Host "VirtIO drive: ${virtioDrive}:" -ForegroundColor Green

# Установить все .inf файлы из ISO (рекурсивно)
# Это поставит: viostor, NetKVM, vioscsi, vionet, vioserial, balloon, qxl, etc.
Get-ChildItem -Path "${virtioDrive}:\" -Recurse -Filter "*.inf" | ForEach-Object {
    Write-Host "Installing: $($_.FullName)"
    try {
        & pnputil /add-driver $_.FullName /install 2>&1 | Out-Null
    } catch {
        Write-Warning "Failed to install $($_.FullName): $_"
    }
}

# Установить QEMU Guest Agent (MSI из VirtIO ISO)
$agentMsi = "${virtioDrive}:\guest-agent\qemu-ga-x86_64.msi"
if (Test-Path $agentMsi) {
    Write-Host "Installing QEMU Guest Agent..." -ForegroundColor Cyan
    Start-Process msiexec -Wait -ArgumentList "/i `"$agentMsi`" /qn /norestart"
    Write-Host "QEMU Guest Agent installed." -ForegroundColor Green
} else {
    Write-Warning "QEMU Guest Agent MSI not found at $agentMsi"
}

Write-Host "=== VirtIO drivers installed ===" -ForegroundColor Green
