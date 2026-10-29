include .secrets.env
export

.PHONY: packer-init packer-validate packer-build \
        terraform-init terraform-plan terraform-apply terraform-destroy \
        ansible-run all clean-template

# ── Packer vars ──────────────────────────────────────────────────────────────
PKR_VARS = PKR_VAR_proxmox_password='$(PROXMOX_PASSWORD)' \
           PKR_VAR_proxmox_username='$(PROXMOX_USERNAME)' \
           PKR_VAR_proxmox_node='$(PROXMOX_NODE)' \
           PKR_VAR_proxmox_url='$(PROXMOX_HOST)'/api2/json \
           PKR_VAR_storage_pool='$(STORAGE_POOL)' \
           PKR_VAR_win_iso='$(WIN_ISO)' \
           PKR_VAR_virtio_iso='$(VIRTIO_ISO)' \
           PKR_VAR_win_password='$(WIN_PASSWORD)' \
           PKR_VAR_template_id='$(TEMPLATE_ID)'

# ── Terraform vars ───────────────────────────────────────────────────────────
TF_VARS  = TF_VAR_proxmox_password='$(PROXMOX_PASSWORD)' \
           TF_VAR_proxmox_username='$(PROXMOX_USERNAME)' \
           TF_VAR_proxmox_node='$(PROXMOX_NODE)' \
           TF_VAR_proxmox_endpoint='$(PROXMOX_HOST)'/ \
           TF_VAR_vm_count='$(VM_COUNT)' \
           TF_VAR_vm_id='$(VM_ID)' \
           TF_VAR_vm_name='$(VM_NAME)' \
           TF_VAR_vm_cores='$(VM_CORES)' \
           TF_VAR_vm_memory='$(VM_MEMORY)' \
           TF_VAR_vm_disk_size='$(VM_DISK_SIZE)' \
           TF_VAR_vm_tags='$(VM_TAGS)' \
           TF_VAR_storage_pool='$(STORAGE_POOL)' \
           TF_VAR_vlan_id='$(VLAN_ID)' \
           TF_VAR_dns_domain='$(DNS_DOMAIN)' \
           TF_VAR_dhcp='$(DHCP)' \
           TF_VAR_ip_address='$(IP_ADDRESS)' \
           TF_VAR_ip_gateway='$(IP_GATEWAY)' \
           TF_VAR_win_password='$(WIN_PASSWORD)' \
           TF_VAR_template_id='$(TEMPLATE_ID)'

PACKER_DIR    = packer
TERRAFORM_DIR = terraform
ANSIBLE_INV   = ansible/inventory/hosts.yml
ANSIBLE_PLAY  = ansible/playbook.yml

# ── Packer ───────────────────────────────────────────────────────────────────
packer-init:
	packer init $(PACKER_DIR)/. || true

packer-validate:
	$(PKR_VARS) packer validate $(PACKER_DIR)/.

packer-build:
	$(PKR_VARS) packer build $(PACKER_DIR)/.

# ── Terraform ────────────────────────────────────────────────────────────────
terraform-init:
	terraform -chdir=$(TERRAFORM_DIR) init

terraform-plan:
	$(TF_VARS) terraform -chdir=$(TERRAFORM_DIR) plan

terraform-apply:
	$(TF_VARS) terraform -chdir=$(TERRAFORM_DIR) apply -auto-approve

terraform-destroy:
	$(TF_VARS) terraform -chdir=$(TERRAFORM_DIR) destroy

# ── Ansible ──────────────────────────────────────────────────────────────────
ansible-run:
	ansible-playbook -i $(ANSIBLE_INV) $(ANSIBLE_PLAY)

# ── Full pipeline ─────────────────────────────────────────────────────────────
all: packer-build terraform-apply ansible-run

# ── Helpers ──────────────────────────────────────────────────────────────────
# Удалить шаблон из Proxmox (перед пересборкой)
clean-template:
	ssh root@$(PROXMOX_NODE_IP) "qm destroy $(TEMPLATE_ID) --destroy-unreferenced-disks 1 || true"
