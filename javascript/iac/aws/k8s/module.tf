data "aws_eks_cluster" "cluster" {
  count = var.module_enabled ? 1 : 0
  name  = module.eks.cluster_id
}

data "aws_eks_cluster_auth" "cluster" {
  count = var.module_enabled ? 1 : 0
  name  = module.eks.cluster_id
}

# In case of not creating the cluster, this will be an incompletely configured, unused provider, which poses no problem.
provider "kubernetes" {
  host                   = element(concat(data.aws_eks_cluster.cluster[*].endpoint, list("")), 0)
  cluster_ca_certificate = base64decode(element(concat(data.aws_eks_cluster.cluster[*].certificate_authority.0.data, list("")), 0))
  token                  = element(concat(data.aws_eks_cluster_auth.cluster[*].token, list("")), 0)
  load_config_file       = false
  version                = "~> 1.11"
}

module "eks" {
  source          = "./module2"
  create_eks      = var.module_enabled
  cluster_version = var.cluster_version
  cluster_name    = "${var.deploy_name}-${var.region}"
  subnets         = var.subnets
  //target_group_arns = "" // TODO : Add NLB ARN from Net output PrivateLink.pl_nlb_arn
  tags = {
    "Environment" = var.environment
  }
  write_kubeconfig = "false"
  vpc_id           = var.vpc_id
//  map_users_count  = "1"
//  map_roles_count  = "1"

//  worker_group_count = var.worker_group_count
  worker_groups = [
    {
      asg_desired_capacity = var.asg_desired_capacity
      asg_min_size         = var.asg_min_size
      asg_max_size         = var.asg_max_size
      instance_type        = var.instance_type
      key_name             = var.key_name
      name                 = "worker"
      root_volume_size     = var.root_volume_size
      autoscaling_enabled  = true
      kubelet_extra_args   = "--node-labels=worker_group=worker --kube-reserved cpu=250m,memory=1000Mi --system-reserved cpu=250m,memory=200Mi"
      additional_userdata  = "yum install -y iptables-services ; iptables --insert FORWARD 1 --in-interface eni+ --destination 169.254.169.254/32 --jump DROP ; iptables-save | tee /etc/sysconfig/iptables ; systemctl enable --now iptables"
    },
    {
      asg_desired_capacity = var.asg_desired_capacity
      asg_min_size         = var.asg_min_size
      asg_max_size         = var.asg_max_size
      instance_type        = var.instance_type
      key_name             = var.key_name
      name                 = "management"
      root_volume_size     = "100"
      autoscaling_enabled  = true
      kubelet_extra_args   = "--node-labels=worker_group=management --register-with-taints=dedicated=management:NoSchedule --kube-reserved cpu=250m,memory=1000Mi --system-reserved cpu=250m,memory=200Mi"
      additional_userdata  = "yum install -y iptables-services ; iptables --insert FORWARD 1 --in-interface eni+ --destination 169.254.169.254/32 --jump DROP ; iptables-save | tee /etc/sysconfig/iptables ; systemctl enable --now iptables"
    },
    {
      asg_desired_capacity = var.asg_desired_capacity
      asg_min_size         = var.asg_min_size
      asg_max_size         = var.asg_max_size
      instance_type        = "c5.xlarge"
      key_name             = var.key_name
      name                 = "frontend"
      root_volume_size     = "100"
      autoscaling_enabled  = true
      kubelet_extra_args   = "--node-labels=worker_group=frontend --register-with-taints=dedicated=frontend:NoSchedule --kube-reserved cpu=250m,memory=1000Mi --system-reserved cpu=250m,memory=200Mi"
      additional_userdata  = "yum install -y iptables-services ; iptables --insert FORWARD 1 --in-interface eni+ --destination 169.254.169.254/32 --jump DROP ; iptables-save | tee /etc/sysconfig/iptables ; systemctl enable --now iptables"
    },
  ]
  map_roles = [
    {
      rolearn  = "arn:aws:iam::${var.aws_account_id[var.environment]}:role/KubernetesAdmin"
      username = "kubernetes-admin"
      groups    = ["system:masters"]
    },
  ]
  map_users = [
    {
      userarn  = "arn:aws:iam::${var.aws_account_id[var.environment]}:user/saas_deployer"
      username = "saas_deployer"
      groups   = ["system:masters"]
    },
  ]
}

//data "aws_eks_cluster_auth" "k8s" {
//  name = "${var.deploy_name}-${var.region}"
//}
