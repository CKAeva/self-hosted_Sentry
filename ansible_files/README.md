# ansible_sentry

An Ansible playbook that fully automates the installation and configuration of a **self-hosted Sentry** instance on **RHEL 9**, including Docker, system tuning, Nginx reverse proxy, and admin user creation — zero manual steps required.

---

## Project Structure

```
ansible_sentry/
├── sentry.yml                   # Master playbook — runs all tasks in order
├── ansible.cfg                  # Ansible runtime configuration (inventory path, SSH settings)
├── group_vars/
│   └── all.yml                  # All variables (packages, paths, credentials, flags)
└── templates/
    ├── docker-daemon.json        # Jinja2 template for Docker daemon configuration
    └── sentry-nginx.conf         # Jinja2 template for Nginx reverse proxy vhost
```

---

## How the Playbook Works

The single playbook `sentry.yml` targets the `[sentry]` host group and executes tasks in the following order:

---

### Stage 1 — System Preparation

- Runs a full `dnf` system update (`dnf update -y`)
- Installs all prerequisite packages defined in `group_vars/all.yml` under `required_packages` (e.g. `git`, `curl`, `python3`, etc.)

---

### Stage 2 — Docker Installation

| Step | What happens |
|---|---|
| Add repo | Adds the official Docker CE repository via `dnf config-manager` (idempotent — skipped if repo file already exists) |
| Install packages | Installs `docker-ce`, `docker-ce-cli`, `containerd.io`, `docker-buildx-plugin`, `docker-compose-plugin` |
| Configure daemon | Renders `templates/docker-daemon.json` → `/etc/docker/daemon.json` (log driver, storage driver settings) |
| Enable service | Enables and starts the `docker` systemd service |
| Add users | Adds every user listed in `docker_users` to the `docker` group so they can run containers without `sudo` |

---

### Stage 3 — System Tuning

Two kernel parameters are set and reloaded immediately via `sysctl`:

| Parameter | Value | Why |
|---|---|---|
| `vm.max_map_count` | `262144` | Required by Elasticsearch (used internally by Sentry) |
| `fs.file-max` | `2097152` | Raises the OS file descriptor limit for high-concurrency workloads |

---

### Stage 4 — Clone Sentry

- Creates the installation directory defined by `sentry_install_dir`
- Clones the official [`getsentry/self-hosted`](https://github.com/getsentry/self-hosted) repository at the tag/branch set by `sentry_version`

---

### Stage 5 — Install Sentry

- Runs the bundled `install.sh --skip-user-creation` script inside `sentry_install_dir`
- Sets `COMPOSE_HTTP_TIMEOUT=240` to prevent timeouts when pulling large Docker images
- Registers the output and marks the task as `changed` only when new volumes are created (idempotency-aware)

---

### Stage 6 — Start Sentry

- Runs `docker compose up -d` to bring all Sentry services up in detached mode
- Services include: `web`, `worker`, `cron`, `relay`, `snuba`, `kafka`, `redis`, `postgres`, `clickhouse`, and more

---

### Stage 7 — Create Admin User

- Uses `docker compose run --rm web createuser` to create the initial superuser account
- Credentials (`sentry_admin_email`, `sentry_admin_pass`) are pulled from `group_vars/all.yml`
- `ignore_errors: true` is set so re-runs don't fail if the user already exists

---

### Stage 8 — Nginx Reverse Proxy *(optional)*

Controlled by the `enable_nginx` boolean in `group_vars/all.yml`. When `true`:

| Step | What happens |
|---|---|
| Install | Installs `nginx` via `dnf` |
| Deploy config | Renders `templates/sentry-nginx.conf` → `/etc/nginx/conf.d/sentry.conf` |
| Clean up | Removes the default Nginx vhost to prevent conflicts |
| Validate | Runs `nginx -t` to catch config syntax errors before restarting |
| Enable | Enables and (re)starts the `nginx` systemd service |

The Nginx config proxies all HTTP traffic to Sentry's internal port (`9000` by default).

---

### Stage 9 — Verify

- Runs `docker ps` and prints all running containers to the Ansible output, confirming all Sentry services are up

---

## Variables (`group_vars/all.yml`)

| Variable | Description | Example |
|---|---|---|
| `required_packages` | List of system packages to pre-install | `[git, curl, python3]` |
| `docker_users` | Users to add to the `docker` group | `[ec2-user, deploy]` |
| `sentry_install_dir` | Where Sentry is cloned and run from | `/opt/sentry` |
| `sentry_version` | Git tag or branch of `self-hosted` repo | `24.11.0` |
| `sentry_admin_email` | Email for the initial superuser | `admin@example.com` |
| `sentry_admin_pass` | Password for the initial superuser | `StrongPassword123` |
| `enable_nginx` | Toggle Nginx reverse proxy setup | `true` / `false` |

> **Security tip:** Move `sentry_admin_pass` into an Ansible Vault file and reference it from `all.yml` rather than storing it in plaintext.

---

## Prerequisites

- Ansible >= 2.12 installed on the control node
- Target host running **RHEL 9** (or compatible, e.g. Rocky Linux 9, AlmaLinux 9)
- SSH access to the target with a user that has `sudo` / `become` rights
- Internet access on the target host (to pull Docker images and clone GitHub)
- Minimum recommended specs: **4 vCPU, 8 GB RAM, 40 GB disk**

---

## Usage

### 1. Clone this repository
```bash
git clone <repo-url>
cd ansible_sentry
```

### 2. Configure your inventory
Edit or create your inventory file (path set in `ansible.cfg`):
```ini
[sentry]
192.168.1.100 ansible_user=ec2-user ansible_ssh_private_key_file=~/.ssh/id_rsa
```

### 3. Set your variables
```bash
vi group_vars/all.yml
```
At minimum, set `sentry_admin_email`, `sentry_admin_pass`, and `sentry_version`.

### 4. (Optional) Encrypt secrets with Vault
```bash
ansible-vault encrypt_string 'StrongPassword123' --name 'sentry_admin_pass'
```
Paste the output into `group_vars/all.yml`.

### 5. Run a dry-run first
```bash
ansible-playbook sentry.yml --check
```

### 6. Run the full playbook
```bash
ansible-playbook sentry.yml
```

With Vault:
```bash
ansible-playbook sentry.yml --ask-vault-pass
```

---

## Accessing Sentry

Once the playbook completes:

| Method | URL |
|---|---|
| Direct (no Nginx) | `http://<host-ip>:9000` |
| Via Nginx | `http://<host-ip>` or your configured domain |

Log in with the `sentry_admin_email` and `sentry_admin_pass` you set in `all.yml`.

---

## Templates

### `docker-daemon.json`
Configures the Docker daemon — typically sets the log driver (`json-file`), log rotation limits, and storage driver. Rendered to `/etc/docker/daemon.json`.

### `sentry-nginx.conf`
Nginx `server` block that proxies requests to `localhost:9000`. Variables like `server_name` are injected from `group_vars/all.yml` at render time.

---

## Idempotency

The playbook is designed to be re-run safely:

- The Docker repo task uses `creates:` to skip if the repo file already exists
- The Sentry install step only marks itself `changed` when new volumes are created
- Admin user creation uses `ignore_errors: true` to skip gracefully if the user exists
- All `dnf` and `systemd` tasks are natively idempotent
