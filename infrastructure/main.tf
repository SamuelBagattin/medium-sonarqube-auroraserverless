module "database" {
  source = "./database"
  eks_cluster_security_group_id = "sg-00112233bb44cc919"
  environment = "stage"
  master_password = var.database_password
  subnet_ids = ["subnet-80a6033cd","subnet-00a3066ff","subnet-11a4022mm"]
  vpc_id = "vpc-c50f19ac"
}

variable "database_password" {
  description = "Password to access the database"
  type = string
}
