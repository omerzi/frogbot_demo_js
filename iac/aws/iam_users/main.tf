resource "aws_iam_user" "iam_user" {
  name = var.user
  tags = {
    Name = var.user
    Managed_By = "Terraform"
  }
}

resource "aws_iam_access_key" "iam_user_key" {
  count = try(var.num_of_keys)
  user = aws_iam_user.iam_user.name
  status = "Active"
}