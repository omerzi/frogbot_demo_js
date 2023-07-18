
resource "aws_iam_role" "eks_cluster" {
  count = var.module_enabled ? 1 : 0
  name  = lookup(var.eks_mng_map.override, "eks_cluster_role_name", "${var.deploy_name}-eks-cluster" )

  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "eks.amazonaws.com"
      },
      "Action": "sts:AssumeRole",
      "Sid": "EKSClusterAssumeRole"
    }
  ]
}
POLICY

}

resource "aws_iam_role_policy_attachment" "AmazonEKSClusterPolicy" {
  count      = var.module_enabled ? 1 : 0
  policy_arn = join(":",  ["arn", var.aws_arn, "iam:", "aws:policy/AmazonEKSClusterPolicy"])
  role       = aws_iam_role.eks_cluster[0].name
}

resource "aws_iam_role_policy_attachment" "AmazonEKSServicePolicy" {
  count      = var.module_enabled ? 1 : 0
  policy_arn = join(":",  ["arn", var.aws_arn, "iam:", "aws:policy/AmazonEKSServicePolicy"])
  role       = aws_iam_role.eks_cluster[0].name
}

resource "aws_eks_cluster" "aws_eks" {
  count                     = var.module_enabled ? 1 : 0
  name                      = var.deploy_name
  role_arn                  = aws_iam_role.eks_cluster[0].arn
  enabled_cluster_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
  version                   = lookup(var.eks_mng_map.override, "eks_version", "1.16")

  vpc_config {
    endpoint_private_access = true

    //    endpoint_public_access = false
    public_access_cidrs = lookup(var.eks_mng_map.override, "public_access_cidrs")
    security_group_ids  = lookup(var.eks_mng_map.override, "additional_sg_ids", null)
    subnet_ids          = lookup(var.eks_mng_map.override, "use_secondary_subnets",false) ? var.secondary_subnets : lookup(var.eks_mng_map.override, "subnet_ids", var.subnets)
  }

  dynamic "encryption_config" {
    for_each = contains(keys(var.eks_mng_map.override), "key_arn") ? ["true"] : [var.kms_key_arn]
    content {
      resources = ["secrets"]
      provider {
        key_arn = lookup(var.eks_mng_map.override, "key_arn",var.kms_key_arn)
      }
    }
  }

  tags = {
    Environment = var.environment
  }
}

resource "aws_iam_role" "eks_nodes" {
  count = var.module_enabled ? 1 : 0
  name  = lookup(var.eks_mng_map.override, "eks_nodes_role_name", "${var.deploy_name}-eks-nodes")

  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole",
      "Sid": "EKSWorkerAssumeRole"
    }
  ]
}
POLICY

}

resource "aws_iam_role_policy_attachment" "AmazonEKSWorkerNodePolicy" {
  count      = var.module_enabled ? 1 : 0
  policy_arn = join(":",  ["arn", var.aws_arn, "iam:", "aws:policy/AmazonEKSWorkerNodePolicy" ] )
  role       = aws_iam_role.eks_nodes[0].name
}

resource "aws_iam_role_policy_attachment" "AmazonEKS_CNI_Policy" {
  count      = var.module_enabled ? 1 : 0
  policy_arn = join(":",  ["arn", var.aws_arn, "iam:", "aws:policy/AmazonEKS_CNI_Policy"])
  role       = aws_iam_role.eks_nodes[0].name
}

resource "aws_iam_role_policy_attachment" "AmazonEC2ContainerRegistryReadOnly" {
  count      = var.module_enabled ? 1 : 0
  policy_arn = join(":",  ["arn", var.aws_arn, "iam:", "aws:policy/AmazonEC2ContainerRegistryReadOnly"])
  role       = aws_iam_role.eks_nodes[0].name
}

resource "aws_iam_role_policy_attachment" "CloudWatchAgentServerPolicy" {
  count      = var.pileus_enabled ? 1 : 0
  policy_arn = join(":",  ["arn", var.aws_arn, "iam:", "aws:policy/CloudWatchAgentServerPolicy"])
  role       = aws_iam_role.eks_nodes[0].name
}
##### backend node group (be) paying customers #####
resource "aws_eks_node_group" "backend" {
  count           = contains(keys(var.eks_mng_map), "be")  ? 1 : 0
  subnet_ids      = lookup(var.eks_mng_map.be,"use_secondary_subnets",false) ? var.secondary_subnets : lookup(var.eks_mng_map.be, "subnet_ids", var.subnets)
  cluster_name    = aws_eks_cluster.aws_eks[0].name
  node_group_name = var.eks_mng_map.be.name
  node_role_arn   = aws_iam_role.eks_nodes[0].arn
  ami_type        = "AL2_ARM_64"
  instance_types  = contains(keys(var.eks_mng_map.be), "use_lt") ? null : [lookup(var.eks_mng_map.be, "instance_type")]
  disk_size       = contains(keys(var.eks_mng_map.be), "use_lt") ? null : lookup(var.eks_mng_map.be, "disk_size")

  dynamic "launch_template" {
    for_each = contains(keys(var.eks_mng_map.be), "use_lt")  ? toset([1]) : toset([])

    content {
      name = aws_launch_template.be_template[count.index].name
      version = aws_launch_template.be_template[count.index].latest_version
    }
  }

  scaling_config {
    desired_size = lookup(var.eks_mng_map.be, "desired_size", 1)
    max_size     = lookup(var.eks_mng_map.be, "max_size", 100)
    min_size     = lookup(var.eks_mng_map.be, "min_size", 1)
  }

  dynamic "remote_access" {
    for_each = try(var.eks_mng_map.override["remote_access_sg"], "false") != "false" ? toset([1]) : toset([])

    content {
      ec2_ssh_key = try(var.eks_mng_map.override["key_name"], var.deploy_name)
      source_security_group_ids = lookup(var.eks_mng_map.override, "remote_access_sg")
    }
  }

  # Ensure that IAM Role permissions are created before and deleted after EKS Node Group handling.
  # Otherwise, EKS will not be able to properly delete EC2 Instances and Elastic Network Interfaces.
  depends_on = [
    aws_iam_role_policy_attachment.AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.AmazonEC2ContainerRegistryReadOnly,
  ]
  lifecycle {
    ignore_changes = [scaling_config[0].desired_size]
  }
}


