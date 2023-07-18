
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
    security_group_ids  = lookup(var.eks_mng_map.override, "additional_sg_ids", var.security_group_ids)
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

##### multipile nodes - node group #####
resource "aws_eks_node_group" "general_node" {
  for_each  = { for k, v in  try(var.eks_mng_map.mpnodes.nodes,{}) : k => v }
  subnet_ids       = lookup(each.value,"use_secondary_subnets",false) ? var.secondary_subnets :  var.subnets
  cluster_name     = aws_eks_cluster.aws_eks[0].name
  node_group_name  = lookup(each.value, "name", "${var.deploy_name}" )
  node_role_arn    = aws_iam_role.eks_nodes[0].arn

  launch_template {

      name = aws_launch_template.mpnodes_template[each.key].name
      version = aws_launch_template.mpnodes_template[each.key].latest_version
  }

  labels = var.enable_tags ? local.node_pools_common_default_labels[each.key] : tomap({
  })

  scaling_config {
    desired_size = lookup(each.value, "desired_size", 1)
    max_size     = lookup(each.value, "max_size", 100)
    min_size     = lookup(each.value, "min_size", 1)
  }

  tags = var.enable_tags ? local.node_pools_common_default_tags[each.key] : {
    Environment = var.environment
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

##### default node group (ng) paying customers #####
resource "aws_eks_node_group" "node" {
  count           = contains(keys(var.eks_mng_map), "ng")  ? 1 : 0
  subnet_ids      = lookup(var.eks_mng_map.ng,"use_secondary_subnets",false) ? var.secondary_subnets : lookup(var.eks_mng_map.ng, "subnet_ids", var.subnets)
  cluster_name    = aws_eks_cluster.aws_eks[0].name
  node_group_name = lookup(var.eks_mng_map.ng, "name", "${var.deploy_name}-ng-1" )
  node_role_arn   = aws_iam_role.eks_nodes[0].arn
  instance_types  = contains(keys(var.eks_mng_map.ng), "use_lt") ? null : [lookup(var.eks_mng_map.ng, "instance_type")]
  disk_size       = contains(keys(var.eks_mng_map.ng), "use_lt") ? null : lookup(var.eks_mng_map.ng, "disk_size")

  dynamic "launch_template" {
    for_each = contains(keys(var.eks_mng_map.ng), "use_lt")  ? toset([1]) : toset([])

    content {
      name = aws_launch_template.node_template[count.index].name
      version = aws_launch_template.node_template[count.index].latest_version
    }
  }

  labels = var.enable_tags ? local.node_pools_common_default_labels.ng : tomap({
    "k8s.jfrog.com/subscription_type" = "paying"
  })

  scaling_config {
    desired_size = lookup(var.eks_mng_map.ng, "desired_size", 1)
    max_size     = lookup(var.eks_mng_map.ng, "max_size", 100)
    min_size     = lookup(var.eks_mng_map.ng, "min_size", 1)
  }

  dynamic "remote_access" {
    for_each = try(var.eks_mng_map.override["remote_access_sg"], "false") != "false" ? toset([1]) : toset([])

    content {
      ec2_ssh_key = try(var.eks_mng_map.override["key_name"], var.deploy_name)
      source_security_group_ids = lookup(var.eks_mng_map.override, "remote_access_sg")
    }
  }

  tags = var.enable_tags ? local.node_pools_common_default_tags.ng : {
    Environment = var.environment
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
  autoscaling_group_name = aws_eks_node_group.node[count.index].resources[0].autoscaling_groups[0].name
  alb_target_group_arn   = var.private_link_tg
}

resource "aws_autoscaling_attachment" "aws_eks_node_group_main_tg_attach_plain" {
  count           = lookup(var.eks_mng_map.override, "enable_pl",true) && var.module_enabled && var.private_link_tg != "" ? 1 : 0
  autoscaling_group_name = aws_eks_node_group.node[count.index].resources[0].autoscaling_groups[0].name
  alb_target_group_arn   = var.private_link_tg_plain
}

##### freetier (ft) node group #####
resource "aws_eks_node_group" "freetier" {
  count           = contains(keys(var.eks_mng_map), "ft")  ? 1 : 0
  cluster_name    = aws_eks_cluster.aws_eks[0].name
  node_group_name = lookup(var.eks_mng_map.ft, "name", "freetier" )
  node_role_arn   = aws_iam_role.eks_nodes[0].arn
  subnet_ids      = try(lookup(var.eks_mng_map.ft,"use_secondary_subnets",false),false) ? var.secondary_subnets : lookup(var.eks_mng_map.ft, "subnet_ids", var.subnets)
  instance_types  = contains(keys(var.eks_mng_map.ft), "use_lt") ? null : [lookup(var.eks_mng_map.ft, "instance_type")]
  disk_size       = contains(keys(var.eks_mng_map.ft), "use_lt") ? null : lookup(var.eks_mng_map.ft, "disk_size")

  dynamic "launch_template" {
    for_each = contains(keys(var.eks_mng_map.ft), "use_lt")  ? toset([1]) : toset([])

    content {
      name = aws_launch_template.freetier_template[count.index].name
      version = aws_launch_template.freetier_template[count.index].latest_version
    }
  }

  labels = var.enable_tags ? local.node_pools_common_default_labels.ft : tomap({
    "k8s.jfrog.com/subscription_type" = "free"
  })

  scaling_config {
    desired_size = lookup(var.eks_mng_map.ft, "desired_size", 1)
    max_size     = lookup(var.eks_mng_map.ft, "max_size", 100)
    min_size     = lookup(var.eks_mng_map.ft, "min_size", 1)
  }

  dynamic "remote_access" {
    for_each = try(var.eks_mng_map.override["remote_access_sg"], "false") != "false" ? toset([1]) : toset([])

    content {
      ec2_ssh_key = try(var.eks_mng_map.override["key_name"], var.deploy_name)
      source_security_group_ids = lookup(var.eks_mng_map.override, "remote_access_sg")
    }
  }

  tags = var.enable_tags ? local.node_pools_common_default_tags.ft : {
    Environment = var.environment
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
##### xuc node group #####
resource "aws_eks_node_group" "xuc" {
  count           = contains(keys(var.eks_mng_map), "xuc")  ? 1 : 0
  cluster_name    = aws_eks_cluster.aws_eks[0].name
  node_group_name = lookup(var.eks_mng_map.xuc, "name", "xuc" )
  node_role_arn   = aws_iam_role.eks_nodes[0].arn
  subnet_ids      = lookup(var.eks_mng_map.xuc, "subnet_ids", var.subnets)
  instance_types  = contains(keys(var.eks_mng_map.xuc), "use_lt") ? null : [lookup(var.eks_mng_map.xuc, "instance_type")]
  disk_size       = contains(keys(var.eks_mng_map.xuc), "use_lt") ? null : lookup(var.eks_mng_map.xuc, "disk_size")

  dynamic "launch_template" {
    for_each = contains(keys(var.eks_mng_map.xuc), "use_lt")  ? toset([1]) : toset([])

    content {
      name = aws_launch_template.xuc_template[count.index].name
      version = aws_launch_template.xuc_template[count.index].latest_version
    }
  }

  labels = var.enable_tags ? local.node_pools_common_default_labels.xuc : tomap({
    "k8s.jfrog.com/dedicated_customer_nodepool" = "xuc"

  })

  scaling_config {
    desired_size = lookup(var.eks_mng_map.xuc, "desired_size", 1)
    max_size     = lookup(var.eks_mng_map.xuc, "max_size", 100)
    min_size     = lookup(var.eks_mng_map.xuc, "min_size", 1)
  }

  dynamic "remote_access" {
    for_each = try(var.eks_mng_map.override["remote_access_sg"], "false") != "false" ? toset([1]) : toset([])

    content {
      ec2_ssh_key = try(var.eks_mng_map.override["key_name"], var.deploy_name)
      source_security_group_ids = lookup(var.eks_mng_map.override, "remote_access_sg")
    }
  }

  tags = var.enable_tags ? local.node_pools_common_default_tags.xuc : {
    Environment = var.environment
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

##### xray-jobs (xj) node group #####
resource "aws_eks_node_group" "xray-jobs" {
  count           = contains(keys(var.eks_mng_map), "xj")  ? 1 : 0
  cluster_name    = aws_eks_cluster.aws_eks[0].name
  node_group_name = lookup(var.eks_mng_map.xj, "name", "xray-jobs" )
  node_role_arn   = aws_iam_role.eks_nodes[0].arn
  subnet_ids      = lookup(var.eks_mng_map.xj,"use_secondary_subnets",false) ? var.secondary_subnets : lookup(var.eks_mng_map.xj, "subnet_ids", var.subnets)
  instance_types  = contains(keys(var.eks_mng_map.xj), "use_lt") ? null : [lookup(var.eks_mng_map.xj, "instance_type")]
  disk_size       = contains(keys(var.eks_mng_map.xj), "use_lt") ? null : lookup(var.eks_mng_map.xj, "disk_size")

  dynamic "launch_template" {
    for_each = contains(keys(var.eks_mng_map.xj), "use_lt")  ? toset([1]) : toset([])

    content {
      name = aws_launch_template.xray_jobs_template[count.index].name
      version = aws_launch_template.xray_jobs_template[count.index].latest_version
    }
  }

  labels = var.enable_tags ? local.node_pools_common_default_labels.xj : tomap({
    "k8s.jfrog.com/app_type" = "xray-jobs"
  })
  scaling_config {
    desired_size = lookup(var.eks_mng_map.xj, "desired_size", 1)
    max_size     = lookup(var.eks_mng_map.xj, "max_size", 100)
    min_size     = lookup(var.eks_mng_map.xj, "min_size", 1)
  }

  dynamic "remote_access" {
    for_each = try(var.eks_mng_map.override["remote_access_sg"], "false") != "false" ? toset([1]) : toset([])

    content {
      ec2_ssh_key = try(var.eks_mng_map.override["key_name"], var.deploy_name)
      source_security_group_ids = lookup(var.eks_mng_map.override, "remote_access_sg")
    }
  }

  tags = var.enable_tags ? local.node_pools_common_default_tags.xj : {
    Environment = var.environment
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

##### wix dedicated node group #####
resource "aws_eks_node_group" "wix" {
  count           = contains(keys(var.eks_mng_map), "wix")  ? 1 : 0
  cluster_name    = aws_eks_cluster.aws_eks[0].name
  node_group_name = lookup(var.eks_mng_map.wix, "name", "wix" )
  node_role_arn   = aws_iam_role.eks_nodes[0].arn
  subnet_ids          = lookup(var.eks_mng_map.wix, "subnet_ids", var.subnets)
  instance_types  = contains(keys(var.eks_mng_map.wix), "use_lt") ? null : [lookup(var.eks_mng_map.wix, "instance_type")]
  disk_size       = contains(keys(var.eks_mng_map.wix), "use_lt") ? null : lookup(var.eks_mng_map.wix, "disk_size")

  dynamic "launch_template" {
    for_each = contains(keys(var.eks_mng_map.wix), "use_lt")  ? toset([1]) : toset([])

    content {
      name = aws_launch_template.wix_template[count.index].name
      version = aws_launch_template.wix_template[count.index].latest_version
    }
  }

  labels = var.enable_tags ? local.node_pools_common_default_labels.wix : tomap({
    "k8s.jfrog.com/dedicated_customer_nodepool" = "wix"
  })
  scaling_config {
    desired_size = lookup(var.eks_mng_map.wix, "desired_size", 1)
    max_size     = lookup(var.eks_mng_map.wix, "max_size", 100)
    min_size     = lookup(var.eks_mng_map.wix, "min_size", 1)
  }

  dynamic "remote_access" {
    for_each = try(var.eks_mng_map.override["remote_access_sg"], "false") != "false" ? toset([1]) : toset([])

    content {
      ec2_ssh_key = try(var.eks_mng_map.override["key_name"], var.deploy_name)
      source_security_group_ids = lookup(var.eks_mng_map.override, "remote_access_sg")
    }
  }

  tags = var.enable_tags ? local.node_pools_common_default_tags.wix : {
    Environment = var.environment
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

##### SonarQube dedicated node group #####
resource "aws_eks_node_group" "sonarqube" {
  count           = contains(keys(var.eks_mng_map), "sonarqube")  ? 1 : 0
  cluster_name    = aws_eks_cluster.aws_eks[0].name
  node_group_name = lookup(var.eks_mng_map.sonarqube, "name", "sonarqube" )
  node_role_arn   = aws_iam_role.eks_nodes[0].arn
  subnet_ids          = lookup(var.eks_mng_map.sonarqube, "subnet_ids", var.subnets)
  instance_types  = contains(keys(var.eks_mng_map.sonarqube), "use_lt") ? null : [lookup(var.eks_mng_map.sonarqube, "instance_type")]
  disk_size       = contains(keys(var.eks_mng_map.sonarqube), "use_lt") ? null : lookup(var.eks_mng_map.sonarqube, "disk_size")

  dynamic "launch_template" {
    for_each = contains(keys(var.eks_mng_map.sonarqube), "use_lt")  ? toset([1]) : toset([])

    content {
      name = aws_launch_template.sonarqube_template[count.index].name
      version = aws_launch_template.sonarqube_template[count.index].latest_version
    }
  }

  labels = var.enable_tags ? local.node_pools_common_default_labels.sonarqube : tomap({
    "k8s.jfrog.com/dedicated_customer_nodepool" = "sonarqube"
  })
  scaling_config {
    desired_size = lookup(var.eks_mng_map.sonarqube, "desired_size", 1)
    max_size     = lookup(var.eks_mng_map.sonarqube, "max_size", 100)
    min_size     = lookup(var.eks_mng_map.sonarqube, "min_size", 1)
  }

  dynamic "remote_access" {
    for_each = try(var.eks_mng_map.override["remote_access_sg"], "false") != "false" ? toset([1]) : toset([])

    content {
      ec2_ssh_key = try(var.eks_mng_map.override["key_name"], var.deploy_name)
      source_security_group_ids = lookup(var.eks_mng_map.override, "remote_access_sg")
    }
  }

  tags = var.enable_tags ? local.node_pools_common_default_tags.sonarqube : {
    Environment = var.environment
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

##### BitBucket dedicated node group #####
resource "aws_eks_node_group" "bitbucket" {
  count           = contains(keys(var.eks_mng_map), "bitbucket")  ? 1 : 0
  cluster_name    = aws_eks_cluster.aws_eks[0].name
  node_group_name = lookup(var.eks_mng_map.bitbucket, "name", "bitbucket" )
  node_role_arn   = aws_iam_role.eks_nodes[0].arn
  subnet_ids          = lookup(var.eks_mng_map.bitbucket, "subnet_ids", var.subnets)
  instance_types  = contains(keys(var.eks_mng_map.bitbucket), "use_lt") ? null : [lookup(var.eks_mng_map.bitbucket, "instance_type")]
  disk_size       = contains(keys(var.eks_mng_map.bitbucket), "use_lt") ? null : lookup(var.eks_mng_map.bitbucket, "disk_size")


  dynamic "launch_template" {
    for_each = contains(keys(var.eks_mng_map.bitbucket), "use_lt")  ? toset([1]) : toset([])

    content {
      name = aws_launch_template.bitbucket_template[count.index].name
      version = aws_launch_template.bitbucket_template[count.index].latest_version
    }
  }

  labels = var.enable_tags ? local.node_pools_common_default_labels.bitbucket : tomap({
    "k8s.jfrog.com/dedicated_customer_nodepool" = "bitbucket"
  })
  scaling_config {
    desired_size = lookup(var.eks_mng_map.bitbucket, "desired_size", 1)
    max_size     = lookup(var.eks_mng_map.bitbucket, "max_size", 100)
    min_size     = lookup(var.eks_mng_map.bitbucket, "min_size", 1)
  }

  dynamic "remote_access" {
    for_each = try(var.eks_mng_map.override["remote_access_sg"], "false") != "false" ? toset([1]) : toset([])

    content {
      ec2_ssh_key = try(var.eks_mng_map.override["key_name"], var.deploy_name)
      source_security_group_ids = lookup(var.eks_mng_map.override, "remote_access_sg")
    }
  }

  tags = var.enable_tags ? local.node_pools_common_default_tags.bitbucket : {
    Environment = var.environment
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

##### openEbs dedicated node group #####
resource "aws_eks_node_group" "openebs" {
  count           = contains(keys(var.eks_mng_map), "openebs")  ? 1 : 0
  cluster_name    = aws_eks_cluster.aws_eks[0].name
  node_group_name = lookup(var.eks_mng_map.openebs, "name", "oe01" )
  node_role_arn   = aws_iam_role.eks_nodes[0].arn
  subnet_ids          = lookup(var.eks_mng_map.openebs, "subnet_ids", var.subnets)
  instance_types  = contains(keys(var.eks_mng_map.openebs), "use_lt") ? null : [lookup(var.eks_mng_map.openebs, "instance_type")]
  disk_size       = contains(keys(var.eks_mng_map.openebs), "use_lt") ? null : lookup(var.eks_mng_map.openebs, "disk_size")


  dynamic "launch_template" {
    for_each = contains(keys(var.eks_mng_map.openebs), "use_lt")  ? toset([1]) : toset([])

    content {
      name = aws_launch_template.openebs_template[count.index].name
      version = aws_launch_template.openebs_template[count.index].latest_version
    }
  }

  labels = var.enable_tags ? local.node_pools_common_default_labels.openebs : tomap({
    "k8s.jfrog.com/app_type" = "openebs"
  })
  scaling_config {
    desired_size = lookup(var.eks_mng_map.openebs, "desired_size", 1)
    max_size     = lookup(var.eks_mng_map.openebs, "max_size", 100)
    min_size     = lookup(var.eks_mng_map.openebs, "min_size", 1)
  }

  dynamic "remote_access" {
    for_each = try(var.eks_mng_map.override["remote_access_sg"], "false") != "false" ? toset([1]) : toset([])

    content {
      ec2_ssh_key = try(var.eks_mng_map.override["key_name"], var.deploy_name)
      source_security_group_ids = lookup(var.eks_mng_map.override, "remote_access_sg")
    }
  }

  tags = var.enable_tags ? local.node_pools_common_default_tags.openebs : {
    Environment = var.environment
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

##### Jenkins dedicated node group #####
resource "aws_eks_node_group" "jenkins" {
  count           = contains(keys(var.eks_mng_map), "jenkins")  ? 1 : 0
  cluster_name    = aws_eks_cluster.aws_eks[0].name
  node_group_name = lookup(var.eks_mng_map.jenkins, "name", "jenkins" )
  node_role_arn   = aws_iam_role.eks_nodes[0].arn
  subnet_ids          = lookup(var.eks_mng_map.jenkins, "subnet_ids", var.subnets)
  instance_types  = contains(keys(var.eks_mng_map.jenkins), "use_lt") ? null : [lookup(var.eks_mng_map.jenkins, "instance_type")]
  disk_size       = contains(keys(var.eks_mng_map.jenkins), "use_lt") ? null : lookup(var.eks_mng_map.jenkins, "disk_size")

  dynamic "launch_template" {
    for_each = contains(keys(var.eks_mng_map.jenkins), "use_lt")  ? toset([1]) : toset([])

    content {
      name = aws_launch_template.jenkins_template[count.index].name
      version = aws_launch_template.jenkins_template[count.index].latest_version
    }
  }

  labels = var.enable_tags ? local.node_pools_common_default_labels.jenkins : tomap({
    "k8s.jfrog.com/dedicated_customer_nodepool" = "jenkins"
  })
  scaling_config {
    desired_size = lookup(var.eks_mng_map.jenkins, "desired_size", 1)
    max_size     = lookup(var.eks_mng_map.jenkins, "max_size", 100)
    min_size     = lookup(var.eks_mng_map.jenkins, "min_size", 1)
  }

  dynamic "remote_access" {
    for_each = try(var.eks_mng_map.override["remote_access_sg"], "false") != "false" ? toset([1]) : toset([])

    content {
      ec2_ssh_key = try(var.eks_mng_map.override["key_name"], var.deploy_name)
      source_security_group_ids = lookup(var.eks_mng_map.override, "remote_access_sg")
    }
  }

  tags = var.enable_tags ? local.node_pools_common_default_tags.jenkins : {
    Environment = var.environment
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

##### UTP dedicated node group #####
resource "aws_eks_node_group" "utp" {
  count           = contains(keys(var.eks_mng_map), "utp")  ? 1 : 0
  cluster_name    = aws_eks_cluster.aws_eks[0].name
  node_group_name = lookup(var.eks_mng_map.utp, "name", "utp" )
  node_role_arn   = aws_iam_role.eks_nodes[0].arn
  subnet_ids          = lookup(var.eks_mng_map.utp, "subnet_ids", var.subnets)
  instance_types  = contains(keys(var.eks_mng_map.utp), "use_lt") ? null : [lookup(var.eks_mng_map.utp, "instance_type")]
  disk_size       = contains(keys(var.eks_mng_map.utp), "use_lt") ? null : lookup(var.eks_mng_map.utp, "disk_size")

  dynamic "launch_template" {
    for_each = contains(keys(var.eks_mng_map.utp), "use_lt")  ? toset([1]) : toset([])

    content {
      name = aws_launch_template.utp_template[count.index].name
      version = aws_launch_template.utp_template[count.index].latest_version
    }
  }

  labels = var.enable_tags ? local.node_pools_common_default_labels.utp : tomap({
    "k8s.jfrog.com/dedicated_customer_nodepool" = "utp"
  })
  scaling_config {
    desired_size = lookup(var.eks_mng_map.utp, "desired_size", 1)
    max_size     = lookup(var.eks_mng_map.utp, "max_size", 100)
    min_size     = lookup(var.eks_mng_map.utp, "min_size", 1)
  }

  dynamic "remote_access" {
    for_each = try(var.eks_mng_map.override["remote_access_sg"], "false") != "false" ? toset([1]) : toset([])

    content {
      ec2_ssh_key = try(var.eks_mng_map.override["key_name"], var.deploy_name)
      source_security_group_ids = lookup(var.eks_mng_map.override, "remote_access_sg")
    }
  }

  tags = var.enable_tags ? local.node_pools_common_default_tags.utp : {
    Environment = var.environment
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

##### env0-agent (env0) node group #####
resource "aws_eks_node_group" "env0" {
  count           = contains(keys(var.eks_mng_map), "env0")  ? 1 : 0
  cluster_name    = aws_eks_cluster.aws_eks[0].name
  node_group_name = lookup(var.eks_mng_map.env0, "name", "env0" )
  node_role_arn   = aws_iam_role.eks_nodes[0].arn
  subnet_ids          = lookup(var.eks_mng_map.env0, "subnet_ids", var.subnets)
  instance_types  = contains(keys(var.eks_mng_map.env0), "use_lt") ? null : [lookup(var.eks_mng_map.env0, "instance_type")]
  disk_size       = contains(keys(var.eks_mng_map.env0), "use_lt") ? null : lookup(var.eks_mng_map.env0, "disk_size")

  dynamic "launch_template" {
    for_each = contains(keys(var.eks_mng_map.env0), "use_lt")  ? toset([1]) : toset([])

    content {
      name = aws_launch_template.env0_template[count.index].name
      version = aws_launch_template.env0_template[count.index].latest_version
    }
  }

  labels = var.enable_tags ? local.node_pools_common_default_labels.env0 : tomap({
    "k8s.jfrog.com/app_type" = "env0"
  })
  scaling_config {
    desired_size = lookup(var.eks_mng_map.env0, "desired_size", 1)
    max_size     = lookup(var.eks_mng_map.env0, "max_size", 30)
    min_size     = lookup(var.eks_mng_map.env0, "min_size", 1)
  }

  dynamic "remote_access" {
    for_each = try(var.eks_mng_map.override["remote_access_sg"], "false") != "false" ? toset([1]) : toset([])

    content {
      ec2_ssh_key = try(var.eks_mng_map.override["key_name"], var.deploy_name)
      source_security_group_ids = lookup(var.eks_mng_map.override, "remote_access_sg")
    }
  }

  tags = var.enable_tags ? local.node_pools_common_default_tags.env0 : {
    Environment = var.environment
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

##### devops node group #####
resource "aws_eks_node_group" "devops" {
  count           = contains(keys(var.eks_mng_map), "devops")  ? 1 : 0
  cluster_name    = aws_eks_cluster.aws_eks[0].name
  node_group_name = lookup(var.eks_mng_map.devops, "name", "devops" )
  node_role_arn   = aws_iam_role.eks_nodes[0].arn
  subnet_ids      = try(lookup(var.eks_mng_map.devops,"use_secondary_subnets",false),false) ? var.secondary_subnets : lookup(var.eks_mng_map.devops, "subnet_ids", var.subnets)
  instance_types  = contains(keys(var.eks_mng_map.devops), "use_lt") ? null : [lookup(var.eks_mng_map.devops, "instance_type")]
  disk_size       = contains(keys(var.eks_mng_map.devops), "use_lt") ? null : lookup(var.eks_mng_map.devops, "disk_size")

  dynamic "launch_template" {
    for_each = contains(keys(var.eks_mng_map.devops), "use_lt")  ? toset([1]) : toset([])

    content {
      name = aws_launch_template.devops_template[count.index].name
      version = aws_launch_template.devops_template[count.index].latest_version
    }
  }
   

  #labels = lookup(var.eks_mng_map.devops, "labels", null)
    labels = var.enable_tags ? local.node_pools_common_default_labels.devops : tomap({
  })

  scaling_config {
    desired_size = lookup(var.eks_mng_map.devops, "desired_size", 1)
    max_size     = lookup(var.eks_mng_map.devops, "max_size", 100)
    min_size     = lookup(var.eks_mng_map.devops, "min_size", 1)
  }


tags = var.enable_tags_devops ? local.node_pools_common_default_tags.devops : {
    environment = var.environment
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

# resource "aws_eks_node_group" "portworx_nodegroup" {
#   count           = contains(keys(var.eks_mng_map), "portworx")  ? 1 : 0
#   cluster_name    = aws_eks_cluster.aws_eks[0].name
#   node_group_name = lookup(var.eks_mng_map.portworx, "name", "portworx" )
#   node_role_arn   = aws_iam_role.eks_nodes[0].arn
#   subnet_ids      = lookup(var.eks_mng_map.portworx, "subnet_ids", var.subnets)
#   instance_types  = contains(keys(var.eks_mng_map.portworx), "use_lt") ? null : [lookup(var.eks_mng_map.devops, "instance_type")]
#   disk_size       = contains(keys(var.eks_mng_map.portworx), "use_lt") ? null : lookup(var.eks_mng_map.devops, "disk_size")

#   dynamic "launch_template" {
#     for_each = contains(keys(var.eks_mng_map.portworx), "use_lt")  ? toset([1]) : toset([])

#     content {
#       name = aws_launch_template.portworx_template[count.index].name
#       version = aws_launch_template.portworx_template[count.index].latest_version
#     }
#   }
   

#   labels = {
#   "portworx.io/node-type" = "storage"
#   "px/metadata-node" ="true"
#   }

#   scaling_config {
#     desired_size = lookup(var.eks_mng_map.portworx, "desired_size", 1)
#     max_size     = lookup(var.eks_mng_map.portworx, "max_size", 100)
#     min_size     = lookup(var.eks_mng_map.portworx, "min_size", 1)
#   }


#   tags = {
#     Environment = var.environment
#   }
  
#   # Ensure that IAM Role permissions are created before and deleted after EKS Node Group handling.
#   # Otherwise, EKS will not be able to properly delete EC2 Instances and Elastic Network Interfaces.
#   depends_on = [
#     aws_iam_role_policy_attachment.AmazonEKSWorkerNodePolicy,
#     aws_iam_role_policy_attachment.AmazonEKS_CNI_Policy,
#     aws_iam_role_policy_attachment.AmazonEC2ContainerRegistryReadOnly,
#   ]
#   lifecycle {
#     ignore_changes = [scaling_config[0].desired_size]
#   }
# }

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

resource "aws_iam_group" "k8s-admins" {
  count      = lookup(var.eks_mng_map.override, "create_k8s-admins_iam" , true) && var.module_enabled ? 1 : 0
  name = "KubernetesAdmins"
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
  depends_on = [aws_eks_cluster.aws_eks, aws_eks_node_group.freetier, aws_eks_node_group.node]

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
- userarn: arn:${var.aws_arn}:iam::${var.aws_account_id}:user/saas_deployer
  username: saas_deployer
  groups:
    - system:masters
YAML
  
  }
  lifecycle {
    ignore_changes = [data]
  }
}

data "template_file" "ft_nodegroup" {
  count = length(var.anitian_sshkey) > 0 ? 1 : 0
  template = file("${path.module}/freetier-v2-gov.sh")

  vars = {
    anitian_s3 = var.anitian_s3,
    anitian_sshkey = var.anitian_sshkey,
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

data "template_file" "xray_nodegroup" {
  count = length(var.anitian_sshkey) > 0 ? 1 : 0
  template = file("${path.module}/xray-jobs-v2-gov.sh")

  vars = {
    anitian_s3 = var.anitian_s3,
    anitian_sshkey = var.anitian_sshkey,
  }
}

resource "aws_launch_template" "mpnodes_template" {
  for_each  = { for k, v in  try(var.eks_mng_map.mpnodes.nodes,{}) : k => v }
  name_prefix = "terraform-"
  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      volume_size = lookup(each.value, "disk_size","500")
      volume_type = lookup(each.value,"volume_type", "gp3")
      iops        = lookup(each.value,"iops", "6000")
      throughput  = lookup(each.value,"throughput", "1000")
    }
  }
  instance_type = lookup(each.value, "instance_type")

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
      tags          = merge(local.node_pools_common_default_tags[each.key], var.launch_template_tags)
    }
  }
  user_data = filebase64("${path.module}/sh-scripts/${each.key}.sh")
}

resource "aws_launch_template" "freetier_template" {
  count       = try(var.eks_mng_map.ft["use_lt"],"false") != "false" ? 1 : 0
  name_prefix = "terraform-"
  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      volume_size = lookup(var.eks_mng_map.ft, "disk_size")
      volume_type = try(var.eks_mng_map.ft["volume_type"], null)
      iops        = try(var.eks_mng_map.ft["iops"], null)
      throughput  = try(var.eks_mng_map.ft["throughput"], null)
    }
  }

  instance_type = lookup(var.eks_mng_map.ft, "instance_type")
 
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
      tags          = merge(local.node_pools_common_default_tags.ft, var.launch_template_tags)
    }
  }
  user_data = length(var.anitian_sshkey) < 1 ? local.ft_user_data : base64encode("${data.template_file.ft_nodegroup[0].rendered}")
}
###################################################################################################
resource "aws_launch_template" "xuc_template" {
  count       = try(var.eks_mng_map.xuc["use_lt"],"false") != "false" ? 1 : 0
  name_prefix = "terraform-"
  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      volume_size = lookup(var.eks_mng_map.xuc, "disk_size")
      volume_type = try(var.eks_mng_map.xuc["volume_type"], null)
      iops        = try(var.eks_mng_map.xuc["iops"], null)
      throughput  = try(var.eks_mng_map.xuc["throughput"], null)
    }
  }

  instance_type = lookup(var.eks_mng_map.xuc, "instance_type")

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
      tags          = merge(local.node_pools_common_default_tags.xuc, var.launch_template_tags)
    }
  }
  user_data = filebase64("${path.module}/xuc.sh")
}




resource "aws_launch_template" "node_template" {
  count       = try(var.eks_mng_map.ng["use_lt"],"false") != "false" ? 1 : 0
  name_prefix = "terraform-"
  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      volume_size = lookup(var.eks_mng_map.ng, "disk_size")
      volume_type = try(var.eks_mng_map.ng["volume_type"], null)
      iops        = try(var.eks_mng_map.ng["iops"], null)
      throughput  = try(var.eks_mng_map.ng["throughput"], null)
    }
  }

  instance_type = lookup(var.eks_mng_map.ng, "instance_type")
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
  user_data = length(var.anitian_sshkey) < 1 ? local.ng_user_data : base64encode("${data.template_file.ng_nodegroup[0].rendered}")
}

resource "aws_launch_template" "xray_jobs_template" {
  count       = try(var.eks_mng_map.xj["use_lt"],"false") != "false" ? 1 : 0
  name_prefix = "terraform-"
  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      volume_size = lookup(var.eks_mng_map.xj, "disk_size")
      volume_type = try(var.eks_mng_map.xj["volume_type"], null)
      iops        = try(var.eks_mng_map.xj["iops"], null)
      throughput  = try(var.eks_mng_map.xj["throughput"], null)
    }
  }

  instance_type = lookup(var.eks_mng_map.xj, "instance_type")

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
      tags          = merge(local.node_pools_common_default_tags.xj, var.launch_template_tags)
    }
  }
  user_data = length(var.anitian_sshkey) < 1 ? local.xray_user_data : base64encode("${data.template_file.xray_nodegroup[0].rendered}")
}

resource "aws_launch_template" "env0_template" {
  count       = try(var.eks_mng_map.env0["use_lt"],"false") != "false" ? 1 : 0
  name_prefix = "terraform-"
  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      volume_size = lookup(var.eks_mng_map.env0, "disk_size")
      volume_type = try(var.eks_mng_map.env0["volume_type"], null)
      iops        = try(var.eks_mng_map.env0["iops"], null)
      throughput  = try(var.eks_mng_map.env0["throughput"], null)
    }
  }

  instance_type = lookup(var.eks_mng_map.env0, "instance_type")

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
      tags          = merge(local.node_pools_common_default_tags.env0, var.launch_template_tags)
    }
  }

  user_data = filebase64("${path.module}/env0.sh") 
}

resource "aws_launch_template" "devops_template" {
  count       = try(var.eks_mng_map.devops["use_lt"],"false") != "false" ? 1 : 0
  name_prefix = "terraform-"
  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      volume_size = lookup(var.eks_mng_map.devops, "disk_size")
      volume_type = try(var.eks_mng_map.devops["volume_type"], null)
      iops        = try(var.eks_mng_map.devops["iops"], null)
      throughput  = try(var.eks_mng_map.devops["throughput"], null)
    }
  }

  instance_type = lookup(var.eks_mng_map.devops, "instance_type")
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
      tags          = merge(local.node_pools_common_default_tags.devops, var.launch_template_tags)
    }
  }

    dynamic metadata_options {
    for_each = var.http_devops_endpoint ? [1] : [] 
    content {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
    }
  }
 
  user_data = contains(keys(var.eks_mng_map.override),"enable_v2_script") != true ? filebase64("${path.module}/devops.sh") : filebase64("${path.module}/devops-v2.sh")
}

