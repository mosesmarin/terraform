# 
# Purpose: Create two region Aurora DB
# Configuration:  no final snapshot, no encryption, 2 host in primary region, 1 host in secondary region, 1 security group
# 
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

variable "sec_vpc_id" {
  type = string
}

variable "pri_eks_security_group_id" {
}

variable "sec_eks_security_group_id" {
}

variable "pri_subnet_ids" {
  type = list(string)
}

variable "sec_subnet_ids" {
  type = list(string)
}

variable "pri_instance_count" {
  type = number
}

variable "sec_instance_count" {
  type = number
}

variable "cluster_name" {
}

variable "pri_dba_security_group_id" {
}

variable "sec_dba_security_group_id" {
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

variable "sec_az_list" {
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
  name        = "${var.product_name}-${var.env}-eks"
  vpc_id      = var.pri_vpc_id

  ingress {
    description = "Allow EKS access"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    security_groups = [
    var.pri_eks_security_group_id]
  }


  tags = {
    Name = "allow_mysql_from_EKS"
  }

}


resource "aws_db_subnet_group" "pri_db_subnet_group" {
  provider    = aws.primary
  name        = "${var.product_name}-${var.env}"
  description = "${var.product_name}-${var.env}-subnetgroup"
  subnet_ids  = var.pri_subnet_ids

}

resource "aws_rds_cluster_parameter_group" "pri_rdsparagroup" {
  provider = aws.primary
  name     = "aurora116-${var.product_name}-${var.env}"
  family   = "aurora-postgresql11"

  parameter {
    name         = "shared_preload_libraries"
    value        = "auto_explain,pg_stat_statements,pg_hint_plan,pgaudit"
    apply_method = "pending-reboot"
  }
  parameter {
    name  = "log_statement"
    value = "ddl"
  }
  parameter {
    name  = "log_connections"
    value = "1"

  }
  parameter {
    name  = "log_disconnections"
    value = "1"

  }
  parameter {
    name  = "log_lock_waits"
    value = "1"

  }
  parameter {
    name  = "log_min_duration_statement"
    value = "5000"

  }
  parameter {
    name  = "auto_explain.log_min_duration"
    value = "5000"

  }
  parameter {
    name  = "auto_explain.log_verbose"
    value = "1"

  }
  parameter {
    name  = "log_rotation_age"
    value = "1440"

  }
  parameter {
    name  = "log_rotation_size"
    value = "102400"

  }
  parameter {
    name  = "rds.log_retention_period"
    value = "10080"

  }
  parameter {
    name  = "random_page_cost"
    value = "1"
  }
  parameter {
    name         = "track_activity_query_size"
    value        = "16384"
    apply_method = "pending-reboot"

  }
  parameter {
    name  = "idle_in_transaction_session_timeout"
    value = "7200000"

  }
  parameter {
    name  = "statement_timeout"
    value = "7200000"

  }

  parameter {
    name  = "search_path"
    value = "\"$user\",public"

  }


}

resource "aws_rds_global_cluster" "global_cluster" {
  provider                  = aws.primary
  global_cluster_identifier = var.cluster_name
  engine                    = "aurora-postgresql"
  engine_version            = "11.7"
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
    "postgresql"
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

###############################################################################
# secondary site                                                              #
###############################################################################

resource "aws_security_group" "sec_rds_sg" {
  provider    = aws.secondary
  description = "${var.product_name}-${var.env}-sg"
  name        = "${var.product_name}-${var.env}-eks"
  vpc_id      = var.sec_vpc_id

  ingress {
    description = "Allow EKS access"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    security_groups = [
    var.sec_eks_security_group_id]
  }

  tags = {
    Name = "allow_mysql_from_EKS"
  }

}


resource "aws_db_subnet_group" "sec_db_subnet_group" {
  provider    = aws.secondary
  name        = "${var.product_name}-${var.env}"
  description = "${var.product_name}-${var.env}-subnetgroup"
  subnet_ids  = var.sec_subnet_ids

}

resource "aws_rds_cluster_parameter_group" "sec_rdsparagroup" {
  provider = aws.secondary
  name     = "aurora116-${var.product_name}-${var.env}"
  family   = "aurora-postgresql11"

  parameter {
    name         = "shared_preload_libraries"
    value        = "auto_explain,pg_stat_statements,pg_hint_plan,pgaudit"
    apply_method = "pending-reboot"
  }
  parameter {
    name  = "log_statement"
    value = "ddl"
  }
  parameter {
    name  = "log_connections"
    value = "1"

  }
  parameter {
    name  = "log_disconnections"
    value = "1"

  }
  parameter {
    name  = "log_lock_waits"
    value = "1"

  }
  parameter {
    name  = "log_min_duration_statement"
    value = "5000"

  }
  parameter {
    name  = "auto_explain.log_min_duration"
    value = "5000"

  }
  parameter {
    name  = "auto_explain.log_verbose"
    value = "1"

  }
  parameter {
    name  = "log_rotation_age"
    value = "1440"

  }
  parameter {
    name  = "log_rotation_size"
    value = "102400"

  }
  parameter {
    name  = "rds.log_retention_period"
    value = "10080"

  }
  parameter {
    name  = "random_page_cost"
    value = "1"
  }
  parameter {
    name         = "track_activity_query_size"
    value        = "16384"
    apply_method = "pending-reboot"

  }
  parameter {
    name  = "idle_in_transaction_session_timeout"
    value = "7200000"

  }
  parameter {
    name  = "statement_timeout"
    value = "7200000"

  }

  parameter {
    name  = "search_path"
    value = "\"$user\",public"

  }


}

resource "aws_rds_cluster" "secondary" {
  provider = aws.secondary
  depends_on = [
    aws_rds_cluster_instance.primary
  ]
  global_cluster_identifier = aws_rds_global_cluster.global_cluster.id
  source_region             = "us-east-1"
  db_subnet_group_name      = aws_db_subnet_group.sec_db_subnet_group.id
  vpc_security_group_ids = [
    aws_security_group.sec_rds_sg.id,
    var.sec_dba_security_group_id
  ]
  cluster_identifier = "${var.cluster_name}-secondary"
  engine             = aws_rds_global_cluster.global_cluster.engine
  engine_version     = aws_rds_global_cluster.global_cluster.engine_version
  engine_mode        = "provisioned"

  db_cluster_parameter_group_name = aws_rds_cluster_parameter_group.sec_rdsparagroup.id
  storage_encrypted               = false
  #  final_snapshot_identifier       = "${var.cluster_name}-secondary-final"
  skip_final_snapshot = true
  deletion_protection = false
  enabled_cloudwatch_logs_exports = [
    "postgresql"
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

resource "aws_rds_cluster_instance" "secondary" {
  provider                   = aws.secondary
  cluster_identifier         = aws_rds_cluster.secondary.id
  count                      = var.sec_instance_count
  availability_zone          = var.sec_az_list[count.index]
  identifier                 = "${aws_rds_cluster.secondary.cluster_identifier}-inst-${count.index}"
  instance_class             = var.instance_class
  engine                     = aws_rds_cluster.secondary.engine
  auto_minor_version_upgrade = true
  apply_immediately          = true

}

###############################################################################
# output vars                                                                 #
###############################################################################


output "primary_cluster_arn" {
	value = aws_rds_cluster.primary.arn
}

output "primary_cluster_endpoint" {
	value = aws_rds_cluster.primary.endpoint
}

output "primary_cluster_endpoint_reader" {
	value = aws_rds_cluster.primary.reader_endpoint
}

output "secondary_cluster_arn" {
	value = aws_rds_cluster.secondary.arn
}

output "secondary_cluster_endpoint" {
	value = aws_rds_cluster.secondary.endpoint
}

output "secondary_cluster_endpoint_reader" {
	value = aws_rds_cluster.secondary.reader_endpoint
}

output "master_username" {
	value = var.username
}

output "master_password" {
	value = var.password
}