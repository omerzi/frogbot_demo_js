resource "aws_security_group" "sdm" {
  count     =  contains(keys(var.sg_map),"sdm") ?  1 : 0 
  name        = "${var.deploy_name}-${var.region}-sdm"
  description = "Managed by Terraform"
  vpc_id      = var.vpc_id

  lifecycle {
    create_before_destroy = true
  }
    egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name        = "${var.deploy_name}-${var.region}-sdm"
    Environment = var.environment
    Terraform   = "true"
  }
}

resource "aws_security_group" "pl_monitoring" {
  count     =  contains(keys(var.sg_map),"pl_monitoring") ?  1 : 0 
  name        = "${var.deploy_name}-${var.region}-pl_monitoring"
  description = "Managed by Terraform"
  vpc_id      = var.vpc_id

  lifecycle {
    create_before_destroy = true
  }
    egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name        = "${var.deploy_name}-${var.region}-pl_monitoring"
    Environment = var.environment
    Terraform   = "true"
  }
}


# resource "aws_security_group" "sshproxy" {
#   count     =  contains(keys(var.sg_map),"sdm") ?  1 : 0 
#   name   = "${var.deploy_name}-${var.region}-sshproxy"
#   vpc_id = var.vpc_id

#   ingress {
#     from_port   = 22
#     to_port     = 22
#     protocol    = "tcp"
#     cidr_blocks = var.ingress_cidr_blocks
#   }

#   egress {
#     from_port   = 0
#     to_port     = 0
#     protocol    = "-1"
#     cidr_blocks = ["0.0.0.0/0"]
#   }

#   tags = {
#     Name = "${var.deploy_name}-${var.region}-sshproxy"
#   }
# }

resource "aws_security_group" "k8s" {
  count     =  contains(keys(var.sg_map),"k8s") ?  1 : 0 
  name        = "${var.deploy_name}-${var.region}-k8s"
  description = "Managed by Terraform"
  vpc_id      = var.vpc_id

  lifecycle {
    create_before_destroy = true
   
  }

    egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
  tags = {
    Name        = "${var.deploy_name}-${var.region}-k8s"
    Environment = var.environment
    Terraform   = "true"
  }

   depends_on = [
      aws_security_group.sdm[0]
    ]
}



resource "aws_security_group_rule" "k8s_ingress_rules_cidr" {
  count     =  contains(keys(var.sg_map),"k8s") && try(contains(keys(var.sg_map.k8s),"cidr_blocks"),false) ?  1 : 0 
  security_group_id = aws_security_group.k8s[0].id
  type            = "ingress"
  from_port       = lookup(var.sg_map.k8s.sg-rule,"from_port",443)
  to_port         = lookup(var.sg_map.k8s.sg-rule,"to_port",443)
  protocol        = lookup(var.sg_map.k8s.sg-rule,"protocol","tcp")
  cidr_blocks     = lookup(var.sg_map.k8s.sg-rule,"cidr_blocks",null)
}
resource "aws_security_group_rule" "k8s_ingress_rules_security_group" {
  count                      = contains(keys(var.sg_map),"k8s") ?  1 : 0 
  security_group_id          = aws_security_group.k8s[0].id
  type                       = "ingress"
  from_port                  = lookup(var.sg_map.k8s.sg-rule,"from_port",443)
  to_port                    = lookup(var.sg_map.k8s.sg-rule,"to_port",443)
  protocol                   = lookup(var.sg_map.k8s.sg-rule,"protocol","tcp")
  source_security_group_id   = aws_security_group.sdm[0].id
}
resource "aws_security_group_rule" "k8s_ingress_rules_self" {
  count     =  contains(keys(var.sg_map),"k8s") ?  1 : 0 
  security_group_id = aws_security_group.k8s[0].id
  type            = "ingress"
      from_port        = 0
    to_port          = 0
    protocol         = "-1"
  self            = lookup(var.sg_map.k8s.sg-rule,"self", true)
}


resource "aws_security_group_rule" "sshproxy_ingress_rules_cidr" {
  count     =  contains(keys(var.sg_map),"sdm") ?  1 : 0 
  security_group_id = aws_security_group.sdm[0].id
  type            = "ingress"
  from_port       = lookup(var.sg_map.sdm.sg-rule,"from_port",22)
  to_port         = lookup(var.sg_map.sdm.sg-rule,"to_port",22)
  protocol        = lookup(var.sg_map.sdm.sg-rule,"protocol","tcp")
  cidr_blocks     = var.ingress_cidr_blocks
}

resource "aws_security_group_rule" "sdm_ingress_rules_cidr" {
  count     =  contains(keys(var.sg_map),"sdm") ?  1 : 0 
  security_group_id = aws_security_group.sdm[0].id
  type            = "ingress"
  from_port       = lookup(var.sg_map.sdm.sg-rule,"from_port",5000)
  to_port         = lookup(var.sg_map.sdm.sg-rule,"to_port",5000)
  protocol        = lookup(var.sg_map.sdm.sg-rule,"protocol","tcp")
  cidr_blocks     = var.sdm_source_ranges
}


resource "aws_security_group_rule" "pl_monitoring_ingress_rule_cidr" {
  count                      = contains(keys(var.sg_map),"pl_monitoring") ?  1 : 0 
  security_group_id          = aws_security_group.pl_monitoring[0].id
  type                       = "ingress"
  from_port                  = lookup(var.sg_map.pl_monitoring.sg-rule,"from_port",443)
  to_port                    = lookup(var.sg_map.pl_monitoring.sg-rule,"to_port",443)
  protocol                   = lookup(var.sg_map.pl_monitoring.sg-rule,"protocol","tcp")
  cidr_blocks                = var.k8s_cidr_blocks
}