resource "aws_launch_template" "portworx_template" {
  count       = try(var.eks_mng_map.portworx["use_lt"],"false") != "false" ? 1 : 0
  name_prefix = "terraform-"
  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      volume_size = lookup(var.eks_mng_map.portworx, "disk_size")
      volume_type = try(var.eks_mng_map.portworx["volume_type"], null)
      iops        = try(var.eks_mng_map.portworx["iops"], null)
      throughput  = try(var.eks_mng_map.portworx["throughput"], null)
    }
  }

  instance_type = lookup(var.eks_mng_map.portworx, "instance_type")
  //  image_id      = "ami-0210bddf620783a5e"
  key_name      = try(var.eks_mng_map.override["key_name"], var.deploy_name)

  dynamic "network_interfaces" {
    for_each = try(var.eks_mng_map.override["cluster_sg_ids"], "false") == "false"  ? toset([]) : toset([1])
    content {
      security_groups = try(var.eks_mng_map.override["cluster_sg_ids"], null)
    }
  }
  #   dynamic "tag_specifications" {
  #   for_each = contains(keys(var.eks_mng_map.override),"enable_lt_tags") == true ? toset(["instance", "volume"]) : []
  #   content {
  #     resource_type = tag_specifications.key
  #     tags          = merge(local.node_pools_common_default_tags.portworx, var.launch_template_tags)
  #   }
  # }
  user_data = filebase64("${path.module}/portworx.sh")
}

