# Ratevig Vault

Homelab automation for deploying a HashiCorp Vault instance on Proxmox.

The project provisions a Debian LXC container with Terraform, then uses Ansible
to install Vault, bootstrap it with TLS, initialize and unseal it, configure the
PKI secrets engine, and replace the temporary bootstrap certificate with a
certificate issued by Vault itself.

## Repository layout

- `terraform/`: Proxmox LXC provisioning.
- `ansible/`: Ansible inventory, playbook, roles, and encrypted secrets.
- `ansible/playbooks/install_vault.yml`: single Ansible entrypoint for the full Vault deployment.
- `ansible/roles/install_vault/`: Vault package installation, directories, bootstrap TLS certificate, systemd, and TLS-only Vault config.
- `ansible/roles/unseal_vault/`: Vault initialization, generated credential output, and unseal.
- `ansible/roles/configure_vault/`: PKI engine configuration and Vault server certificate rotation.

## Prerequisites

- Terraform.
- Docker, if you use `ansible/run-ansible.sh` as the Ansible control environment.
- SSH access to the target container as `root`.
- A Proxmox API token with permissions to create and start the LXC container.
- The SSH private key referenced by `ansible/ansible.cfg` inside the Ansible control environment:
  `/root/.ssh/ansible_id`.

## Secrets

Do not commit local plaintext secrets. The following files are expected to stay
private and untracked:

- `terraform/secrets.auto.tfvars`
- `ansible/.ansible.key`

`ansible/vault/secrets.yml` may be committed only if it is encrypted with
Ansible Vault. Never commit it in plaintext.

Example Terraform secrets file:

```hcl
pm_api_token_secret = "replace-me"
ct_password         = "replace-me"
ssh_key             = "ssh-ed25519 AAAA... user@host"
```

For the first Vault deployment, `ansible/vault/secrets.yml` only needs to exist
and define placeholder values if the playbook expects the file to decrypt. Vault
will be initialized automatically with one unseal key and a threshold of one.

After the first successful initialization, the playbook prints:

- the Vault unseal key;
- the Vault root token.

Store those generated values in `ansible/vault/secrets.yml` for future
idempotent runs:

```yaml
vault_root_token: "paste-root-token-here"
vault_unseal_keys:
  - "paste-unseal-key-here"
```

Encrypt or edit the file with Ansible Vault, using `ansible/.ansible.key` as the
vault password file:

```bash
cd ansible
ansible-vault edit vault/secrets.yml --vault-password-file .ansible.key
```

If Vault was initialized but the root token was not stored, Vault cannot display
that initial root token again. You must either use another valid privileged
token, generate a new root token with Vault's operator workflow, or reset the
Vault storage if this is only a disposable lab instance.

## Installation

### 1. Provision the LXC container with Terraform

From the Terraform directory:

```bash
cd terraform
terraform init
terraform plan
terraform apply
```

The current Terraform configuration creates a Debian LXC container named
`vault-ct` on Proxmox with IP address `192.168.2.2/24`.

After the apply completes, verify that SSH works from the Ansible control
environment:

```bash
ssh root@192.168.2.2
```

### 2. Prepare the Ansible environment

From the repository root, enter the Ansible directory and install the required
collections:

```bash
cd ansible
ansible-galaxy collection install -r requirements.yml
```

If you use the provided Docker-based helper, run it from the Ansible directory:

```bash
./run-ansible.sh
ansible-galaxy collection install -r requirements.yml
```

The inventory currently targets:

```ini
[vault]
vault-01 ansible_host=192.168.2.2
```

### 3. Deploy Vault

Run the single deployment playbook:

```bash
ansible-playbook playbooks/install_vault.yml --vault-password-file .ansible.key
```

The playbook:

- installs Vault and required packages;
- creates the Vault user, group, data directory, config directory, and TLS directory;
- generates a temporary self-signed bootstrap TLS certificate;
- starts Vault with TLS enabled from the first startup;
- initializes Vault with `secret_shares: 1` and `secret_threshold: 1` when needed;
- unseals Vault;
- enables and configures the PKI secrets engine;
- generates the internal root CA if none exists;
- issues a Vault server certificate from Vault PKI;
- replaces the temporary bootstrap certificate;
- restarts Vault only when the server certificate is rotated;
- unseals Vault again after a restart when needed.

Vault is available at:

```text
https://192.168.2.2:8200
```

The first run prints the generated unseal key and root token. Store them in the
encrypted `ansible/vault/secrets.yml` before relying on future unattended runs.

## TLS and PKI flow

The deployment uses two certificate phases:

1. Bootstrap TLS: Ansible generates a temporary self-signed certificate before
   Vault starts, so Vault is TLS-only from the beginning.
2. Vault-issued TLS: once Vault is initialized and unsealed, the `configure_vault`
   role enables PKI, issues a server certificate, writes it to the same TLS file
   paths, and restarts Vault if the certificate changed.

The final Vault certificate and key are stored under:

```text
/etc/vault.d/tls/vault.crt
/etc/vault.d/tls/vault.key
```

The generated Vault CA certificate is printed by the playbook. Trust that CA on
client machines that need to access Vault without certificate warnings.

## Common commands

```bash
# Terraform
cd terraform
terraform plan
terraform apply

# Ansible
cd ansible
ansible-galaxy collection install -r requirements.yml
ansible-playbook playbooks/install_vault.yml --vault-password-file .ansible.key
ansible-vault edit vault/secrets.yml --vault-password-file .ansible.key
```
