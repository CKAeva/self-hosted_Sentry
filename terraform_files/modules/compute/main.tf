locals {
  instance_type = var.instance_type_map[var.env_name]
  ami_id        = var.ami_map[var.region]

  bastion_subnet = values(var.public_subnet_ids)[0]
  private_subnet = values(var.private_subnet_ids)[0]
}

resource "aws_instance" "bastion" {
  ami                         = local.ami_id
  instance_type               = "t3.medium"
  subnet_id                   = local.bastion_subnet
  vpc_security_group_ids      = [var.public_sg_id]
  associate_public_ip_address = true
  key_name                    = var.key_name

  user_data = <<-EOF
              #!/bin/bash
              yum update -y
              echo "Bastion Host Ready" > /home/ec2-user/info.txt
              EOF

  root_block_device {
    volume_size = 50
    volume_type = "gp3"
  }

  tags = {
    Name = "tera-${var.project_name}-bastion"
    Environment = var.env_name
  }
}

resource "aws_instance" "private" {
  ami                    = local.ami_id
  instance_type          = local.instance_type
  subnet_id              = local.private_subnet
  vpc_security_group_ids = [var.private_sg_id]
  key_name               = var.key_name

  user_data = <<-EOF
              #!/bin/bash
              yum update -y
              yum -y install python3.11 git python3.11-pip gcc
              pip3.11 install pywinrm ansible
              mkdir -p /opt/ansible/inventory /opt/ansible/scripts

              echo "[defaults]
              remote_tmp = /tmp/.ansible
              host_key_checking = False
              inventory = /opt/ansible/inventory/hosts
              vault_password_file = /opt/ansible/scripts/passwd
              [inventory]
              enable_plugins = host_list, script, auto, yaml, ini, toml
              " > /root/.ansible.cfg

              # ======= SSH CONFIGURATION =======
    
              # Backup existing sshd configuration
              cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak
    
              # Ensure password authentication is enabled
              sed -i 's/^PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config
              sed -i 's/^#PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config
    
              # Add/ensure required SSH parameters
              grep -qxF 'RSAAuthentication yes' /etc/ssh/sshd_config || echo 'RSAAuthentication yes' >> /etc/ssh/sshd_config
              grep -qxF 'GSSAPIAuthentication yes' /etc/ssh/sshd_config || echo 'GSSAPIAuthentication yes' >> /etc/ssh/sshd_config
              grep -qxF 'PubkeyAuthentication yes' /etc/ssh/sshd_config || echo 'PubkeyAuthentication yes' >> /etc/ssh/sshd_config
              grep -qxF 'PermitRootLogin yes' /etc/ssh/sshd_config || echo 'PermitRootLogin yes' >> /etc/ssh/sshd_config
              grep -qxF 'UseDNS no' /etc/ssh/sshd_config || echo 'UseDNS no' >> /etc/ssh/sshd_config
    
              # Also modify cloud-init SSH override if it exists
              if [ -f /etc/ssh/sshd_config.d/50-cloud-init.conf ]; then
                sed -i 's/^PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config.d/50-cloud-init.conf
                sed -i 's/^#PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config.d/50-cloud-init.conf
              fi
    
              sudo sed -i 's/^SELINUX=enforcing/SELINUX=permissive/' /etc/selinux/config
              sudo setenforce 0
              # Restart SSH service
              systemctl restart sshd

              echo "Private App Server" > /home/ec2-user/app.txt
              EOF

  root_block_device {
    volume_size = var.root_volume_size
    volume_type = "gp3"
  }

  tags = {
    Name = "tera-${var.project_name}-sentry"
    Environment = var.env_name
  }
}