resource "aws_autoscaling_attachment" "aws_eks_node_group_main_tg_attach" {
  count           = lookup(var.eks_mng_map.override, "enable_pl",true)  && var.module_enabled && var.private_link_tg != "" ? 1 : 0
  autoscaling_group_name = aws_eks_node_group.backend[count.index].resources[0].autoscaling_groups[0].name
  alb_target_group_arn   = var.private_link_tg
}

resource "aws_autoscaling_attachment" "aws_eks_node_group_main_tg_attach_plain" {
  count           = lookup(var.eks_mng_map.override, "enable_pl",true) && var.module_enabled && var.private_link_tg != "" ? 1 : 0
  autoscaling_group_name = aws_eks_node_group.backend[count.index].resources[0].autoscaling_groups[0].name
  alb_target_group_arn   = var.private_link_tg_plain
}

##### open-search-master (osm) node group #####
resource "aws_eks_node_group" "open-search-master" {
  count           = contains(keys(var.eks_mng_map), "osm")  ? 1 : 0
  cluster_name    = aws_eks_cluster.aws_eks[0].name
  node_group_name = var.eks_mng_map.osm.name
  node_role_arn   = aws_iam_role.eks_nodes[0].arn
  subnet_ids      = try(lookup(var.eks_mng_map.osm,"use_secondary_subnets",false),false) ? var.secondary_subnets : lookup(var.eks_mng_map.osm, "subnet_ids", var.subnets)
  instance_types  = contains(keys(var.eks_mng_map.osm), "use_lt") ? null : [lookup(var.eks_mng_map.osm, "instance_type")]
  ami_type        = "AL2_ARM_64"
  disk_size       = contains(keys(var.eks_mng_map.osm), "use_lt") ? null : lookup(var.eks_mng_map.osm, "disk_size")

  dynamic "launch_template" {
    for_each = contains(keys(var.eks_mng_map.osm), "use_lt")  ? toset([1]) : toset([])

    content {
      name = aws_launch_template.osm_template[count.index].name
      version = aws_launch_template.osm_template[count.index].latest_version
    }
  }

  scaling_config {
    desired_size = lookup(var.eks_mng_map.osm, "desired_size", 1)
    max_size     = lookup(var.eks_mng_map.osm, "max_size", 100)
    min_size     = lookup(var.eks_mng_map.osm, "min_size", 1)
  }

  dynamic "remote_access" {
    for_each = try(var.eks_mng_map.override["remote_access_sg"], "false") != "false" ? toset([1]) : toset([])

    content {
      ec2_ssh_key = try(var.eks_mng_map.override["key_name"], var.deploy_name)
      source_security_group_ids = lookup(var.eks_mng_map.override, "remote_access_sg")
    }
  }
  # Ensure that IAM Role permissions are created before and deleted after EKS Node Group handling.
  # Otherwise, EKS will not be able to properly delete EC2 Instances and Elastic Network Interfaces.
  depends_on = [
    aws_iam_role_policy_attachment.AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.AmazonEC2ContainerRegistryReadOnly,
  ]
  lifecycle {
    ignore_changes = [scaling_config[0].desired_size]
  }
}
##################################################################################################
resource "aws_eks_node_group" "osh" {
  count           = contains(keys(var.eks_mng_map), "osh")  ? 1 : 0
  cluster_name    = aws_eks_cluster.aws_eks[0].name
  node_group_name = var.eks_mng_map.osh.name
  node_role_arn   = aws_iam_role.eks_nodes[0].arn
  subnet_ids      = lookup(var.eks_mng_map.osh, "subnet_ids", var.subnets)
  instance_types  = contains(keys(var.eks_mng_map.osh), "use_lt") ? null : [lookup(var.eks_mng_map.osh, "instance_type")]
  ami_type        = "AL2_ARM_64"
  disk_size       = contains(keys(var.eks_mng_map.osh), "use_lt") ? null : lookup(var.eks_mng_map.osh, "disk_size")

  dynamic "launch_template" {
    for_each = contains(keys(var.eks_mng_map.osh), "use_lt")  ? toset([1]) : toset([])

    content {
      name = aws_launch_template.osh_template[count.index].name
      version = aws_launch_template.osh_template[count.index].latest_version
    }
  }

  scaling_config {
    desired_size = lookup(var.eks_mng_map.osh, "desired_size", 1)
    max_size     = lookup(var.eks_mng_map.osh, "max_size", 100)
    min_size     = lookup(var.eks_mng_map.osh, "min_size", 1)
  }

  dynamic "remote_access" {
    for_each = try(var.eks_mng_map.override["remote_access_sg"], "false") != "false" ? toset([1]) : toset([])

    content {
      ec2_ssh_key = try(var.eks_mng_map.override["key_name"], var.deploy_name)
      source_security_group_ids = lookup(var.eks_mng_map.override, "remote_access_sg")
    }
  }

  # Ensure that IAM Role permissions are created before and deleted after EKS Node Group handling.
  # Otherwise, EKS will not be able to properly delete EC2 Instances and Elastic Network Interfaces.
  depends_on = [
    aws_iam_role_policy_attachment.AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.AmazonEC2ContainerRegistryReadOnly,
  ]
  lifecycle {
    ignore_changes = [scaling_config[0].desired_size]
  }
}