resource "aws_launch_template" "wix_template" {
  count       = try(var.eks_mng_map.wix["use_lt"],"false") != "false" ? 1 : 0
  name_prefix = "terraform-"
  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      volume_size = lookup(var.eks_mng_map.wix, "disk_size")
      volume_type = try(var.eks_mng_map.wix["volume_type"], null)
      iops        = try(var.eks_mng_map.wix["iops"], null)
      throughput  = try(var.eks_mng_map.wix["throughput"], null)
    }
  }

  instance_type = lookup(var.eks_mng_map.wix, "instance_type")
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
      tags          = merge(local.node_pools_common_default_tags.wix, var.launch_template_tags)
    }
  }
  user_data = contains(keys(var.eks_mng_map.override),"enable_v2_script") != true ? filebase64("${path.module}/wix.sh") : filebase64("${path.module}/wix-v2.sh")
}

resource "aws_launch_template" "sonarqube_template" {
  count       = try(var.eks_mng_map.sonarqube["use_lt"],"false") != "false" ? 1 : 0
  name_prefix = "terraform-"
  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      volume_size = lookup(var.eks_mng_map.sonarqube, "disk_size")
      volume_type = try(var.eks_mng_map.sonarqube["volume_type"], null)
      iops        = try(var.eks_mng_map.sonarqube["iops"], null)
      throughput  = try(var.eks_mng_map.sonarqube["throughput"], null)
    }
  }

  instance_type = lookup(var.eks_mng_map.sonarqube, "instance_type")
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
      tags          = merge(local.node_pools_common_default_tags.sonarqube, var.launch_template_tags)
    }
  }
  user_data = contains(keys(var.eks_mng_map.override),"enable_v2_script") != true ? filebase64("${path.module}/sonarqube.sh") : filebase64("${path.module}/sonarqube-v2.sh")
}

