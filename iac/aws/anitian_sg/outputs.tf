output "anitian_allow_sg" {
    value = [aws_security_group.anitian_allow_sg.id]
}

output "ec2_instance_profile_name" {
  value  = aws_iam_instance_profile.ec2_gov_profile.name
}

