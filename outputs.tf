output "hbase_export_bucket" {
  value = {
    id  = aws_s3_bucket.hbase_export_bucket.id
    arn = aws_s3_bucket.hbase_export_bucket.arn
  }
}