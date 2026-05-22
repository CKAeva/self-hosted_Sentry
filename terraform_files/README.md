# terraform_sentry

A modular Terraform project that provisions cloud infrastructure across three core domains: **Application Load Balancing (ALB)**, **Compute**, and **Networking**. Each domain is encapsulated in its own reusable module, keeping concerns separated and the root configuration clean.

---

## Project Structure

```
terraform_sentry/
├── main.tf                  # Root module — wires together all child modules
├── variables.tf             # Root-level input variables
├── terraform.tfvars         # Variable value overrides (env-specific config)
└── modules/
    ├── alb/                 # Application Load Balancer module
    │   ├── main.tf
    │   ├── outputs.tf
    │   └── variables.tf
    ├── compute/             # EC2 / compute resource module
    │   ├── main.tf
    │   ├── outputs.tf
    │   └── variables.tf
    └── networking/          # VPC, subnets, routing, security groups
        ├── main.tf
        ├── outputs.tf
        └── variables.tf
```

---

## How It Works

### 1. Root Entry Point (`main.tf` + `terraform.tfvars`)

The root `main.tf` is the orchestration layer. It instantiates each child module and passes values between them — for example, the VPC and subnet IDs created by the **networking** module are forwarded into the **alb** and **compute** modules.

`terraform.tfvars` holds the concrete values for all root-level variables (region, CIDR blocks, instance types, etc.), keeping secrets and environment-specific config out of version control when needed.

---

### 2. Networking Module (`modules/networking/`)

**Provisioned first** — all other modules depend on its outputs.

| File | Purpose |
|---|---|
| `main.tf` | Creates the VPC, public/private subnets, internet gateway, route tables, and security groups |
| `variables.tf` | Accepts inputs such as `vpc_cidr`, `availability_zones`, `environment` |
| `outputs.tf` | Exports `vpc_id`, `subnet_ids`, `security_group_ids` for consumption by other modules |

---

### 3. ALB Module (`modules/alb/`)

Depends on **networking** outputs.

| File | Purpose |
|---|---|
| `main.tf` | Creates the Application Load Balancer, target groups, and HTTP/HTTPS listeners |
| `variables.tf` | Accepts `vpc_id`, `subnet_ids`, `certificate_arn`, and related settings |
| `outputs.tf` | Exports `alb_dns_name`, `target_group_arn` used by the compute module |

---

### 4. Compute Module (`modules/compute/`)

Depends on both **networking** and **alb** outputs.

| File | Purpose |
|---|---|
| `main.tf` | Provisions EC2 instances or Auto Scaling Groups, attaches them to the ALB target group |
| `variables.tf` | Accepts `ami_id`, `instance_type`, `subnet_ids`, `target_group_arn`, `security_group_ids` |
| `outputs.tf` | Exports instance IDs, Auto Scaling Group name, and other compute-layer identifiers |

---

## Prerequisites

- [Terraform](https://developer.hashicorp.com/terraform/downloads) >= 1.3
- AWS credentials configured (`~/.aws/credentials` or environment variables)
- An S3 backend (optional but recommended for remote state)

---

## Usage

### 1. Clone the repository
```bash
git clone <repo-url>
cd terraform_sentry
```

### 2. Review and edit variable values
```bash
cp terraform.tfvars terraform.tfvars.local   # optional: keep a local override
vi terraform.tfvars
```

### 3. Initialise Terraform
```bash
terraform init
```

### 4. Preview the execution plan
```bash
terraform plan
```

### 5. Apply the infrastructure
```bash
terraform apply
```

### 6. Destroy when done
```bash
terraform destroy
```

---

## Key Variables

| Variable | Description | Example |
|---|---|---|
| `region` | AWS region to deploy into | `ap-south-1` |
| `environment` | Deployment environment tag | `dev`, `staging`, `prod` |
| `vpc_cidr` | CIDR block for the VPC | `10.0.0.0/16` |
| `instance_type` | EC2 instance size | `t3.micro` |
| `ami_id` | AMI to launch compute instances from | `ami-0abcdef1234567890` |

> Full variable definitions and descriptions live in each module's `variables.tf`.

---

## Outputs

After a successful `apply`, Terraform prints the root outputs defined in `main.tf`, which typically include:

- `alb_dns_name` — the public DNS of the load balancer
- `vpc_id` — the created VPC identifier
- Instance or ASG identifiers from the compute layer

---

## Module Isolation

Each module is fully self-contained:
- **`variables.tf`** — declares what the module needs (inputs)
- **`main.tf`** — defines the resources
- **`outputs.tf`** — declares what the module exposes (outputs)

This means any module can be tested or reused independently by pointing to it directly with a `module` block and supplying its required variables.
