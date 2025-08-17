terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.9.0"
    }
  }
  required_version = "~> 1.12.2"
}

provider "aws" {
  region  = var.region
  profile = var.aws_profile
}

# Data sources
data "aws_ami" "ubuntu" {
  most_recent = true
  filter {
    name   = "name"
    values = [var.instance_settings.ec2.ami_filter]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
  owners = ["099720109477"] # Canonical
}

data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_vpc" "app_vpc" {
  cidr_block           = var.vpc_cidr_block
  enable_dns_hostnames = true
}

resource "aws_internet_gateway" "app_igw" {
  vpc_id = aws_vpc.app_vpc.id
}

# Public subnet for EC2
resource "aws_subnet" "app_public_subnet" {
  vpc_id                  = aws_vpc.app_vpc.id
  cidr_block              = "10.0.0.0/24"
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true
}

# Private subnets for RDS
# RDS requires multiple AZs so we need two subnets even when only using one instance
resource "aws_subnet" "app_private_subnet_1" {
  vpc_id            = aws_vpc.app_vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = data.aws_availability_zones.available.names[0]
}

resource "aws_subnet" "app_private_subnet_2" {
  vpc_id            = aws_vpc.app_vpc.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = data.aws_availability_zones.available.names[1]
}

# Public route table
resource "aws_route_table" "app_public_rt" {
  vpc_id = aws_vpc.app_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.app_igw.id
  }
}

resource "aws_route_table_association" "public" {
  route_table_id = aws_route_table.app_public_rt.id
  subnet_id      = aws_subnet.app_public_subnet.id
}

# Is this even needed?
#resource "aws_route_table" "app_private_rt" {
#  vpc_id = aws_vpc.app_vpc.id
#}
#
#resource "aws_route_table_association" "private1" {
#  route_table_id = aws_route_table.app_private_rt.id
#  subnet_id      = aws_subnet.app_private_subnet_1.id
#}
#
#resource "aws_route_table_association" "private2" {
#  route_table_id = aws_route_table.app_private_rt.id
#  subnet_id      = aws_subnet.app_private_subnet_2.id
#}

# Security group for EC2
resource "aws_security_group" "app_ec2_sg" {
  name        = "app_ec2_sg"
  description = "Security group for web server"
  vpc_id      = aws_vpc.app_vpc.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${var.my_ip}/32"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Security group for RDS
resource "aws_security_group" "app_rds_sg" {
  name        = "app_rds_sg"
  description = "Security group for database"
  vpc_id      = aws_vpc.app_vpc.id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.app_ec2_sg.id]
  }
}

resource "aws_db_subnet_group" "app_db_subnet_group" {
  name       = "app_db_subnet_group"
  subnet_ids = [aws_subnet.app_private_subnet_1.id, aws_subnet.app_private_subnet_2.id]
}

resource "aws_db_instance" "app_rds" {
  allocated_storage      = var.instance_settings.rds.allocated_storage
  max_allocated_storage  = var.instance_settings.rds.max_allocated_storage
  storage_type           = var.instance_settings.rds.storage_type
  engine                 = var.instance_settings.rds.engine
  engine_version         = var.instance_settings.rds.engine_version
  instance_class         = var.instance_settings.rds.instance_class
  skip_final_snapshot    = var.instance_settings.rds.skip_final_snapshot
  db_name                = var.instance_settings.rds.db_name
  username               = var.db_username
  password               = var.db_password
  db_subnet_group_name   = aws_db_subnet_group.app_db_subnet_group.id
  vpc_security_group_ids = [aws_security_group.app_rds_sg.id]
}

resource "aws_key_pair" "deployer" {
  key_name   = "deployer-key"
  public_key = file(var.ssh_pub_key)
}

resource "aws_instance" "app_ec2" {
  ami                    = data.aws_ami.ubuntu.id
  key_name               = aws_key_pair.deployer.key_name
  instance_type          = var.instance_settings.ec2.instance_type
  subnet_id              = aws_subnet.app_public_subnet.id
  vpc_security_group_ids = [aws_security_group.app_ec2_sg.id]
  user_data_base64 = base64encode(templatefile("${path.module}/scripts/provision_ec2.sh",
    {
      github_repo  = var.github_repo
      github_token = var.github_token
      git_branch   = var.git_branch
      db_username  = var.db_username
      db_password  = var.db_password
      db_name      = var.instance_settings.rds.db_name
      db_host      = aws_db_instance.app_rds.address
  }))
}
