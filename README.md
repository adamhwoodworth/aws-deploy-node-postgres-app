# aws-deploy-node-app

Deploy a Node.js & PostgreSQL app into the AWS cloud. Suitable for dev/sandbox work.

Creates an EC2 instance, RDS Postgres database, and appropriate VPC, subnets, and gateway.

The end result is that you have a node web app running at port 3000 on the EC2 instance, and it can connect to the Postgres database.

## Setup

* Install Terraform (https://developer.hashicorp.com/)
* Schema files should be in `sys/sql/schema` in your repo.
* Copy `terraform.tfvars.sample` to `terraform.tvfars` and update as appropriate.

## Deploy

```
terraform init
terraform apply
```

## Limitations

* Currently hardcoded to use port 3000.
* Single AZ only database.
* No auto-scaling for EC2.
* Not meant for production use.
