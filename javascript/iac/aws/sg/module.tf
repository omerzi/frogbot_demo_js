resource "aws_security_group" "terraform_logstash_whitelist" {
  count       = var.module_enabled ? 1 : 0
  name        = "Terraform_logstash_whitelist"
  description = "Allow all JFrog NAT ips access logstash ELB"
  vpc_id      = var.logstash_vpc_id
  ingress {
    description      = "Logstash port from NAT ips"
    from_port        = var.from_port
    to_port          = var.to_port
    protocol         = "tcp"
    cidr_blocks      = var.cidr_blocks_list
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "Terraform_logstash_whitelist"
    Managed_By = "Terraform"
  }
}
