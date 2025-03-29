provider "aws" {
  region = var.aws_region
}

# 🔹 VARIABLES
variable "aws_region" { default = "ap-south-1" }
variable "s3_bucket_name" {}
variable "key_name" {}
variable "ecs_cluster_name" {}
variable "ecs_service_name" {}
variable "ami_id" {}
variable "instance_type" {}
variable "vpc_id" {}

# 🔹 SECURITY GROUP (Allow Port 3000 for Backend)
resource "aws_security_group" "backend_sg" {
  name        = "backend-security-group"
  description = "Allow inbound traffic on port 3000"
  vpc_id      = var.vpc_id  

  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# 🔹 EC2 INSTANCE FOR BACKEND (With Docker Setup)
resource "aws_instance" "backend_ec2" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.backend_sg.id]

  # 🔹 Install Docker & Start the Container
  user_data = <<-EOF
    #!/bin/bash
    sudo apt update -y
    sudo apt install -y docker.io git
    sudo systemctl start docker
    sudo systemctl enable docker
    sudo usermod -aG docker ubuntu

    # Create backend directory
    mkdir -p /home/ubuntu/backend
    cd /home/ubuntu/backend

    # Clone your repository (Modify the repo URL)
    git clone https://github.com/YOUR_GITHUB_USER/YOUR_BACKEND_REPO.git .

    # Build and run the container
    docker build -t backend-app .
    docker run -d -p 3000:3000 backend-app
  EOF

  tags = {
    Name = "backend-server"
  }
}
