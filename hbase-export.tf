data "local_file" "hbase_snapshot_exporter_script" {
  filename = "files/hbase-snapshot-exporter.sh"
}

resource "aws_s3_bucket_object" "hbase_snapshot_exporter_script" {
  bucket     = data.terraform_remote_state.common.outputs.config_bucket.id
  key        = "component/hbase-exporter/hbase-snapshot-exporter.sh"
  content    = data.local_file.hbase_snapshot_exporter_script.content
  kms_key_id = data.terraform_remote_state.common.outputs.config_bucket_cmk.arn
}