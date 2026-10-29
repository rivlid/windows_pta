# Windows на Proxmox — Packer + Terraform + Ansible

Структура проекта аналогична Debian-стеку, адаптирована для Windows.

## Структура

```
windows_proxmox/
├── Makefile                        # Те же цели: packer-build, terraform-apply, ansible-run
├── .secrets.env                    # Все параметры — proxmox, ISO пути, пароль
├── packer/
│   ├── windows.pkr.hcl             # Packer: собирает шаблон из ISO
│   ├── http/
│   │   └── autounattend.xml        # Автоустановка Windows (аналог preseed)
│   └── scripts/
│       ├── 01-install-virtio.ps1   # VirtIO драйверы + QEMU Guest Agent
│       ├── 02-install-cloudbase-init.ps1  # Cloud-init для Windows
│       ├── 03-windows-setup.ps1    # WinRM, очистка, базовые настройки
│       └── 04-sysprep.ps1          # Генерализация (ВСЕГДА последний)
├── terraform/
│   ├── main.tf                     # Клонировать шаблон, задать параметры
│   └── variables.tf
└── ansible/
    ├── playbook.yml
    ├── inventory/hosts.yml
    ├── group_vars/windows.yml
    └── roles/windows-base/tasks/main.yml
```

## Подготовка — один раз

### 1. Скачать ISO и загрузить в Proxmox

```bash
# Windows Server 2022 (180 дней eval, бесплатно)
# https://www.microsoft.com/en-us/evalcenter/download-windows-server-2022

# VirtIO драйверы (обязательно!)
wget https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/stable-virtio/virtio-win.iso

# Загрузить оба ISO в Proxmox через веб-интерфейс или:
scp virtio-win.iso root@192.168.0.27:/var/lib/vz/template/iso/
```

### 2. Настроить пароль в autounattend.xml

Текущие base64 значения рассчитаны для пароля `Str0ngP@ssw0rd!`.
При смене пароля нужно пересчитать:

```bash
# Пароль для <AdministratorPassword>
echo -n "НОВЫЙПАРОЛЬAdministratorPassword" | base64

# Пароль для <AutoLogon>
echo -n "НОВЫЙПАРОЛЬ" | base64
```

Заменить в `packer/http/autounattend.xml` в двух местах.

### 3. Для Windows 11 — раскомментировать TPM и EFI

В `packer/windows.pkr.hcl` раскомментировать блоки `tpm_config` и `efi_config`.
В `terraform/main.tf` раскомментировать блок `tpm_state`.
В `autounattend.xml` убрать блок `<ProductKey>` (Win11 не требует ключ при установке).

### 4. Настроить .secrets.env

```bash
cp .secrets.env .secrets.env.example
# Отредактировать .secrets.env под своё окружение
```

## Запуск

```bash
# Шаг 1: Собрать шаблон (занимает 20-40 минут)
make packer-init
make packer-build

# Шаг 2: Развернуть VM из шаблона
make terraform-init
make terraform-plan
make terraform-apply

# Шаг 3: Настроить через Ansible
# Сначала вписать IP из terraform output в ansible/inventory/hosts.yml
make ansible-run

# Или всё сразу (после первого packer-build)
# make all
```

## Установить Ansible модули для Windows

```bash
pip install pywinrm
ansible-galaxy collection install ansible.windows community.windows chocolatey.chocolatey
```

## Отличия от Linux (Debian) стека

| | Debian 13 | Windows Server 2022 |
|---|---|---|
| Автоустановка | preseed / cloud-init | autounattend.xml |
| Packer communicator | SSH | WinRM (порт 5985) |
| Cloud-init | встроен | cloudbase-init (MSI) |
| Генерализация | нет | Sysprep (обязателен) |
| Ansible connection | ssh | winrm |
| Ansible модули | linux модули | win_* модули |
| VirtIO драйверы | в ядре | отдельный ISO |
| Время сборки шаблона | ~5 мин | ~30-40 мин |
| Размер шаблона | ~2 GB | ~15-20 GB |

## Troubleshooting

**Packer не может подключиться по WinRM:**
- Проверить что WinRM включился в `autounattend.xml` → `FirstLogonCommands`
- Увеличить `winrm_timeout` в pkr.hcl (до 90m)
- Проверить в Proxmox консоли что VM загрузилась и нет ошибок установки

**Packer не видит диск во время установки:**
- VirtIO ISO должен быть примонтирован как второй CD
- Путь к драйверу в autounattend.xml: `E:\viostor\2k22\amd64` для WinServer 2022,
  `E:\viostor\w11\amd64` для Windows 11

**Terraform: initialization не применяется:**
- cloudbase-init должен быть установлен в шаблоне
- Проверить логи: `C:\Program Files\Cloudbase Solutions\Cloudbase-Init\log\`

**Ansible: WinRM connection refused:**
```bash
# Проверить доступность
curl -v http://VM_IP:5985/wsman
# Убедиться что pywinrm установлен
pip show pywinrm
```
