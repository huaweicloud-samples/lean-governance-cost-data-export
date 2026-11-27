variable "region" {
  description = "华为云区域（费用中心数据存储的 OBS 桶需与目标服务可达；一般用主账号所在 region）"
  type        = string
  default     = "cn-north-4"
}

variable "bucket_name" {
  description = "目的 OBS 桶名（全局唯一，DNS 合规；建议后缀租户账号 ID 以保证唯一）"
  type        = string
  default     = "hw-cur-filtered-export"
}

variable "bucket_prefix" {
  description = "账单文件在桶内的对象前缀"
  type        = string
  default     = "cost-export/"
}

variable "account_id" {
  description = "租户账号 ID（domain id）。非空时在桶策略中显式授权账单投递服务以租户身份写入；留空则投递权限由费用中心「验证」步骤自动授予"
  type        = string
  default     = ""
}

variable "name_prefix" {
  description = "资源命名/标签前缀，用于归属识别与按前缀清理"
  type        = string
  default     = "cur-filtered"
}
