provider "aws" {
  region = "us-east-1"
}

resource "tls_private_key" "this" {
  algorithm = "RSA"
}

module "key_pair" {
  source = "terraform-aws-modules/key-pair/aws"

  key_name   = "jmails-key-pair"
  public_key = file("~/.ssh/jmail_key_pair.pub")
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.1.2"

  name = var.vpc_name
  cidr = var.vpc_cidr

  azs             = var.vpc_azs
  private_subnets = var.vpc_private_subnets
  public_subnets  = var.vpc_public_subnets

  enable_nat_gateway = var.vpc_enable_nat_gateway

  tags = var.vpc_tags
}

module "security_group" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "5.1.0"

  name        = "jmails-sg"
  description = "Jmails security group"
  vpc_id      = module.vpc.vpc_id

  ingress_cidr_blocks = ["0.0.0.0/0"]
  ingress_rules       = ["all-all"]
  egress_rules        = ["all-all"]
}

module "ec2_instances" {
  source  = "terraform-aws-modules/ec2-instance/aws"
  version = "5.6.0"

  count = 2
  name  = "my-ec2-cluster-${count.index}"

  ami                         = "ami-0005e0cfe09cc9050"
  instance_type               = "t2.micro"
  vpc_security_group_ids      = [module.security_group.security_group_id]
  subnet_id                   = module.vpc.public_subnets[0]
  key_name                    = module.key_pair.key_pair_name
  associate_public_ip_address = true


  tags = {
    Terraform   = "true"
    Environment = "dev"
  }

  user_data = <<-EOF
  #!/bin/bash
  sudo yum update -y
  sudo yum install docker -y
  sudo service docker start
  sudo usermod -a -G docker ec2-user
  EOF
}
