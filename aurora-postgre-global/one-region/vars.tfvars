
product_name              = "aaaa"
env                       = "dev"
pri_vpc_id                = "vpc-9f9b25e5"
pri_eks_security_group_id = "sg-0809277d718934c83"
pri_subnet_ids            = ["subnet-173e5370", "subnet-1bfa9335"]
cluster_name              = "aurorapostgre01"
pri_instance_count        = 1
pri_dba_security_group_id = ""
username                  = "dbausername"
password                  = "dbapassword"
owner                     = "DBAdmins"
env_tag                   = "development"
instance_class            = "db.r5.large"
pri_az_list               = ["us-east-1a", "us-east-1b"]