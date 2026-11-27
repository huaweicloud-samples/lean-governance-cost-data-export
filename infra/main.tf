provider "huaweicloud" {
  region = var.region
}

# ---------------------------------------------------------------------------
# 目的桶：接收费用中心「数据存储」每日推送的数据明细（CSV）
# 桶属性：私有、TLS 强制
# ---------------------------------------------------------------------------
resource "huaweicloud_obs_bucket" "bill_export" {
  bucket        = var.bucket_name
  acl           = "private"
  force_destroy = true # 调试/销毁友好：空桶即可删除（见 docs/obs-bucket-policy-gotchas.md）

  tags = {
    managed_by  = "terraform"
    purpose     = "cost-bill-export"
    name_prefix = var.name_prefix
  }
}

# ---------------------------------------------------------------------------
# 桶策略（OBS 策略格式，见 docs/obs-bucket-policy-gotchas.md）：
#   ① EnforceTLS —— 拒绝所有非 HTTPS 请求
#   ② AllowBillDelivery —— 授权账单投递服务以租户身份写入
# 注意：OBS 动作名为裸名（"*" / "PutObject" / "GetBucketPolicy"），
#       Resource 直接写桶名，Principal 用 {"ID":[...]}
# ---------------------------------------------------------------------------
locals {
  statements = concat(
    [
      {
        Sid       = "EnforceTLS"
        Effect    = "Deny"
        # OBS 的 Principal 需写成 {"ID": ["*"]}，裸 "*" 不被接受
        Principal = {
          ID = ["*"]
        }
        Action    = ["*"]
        Resource = [
          huaweicloud_obs_bucket.bill_export.bucket,
          "${huaweicloud_obs_bucket.bill_export.bucket}/*"
        ]
        # OBS 条件键为 SecureTransport，
        # 且值必须是字符串数组 ["false"]，不能是 JSON 布尔。否则报
        # MalformedPolicy: Policy has invalid condition（实测坑，见 docs/obs-bucket-policy-gotchas.md）
        Condition = {
          Bool = {
            "SecureTransport" = ["false"]
          }
        }
      }
    ],
    var.account_id != "" ? [
      {
        Sid    = "AllowBillDelivery"
        Effect = "Allow"
        Principal = {
          ID = ["domain/${var.account_id}:user/*"]
        }
        Action = [
          "PutObject",
          "GetBucketPolicy"
        ]
        Resource = [
          huaweicloud_obs_bucket.bill_export.bucket,
          "${huaweicloud_obs_bucket.bill_export.bucket}/*"
        ]
      }
    ] : []
  )
}

resource "huaweicloud_obs_bucket_policy" "bill_export" {
  bucket = huaweicloud_obs_bucket.bill_export.bucket
  policy = jsonencode({
    # OBS 桶策略 Version 必须为 2008-10-17，不接受 2018-10-17，
    # 否则报 MalformedPolicy: Invalid Version（实测坑，见 docs/obs-bucket-policy-gotchas.md）
    Version   = "2008-10-17"
    Statement = local.statements
  })
}
