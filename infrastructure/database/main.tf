
###
# Variables
###
variable "vpc_id" {
  type = string
  description = "ID of the VPC in which is located the db"
}

variable "subnet_ids" {
  type = list(string)
  description = "Subnet ids associated to the db cluster"
}

variable "master_password" {
  description = "Master password for the Aurora serverless DB"
  type        = string
  sensitive   = true
}

variable "eks_cluster_security_group_id" {
  description = "Security group id of the EKS cluster to allow connection from sonarqube to the database"
  type        = string
}

variable "environment" {
  description = "The environment the db cluster will be deployed into"
  type        = string
}

###
# Local variables that you can change regarding your needs
###
locals {
  dbsubnetgroup_name           = "sonarqube-${var.environment}-database-dbsubnetgroup"
  dbcluster_name               = "sonarqube-${var.environment}-database-cluster"
  dbcluster_initialdb_name     = "sonarqube"
  dbcluster_postgres_version   = "10.12"
  dbcluster_finalsnapshot_name = "sonarqube-${var.environment}-database-finalsnapshot"
  dbcluster_master_username    = "sonarqube"
  dbcluster_max_acu            = 16
  dbcluster_min_acu            = 2
  dbcluster_securitygroup_name = "sonarqube-${var.environment}-database-securitygroup"
  dbcluster_postgresql_port    = 5432
}

###
# Resources
###

# The db subnet group that will be associated to the cluster
resource "aws_db_subnet_group" "sonarqube" {
  name = local.dbsubnetgroup_name
  subnet_ids = var.subnet_ids # Associate the subnets
  description = "DB Subnet group for sonarqube"
}

# The actual database cluster
resource "aws_rds_cluster" "sonarqube" {
  backup_retention_period   = 7
  cluster_identifier        = local.dbcluster_name # Name of the cluster
  copy_tags_to_snapshot     = true # Tag snapshots with cluster tags
  database_name             = local.dbcluster_initialdb_name # Name of the database initially created
  deletion_protection       = true # Enabled for safety
  db_subnet_group_name      = aws_db_subnet_group.sonarqube.name # Name of the associated subnet group
  engine_mode               = "serverless" # To choose serverless database
  engine_version            = local.dbcluster_postgres_version # The version of the postgres engine. Now, only 10.12 is available
  engine                    = "aurora-postgresql" # To select aurora with postgres compatibilityt
  final_snapshot_identifier = local.dbcluster_finalsnapshot_name # Name of the snapshot created on cluster deletion
  master_password           = var.master_password # Password of the master user
  master_username           = local.dbcluster_master_username # Name of the master user
  port                      = local.dbcluster_postgresql_port # Cluster listening port

  scaling_configuration {
    max_capacity             = local.dbcluster_max_acu # Minimum cluster capacity
    min_capacity             = local.dbcluster_min_acu # Maximum cluster capacity
    timeout_action           = "RollbackCapacityChange" # Not set to "ForceApplyCapacityChange" to prevent trasactions aborts and temporary table deletions
  }
  storage_encrypted = true # Always encrypt :D

  depends_on             = [aws_db_subnet_group.sonarqube]
  vpc_security_group_ids = [aws_security_group.db_security_group.id] # Associate the security group created, to the cluster
}


# The security group that will be associated to the cluster
resource "aws_security_group" "db_security_group" {
  name        = local.dbcluster_securitygroup_name # Name of the sg
  description = "Security group for sonarqube database cluster"
  vpc_id      = var.vpc_id # The same VPC as the subnets of the cluster

  # Enable traffic coming from the EKS cluster, only on TCP to the listening port of the DB cluster
  ingress {
    description = "Ingress to Postgre database from cluster"
    from_port   = local.dbcluster_postgresql_port
    protocol    = "tcp"
    to_port     = local.dbcluster_postgresql_port
    security_groups = [var.eks_cluster_security_group_id]
  }
}
