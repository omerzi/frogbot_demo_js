resource "aws_iam_group" "jfrog_whitelist" {
  name = "JFrog-Whitelist"
}

resource "aws_iam_policy" "policy" {
  name        = "JFrog-Whitelist-policy"
  description = "A list of allowed IPs for high risk IAM users"
  policy = var.policy_file
  tags = {
    Name = "jfrog_whitelist_policy"
    Managed_By = "Terraform"
  }
}

resource "aws_iam_group_policy_attachment" "attach_policy_to_group" {
  group      = aws_iam_group.jfrog_whitelist.name
  policy_arn = aws_iam_policy.policy.arn
}

resource "aws_iam_group_membership" "jfrog_whitelist_Users" {
  name = "jfrog_whitelist_group_members"
  users = toset(var.users)
  group = aws_iam_group.jfrog_whitelist.name
}