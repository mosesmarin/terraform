# 
# Purpose: Create single region Aurora DB, no final snapshot, no encryption
#  

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 2.70"
    }
  }
}

variable "product_name" {
}

variable "env" {
  type = string
}

variable "pri_vpc_id" {
  type = string
}

variable "pri_eks_security_group_id" {
}

variable "pri_subnet_ids" {
  type = list(string)
}

variable "pri_instance_count" {
  type = number
}

variable "cluster_name" {
}

variable "pri_dba_security_group_id" {
}

variable "username" {
  type = string
}

variable "password" {
  type = string
}

variable "owner" {
  type = string
}

variable "env_tag" {
  type = string
}

variable "instance_class" {
  type = string
}

variable "pri_az_list" {
  description = "list of Availability Zones"
  type        = list(string)


}

provider "aws" {
  alias  = "primary"
  region = "us-east-1"
}

provider "aws" {
  alias  = "secondary"
  region = "us-west-2"
}

###############################################################################
# primary site                                                                #
###############################################################################

resource "aws_security_group" "pri_rds_sg" {
  provider    = aws.primary
  description = "${var.product_name}-${var.env}-sg"
  name = "${var.product_name}-${var.env}-eks"
  vpc_id      = var.pri_vpc_id

  ingress {
    description = "Allow EKS access"
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    security_groups = [
    var.pri_eks_security_group_id]
  }

  egress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    cidr_blocks = [
    "0.0.0.0/0"]
  }

  tags = {
    Name = "allow_mysql_from_EKS"
  }

}


resource "aws_db_subnet_group" "pri_db_subnet_group" {
  provider   = aws.primary
  name       = "${var.product_name}-${var.env}"
  description       = "${var.product_name}-${var.env}-subnetgroup"
  subnet_ids = var.pri_subnet_ids

}

resource "aws_rds_cluster_parameter_group" "pri_rdsparagroup" {
  provider = aws.primary
  name     = "aurora57-${var.product_name}-${var.env}"
  family   = "aurora-mysql5.7"

  parameter {
    name  = "slow_query_log"
    value = "1"
  }
  parameter {
    name  = "general_log"
    value = "1"
  }
  parameter {
    name  = "server_audit_logging"
    value = "1"
  }
  parameter {
    name  = "server_audit_logs_upload"
    value = "1"
  }

}

resource "aws_rds_global_cluster" "global_cluster" {
  provider                  = aws.primary
  global_cluster_identifier = var.cluster_name
  engine                    = "aurora-mysql"
  engine_version            = "5.7.mysql_aurora.2.08.1"
  storage_encrypted         = false
}

resource "aws_rds_cluster" "primary" {
  provider             = aws.primary
  db_subnet_group_name = aws_db_subnet_group.pri_db_subnet_group.id
  vpc_security_group_ids = [
    aws_security_group.pri_rds_sg.id,
    var.pri_dba_security_group_id
  ]

  cluster_identifier              = "${var.cluster_name}-primary"
  engine                          = aws_rds_global_cluster.global_cluster.engine
  engine_version                  = aws_rds_global_cluster.global_cluster.engine_version
  engine_mode                     = "provisioned"
  global_cluster_identifier       = aws_rds_global_cluster.global_cluster.id
  db_cluster_parameter_group_name = aws_rds_cluster_parameter_group.pri_rdsparagroup.id
  master_username                 = var.username
  master_password                 = var.password
  storage_encrypted               = false
  #  final_snapshot_identifier       = "${var.cluster_name}-primary-final"
  skip_final_snapshot = true
  deletion_protection = false
  enabled_cloudwatch_logs_exports = [
    "general",
    "slowquery",
    "error",
    "audit"
  ]
  backup_retention_period      = 35
  preferred_backup_window      = "07:00-09:00"
  preferred_maintenance_window = "sun:09:00-sun:11:00"
  tags = {
    Owner       = var.owner,
    environment = var.env_tag,
    application = var.product_name,
    team        = "DatabaseAdmins"
    deployed_by = "DatabaseAdmins using Terraform"
  }
}

resource "aws_rds_cluster_instance" "primary" {
  provider                   = aws.primary
  count                      = var.pri_instance_count
  availability_zone          = var.pri_az_list[count.index]
  identifier                 = "${aws_rds_cluster.primary.cluster_identifier}-inst-${count.index}"
  cluster_identifier         = aws_rds_cluster.primary.id
  instance_class             = var.instance_class
  engine                     = aws_rds_cluster.primary.engine
  auto_minor_version_upgrade = true
  apply_immediately          = true


}