resource "aws_launch_template" "bitbucket_template" {
  count       = try(var.eks_mng_map.bitbucket["use_lt"],"false") != "false" ? 1 : 0
  name_prefix = "terraform-"
  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      volume_size = lookup(var.eks_mng_map.bitbucket, "disk_size")
      volume_type = try(var.eks_mng_map.bitbucket["volume_type"], null)
      iops        = try(var.eks_mng_map.bitbucket["iops"], null)
      throughput  = try(var.eks_mng_map.bitbucket["throughput"], null)
    }
  }
    block_device_mappings {
    device_name = "/dev/sdf"

    ebs {
      volume_size = lookup(var.eks_mng_map.bitbucket, "disk_size")
      volume_type = try(var.eks_mng_map.bitbucket["volume_type"], null)
      iops        = try(var.eks_mng_map.bitbucket["iops"], null)
      throughput  = try(var.eks_mng_map.bitbucket["throughput"], null)
    }
  }

  instance_type = lookup(var.eks_mng_map.bitbucket, "instance_type")
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
      tags          = merge(local.node_pools_common_default_tags.bitbucket, var.launch_template_tags)
    }
  }
  user_data = contains(keys(var.eks_mng_map.override),"enable_v2_script") != true ? filebase64("${path.module}/bitbucket.sh") : filebase64("${path.module}/bitbucket-v2.sh")
}

