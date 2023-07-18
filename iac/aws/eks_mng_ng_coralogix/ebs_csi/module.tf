data "aws_iam_policy_document" "ebs-csi-assume_role_policy" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    principals {
      identifiers = [var.oicd.arn]
      type        = "Federated"
    }
  }
}

resource "aws_iam_role" "ebs-csi-controller" {
    name = "ebs-csi-controller-${var.key_name}"
    assume_role_policy = data.aws_iam_policy_document.ebs-csi-assume_role_policy.json
 
  }


resource "aws_iam_role_policy_attachment" "ebs-csi-controller-attach" {
    role       = aws_iam_role.ebs-csi-controller.name
    policy_arn = "arn:aws-us-gov:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"

  }
