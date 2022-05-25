output "hbase_export_bucket" {
  value = {
    id  = aws_s3_bucket.hbase_export_bucket.id
    arn = aws_s3_bucket.hbase_export_bucket.arn
  }
}

output "hbase_snapshot_exporter_script" {
  value = "s3://${data.terraform_remote_state.common.outputs.config_bucket.id}/${aws_s3_bucket_object.hbase_snapshot_exporter_script.key}"
}