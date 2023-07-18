resource "aws_security_group" "anitian_allow_sg" {
  name   = "${var.deploy_name}-${var.region}-anitian-allow"
  vpc_id = var.vpc_id

  dynamic ingress {
    for_each    = var.anitian_port
    iterator    = anitian_port
    content {
    from_port   = anitian_port.value
    to_port     = anitian_port.value
    protocol    = "tcp"
    cidr_blocks = var.anitian_cidrs
    }
  }

  dynamic ingress {
    for_each    =  var.anitian_qualys != null ? [1] : []
    content {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = var.anitian_qualys
    }
  }

  dynamic egress {
    for_each    = var.anitian_port
    iterator    = anitian_port
    content {
    from_port   = anitian_port.value
    to_port     = anitian_port.value
    protocol    = "tcp"
    cidr_blocks = var.anitian_cidrs
    }
  }

  dynamic egress {
    for_each    =  var.anitian_qualys != null ? [1] : []
    content {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = var.anitian_qualys
    }
  }

  tags = {
    Name = "anitian_allow"
  }
}

resource "aws_iam_policy" "ec2_gov" {
    name     = "ec2_gov_setup"
    path     = "/"
    description = "creates policy needed for ec2 gov instances"
    policy =  jsonencode({
        Version = "2012-10-17"
        Statement = [
                {
            "Effect": "Allow",
            "Action": [
                "s3:ListBucket",
                "s3:GetObject"
            ],
            "Resource": [
                "arn:aws-us-gov:s3:::${var.anitian_s3}",
                "arn:aws-us-gov:s3:::${var.anitian_s3}/*"
            ]
        },
        {
            "Action"   = [
                "ssm:DescribeParameters",
                    ]
            "Effect"   = "Allow"
            "Resource" = "*"
        },
        {
            "Action"   = "ssm:GetParameter*"
            "Effect"   = "Allow"
            "Resource" = "*"
        },
        {
            "Action"   = [
                "secretsmanager:GetResourcePolicy",
                "secretsmanager:GetSecretValue",
                "secretsmanager:DescribeSecret",
                "secretsmanager:ListSecretVersionIds",
                "secretsmanager:GetRandomPassword",
                "secretsmanager:ListSecrets",
                    ]
            "Effect"   = "Allow"
            "Resource" = "arn:aws-us-gov:secretsmanager:*:${var.aws_account_id}:secret:*"
        },
        {
            "Action"   = "ssm:GetParameter*"
            "Effect"   = "Allow"
            "Resource" = "*"
        },
        ]
    })
}

resource "aws_iam_role" "ec2_gov" {
    name      = "ec2_gov_setup"
    assume_role_policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
       {
            Action = "sts:AssumeRole"
            Effect = "Allow"
            Sid = ""
            Principal = {
                Service = "ec2.amazonaws.com"
            }
        },
    ]
  })
}

resource "aws_iam_policy_attachment" "ec2_gov_policy_role" {
    name   = "ec2_gov_attachment"
    roles  = [aws_iam_role.ec2_gov.name,var.additional_role_attachemts]
    policy_arn = aws_iam_policy.ec2_gov.arn
}

resource "aws_iam_instance_profile" "ec2_gov_profile" {
    name    = "ec2_gov_profile"
    role    = aws_iam_role.ec2_gov.name
}