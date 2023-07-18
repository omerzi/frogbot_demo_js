data "tls_certificate" "eks-tls-certiciate" {
  count = var.create_oidc ? 1 : 0 
  url = aws_eks_cluster.aws_eks[0].identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "open-id-connect" {
  count = var.create_oidc ? 1 : 0 
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks-tls-certiciate[0].certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.aws_eks[0].identity[0].oidc[0].issuer
}


data "aws_iam_policy_document" "ebs-csi-assume-role-policy" {
  count = var.create_ebs_csi_driver ? 1 : 0 
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    condition {
      test     = "StringEquals"
      variable = "${replace(aws_iam_openid_connect_provider.open-id-connect[0].url, "https://", "")}:sub"
      values   = ["system:serviceaccount:kube-system:ebs-csi-controller-sa"]
    }

    principals {
      identifiers = [aws_iam_openid_connect_provider.open-id-connect[0].arn]
      type        = "Federated"
    }
  }
}

resource "aws_iam_role_policy_attachment" "ebs-csi-policy-attachment" {
  count = var.create_ebs_csi_driver ? 1 : 0 
  role       = aws_iam_role.ebs-csi-role[0].name
  policy_arn = aws_iam_policy.ebs-csi-driver-policy[0].arn
}

resource "aws_iam_role" "ebs-csi-role" {
  count = var.create_ebs_csi_driver ? 1 : 0 
  assume_role_policy = data.aws_iam_policy_document.ebs-csi-assume-role-policy[0].json
  name               = "ebs-csi-role-${var.deploy_name}"
}

resource "aws_iam_policy" "ebs-csi-driver-policy" {
  count = var.create_ebs_csi_driver ? 1 : 0 
  name   = "ebs-csi-policy-${var.deploy_name}"
  policy = data.aws_iam_policy_document.ebs-controller-policy-doc[0].json
}

data "aws_iam_policy_document" "ebs-controller-policy-doc" {
  count = var.create_ebs_csi_driver ? 1 : 0 
  statement {
    effect    = "Allow"
    resources = ["*"]
    actions = [
      "ec2:AttachVolume",
      "ec2:CreateSnapshot",
      "ec2:CreateTags", 
      "ec2:CreateVolume",
      "ec2:DeleteSnapshot",
      "ec2:DeleteTags",
      "ec2:DeleteVolume",
      "ec2:DescribeInstances",
      "ec2:DescribeSnapshots",
      "ec2:DescribeTags",
      "ec2:DescribeVolumes",
      "ec2:DetachVolume",
      "ec2:ModifyVolume",
      "ec2:DescribeAvailabilityZones",
      "ec2:DescribeVolumesModifications"
    ]
  }
}