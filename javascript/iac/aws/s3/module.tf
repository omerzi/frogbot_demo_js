data "aws_elb_service_account" "main" {
}

data "aws_kms_alias" "s3" {
  name = "alias/aws/s3"
}

resource "aws_s3_bucket" "default" {
  for_each = var.s3_buckets
  bucket = lookup(each.value, "bucket_name","")
  acl    = lookup(each.value, "acl","private")
  versioning {
    enabled = lookup(each.value,"versioning",true)
  }
  tags = {
    Name        = "${var.deploy_name}-${var.region}"
    Environment = var.environment
  }
//  tags = data.null_data_source.s3_tags[count.index].inputs
  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        kms_master_key_id = data.aws_kms_alias.s3.target_key_arn // The default aws/s3
        sse_algorithm     = "aws:kms"
      }
    }
  }
}

resource "aws_s3_bucket_public_access_block" "default" {
  for_each = var.s3_buckets
  bucket = lookup(each.value, "bucket_name", "")
  block_public_acls = lookup(each.value, "block_public_acls", "")
  block_public_policy = lookup(each.value, "block_public_policy", "")
  restrict_public_buckets = lookup(each.value, "restrict_public_buckets","")
  ignore_public_acls = lookup(each.value, "ignore_public_acls","")
}

//data "null_data_source" "s3_tags" {
//  count    = var.module_enabled ? 1 : 0
//  inputs = {
//    cloud_project = lower(var.project_name)
//    name          = lower("${var.deploy_name}-${var.region}")
//    environment   = lower(var.environment)
//    jfrog_region  = lower(var.narcissus_domain_short)
//    cloud_region  = lower(var.region)
//    owner         = lower(contains(keys(var.s3_tags), "owner") ? var.s3_tags["owner"] : "devops")
//    customer      = lower(contains(keys(var.s3_tags), "customer") ? var.s3_tags["customer"] : "shared")
//    purpose       = lower(contains(keys(var.s3_tags), "purpose") ? var.s3_tags["purpose"] : "all-jfrog-apps")
//    workload_type = lower(contains(keys(var.s3_tags), "workload_type") ? var.s3_tags["workload_type"] : "main")
//    application   = lower(contains(keys(var.s3_tags), "application") ? var.s3_tags["application"]: "all")
//  }
//}

//  acl    = var.acl
//
//  versioning {
//    enabled = var.versioning
//  }
//
//
//resource "aws_s3_bucket_public_access_block" "bucket" {
//  count  = var.module_enabled ? 1 : 0
//  bucket = aws_s3_bucket.default[count.index].id
//
//  block_public_acls   = true
//  block_public_policy = true
//  ignore_public_acls  = true
//  restrict_public_buckets = true
//}
//
//resource "aws_s3_bucket_object" "folder" {
//  count  = var.module_enabled ? 1 : 0
//  bucket = aws_s3_bucket.default[0].id
//  acl    = "private"
//  key    = "elb/logs/"
//  source = "/dev/null"
//}

//resource "aws_s3_bucket_policy" "policy" {
//  count  = var.module_enabled ? 1 : 0
//  bucket = aws_s3_bucket.default[0].id
//
//  policy = <<POLICY
//{
//  "Version": "2012-10-17",
//  "Statement": [
//    {
//      "Effect": "Allow",
//      "Principal": {
//        "AWS": "${data.aws_elb_service_account.main.arn}"
//      },
//      "Action": "s3:PutObject",
//      "Resource": "arn:aws:s3:::${aws_s3_bucket.default[0].id}/elb/logs/*"
//    }
//  ]
//}
//POLICY

//  lifecycle {
//    ignore_changes = [
//      policy
//    ]
//  }
//}