##### open-search-warm (osw) node group #####
resource "aws_eks_node_group" "open-search-warm" {
  count           = contains(keys(var.eks_mng_map), "osw")  ? 1 : 0
  cluster_name    = aws_eks_cluster.aws_eks[0].name
  node_group_name = lookup(var.eks_mng_map.osw, "name", "open-search-warm" )
  node_role_arn   = aws_iam_role.eks_nodes[0].arn
  subnet_ids      = lookup(var.eks_mng_map.osw,"use_secondary_subnets",false) ? var.secondary_subnets : lookup(var.eks_mng_map.osw, "subnet_ids", var.subnets)
  instance_types  = contains(keys(var.eks_mng_map.osw), "use_lt") ? null : [lookup(var.eks_mng_map.osw, "instance_type")]
  ami_type        = "AL2_ARM_64"
  disk_size       = contains(keys(var.eks_mng_map.osw), "use_lt") ? null : lookup(var.eks_mng_map.osw, "disk_size")

  dynamic "launch_template" {
    for_each = contains(keys(var.eks_mng_map.osw), "use_lt")  ? toset([1]) : toset([])

    content {
      name = aws_launch_template.osw_template[count.index].name
      version = aws_launch_template.osw_template[count.index].latest_version
    }
  }
  scaling_config {
    desired_size = lookup(var.eks_mng_map.osw, "desired_size", 1)
    max_size     = lookup(var.eks_mng_map.osw, "max_size", 100)
    min_size     = lookup(var.eks_mng_map.osw, "min_size", 1)
  }

  dynamic "remote_access" {
    for_each = try(var.eks_mng_map.override["remote_access_sg"], "false") != "false" ? toset([1]) : toset([])

    content {
      ec2_ssh_key = try(var.eks_mng_map.override["key_name"], var.deploy_name)
      source_security_group_ids = lookup(var.eks_mng_map.override, "remote_access_sg")
    }
  }


  # Ensure that IAM Role permissions are created before and deleted after EKS Node Group handling.
  # Otherwise, EKS will not be able to properly delete EC2 Instances and Elastic Network Interfaces.
  depends_on = [
    aws_iam_role_policy_attachment.AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.AmazonEC2ContainerRegistryReadOnly,
  ]
  lifecycle {
    ignore_changes = [scaling_config[0].desired_size]
  }
}

##### open-search-client dedicated node group #####
resource "aws_eks_node_group" "open-search-client" {
  count           = contains(keys(var.eks_mng_map), "osc")  ? 1 : 0
  cluster_name    = aws_eks_cluster.aws_eks[0].name
  node_group_name = lookup(var.eks_mng_map.osc, "name", "osc" )
  node_role_arn   = aws_iam_role.eks_nodes[0].arn
  subnet_ids          = lookup(var.eks_mng_map.osc, "subnet_ids", var.subnets)
  ami_type        = "AL2_ARM_64"
  instance_types  = contains(keys(var.eks_mng_map.osc), "use_lt") ? null : [lookup(var.eks_mng_map.osc, "instance_type")]
  disk_size       = contains(keys(var.eks_mng_map.osc), "use_lt") ? null : lookup(var.eks_mng_map.osc, "disk_size")

  dynamic "launch_template" {
    for_each = contains(keys(var.eks_mng_map.osc), "use_lt")  ? toset([1]) : toset([])

    content {
      name = aws_launch_template.osc_template[count.index].name
      version = aws_launch_template.osc_template[count.index].latest_version
    }
  }
  scaling_config {
    desired_size = lookup(var.eks_mng_map.osc, "desired_size", 1)
    max_size     = lookup(var.eks_mng_map.osc, "max_size", 100)
    min_size     = lookup(var.eks_mng_map.osc, "min_size", 1)
  }

  dynamic "remote_access" {
    for_each = try(var.eks_mng_map.override["remote_access_sg"], "false") != "false" ? toset([1]) : toset([])

    content {
      ec2_ssh_key = try(var.eks_mng_map.override["key_name"], var.deploy_name)
      source_security_group_ids = lookup(var.eks_mng_map.override, "remote_access_sg")
    }
  }

  # Ensure that IAM Role permissions are created before and deleted after EKS Node Group handling.
  # Otherwise, EKS will not be able to properly delete EC2 Instances and Elastic Network Interfaces.
  depends_on = [
    aws_iam_role_policy_attachment.AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.AmazonEC2ContainerRegistryReadOnly,
  ]
  lifecycle {
    ignore_changes = [scaling_config[0].desired_size]
  }
}

##### open-search-ingestclient dedicated node group #####
resource "aws_eks_node_group" "open-search-ingestclient" {
  count           = contains(keys(var.eks_mng_map), "osic")  ? 1 : 0
  cluster_name    = aws_eks_cluster.aws_eks[0].name
  node_group_name = lookup(var.eks_mng_map.osic, "name", "osic" )
  node_role_arn   = aws_iam_role.eks_nodes[0].arn
  subnet_ids          = lookup(var.eks_mng_map.osic, "subnet_ids", var.subnets)
  instance_types  = contains(keys(var.eks_mng_map.osic), "use_lt") ? null : [lookup(var.eks_mng_map.osic, "instance_type")]
  disk_size       = contains(keys(var.eks_mng_map.osic), "use_lt") ? null : lookup(var.eks_mng_map.osic, "disk_size")

  dynamic "launch_template" {
    for_each = contains(keys(var.eks_mng_map.osic), "use_lt")  ? toset([1]) : toset([])

    content {
      name = aws_launch_template.osic_template[count.index].name
      version = aws_launch_template.osic_template[count.index].latest_version
    }
  }

  scaling_config {
    desired_size = lookup(var.eks_mng_map.osic, "desired_size", 1)
    max_size     = lookup(var.eks_mng_map.osic, "max_size", 100)
    min_size     = lookup(var.eks_mng_map.osic, "min_size", 1)
  }

  dynamic "remote_access" {
    for_each = try(var.eks_mng_map.override["remote_access_sg"], "false") != "false" ? toset([1]) : toset([])

    content {
      ec2_ssh_key = try(var.eks_mng_map.override["key_name"], var.deploy_name)
      source_security_group_ids = lookup(var.eks_mng_map.override, "remote_access_sg")
    }
  }
  

  # Ensure that IAM Role permissions are created before and deleted after EKS Node Group handling.
  # Otherwise, EKS will not be able to properly delete EC2 Instances and Elastic Network Interfaces.
  depends_on = [
    aws_iam_role_policy_attachment.AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.AmazonEC2ContainerRegistryReadOnly,
  ]
  lifecycle {
    ignore_changes = [scaling_config[0].desired_size]
  }
}

