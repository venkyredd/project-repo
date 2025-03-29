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

# 🔹 EC2 INSTANCE FOR BACKEND
resource "aws_instance" "backend_ec2" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.backend_sg.id]

  tags = {
    Name = "backend-server"
  }
}

# 🔹 S3 BUCKET FOR FRONTEND
resource "aws_s3_bucket" "frontend" {
  bucket = var.s3_bucket_name
}

resource "aws_s3_bucket_public_access_block" "frontend_access" {
  bucket = aws_s3_bucket.frontend.id
  block_public_acls   = false
  block_public_policy = false
}

# 🔹 CLOUDFRONT FOR S3
resource "aws_cloudfront_distribution" "cdn" {
  origin {
    domain_name = aws_s3_bucket.frontend.bucket_regional_domain_name
    origin_id   = "S3-Origin"
  }

  enabled = true

  default_cache_behavior {
    target_origin_id       = "S3-Origin"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
}

# 🔹 ECS CLUSTER (For Future Fargate Deployments)
resource "aws_ecs_cluster" "ecs_cluster" {
  name = var.ecs_cluster_name
}

# 🔹 ECS SERVICE
resource "aws_ecs_service" "ecs_service" {
  name            = var.ecs_service_name
  cluster         = aws_ecs_cluster.ecs_cluster.id
  desired_count   = 1
  launch_type     = "FARGATE"
}

# 🔹 IAM ROLE FOR GITHUB ACTIONS
resource "aws_iam_role" "github_actions_role" {
  name = "github-actions-role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::ACCOUNT-ID-WITH-OPENID-CONNECT"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

# 🔹 ATTACH POLICY TO IAM ROLE (More Secure than Admin)
resource "aws_iam_role_policy_attachment" "github_actions_policy" {
  role       = aws_iam_role.github_actions_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2FullAccess"
}
