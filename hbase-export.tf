data "local_file" "hbase_snapshot_exporter_script" {
  filename = "files/hbase-snapshot-exporter.sh"
}

resource "aws_s3_bucket_object" "hbase_snapshot_exporter_script" {
  bucket     = data.terraform_remote_state.common.outputs.config_bucket.id
  key        = "component/hbase-exporter/hbase-snapshot-exporter.sh"
  content    = data.local_file.hbase_snapshot_exporter_script.content
  kms_key_id = data.terraform_remote_state.common.outputs.config_bucket_cmk.arn
}

data "aws_iam_policy_document" "hbase_export_s3_key_policy" {
  statement {
    sid = "Enable IAM User Permissions"
    effect = "Allow"

    principals {
      type = "AWS"
      identifiers = ["arn:aws:iam::${local.account[local.environment]}:root"]
    }

    actions = ["kms:*"]

    resources = ["*"]
  }

  statement {
    sid = "Allow Cross Account HBASE Ingest EMR Decrypt"
    effect = "Allow"

    principals {
      type = "AWS"
      identifiers = local.cross_account_roles
    }

    actions = ["kms:decrypt"]

    resources = ["*"]
  }
}

resource "aws_kms_key" "hbase_export_s3" {
  description             = "hbase-export-s3"
  enable_key_rotation     = true
  deletion_window_in_days = 7

  policy = data.aws_iam_policy_document.hbase_export_s3_key_policy.json

  tags = { "Name" = "hbase-export-bucket", "ProtectSensitiveData" = "True" }

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_kms_alias" "hbase_export_s3" {
  name          = "alias/hbase-export/hbase-export-s3"
  target_key_id = aws_kms_key.hbase_export_s3.id

  lifecycle {
    prevent_destroy = true
  }
}

resource "random_id" "hbase_export_bucket_name" {
  byte_length = 16
}

resource "aws_s3_bucket" "hbase_export_bucket" {
  bucket = random_id.hbase_export_bucket_name.hex
  acl    = "private"

  tags = { "Name" = "hbase-export-bucket" }

  versioning {
    enabled = false
  }

  lifecycle_rule {
    id      = ""
    prefix  = "/"
    enabled = true
    expiration {
      days = 30
    }
  }

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        kms_master_key_id = aws_kms_alias.hbase_export_s3.arn
        sse_algorithm     = "aws:kms"
      }
    }
  }
}

resource "aws_s3_bucket_public_access_block" "hbase_export" {
  bucket = aws_s3_bucket.hbase_export_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  restrict_public_buckets = true
  ignore_public_acls      = true
}

data "aws_iam_policy_document" "hbase_export_bucket_policy" {
  statement {
    sid     = "BlockHTTP"
    effect  = "Deny"
    actions = ["*"]

    resources = [
      aws_s3_bucket.hbase_export_bucket.arn,
      "${aws_s3_bucket.hbase_export_bucket.arn}/*",
    ]

    principals {
      identifiers = ["*"]
      type        = "AWS"
    }

    condition {
      test     = "Bool"
      values   = ["false"]
      variable = "aws:SecureTransport"
    }
  }

  statement {
    principals {
      type        = "AWS"
      identifiers = local.cross_account_roles
    }

    actions = [
      "s3:GetObject",
      "s3:ListBucket",
    ]

    resources = [
      data.terraform_remote_state.hbase_export.outputs.hbase_export_bucket.arn,
      "${data.terraform_remote_state.hbase_export.outputs.hbase_export_bucket.arn}/*",
    ]
  }
}

resource "aws_s3_bucket_policy" "hbase_export_bucket_policy" {
  depends_on = [aws_s3_bucket.hbase_export_bucket]
  bucket     = aws_s3_bucket.hbase_export_bucket.id
  policy     = data.aws_iam_policy_document.hbase_export_bucket_policy.json
}

data "aws_iam_policy_document" "hbase_s3_export" {
  statement {
    sid    = "PutExportBucket"
    effect = "Allow"

    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:DescribeKey",
    ]

    resources = [
      aws_kms_key.hbase_export_s3.arn,
    ]
  }
}

resource "aws_iam_policy" "hbase_s3_export" {
  name        = "IngestHbaseS3Export"
  description = "Allow Ingestion EMR cluster to export HBASE tables to the export bucket"
  policy      = data.aws_iam_policy_document.hbase_s3_export.json
}

resource "aws_iam_role_policy_attachment" "emr_ingest_hbase_main" {
  role       = data.terraform_remote_state.internal_compute.outputs.emr_instance_role.id
  policy_arn = aws_iam_policy.hbase_s3_export.arn
}