##### kafka-cluster dedicated node group #####
resource "aws_eks_node_group" "kafka-cluster" {
  count           = contains(keys(var.eks_mng_map), "kc")  ? 1 : 0
  cluster_name    = aws_eks_cluster.aws_eks[0].name
  node_group_name = lookup(var.eks_mng_map.kc, "name", "kc" )
  node_role_arn   = aws_iam_role.eks_nodes[0].arn
  subnet_ids          = lookup(var.eks_mng_map.kc, "subnet_ids", var.subnets)
  instance_types  = contains(keys(var.eks_mng_map.kc), "use_lt") ? null : [lookup(var.eks_mng_map.kc, "instance_type")]
  disk_size       = contains(keys(var.eks_mng_map.kc), "use_lt") ? null : lookup(var.eks_mng_map.kc, "disk_size")


  dynamic "launch_template" {
    for_each = contains(keys(var.eks_mng_map.kc), "use_lt")  ? toset([1]) : toset([])

    content {
      name = aws_launch_template.kc_template[count.index].name
      version = aws_launch_template.kc_template[count.index].latest_version
    }
  }
  
  scaling_config {
    desired_size = lookup(var.eks_mng_map.kc, "desired_size", 1)
    max_size     = lookup(var.eks_mng_map.kc, "max_size", 100)
    min_size     = lookup(var.eks_mng_map.kc, "min_size", 1)
  }

  dynamic "remote_access" {
    for_each = try(var.eks_mng_map.override["remote_access_sg"], "false") != "false" ? toset([1]) : toset([])

    content {
      ec2_ssh_key = try(var.eks_mng_map.override["key_name"], var.deploy_name)
      source_security_group_ids = lookup(var.eks_mng_map.override, "remote_access_sg")
    }
  }

  # Ensure that IAM Role permissions are created before and deleted after EKS Node Group handling.
  # Otherwise, EKS will not be able to properly delete EC2 Instances and Elastic Network Interfaces.
  depends_on = [
    aws_iam_role_policy_attachment.AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.AmazonEC2ContainerRegistryReadOnly,
  ]
  lifecycle {
    ignore_changes = [scaling_config[0].desired_size]
  }
}

##### zookeeper-cluster dedicated node group #####
resource "aws_eks_node_group" "zookeeper-cluster" {
  count           = contains(keys(var.eks_mng_map), "zc")  ? 1 : 0
  cluster_name    = aws_eks_cluster.aws_eks[0].name
  node_group_name = lookup(var.eks_mng_map.zc, "name", "oe01" )
  node_role_arn   = aws_iam_role.eks_nodes[0].arn
  subnet_ids          = lookup(var.eks_mng_map.zc, "subnet_ids", var.subnets)
  instance_types  = contains(keys(var.eks_mng_map.zc), "use_lt") ? null : [lookup(var.eks_mng_map.zc, "instance_type")]
  disk_size       = contains(keys(var.eks_mng_map.zc), "use_lt") ? null : lookup(var.eks_mng_map.zc, "disk_size")


  dynamic "launch_template" {
    for_each = contains(keys(var.eks_mng_map.zc), "use_lt")  ? toset([1]) : toset([])

    content {
      name = aws_launch_template.zc_template[count.index].name
      version = aws_launch_template.zc_template[count.index].latest_version
    }
  }
  
  scaling_config {
    desired_size = lookup(var.eks_mng_map.zc, "desired_size", 1)
    max_size     = lookup(var.eks_mng_map.zc, "max_size", 100)
    min_size     = lookup(var.eks_mng_map.zc, "min_size", 1)
  }

  dynamic "remote_access" {
    for_each = try(var.eks_mng_map.override["remote_access_sg"], "false") != "false" ? toset([1]) : toset([])

    content {
      ec2_ssh_key = try(var.eks_mng_map.override["key_name"], var.deploy_name)
      source_security_group_ids = lookup(var.eks_mng_map.override, "remote_access_sg")
    }
  }

  # Ensure that IAM Role permissions are created before and deleted after EKS Node Group handling.
  # Otherwise, EKS will not be able to properly delete EC2 Instances and Elastic Network Interfaces.
  depends_on = [
    aws_iam_role_policy_attachment.AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.AmazonEC2ContainerRegistryReadOnly,
  ]
  lifecycle {
    ignore_changes = [scaling_config[0].desired_size]
  }
}

##### clickhouse-cluster dedicated node group #####
resource "aws_eks_node_group" "clickhouse-cluster" {
  count           = contains(keys(var.eks_mng_map), "cc")  ? 1 : 0
  cluster_name    = aws_eks_cluster.aws_eks[0].name
  node_group_name = lookup(var.eks_mng_map.cc, "name", "cc" )
  node_role_arn   = aws_iam_role.eks_nodes[0].arn
  subnet_ids          = lookup(var.eks_mng_map.cc, "subnet_ids", var.subnets)
  instance_types  = contains(keys(var.eks_mng_map.cc), "use_lt") ? null : [lookup(var.eks_mng_map.cc, "instance_type")]
  disk_size       = contains(keys(var.eks_mng_map.cc), "use_lt") ? null : lookup(var.eks_mng_map.cc, "disk_size")

  dynamic "launch_template" {
    for_each = contains(keys(var.eks_mng_map.cc), "use_lt")  ? toset([1]) : toset([])

    content {
      name = aws_launch_template.cc_template[count.index].name
      version = aws_launch_template.cc_template[count.index].latest_version
    }
  }
  
  scaling_config {
    desired_size = lookup(var.eks_mng_map.cc, "desired_size", 1)
    max_size     = lookup(var.eks_mng_map.cc, "max_size", 100)
    min_size     = lookup(var.eks_mng_map.cc, "min_size", 1)
  }

  dynamic "remote_access" {
    for_each = try(var.eks_mng_map.override["remote_access_sg"], "false") != "false" ? toset([1]) : toset([])

    content {
      ec2_ssh_key = try(var.eks_mng_map.override["key_name"], var.deploy_name)
      source_security_group_ids = lookup(var.eks_mng_map.override, "remote_access_sg")
    }
  }
  

  # Ensure that IAM Role permissions are created before and deleted after EKS Node Group handling.
  # Otherwise, EKS will not be able to properly delete EC2 Instances and Elastic Network Interfaces.
  depends_on = [
    aws_iam_role_policy_attachment.AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.AmazonEC2ContainerRegistryReadOnly,
  ]
  lifecycle {
    ignore_changes = [scaling_config[0].desired_size]
  }
}

