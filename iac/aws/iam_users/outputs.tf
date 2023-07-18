output "aws_access_key_id" {
  value = element(concat(aws_iam_access_key.iam_user_key.*.id, [""]), 0)
}

output "aws_access_secret_key" {
  value = element(concat(aws_iam_access_key.iam_user_key.*.secret, [""]), 0)
}