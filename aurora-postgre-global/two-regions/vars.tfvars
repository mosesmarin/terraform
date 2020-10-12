# Primary
product_name              = "aaaa"
env                       = "dev"
pri_vpc_id                = "vpc-9f9b25e5"
pri_eks_security_group_id = "sg-0809277d718934c83"
pri_subnet_ids            = ["subnet-173e5370", "subnet-1bfa9335"]
cluster_name              = "aurorapostgretworegions01"
pri_instance_count        = 2
pri_dba_security_group_id = ""
username                  = "dbausername"
password                  = "dbapassword"
owner                     = "DBAdmins"
env_tag                   = "development"
instance_class            = "db.r5.large"
pri_az_list               = ["us-east-1a", "us-east-1b"]

# Secondary
sec_vpc_id                = "vpc-99fc24e1"
sec_eks_security_group_id = "sg-054c5b740f8330e68"
sec_subnet_ids            = ["subnet-b44570cd", "subnet-7cd68137"]
sec_instance_count        = 1
sec_dba_security_group_id = ""
sec_az_list               = ["us-west-2a"]