resource "aws_iam_group_policy" "k8s-coralogix_policy" {
  count = var.coralogix_user == true ? 1  : 0
  name  = "KubernetesCoralogix"
  group = aws_iam_group.k8s-coralogix[count.index].id

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "VisualEditor0",
            "Effect": "Allow",
            "Action": [
                "ec2:DescribeVpcs",
                "ec2:DescribeVpcEndpointServices",
                "ec2:DescribeVpcEndpointServiceConfigurations",
                "ec2:DescribeVpcEndpoints",
                "ec2:DescribeVpcEndpointConnections",
                "ec2:DescribeSubnets",
                "ec2:DescribeAvailabilityZones"
            ],
            "Resource": "*",
            "Condition": {
                "StringEquals": {
                    "ec2:Region": "us-gov-west-1"
                }
            }
        },
        {
            "Sid": "VisualEditor1",
            "Effect": "Allow",
            "Action": "ec2:CreateSecurityGroup",
            "Resource": [
                "arn:aws-us-gov:ec2:us-gov-west-1:${var.aws_account_id}:vpc/${var.vpc_id}",
                "arn:aws-us-gov:ec2:*:${var.aws_account_id}:security-group/*"
            ]
        },
        {
            "Sid": "VisualEditor2",
            "Effect": "Allow",
            "Action": [
                "ec2:CreateSecurityGroup",
                "ec2:DescribeVpcAttribute",
                "ec2:CreateTags"
            ],
            "Resource": [
                "arn:aws-us-gov:ec2:us-gov-west-1:${var.aws_account_id}:vpc/${var.vpc_id}",
                "arn:aws-us-gov:ec2:us-gov-west-1:${var.aws_account_id}:security-group/*"
            ]
        },
        {
            "Sid": "VisualEditor3",
            "Effect": "Allow",
            "Action": [
                "elasticloadbalancing:ModifyListener",
                "elasticloadbalancing:RegisterTargets",
                "elasticloadbalancing:SetIpAddressType",
                "rds:CreateOptionGroup",
                "rds:ModifyOptionGroup",
                "rds:CreateDBSubnetGroup",
                "elasticloadbalancing:DeleteLoadBalancer",
                "elasticloadbalancing:SetWebAcl",
                "elasticloadbalancing:DescribeLoadBalancers",
                "rds:ModifyDBParameterGroup",
                "eks:DescribeNodegroup",
                "elasticloadbalancing:CreateRule",
                "elasticloadbalancing:AddListenerCertificates",
                "elasticloadbalancing:ModifyTargetGroupAttributes",
                "rds:CreateDBParameterGroup",
                "elasticloadbalancing:CreateTargetGroup",
                "elasticloadbalancing:DeregisterTargets",
                "elasticloadbalancing:DescribeLoadBalancerAttributes",
                "rds:DeleteDBSubnetGroup",
                "elasticloadbalancing:DescribeTargetGroupAttributes",
                "elasticloadbalancing:ModifyRule",
                "elasticloadbalancing:DescribeAccountLimits",
                "elasticloadbalancing:AddTags",
                "eks:DescribeCluster",
                "elasticloadbalancing:DescribeRules",
                "eks:ListClusters",
                "elasticloadbalancing:ModifyLoadBalancerAttributes",
                "rds:RemoveTagsFromResource",
                "rds:DescribeOptionGroups",
                "rds:DescribeDBSubnetGroups",
                "rds:DescribeDBParameterGroups",
                "elasticloadbalancing:SetRulePriorities",
                "elasticloadbalancing:RemoveListenerCertificates",
                "elasticloadbalancing:RemoveTags",
                "elasticloadbalancing:CreateListener",
                "elasticloadbalancing:DescribeListeners",
                "rds:CreateDBInstance",
                "elasticloadbalancing:DescribeListenerCertificates",
                "rds:DescribeDBParameters",
                "elasticloadbalancing:DeleteRule",
                "elasticloadbalancing:DescribeSSLPolicies",
                "rds:AddTagsToResource",
                "elasticloadbalancing:CreateLoadBalancer",
                "s3:*",
                "elasticloadbalancing:DescribeTags",
                "elasticloadbalancing:SetSubnets",
                "elasticloadbalancing:DeleteTargetGroup",
                "rds:ListTagsForResource",
                "elasticloadbalancing:DescribeTargetHealth",
                "elasticloadbalancing:SetSecurityGroups",
                "elasticloadbalancing:DescribeTargetGroups",
                "elasticloadbalancing:ModifyTargetGroup",
                "elasticloadbalancing:DeleteListener",
                "rds:ModifyDBSubnetGroup",
                "ec2:DescribeSecurityGroups",
                "ec2:ModifySecurityGroupRules",
                "ec2:UpdateSecurityGroupRuleDescriptionsEgress",
                "ec2:UpdateSecurityGroupRuleDescriptionsIngress",
                "ec2:RevokeSecurityGroupEgress",
                "ec2:RevokeSecurityGroupIngress",
                "ec2:AuthorizeSecurityGroupIngress",
                "ec2:AuthorizeSecurityGroupEgress",
                "rds:DescribeDBInstances",
                "ec2:DescribeInstances"
            ],
            "Resource": "*"
        },
        {
            "Sid": "VisualEditor4",
            "Effect": "Allow",
            "Action": "sts:AssumeRole",
            "Resource": "arn:aws-us-gov:iam::${var.aws_account_id}:role/KubernetesCoralogix"
        }
    ]
}
EOF
  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_iam_group_policy" "k8s-admins_policy" {
  count      = lookup(var.eks_mng_map.override, "create_k8s-admins_iam" , true) && var.module_enabled ? 1 : 0
  name  = "KubernetesAdmin"
  group = aws_iam_group.k8s-admins[count.index].id

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "sts:AssumeRole"
      ],
      "Effect": "Allow",
      "Resource": "arn:${var.aws_arn}:iam::${var.aws_account_id}:role/KubernetesAdmin"
    },
    {
      "Effect": "Allow",
      "Action": [
          "eks:DescribeNodegroup",
          "eks:DescribeCluster",
          "eks:ListClusters"
      ],
      "Resource": "*"
    }
  ]
}
EOF
  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_iam_group" "k8s-coralogix" {
  count = var.coralogix_user == true ? 1  : 0
  name = "KubernetesCoralogixs"
  lifecycle {
    prevent_destroy = true
  }
}
resource "aws_iam_group" "k8s-admins" {
  count      = lookup(var.eks_mng_map.override, "create_k8s-admins_iam" , true) && var.module_enabled ? 1 : 0
  name = "KubernetesAdmins"
  lifecycle {
    prevent_destroy = true
  }
}
resource "aws_iam_role" "role-coralogix" {
  count = var.coralogix_user == true ? 1  : 0
  name = "KubernetesCoralogix"
  description = "Kubernetes administrator role (for AWS IAM Authenticator for Kubernetes)."

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Condition": {},
      "Principal": {
        "AWS": "arn:${var.aws_arn}:iam::${var.aws_account_id}:user/coralogix_user"
      },
      "Effect": "Allow"
    }
  ]
}
EOF
lifecycle {
    prevent_destroy = true
  }
}

