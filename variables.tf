variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "aws_profile" {
  description = "AWS profile"
  type        = string
}

variable "ssh_pub_key" {
  description = "SSH pub key for EC2 instance"
  type        = string
}

variable "vpc_cidr_block" {
  description = "CIDR block for VPN"
  type        = string
  default     = "10.0.0.0/16"
}

variable "instance_settings" {
  description = "EC2 and RDS instance settings"
  type        = map(any)
  default = {
    "rds" = {
      engine                = "postgres"
      engine_version        = "17.4"
      instance_class        = "db.t3.micro"
      db_name               = "appdb"
      allocated_storage     = 20
      max_allocated_storage = 40
      storage_type          = "gp2"
      skip_final_snapshot   = true
    }
    "ec2" = {
      instance_type = "t3.micro"
      ami_filter    = "ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"
    }
  }
}

variable "db_username" {
  description = "DB master user"
  type        = string
  sensitive   = true
}

variable "db_password" {
  description = "DB master password"
  type        = string
  sensitive   = true
}

variable "my_ip" {
  description = "IP address to allow SSH into EC2"
  type        = string
  sensitive   = true
}

variable "github_repo" {
  description = "GitHub repo, not full URL"
  type        = string
}

variable "github_token" {
  description = "GitHub personal access token"
  type        = string
  sensitive   = true
}

variable "git_branch" {
  description = "git branch to clone"
  type        = string
  default     = "main"
}
