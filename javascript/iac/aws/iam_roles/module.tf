resource "aws_iam_group_policy" "k8s-admins_policy" {
  name  = "KubernetesAdmin"
  group = aws_iam_group.k8s-admins.id

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
}

resource "aws_iam_group" "k8s-admins" {
  name = "KubernetesAdmins"
}

resource "aws_iam_role" "role-admin" {
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
}

resource "aws_iam_role" "pileus-role" {
  count = var.pileus_enabled ? 1 : 0 
  name = "CloudWatchAgentServerRole"
  description = "Allows EC2 instances to call AWS services on your behalf."

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "pileus-attach" {
  count = var.pileus_enabled ? 1 : 0 
  role       = aws_iam_role.pileus-role[0].name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}