resource "aws_iam_role" "role-admin" {
  count      = lookup(var.eks_mng_map.override, "create_k8s-admins_iam" , true) && var.module_enabled ? 1 : 0
  name = "KubernetesAdmin"
  description = "Kubernetes administrator role (for AWS IAM Authenticator for Kubernetes)."

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Condition": {},
      "Principal": {
        "AWS": "arn:${var.aws_arn}:iam::${var.aws_account_id}:user/strongdm-eks-admin"
      },
      "Effect": "Allow"
    }
  ]
}
EOF
lifecycle {
    prevent_destroy = true
  }
}

data "aws_eks_cluster" "cluster" {
  count = var.module_enabled ? 1 : 0
  name = aws_eks_cluster.aws_eks[count.index].id
}

data "aws_eks_cluster_auth" "cluster" {
  count = var.module_enabled ? 1 : 0
  name = aws_eks_cluster.aws_eks[count.index].id
}

provider "kubernetes" {
  host                   = try(var.eks_mng_map.override["k8s_sdm"], element(concat(data.aws_eks_cluster.cluster[*].endpoint, []), 0))
  cluster_ca_certificate = base64decode(element(concat(data.aws_eks_cluster.cluster[*].certificate_authority.0.data, []), 0))
  token                  = element(concat(data.aws_eks_cluster_auth.cluster[*].token, []), 0)
  load_config_file       = false
}

resource "kubernetes_config_map" "aws_auth" {
  count      = var.module_enabled ? 1 : 0
  depends_on = [aws_eks_cluster.aws_eks, aws_eks_node_group.open-search-master, aws_eks_node_group.backend]

  metadata {
    name      = "aws-auth"
    namespace = "kube-system"
  }

  data = {
    mapRoles = <<YAML
- rolearn: arn:${var.aws_arn}:iam::${var.aws_account_id}:role/KubernetesAdmin
  username: kubernetes-admin
  groups:
    - system:masters
YAML

    mapUsers = <<YAML
- userarn: arn:${var.aws_arn}:iam::${var.aws_account_id}:user/strongdm-eks-admin
  username: strongdm-eks-admin
  groups:
    - system:masters
YAML
  
  }
  lifecycle {
    ignore_changes = [data]
  }
}

data "template_file" "ng_nodegroup" {
  count = length(var.anitian_sshkey) > 0 ? 1 : 0
  template = file("${path.module}/node-v2-gov.sh")

  vars = {
    anitian_s3 = var.anitian_s3,
    anitian_sshkey = var.anitian_sshkey,
  }
}

resource "aws_launch_template" "osm_template" {
  count       = try(var.eks_mng_map.osm["use_lt"],"false") != "false" ? 1 : 0
  name_prefix = "terraform-"
  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      volume_size = lookup(var.eks_mng_map.osm, "disk_size")
      volume_type = try(var.eks_mng_map.osm["volume_type"], null)
      iops        = try(var.eks_mng_map.osm["iops"], null)
      throughput  = try(var.eks_mng_map.osm["throughput"], null)
    }
  }

  instance_type = lookup(var.eks_mng_map.osm, "instance_type")
 
  dynamic metadata_options {
    for_each = var.http_endpoint ? [1] : []
    content {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
    }
  }
//  image_id      = "ami-0210bddf620783a5e"
  key_name      = try(var.eks_mng_map.override["key_name"], var.deploy_name)

  dynamic "network_interfaces" {
    for_each = try(var.eks_mng_map.override["cluster_sg_ids"], "false") == "false"  ? toset([]) : toset([1])
    content {
      security_groups = try(var.eks_mng_map.override["cluster_sg_ids"], null)
    }
  }
   dynamic "tag_specifications" {
    for_each = contains(keys(var.eks_mng_map.override),"enable_lt_tags") == true ? toset(["instance", "volume"]) : []
    content {
      resource_type = tag_specifications.key
      tags          = merge(local.node_pools_common_default_tags.osm, var.launch_template_tags)
    }
  }
  user_data = base64encode("${data.template_file.ng_nodegroup[0].rendered}")
}
###################################################################################################
resource "aws_launch_template" "osh_template" {
  count       = try(var.eks_mng_map.osh["use_lt"],"false") != "false" ? 1 : 0
  name_prefix = "terraform-"
  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      volume_size = lookup(var.eks_mng_map.osh, "disk_size")
      volume_type = try(var.eks_mng_map.osh["volume_type"], null)
      iops        = try(var.eks_mng_map.osh["iops"], null)
      throughput  = try(var.eks_mng_map.osh["throughput"], null)
    }
  }

  instance_type = lookup(var.eks_mng_map.osh, "instance_type")

  dynamic metadata_options {
    for_each = var.http_endpoint ? [1] : []
    content {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
    }
  }
//  image_id      = "ami-0210bddf620783a5e"
  key_name      = try(var.eks_mng_map.override["key_name"], var.deploy_name)

  dynamic "network_interfaces" {
    for_each = try(var.eks_mng_map.override["cluster_sg_ids"], "false") == "false"  ? toset([]) : toset([1])
    content {
      security_groups = try(var.eks_mng_map.override["cluster_sg_ids"], null)
    }
  }
   dynamic "tag_specifications" {
    for_each = contains(keys(var.eks_mng_map.override),"enable_lt_tags") == true ? toset(["instance", "volume"]) : []
    content {
      resource_type = tag_specifications.key
      tags          = merge(local.node_pools_common_default_tags.osh, var.launch_template_tags)
    }
  }
  user_data = base64encode("${data.template_file.ng_nodegroup[0].rendered}")
}




