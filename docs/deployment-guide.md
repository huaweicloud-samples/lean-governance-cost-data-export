# 部署指导书

> **部署状态（2026-08-14）**：基础设施已通过 `terraform apply` 实际创建成功 —— OBS 桶 `cur-filtered-export-260814-5fdb15`（区域 `cn-north-4`，私有 + `force_destroy`）+ 强制 HTTPS 桶策略（仅 `EnforceTLS`）。**下一步需在控制台开启费用中心「数据存储」订阅**（见步骤 2）。全程无公网 NAT / 计算实例。

> 本实践涉及的云服务规格以实际部署资源为准。

## 前置条件

- 已注册华为云账号，并拥有**费用中心**与**OBS**操作权限（主账号或具备 `BSS Administrator` / `OBS Administrator` 的 IAM 用户）。
- 若需"按成员账号筛选"，当前账号须为**统一核算主账号**（财务托管/统一核算），成员账号已纳入统一核算。
- 本地已安装：
- Terraform >= 1.5.0
- Python >= 3.8（用于 `verify_bills.py`，可选）
- 凭据通过**环境变量**注入（**禁止写入任何文件**，见安全红线）：
- `HW_ACCESS_KEY`、`HW_SECRET_KEY`、`HW_REGION_NAME`
- 离线部署（无 registry 网络）：设置 `TF_CLI_CONFIG_FILE` 指向本地 provider 镜像配置（见下面的"离线初始化"）。

## 快速开始

```bash
# 1. 配置访问密钥 AK/SK（仅当前会话，不落盘）
export HW_ACCESS_KEY="<HW_ACCESS_KEY>"
export HW_SECRET_KEY="<HW_SECRET_KEY>"
export HW_REGION_NAME="cn-north-4"

# 2. 部署 OBS 桶与桶策略（默认仅 init+plan，不自动 apply）
./deploy.sh --bucket <全局唯一的桶名> --region cn-north-4

# 3. 确认 plan 无误后真正创建资源
./deploy.sh --bucket <全局唯一的桶名> --region cn-north-4 --apply
```

## 离线初始化（无 registry 访问）

若执行机无法访问 `registry.terraform.io`，使用本地 `huaweicloud` provider 镜像：

```bash
export TF_CLI_CONFIG_FILE="/path/to/.terraformrc" # 含 filesystem_mirror 指向本地插件目录
cd infra
terraform init -input=false
terraform validate
```

## 分步部署

### 步骤 1：Terraform 创建 OBS 桶 + 桶策略

`infra/` 包含：

- `versions.tf` —— 锁定 `huaweicloud` provider >= 1.96.0
- `variables.tf` —— 区域、桶名、前缀、账号 ID、命名前缀
- `main.tf` —— `huaweicloud_obs_bucket`（私有、`force_destroy`）+ `huaweicloud_obs_bucket_policy`（强制 HTTPS + 投递授权）
- `outputs.tf` —— 输出桶名与生效策略

预期输出：`terraform apply` 成功后输出 `bucket_name`。

> ⚠️ OBS 桶策略需遵循四处语法要求（Version 必须为 `2008-10-17`、条件键使用 `SecureTransport`、条件值须为字符串数组、Principal 须为 `{"ID":["*"]}`），写法不符会报 `MalformedPolicy`。已实测修正并记录于 `docs/obs-bucket-policy-gotchas.md`。

### 步骤 2：控制台开启「数据存储」（等价启用数据导出）

该步骤含短信验证，需人工在控制台完成：

1. 登录华为云控制台 → **费用中心 → 数据存储**。
2. 设置**存储桶**为上一步创建的桶名。
3. 点击**验证**，通过后勾选要导出的数据类型。
4. （统一核算主账号）将**保存统一核算成员账号的账单**设为**是**——实现"只归档指定成员账号"。
5. 点击**获取验证码** → 输入短信验证码 → 确定，开启订阅。
6. 开启后，华为云**每天 18:30** 推送账单文件到桶（建议 20:00 后取数）。

### 步骤 3：验证投递

```bash
pip install esdk-obs-python
export OBS_SERVER="obs.cn-north-4.myhuaweicloud.com"
python3 src/subscription/verify_bills.py --bucket <桶名> --prefix cost-export/ --days 3
```

预期：列出当日（及近几日）的账单对象，提示"数据存储投递生效"。

## 清理资源

```bash
cd infra
terraform destroy -var="bucket_name=<桶名>" -var="region=cn-north-4"
```

> 同时建议在费用中心「数据存储」点击**关闭**，停止账单推送。OBS 标准存储按量计费，销毁桶即可停止存储费用。

> 本实践涉及的云服务规格以实际部署资源为准。