resource "aws_launch_template" "openebs_template" {
  count       = try(var.eks_mng_map.openebs["use_lt"],"false") != "false" ? 1 : 0
  name_prefix = "terraform-"
  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      volume_size = lookup(var.eks_mng_map.openebs, "disk_size")
      volume_type = try(var.eks_mng_map.openebs["volume_type"], null)
      iops        = try(var.eks_mng_map.openebs["iops"], null)
      throughput  = try(var.eks_mng_map.openebs["throughput"], null)
    }
  }
    block_device_mappings {
    device_name = "/dev/sdf"

    ebs {
      volume_size = lookup(var.eks_mng_map.openebs, "disk_size")
      volume_type = try(var.eks_mng_map.openebs["volume_type"], null)
      iops        = try(var.eks_mng_map.openebs["iops"], null)
      throughput  = try(var.eks_mng_map.openebs["throughput"], null)
    }
  }

  instance_type = lookup(var.eks_mng_map.openebs, "instance_type")
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
      tags          = merge(local.node_pools_common_default_tags.openebs, var.launch_template_tags)
    }
  }
  user_data = contains(keys(var.eks_mng_map.override),"enable_v2_script") != true ? filebase64("${path.module}/openebs.sh") : filebase64("${path.module}/openebs-v2.sh")
}



