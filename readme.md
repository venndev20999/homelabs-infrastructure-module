# 🏗️ Homelabs Infrastructure Modules

A centralized repository for reusable, version-controlled **Terraform Modules** and **Ansible Roles**. This repository serves as the "source of truth" for infrastructure building blocks across all environments.

## 📂 Repository Structure

```text
homelabs-infrastructure-module/
├── terraform/                   # Reusable Terraform Modules
│   ├── talos-instance/          # Provision a Talos KVM node
│   ├── vm-instance/             # Provision a generic Ubuntu KVM node
│   └── database/                # e.g., PostgreSQL VM/Instance
└── ansible/                     # Reusable Ansible Content
    ├── roles/                   # Standardized Roles
    │   ├── common/              # Base security, users, ssh config
    │   ├── patching/            # OS updates logic
    │   ├── elasticsearch/       # Installation & clustering logic
    │   └── kafka/               # Kafka setup logic
    └── requirements.yml         # Shared external dependencies
```

---

## 🚀 Usage in Client Repositories

The "Client" repository (e.g., `infrastructure-live`) calls these modules using Git-based references. This ensures stability and reusability.

### A. Generic VM (Terraform)
Provision a simple Ubuntu VM with DHCP reservation.

```hcl
module "app_server" {
  # Syntax: git::URL//path/to/module?ref=version
  source = "git::github.com/venndev20999/homelabs-infrastructure-module.git//terraform/vm-instance?ref=v1.0.0"

  name             = "web-server"
  ip_address       = "192.168.122.50"
  memory           = 2048
  vcpus            = 1
  base_volume_name = "ubuntu-server"
}
```

### B. Talos Kubernetes Cluster (Terraform)
Chain the `talos-instance` and `talos-cluster` modules for a full K8s setup.

```hcl
# 1. Provision VMs for Talos
module "talos_nodes" {
  source = "git::github.com/venndev20999/homelabs-infrastructure-module.git//terraform/talos-instance?ref=v1.0.0"
  # ... node configurations
}

# 2. Bootstrap the Talos cluster once nodes are ready
module "talos_cluster" {
  source           = "git::github.com/venndev20999/homelabs-infrastructure-module.git//terraform/talos-cluster?ref=v1.0.0"
  cluster_name     = "homelab"
  controlplane_ips = [module.talos_nodes[0].ip_address]
  worker_ips       = [module.talos_nodes[1].ip_address]
  # ... cluster configurations
}
```

### C. Ansible Roles (ansible-galaxy)
In your client repository, define the Git source in `requirements.yml`.

```yaml
# infrastructure-live/ansible/requirements.yml
roles:
  - name: internal.patching
    src: https://github.com/venndev20999/homelabs-infrastructure-module.git
    scm: git
    version: v1.0.0
    path: ansible/roles/patching
```

To install:
```bash
ansible-galaxy install -r requirements.yml -p ./roles/
```


---

## 🛠️ The "Hybrid" Pattern (Best Practice)
Sometimes, you want Terraform to automatically trigger the Ansible run after provisioning. You can achieve this using a `local-exec` provisioner.

**Example: `terraform/vm-instance/main.tf`**
```hcl
resource "null_resource" "ansible_run" {
  # Trigger this whenever the VM is created or the IP changes
  triggers = {
    instance_id = libvirt_domain.vm.id
    ip          = var.ip_address
  }
  
  provisioner "local-exec" {
    # This calls a local playbook using the newly provisioned IP
    command = "ansible-playbook -i '${var.ip_address},' -u user site.yml"
  }
  
  depends_on = [libvirt_domain.vm]
}
```

---

## 📊 Integration Flow

```mermaid
graph TD
    subgraph "Infrastructure Modules (This Repo)"
        TM[Terraform Modules]
        AR[Ansible Roles]
    end

    subgraph "Infrastructure Live (Production/Dev)"
        T[Terraform Run] -->|Fetches| TM
        A[Ansible Playbook] -->|Installs| AR
    end

    T -.->|Provision & Handoff| A
```

---

## 📝 Usage Summary

| Tool | Mechanism | Method |
| :--- | :--- | :--- |
| **Terraform** | source block | Git URL + sub-path (//terraform/vm) |
| **Ansible** | requirements.yml | ansible-galaxy install |
