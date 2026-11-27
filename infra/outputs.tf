output "bucket_name" {
  description = "数据归档目的桶名称"
  value       = huaweicloud_obs_bucket.bill_export.bucket
}

output "bucket_policy" {
  description = "生效的 OBS 桶策略（JSON）"
  value       = huaweicloud_obs_bucket_policy.bill_export.policy
}