resource "aws_launch_template" "jenkins_template" {
  count       = try(var.eks_mng_map.jenkins["use_lt"],"false") != "false" ? 1 : 0
  name_prefix = "terraform-"
  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      volume_size = lookup(var.eks_mng_map.jenkins, "disk_size")
      volume_type = try(var.eks_mng_map.jenkins["volume_type"], null)
      iops        = try(var.eks_mng_map.jenkins["iops"], null)
      throughput  = try(var.eks_mng_map.jenkins["throughput"], null)
    }
  }

  instance_type = lookup(var.eks_mng_map.jenkins, "instance_type")
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
      tags          = merge(local.node_pools_common_default_tags.jenkins, var.launch_template_tags)
    }
  }
  user_data = contains(keys(var.eks_mng_map.override),"enable_v2_script") != true ? filebase64("${path.module}/jenkins.sh") : filebase64("${path.module}/jenkins-v2.sh")
}

resource "aws_launch_template" "utp_template" {
  count       = try(var.eks_mng_map.utp["use_lt"],"false") != "false" ? 1 : 0
  name_prefix = "terraform-"
  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      volume_size = lookup(var.eks_mng_map.utp, "disk_size")
      volume_type = try(var.eks_mng_map.utp["volume_type"], null)
      iops        = try(var.eks_mng_map.utp["iops"], null)
      throughput  = try(var.eks_mng_map.utp["throughput"], null)
    }
  }

  instance_type = lookup(var.eks_mng_map.utp, "instance_type")
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
      tags          = merge(local.node_pools_common_default_tags.utp, var.launch_template_tags)
    }
  }
  user_data = contains(keys(var.eks_mng_map.override),"enable_v2_script") != true ? filebase64("${path.module}/utp.sh") : filebase64("${path.module}/utp-v2.sh")
}

