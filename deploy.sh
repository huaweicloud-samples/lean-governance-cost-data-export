#!/usr/bin/env bash
# ============================================================================
# deploy.sh —— 部署「明细数据按账号筛选归档到 OBS」华为云实践
#
# 本脚本用 Terraform 创建 OBS 桶+桶策略，并指引在
# 费用中心开启「数据存储」（该步骤含短信验证，故为控制台步骤）。
#
# 用法：
#   ./deploy.sh --bucket <obs-bucket-name> [--prefix cost-export/] \
#               [--region cn-north-4] [--apply] [--accounts-file accounts.csv]
# ============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
INFRA_DIR="$SCRIPT_DIR/infra"
ACCOUNTS_FILE="$SCRIPT_DIR/accounts.csv"
BUCKET=""
PREFIX="cost-export/"
REGION="cn-north-4"
APPLY="false"

usage() {
  echo "Usage: $0 --bucket <obs-bucket-name> [options]"
  echo ""
  echo "Required:"
  echo "  --bucket     目的 OBS 桶名（全局唯一）"
  echo ""
  echo "Optional:"
  echo "  --prefix     桶内对象前缀 (default: cost-export/)"
  echo "  --region     华为云区域 (default: cn-north-4)"
  echo "  --accounts-file  成员账号列表 CSV (default: accounts.csv)"
  echo "  --apply      执行 terraform apply（默认仅 init+plan，避免误计费）"
  echo "  --help       显示帮助"
  exit 1
}

while [[ $# -gt 0 ]]; do
  case $1 in
    --bucket) BUCKET="$2"; shift 2 ;;
    --prefix) PREFIX="$2"; shift 2 ;;
    --region) REGION="$2"; shift 2 ;;
    --accounts-file) ACCOUNTS_FILE="$2"; shift 2 ;;
    --apply) APPLY="true"; shift ;;
    --help) usage ;;
    *) echo "Unknown option: $1"; usage ;;
  esac
done

if [[ -z "$BUCKET" ]]; then
  echo "ERROR: --bucket is required"
  usage
fi

# --------------------------------------------------------------------------
# 1) 读取并校验 accounts.csv（统一核算成员账号，仅作范围说明；真正的
#    账号筛选在费用中心「数据存储 → 保存统一核算成员账号的账单 = 是」完成）
# --------------------------------------------------------------------------
if [[ -f "$ACCOUNTS_FILE" ]]; then
  ACCOUNT_IDS=()
  while IFS=, read -r account_id _rest; do
    account_id="$(echo "$account_id" | tr -d '[:space:]' | tr -d '"')"
    if [[ "$account_id" =~ ^[0-9]{12}$ || "$account_id" =~ ^[a-f0-9]{32}$ ]]; then
      ACCOUNT_IDS+=("$account_id")
    fi
  done < "$ACCOUNTS_FILE"

  if [[ ${#ACCOUNT_IDS[@]} -gt 0 ]]; then
    echo "范围内成员账号（统一核算下将被推送账单）："
    printf "  - %s\n" "${ACCOUNT_IDS[@]}"
  else
    echo "WARNING: accounts.csv 未解析到有效账号 ID（12 位账号或 32 位 domain id）。"
  fi
else
  echo "WARNING: 未找到 $ACCOUNTS_FILE，按全部统一核算成员账号处理。"
fi

# --------------------------------------------------------------------------
# 2) Terraform init（离线优先：若设置 TF_CLI_CONFIG_FILE 则走本地 provider 镜像）
# --------------------------------------------------------------------------
echo ""
echo "Terraform 工作目录: $INFRA_DIR"
cd "$INFRA_DIR"

if [[ -n "${TF_CLI_CONFIG_FILE:-}" ]]; then
  echo "[init] 使用本地 provider 镜像（离线）: $TF_CLI_CONFIG_FILE"
else
  echo "[init] 未设置 TF_CLI_CONFIG_FILE，将尝试默认 registry（如需离线见 deployment-guide）"
fi

terraform init -input=false

# --------------------------------------------------------------------------
# 3) plan / apply
# --------------------------------------------------------------------------
echo ""
echo "Planning..."
terraform plan \
  -var="bucket_name=$BUCKET" \
  -var="bucket_prefix=$PREFIX" \
  -var="region=$REGION"

if [[ "$APPLY" == "true" ]]; then
  echo ""
  echo "Applying..."
  terraform apply -auto-approve \
    -var="bucket_name=$BUCKET" \
    -var="bucket_prefix=$PREFIX" \
    -var="region=$REGION"
else
  echo ""
  echo "已完成 init+plan（未执行 apply）。确认无误后加 --apply 执行，或手动："
  echo "  terraform apply -var=\"bucket_name=$BUCKET\" -var=\"bucket_prefix=$PREFIX\" -var=\"region=$REGION\""
fi

# --------------------------------------------------------------------------
# 4) 控制台开启「数据存储」（等价启用 BCM Data Exports）
# --------------------------------------------------------------------------
cat << EOF

============================================================================
  下一步：在费用中心开启「数据存储」（账单按日推送到 OBS）
  （该步骤含短信验证，无法纯 API 化，需在控制台完成）
----------------------------------------------------------------------------
  1. 登录华为云控制台 → 费用中心 → 数据存储（Expenditure Data Storage）。
  2. 设置「存储桶」为上一步创建的桶：$BUCKET
  3. 点击「验证」，验证通过后勾选要导出的账单类型（建议勾选
     「资源账单 / 明细账单」）。
  4. 若当前账号为【统一核算主账号】，将
     「保存统一核算成员账号的账单」设为【是】——
     按账号筛选后，仅将指定成员账号的数据推送到本桶。
  5. 点击「获取验证码」→ 输入短信验证码 → 确定，开启订阅。
  6. 开启后，华为云每天 18:30 将账单文件推送到桶（建议 20:00 后取数）。

  验证投递是否生效（每天推送后）：
     python3 ../src/subscription/verify_bills.py \\
        --bucket $BUCKET --prefix $PREFIX
============================================================================
EOF
