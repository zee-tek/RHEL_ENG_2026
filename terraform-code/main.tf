terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

# 1. Key generation for lab infrastructure and student user
resource "tls_private_key" "lab_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "tls_private_key" "student_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "aws_deploy_key" {
  key_name   = "rhcsa-ansible-lab"
  public_key = tls_private_key.lab_key.public_key_openssh
}

# 2. Automate writing the deployment key directly to your VirtualBox machine
resource "local_file" "local_ssh_key" {
  content         = tls_private_key.lab_key.private_key_pem
  filename        = "${path.module}/rhcsa-ansible-lab.pem"
  file_permission = "0400"
}

# 3. Global Lab Security Group
resource "aws_security_group" "lab_sg" {
  name        = "ansible-lab-security-group"
  description = "Allow inbound SSH, HTTP, and internal VPC communication"

  ingress {
    description = "SSH from anywhere"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP traffic from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow all intra-VPC traffic natively"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self        = true
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# 4. Managed Nodes Configuration
variable "node_names" {
  type    = list(string)
  default = ["servera", "serverb", "serverc"]
}

resource "aws_instance" "managed_nodes" {
  count                  = length(var.node_names)
  ami                    = "ami-0583d8c7a9c35822c" # RHEL 9
  instance_type          = "t3.micro"
  key_name               = aws_key_pair.aws_deploy_key.key_name
  vpc_security_group_ids = [aws_security_group.lab_sg.id]

  user_data = <<-EOF
              #!/bin/bash
              setenforce 0
              sed -i 's/SELINUX=enforcing/SELINUX=permissive/g' /etc/selinux/config
              useradd -m -s /bin/bash ansi_user
              echo "ansi_user ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/ansi_user
              mkdir -p /home/ansi_user/.ssh
              
              # Append both keys so deployment tools AND student can connect natively
              echo "${tls_private_key.lab_key.public_key_openssh}" >> /home/ansi_user/.ssh/authorized_keys
              echo "${tls_private_key.student_key.public_key_openssh}" >> /home/ansi_user/.ssh/authorized_keys
              
              chmod 700 /home/ansi_user/.ssh
              chmod 600 /home/ansi_user/.ssh/authorized_keys
              chown -R ansi_user:ansi_user /home/ansi_user
              systemctl restart sshd
              EOF

  tags = {
    Name = var.node_names[count.index]
  }
}

# 5. Ansible Control Node Configuration
resource "aws_instance" "controller" {
  ami                    = "ami-0583d8c7a9c35822c"
  instance_type          = "t3.small"
  key_name               = aws_key_pair.aws_deploy_key.key_name
  vpc_security_group_ids = [aws_security_group.lab_sg.id]

  user_data = templatefile("${path.module}/controller_bootstrap.tftpl", {
    private_key_pem    = tls_private_key.lab_key.private_key_pem
    public_key_ssh     = tls_private_key.lab_key.public_key_openssh
    student_private    = tls_private_key.student_key.private_key_pem
    student_public     = tls_private_key.student_key.public_key_openssh
    managed_instances = [
      for inst in aws_instance.managed_nodes : {
        name       = inst.tags["Name"]
        private_ip = inst.private_ip
      }
    ]
  })

  tags = {
    Name = "controller"
  }
}