module "efs_csi" {
 count      = var.enable_efs_csi ? 1 : 0
 source                 = "./efs_csi"
  depends_on = [
     aws_eks_cluster.aws_eks,
     aws_eks_node_group.freetier,
     aws_eks_node_group.node
     ]
key_name               = lookup(var.eks_mng_map.override, "key_name")
deploy_name            = var.deploy_name  // add deploy name to sg ?
project_name           = var.project_name // add deploy name to sg ?
oicd                   = aws_iam_openid_connect_provider.open-id-connect[0]
file_system_id         = var.file_system_id
}


##### default node group (ng) paying customers #####
resource "aws_eks_node_group" "pipelines" {
  count           = contains(keys(var.eks_mng_map), "pipelines")  ? 1 : 0
  cluster_name    = aws_eks_cluster.aws_eks[0].name
  node_group_name = lookup(var.eks_mng_map.pipelines, "name", "${var.deploy_name}-ng-1" )
  node_role_arn   = aws_iam_role.eks_nodes[0].arn
  subnet_ids      = lookup(var.eks_mng_map.pipelines, "subnet_ids", var.subnets)
  instance_types  = contains(keys(var.eks_mng_map.pipelines), "use_lt") ? null : [lookup(var.eks_mng_map.pipelines, "instance_type")]
  disk_size       = contains(keys(var.eks_mng_map.pipelines), "use_lt") ? null : lookup(var.eks_mng_map.pipelines, "disk_size")

  dynamic "launch_template" {
    for_each = contains(keys(var.eks_mng_map.pipelines), "use_lt")  ? toset([1]) : toset([])

    content {
      name = aws_launch_template.pipelines_template[count.index].name
      version = aws_launch_template.pipelines_template[count.index].latest_version
    }
  }

  labels = var.enable_tags ? local.node_pools_common_default_labels.pipelines : tomap({
  })

  scaling_config {
    desired_size = lookup(var.eks_mng_map.pipelines, "desired_size", 1)
    max_size     = lookup(var.eks_mng_map.pipelines, "max_size", 100)
    min_size     = lookup(var.eks_mng_map.pipelines, "min_size", 1)
  }

  tags = var.enable_tags ? local.node_pools_common_default_tags.pipelines : {
    Environment = var.environment
  }
}

resource "aws_launch_template" "pipelines_template" {
  count           = contains(keys(var.eks_mng_map), "pipelines")  ? 1 : 0
  name_prefix = "terraform-"
  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      volume_size = lookup(var.eks_mng_map.pipelines, "disk_size")
      volume_type = try(var.eks_mng_map.pipelines["volume_type"], null)
      iops        = try(var.eks_mng_map.pipelines["iops"], null)
      throughput  = try(var.eks_mng_map.pipelines["throughput"], null)
    }
  }

  instance_type = lookup(var.eks_mng_map.pipelines, "instance_type")
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
      tags          = merge(local.node_pools_common_default_tags.pipelines, var.launch_template_tags)
    }
  }
  user_data =  filebase64("${path.module}/pipelines.sh")
}