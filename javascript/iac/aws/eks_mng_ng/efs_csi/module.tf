data "aws_iam_policy_document" "efs-csi-assume_role_policy" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    condition {
      test     = "StringEquals"
      variable = "${replace(var.oicd.url, "https://", "")}:sub"
      values   = ["system:serviceaccount:jfrog-saas-csi:efs-csi-controller-sa"]
    }

    principals {
      identifiers = [var.oicd.arn]
      type        = "Federated"
    }
  }
}

resource "aws_iam_role" "efs-csi-controller" {
    name = "efs-csi-controller-${var.key_name}"
    assume_role_policy = data.aws_iam_policy_document.efs-csi-assume_role_policy.json
 
  }

resource "aws_iam_policy" "efs-csi-controller-policy" {
    name = "efs-csi-controller-policy-${var.key_name}"
    description = "Allows the CSI driver's service account to make calls to AWS APIs"
    policy = <<EOF
{
   "Version": "2012-10-17",
   "Statement": [
     {
       "Effect": "Allow",
       "Action": [
         "elasticfilesystem:DescribeAccessPoints",
         "elasticfilesystem:DescribeFileSystems",
         "elasticfilesystem:DescribeMountTargets",
         "ec2:DescribeAvailabilityZones"
       ],
       "Resource": "*"
     },
     {
       "Effect": "Allow",
       "Action": [
         "elasticfilesystem:CreateAccessPoint"
       ],
       "Resource": "*",
       "Condition": {
         "StringLike": {
           "aws:RequestTag/efs.csi.aws.com/cluster": "true"
         }
       }
     },
     {
       "Effect": "Allow",
       "Action": "elasticfilesystem:DeleteAccessPoint",
       "Resource": "*",
       "Condition": {
         "StringEquals": {
           "aws:ResourceTag/efs.csi.aws.com/cluster": "true"
         }
       }
     }
   ]
}
 EOF

  }

resource "aws_iam_role_policy_attachment" "efs-csi-controller-attach" {
    role       = aws_iam_role.efs-csi-controller.name
    policy_arn = aws_iam_policy.efs-csi-controller-policy.arn

  }

resource "kubernetes_namespace" "efs-csi" {
  depends_on = [aws_iam_role_policy_attachment.efs-csi-controller-attach]
  metadata {
    name = "jfrog-saas-csi"
  }
}
resource "kubernetes_service_account" "eks_sa" {
  depends_on = [kubernetes_namespace.efs-csi]
  metadata {
    name = "efs-csi-controller-sa"
    namespace = "jfrog-saas-csi" // confirm on a differen unique ns jfrog-saas-*
    annotations = {
      "eks.amazonaws.com/role-arn" = "${aws_iam_role.efs-csi-controller.arn}"
    }
  }
  automount_service_account_token = true
}

 resource "kubernetes_storage_class" "efs-storage_class" {
  depends_on =[kubernetes_service_account.eks_sa,]
  metadata {
    name = "efs-sc"
  }
  storage_provisioner = "efs.csi.aws.com"
  reclaim_policy      = "Retain"
  parameters = {
    fileSystemId = "${var.file_system_id}"
    provisioningMode="efs-ap"
    directoryPerms = "700"
  }  
}