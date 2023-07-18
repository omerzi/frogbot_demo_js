locals {
  tags = {
    Terraform         = "true"
    Environment       = var.environment
    usedFor           = "PrivateLink"
  }
}

resource "aws_subnet" "privatelink" {
  count = data.null_data_source.local.inputs.enable_pl ? length(var.vpc_extra_pl_azs[var.region]) : 0

  vpc_id                          = var.vpc_id
  cidr_block                      = var.vpc_extra_pl_subnets[count.index]
  availability_zone               = var.vpc_extra_pl_azs[var.region][count.index]
  assign_ipv6_address_on_creation = false

  ipv6_cidr_block = null

  tags = merge(
  {
    "Name" = format(
    "%s-privatelink-%s",
    try(var.privatelink_map.BaseName, ""),
    element(var.vpc_extra_pl_azs[var.region], count.index),
    )
  },
  local.tags,
  )
}

resource "aws_route_table" "privatelink" {
  count = data.null_data_source.local.inputs.enable_pl ? length(var.vpc_extra_pl_azs[var.region]) : 0

  vpc_id = var.vpc_id

  tags = merge(
  {
    "Name" = format(
    "%s-pl-rtb-%s",
    try(var.privatelink_map.BaseName, ""),
    element(var.vpc_extra_pl_azs[var.region], count.index),
    )
  },
  local.tags,
  )
}

resource "aws_route_table_association" "privatelink" {
  count = data.null_data_source.local.inputs.enable_pl ? length(var.vpc_extra_pl_azs[var.region]) : 0

  subnet_id = element(aws_subnet.privatelink.*.id, count.index)
  route_table_id = element(aws_route_table.privatelink.*.id, count.index)

  depends_on = [
    aws_subnet.privatelink,
    aws_route_table.privatelink
  ]
}

