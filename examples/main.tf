locals {
    app = "shaneschambers"
    env = "dev"
    service = "eks"
    region = "us-east-1"
  vpc_name = "${local.env}-${local.app}-vpc"
  cluster_name = "${local.env}-${local.app}-${local.service}-cluster"
  tags ={
    build_number = var.build_number
    created_by = var.created_by
    managed_by = var.managed_by
    "sc.app" = local.app
    "sc.env" = local.env
    "sc.service" = local.service
  }
}

provider "aws" {
  default_tags = local.tags
  region = "${local.region}"
}

data "aws_vpc"  vpc {
    name = local.vpc_name
}

data "aws_subnet" master {
    name = "${local.vpc_name}-public-${local.region}a"
}

data "aws_subnets" public_subnets {
    filter {
        key = "Name"
        values = ["${local.vpc_name}-public-*"]
    }
}


data "aws_subnets" private_subnets {
    filter {
        key = "Name"
        values = ["${local.vpc_name}-private-*"]
    }
}

module "kubernetes" {
  source = "scholzj/kubernetes/aws"

  aws_region           = local.region
  cluster_name         = local.cluster_name
  master_instance_type = "t2.medium"
  worker_instance_type = "t2.medium"
  ssh_public_key       = "~/.ssh/id_rsa.pub"
  ssh_access_cidr      = ["0.0.0.0/0"]
  api_access_cidr      = ["0.0.0.0/0"]
  min_worker_count     = 1
  max_worker_count     = 2
  hosted_zone          = "shaneschambers.com"
  hosted_zone_private  = false
  
  master_subnet_id = data.aws_subnet.master.id
  worker_subnet_ids = tolist(data.aws_subnets.public_subnets.ids)

  # Tags
  tags = local.tags

  # Tags in a different format for Auto Scaling Group
  tags2 = [
    {
      key                 = "build_number"
      value               = var.build_number
      propagate_at_launch = true
    },
    {
      key                 = "created_by"
      value               = var.created_by
      propagate_at_launch = true
    },
    {
      key                 = "managed_by"
      value               = var.managed_by
      propagate_at_launch = true
    },
    {
        key = "app"
        value = loca.app
        propagate_at_launch = true
    },
    {
        key = "env"
        value = local.env
        propagate_at_launch = true
    }
  ]

  addons = [
    "https://raw.githubusercontent.com/scholzj/terraform-aws-kubernetes/master/addons/storage-class.yaml",
    "https://raw.githubusercontent.com/scholzj/terraform-aws-kubernetes/master/addons/csi-driver.yaml",
    "https://raw.githubusercontent.com/scholzj/terraform-aws-kubernetes/master/addons/metrics-server.yaml",
    "https://raw.githubusercontent.com/scholzj/terraform-aws-kubernetes/master/addons/dashboard.yaml",
    "https://raw.githubusercontent.com/scholzj/terraform-aws-kubernetes/master/addons/external-dns.yaml",
    "https://raw.githubusercontent.com/scholzj/terraform-aws-kubernetes/master/addons/autoscaler.yaml",
  ]
}

