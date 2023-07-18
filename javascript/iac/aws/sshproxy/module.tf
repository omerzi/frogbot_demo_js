#### without ASG (single instance) ####

resource "sdm_node" "gateway" {
  count = var.sdm_gateway ? 1 : 0
  gateway {
    name = "AWS-${var.deploy_name}-${var.region}"
    listen_address = "sshproxy-aws-${var.deploy_name}-${var.region}.jfrog.net:5000"
  }
}
data "template_file" "startup-script" {
  template = length(var.anitian_sg) > 0 ? file("${path.module}/files/${var.service_name}_bootstrap_gov.sh") : var.sdm_gateway ? file("${path.module}/files/${var.service_name}_bootstrap_include_sdm.sh") :  file("${path.module}/files/${var.service_name}_bootstrap.sh")

  vars = {
    token = try(sdm_node.gateway[0].gateway.0.token,null)
    sshkeys = join("\n",var.sshkeys),
    anitian_s3 = var.anitian_s3,
    anitian_sshkey = var.anitian_sshkey,
  }
}

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name = "name"

    values = [var.ami]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = [var.image_owner] # Canonical
}

resource "aws_eip" "sshproxy" {
  count = var.module_enabled ? "1" : "0"
  instance = join("", aws_instance.sshproxy.*.id)
  vpc   = true
}

resource "aws_instance" "sshproxy" {
  count                       = var.module_enabled ? "1" : "0"
  ami                         = var.asg_specified_ami == "" ? data.aws_ami.ubuntu.id : var.asg_specified_ami
  instance_type               = var.machine_type
  iam_instance_profile        = length(var.anitian_sg) > 0 ? var.ec2_instance_profile_name : ""
  user_data                   = data.template_file.startup-script.rendered
  vpc_security_group_ids      = var.sdm_security_group_id != null ? concat([var.sdm_security_group_id]) : concat(var.anitian_sg,var.vpc_security_group_override,aws_security_group.sdm.*.id,aws_security_group.sshproxy.*.id)
  key_name                    = var.key_name
  subnet_id                   = var.subnets[0]
  monitoring                  = var.detailed_monitoring
  ebs_optimized               = var.ebs_optimized
  user_data_replace_on_change = var.user_data_replace_on_change


  root_block_device {
    encrypted   = true
    volume_size           = "50"
    volume_type           = "gp3"
  }

  tags = {
    Name        = "${var.deploy_name}-${var.region}-${var.service_name}"
    Environment = var.environment
    Terraform   = "true"
  }
  lifecycle {
    ignore_changes = [
      ami
    ]
  }
}

resource "aws_security_group" "sdm" {
  count  = var.module_enabled && var.create_security_groups?  1 : 0
  name   = "${var.deploy_name}-${var.region}-sdm"
  vpc_id = var.vpc_id
  
  ingress {
    from_port   = "5000"
    to_port     = "5000"
    protocol    = "tcp"
    cidr_blocks = var.sdm_source_ranges
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.deploy_name}-${var.region}-sdm"
  }
}

resource "aws_security_group" "sshproxy" {
  count  = var.module_enabled && var.create_security_groups ? 1 : 0
  name   = "${var.deploy_name}-${var.region}-${var.service_name}"
  vpc_id = var.vpc_id

  ingress {
    from_port   = var.port
    to_port     = var.port
    protocol    = "tcp"
    cidr_blocks = var.ingress_cidr_blocks
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.deploy_name}-${var.region}-${var.service_name}"
  }
}

resource "aws_security_group" "builders" {
  count = var.module_enabled && (var.deploy_name == "builders" || var.create_builders_sg) ? 1 : 0
  name = "${var.deploy_name}-${var.region}-builders"
  vpc_id = var.vpc_id

  ingress {
    from_port = "22"
    to_port = "22"
    protocol = "tcp"
    security_groups = [
      aws_security_group.sshproxy[0].id]
  }

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = [
      "0.0.0.0/0"]
  }
  tags = {
    Name      = "${var.deploy_name}-${var.region}-builders"
    Terraform = "true"
  }
}