resource "aws_launch_template" "be_template" {
  count       = try(var.eks_mng_map.be["use_lt"],"false") != "false" ? 1 : 0
  name_prefix = "terraform-"
  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      volume_size = lookup(var.eks_mng_map.be, "disk_size")
      volume_type = try(var.eks_mng_map.be["volume_type"], null)
      iops        = try(var.eks_mng_map.be["iops"], null)
      throughput  = try(var.eks_mng_map.be["throughput"], null)
    }
  }

  instance_type = lookup(var.eks_mng_map.be, "instance_type")
  //  image_id      = "ami-0210bddf620783a5e"
  
  dynamic metadata_options {
    for_each = var.http_endpoint ? [1] : []
    content {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
    }
  }

  key_name      = try(var.eks_mng_map.override["key_name"], var.deploy_name)

  dynamic "network_interfaces" {
    for_each = try(var.eks_mng_map.override["cluster_sg_ids"], "false") == "false"  ? toset([]) : toset([1])
    content {
      security_groups = try(var.eks_mng_map.override["cluster_sg_ids"], null)
    }
  }
  dynamic "tag_specifications" {
    for_each = contains(keys(var.eks_mng_map.override),"enable_lt_tags") == true ? toset(["instance", "volume"]) : []
    content {
      resource_type = tag_specifications.key
      tags          = merge(local.node_pools_common_default_tags.ng, var.launch_template_tags)
    }
  }
  user_data = base64encode("${data.template_file.ng_nodegroup[0].rendered}")
}

resource "aws_launch_template" "osw_template" {
  count       = try(var.eks_mng_map.osw["use_lt"],"false") != "false" ? 1 : 0
  name_prefix = "terraform-"
  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      volume_size = lookup(var.eks_mng_map.osw, "disk_size")
      volume_type = try(var.eks_mng_map.osw["volume_type"], null)
      iops        = try(var.eks_mng_map.osw["iops"], null)
      throughput  = try(var.eks_mng_map.osw["throughput"], null)
    }
  }

  instance_type = lookup(var.eks_mng_map.osw, "instance_type")

  dynamic metadata_options {
    for_each = var.http_endpoint ? [1] : []
    content {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
    }
  }
  //  image_id      = "ami-0210bddf620783a5e"
  key_name      = try(var.eks_mng_map.override["key_name"], var.deploy_name)

  dynamic "network_interfaces" {
    for_each = try(var.eks_mng_map.override["cluster_sg_ids"], "false") == "false"  ? toset([]) : toset([1])
    content {
      security_groups = try(var.eks_mng_map.override["cluster_sg_ids"], null)
    }
  }
    dynamic "tag_specifications" {
    for_each = contains(keys(var.eks_mng_map.override),"enable_lt_tags") == true ? toset(["instance", "volume"]) : []
    content {
      resource_type = tag_specifications.key
      tags          = merge(local.node_pools_common_default_tags.osw, var.launch_template_tags)
    }
  }
  user_data = base64encode("${data.template_file.ng_nodegroup[0].rendered}")
}

resource "aws_launch_template" "osc_template" {
  count       = try(var.eks_mng_map.osc["use_lt"],"false") != "false" ? 1 : 0
  name_prefix = "terraform-"
  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      volume_size = lookup(var.eks_mng_map.osc, "disk_size")
      volume_type = try(var.eks_mng_map.osc["volume_type"], null)
      iops        = try(var.eks_mng_map.osc["iops"], null)
      throughput  = try(var.eks_mng_map.osc["throughput"], null)
    }
  }

  instance_type = lookup(var.eks_mng_map.osc, "instance_type")
  //  image_id      = "ami-0210bddf620783a5e"
    dynamic metadata_options {
    for_each = var.http_endpoint ? [1] : []
    content {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
    }
  }
  key_name      = try(var.eks_mng_map.override["key_name"], var.deploy_name)

  dynamic "network_interfaces" {
    for_each = try(var.eks_mng_map.override["cluster_sg_ids"], "false") == "false"  ? toset([]) : toset([1])
    content {
      security_groups = try(var.eks_mng_map.override["cluster_sg_ids"], null)
    }
  }
    dynamic "tag_specifications" {
    for_each = contains(keys(var.eks_mng_map.override),"enable_lt_tags") == true ? toset(["instance", "volume"]) : []
    content {
      resource_type = tag_specifications.key
      tags          = merge(local.node_pools_common_default_tags.osc, var.launch_template_tags)
    }
  }
  user_data = base64encode("${data.template_file.ng_nodegroup[0].rendered}")
}

resource "aws_launch_template" "osic_template" {
  count       = try(var.eks_mng_map.osic["use_lt"],"false") != "false" ? 1 : 0
  name_prefix = "terraform-"
  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      volume_size = lookup(var.eks_mng_map.osic, "disk_size")
      volume_type = try(var.eks_mng_map.osic["volume_type"], null)
      iops        = try(var.eks_mng_map.osic["iops"], null)
      throughput  = try(var.eks_mng_map.osic["throughput"], null)
    }
  }

  instance_type = lookup(var.eks_mng_map.osic, "instance_type")
  //  image_id      = "ami-0210bddf620783a5e"
  dynamic metadata_options {
    for_each = var.http_endpoint ? [1] : []
    content {
      http_endpoint               = "enabled"
      http_tokens                 = "required"
      http_put_response_hop_limit = 2
    }
  }
  key_name      = try(var.eks_mng_map.override["key_name"], var.deploy_name)

  dynamic "network_interfaces" {
    for_each = try(var.eks_mng_map.override["cluster_sg_ids"], "false") == "false"  ? toset([]) : toset([1])
    content {
      security_groups = try(var.eks_mng_map.override["cluster_sg_ids"], null)
    }
  }
  dynamic "tag_specifications" {
    for_each = contains(keys(var.eks_mng_map.override),"enable_lt_tags") == true ? toset(["instance", "volume"]) : []
    content {
      resource_type = tag_specifications.key
      tags          = merge(local.node_pools_common_default_tags.osic, var.launch_template_tags)
    }
  }
  user_data = base64encode("${data.template_file.ng_nodegroup[0].rendered}")
}

