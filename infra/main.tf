provider "aws" {
  region = var.aws_region
}

variable "aws_region" {
  default = "ap-south-1"
}

variable "s3_bucket_name" {}
variable "key_name" {}
variable "ecs_cluster_name" {}
variable "ecs_service_name" {}
variable "ami_id" {}
variable "instance_type" {}
variable "vpc_id" {}

# 🔹 Security Group for Backend EC2 (Allows port 3000)
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

# 🔹 S3 Bucket for Frontend Hosting
resource "aws_s3_bucket" "frontend" {
  bucket = var.s3_bucket_name
}

resource "aws_s3_bucket_public_access_block" "frontend" {
  bucket = aws_s3_bucket.frontend.id
  block_public_acls   = false
  block_public_policy = false
}

# 🔹 CloudFront for S3
resource "aws_cloudfront_distribution" "cdn" {
  origin {
    domain_name = aws_s3_bucket.frontend.bucket_regional_domain_name
    origin_id   = "S3-Origin"
  }
  enabled = true
  default_cache_behavior {
    viewer_protocol_policy = "redirect-to-https"
  }
}

# 🔹 EC2 Instance for Backend (With Security Group Attached)
resource "aws_instance" "ec2_backend" {
  ami           = var.ami_id
  instance_type = var.instance_type
  key_name      = var.key_name
  security_groups = [aws_security_group.backend_sg.name]  

  tags = {
    Name = "backend-server"
  }
}

# 🔹 ECS Cluster
resource "aws_ecs_cluster" "ecs_cluster" {
  name = var.ecs_cluster_name
}

# 🔹 ECS Service
resource "aws_ecs_service" "ecs_service" {
  name            = var.ecs_service_name
  cluster         = aws_ecs_cluster.ecs_cluster.id
  desired_count   = 1
  launch_type     = "FARGATE"
}

# 🔹 IAM Role for GitHub Actions
resource "aws_iam_role" "github_actions_role" {
  name = "github-actions-role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::aws:policy/AdministratorAccess"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

# 🔹 Attach Policies to Role
resource "aws_iam_role_policy_attachment" "github_actions_policy" {
  role       = aws_iam_role.github_actions_role.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}