resource "aws_launch_template" "kc_template" {
  count       = try(var.eks_mng_map.kc["use_lt"],"false") != "false" ? 1 : 0
  name_prefix = "terraform-"
  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      volume_size = lookup(var.eks_mng_map.kc, "disk_size")
      volume_type = try(var.eks_mng_map.kc["volume_type"], null)
      iops        = try(var.eks_mng_map.kc["iops"], null)
      throughput  = try(var.eks_mng_map.kc["throughput"], null)
    }
  }
    block_device_mappings {
    device_name = "/dev/sdf"

    ebs {
      volume_size = lookup(var.eks_mng_map.kc, "disk_size")
      volume_type = try(var.eks_mng_map.kc["volume_type"], null)
      iops        = try(var.eks_mng_map.kc["iops"], null)
      throughput  = try(var.eks_mng_map.kc["throughput"], null)
    }
  }

  instance_type = lookup(var.eks_mng_map.kc, "instance_type")
  //  image_id      = "ami-0210bddf620783a5e"
  dynamic metadata_options {
    for_each = var.http_endpoint ? [1] : []
    content {
      http_endpoint               = "enabled"
      http_tokens                 = "required"
      http_put_response_hop_limit = 2
    }
  }
  key_name      = try(var.eks_mng_map.override["key_name"], var.deploy_name)

  dynamic "network_interfaces" {
    for_each = try(var.eks_mng_map.override["cluster_sg_ids"], "false") == "false"  ? toset([]) : toset([1])
    content {
      security_groups = try(var.eks_mng_map.override["cluster_sg_ids"], null)
    }
  }
  dynamic "tag_specifications" {
    for_each = contains(keys(var.eks_mng_map.override),"enable_lt_tags") == true ? toset(["instance", "volume"]) : []
    content {
      resource_type = tag_specifications.key
      tags          = merge(local.node_pools_common_default_tags.kc, var.launch_template_tags)
    }
  }
  user_data = base64encode("${data.template_file.ng_nodegroup[0].rendered}")
}

resource "aws_launch_template" "zc_template" {
  count       = try(var.eks_mng_map.zc["use_lt"],"false") != "false" ? 1 : 0
  name_prefix = "terraform-"
  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      volume_size = lookup(var.eks_mng_map.zc, "disk_size")
      volume_type = try(var.eks_mng_map.zc["volume_type"], null)
      iops        = try(var.eks_mng_map.zc["iops"], null)
      throughput  = try(var.eks_mng_map.zc["throughput"], null)
    }
  }
    block_device_mappings {
    device_name = "/dev/sdf"

    ebs {
      volume_size = lookup(var.eks_mng_map.zc, "disk_size")
      volume_type = try(var.eks_mng_map.zc["volume_type"], null)
      iops        = try(var.eks_mng_map.zc["iops"], null)
      throughput  = try(var.eks_mng_map.zc["throughput"], null)
    }
  }

  instance_type = lookup(var.eks_mng_map.zc, "instance_type")
  //  image_id      = "ami-0210bddf620783a5e"
  dynamic metadata_options {
    for_each = var.http_endpoint ? [1] : []
    content {
      http_endpoint               = "enabled"
      http_tokens                 = "required"
      http_put_response_hop_limit = 2
    }
  }
  key_name      = try(var.eks_mng_map.override["key_name"], var.deploy_name)

  dynamic "network_interfaces" {
    for_each = try(var.eks_mng_map.override["cluster_sg_ids"], "false") == "false"  ? toset([]) : toset([1])
    content {
      security_groups = try(var.eks_mng_map.override["cluster_sg_ids"], null)
    }
  }
  dynamic "tag_specifications" {
    for_each = contains(keys(var.eks_mng_map.override),"enable_lt_tags") == true ? toset(["instance", "volume"]) : []
    content {
      resource_type = tag_specifications.key
      tags          = merge(local.node_pools_common_default_tags.zc, var.launch_template_tags)
    }
  }
  user_data = base64encode("${data.template_file.ng_nodegroup[0].rendered}")
}



resource "aws_launch_template" "cc_template" {
  count       = try(var.eks_mng_map.cc["use_lt"],"false") != "false" ? 1 : 0
  name_prefix = "terraform-"
  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      volume_size = lookup(var.eks_mng_map.cc, "disk_size")
      volume_type = try(var.eks_mng_map.cc["volume_type"], null)
      iops        = try(var.eks_mng_map.cc["iops"], null)
      throughput  = try(var.eks_mng_map.cc["throughput"], null)
    }
  }

  instance_type = lookup(var.eks_mng_map.cc, "instance_type")
  //  image_id      = "ami-0210bddf620783a5e"
  dynamic metadata_options {
    for_each = var.http_endpoint ? [1] : []
    content {
      http_endpoint               = "enabled"
      http_tokens                 = "required"
      http_put_response_hop_limit = 2
    }
  }
  key_name      = try(var.eks_mng_map.override["key_name"], var.deploy_name)

  dynamic "network_interfaces" {
    for_each = try(var.eks_mng_map.override["cluster_sg_ids"], "false") == "false"  ? toset([]) : toset([1])
    content {
      security_groups = try(var.eks_mng_map.override["cluster_sg_ids"], null)
    }
  }
  dynamic "tag_specifications" {
    for_each = contains(keys(var.eks_mng_map.override),"enable_lt_tags") == true ? toset(["instance", "volume"]) : []
    content {
      resource_type = tag_specifications.key
      tags          = merge(local.node_pools_common_default_tags.cc, var.launch_template_tags)
    }
  }
  user_data = base64encode("${data.template_file.ng_nodegroup[0].rendered}")
}


module "ebs_csi" {
 count      = var.enable_ebs_csi ? 1 : 0
 source                 = "./ebs_csi"
  depends_on = [
     aws_eks_cluster.aws_eks,
     aws_eks_node_group.open-search-master,
     aws_eks_node_group.backend
     ]
key_name               = lookup(var.eks_mng_map.override, "key_name")
deploy_name            = var.deploy_name  // add deploy name to sg ?
project_name           = var.project_name // add deploy name to sg ?
oicd                   = aws_iam_openid_connect_provider.open-id-connect[0]
file_system_id         = var.file_system_id
}

