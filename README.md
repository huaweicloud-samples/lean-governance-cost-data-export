# lean-governance-cost-data-export · 明细数据按账号筛选归档到 OBS

![License: MIT No Attribution](https://img.shields.io/badge/License-MIT--No--Attribution-green.svg)
![Huawei Cloud](https://img.shields.io/badge/Huawei%20Cloud-OBS%20%2F%20Billing%20Center-orange.svg)
![Build](https://img.shields.io/badge/terraform%20validate-passing-brightgreen.svg)

## 1. 简介 / Overview

### 简介


本实践介绍一种在华为云上**把成本/账单明细按指定成员账号范围，每日自动归档到对象存储（OBS）**的方案，便于对账、用量分析与长期留存。利用费用中心「数据存储」原生能力，结合统一核算成员账号开关实现"按账号筛选"，零代码、轻量。

---

## 2. 目录

- [1. 简介 / Overview](#1-简介--overview)
- [2. 目录](#2-目录)
- [3. 架构图](#3-架构图)
- [4. 方案亮点](#4-方案亮点)
- [5. 涉及云服务](#5-涉及云服务)
- [6. 前置条件](#6-前置条件)
- [7. 快速开始](#7-快速开始)
- [8. 分步部署](#8-分步部署)
- [9. 使用方法 / 验证](#9-使用方法--验证)
- [10. 清理资源](#10-清理资源)
- [11. 详细说明](#11-详细说明)
- [12. 依赖](#12-依赖)
- [13. FAQ / 故障排除](#13-faq--故障排除)
- [14. 贡献指南](#14-贡献指南)
- [15. 许可证](#15-许可证)
- [16. 联系方式 / 维护者](#16-联系方式--维护者)


```
├── infra/                  # Terraform 基础设施
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   └── versions.tf
├── src/                    # 业务代码（含订阅验证脚本）
├── docs/                   # 文档
│   ├── architecture.md
│   ├── deployment-guide.md
│   └── obs-bucket-policy-gotchas.md
├── deploy.sh               # 部署入口
├── accounts.csv            # 成员账号清单
└── README.md
```

---

## 3. 架构图

```mermaid
flowchart LR
BC[费用中心 数据存储] -->|每日 18:30 推送 CSV| OBS[(OBS 桶 私有/强制HTTPS)]
UA[统一核算成员账号开关] -. 仅推送指定成员账号 .-> BC
OBS --> USER[对账/成本分析/数据湖]
```

---

## 4. 方案亮点

- **零代码**：账单投递由费用中心原生「数据存储」托管，无需编写函数或流水线。
- **按账号筛选**：统一核算主账号开启「保存统一核算成员账号的账单 = 是」，即只归档指定成员账号账单。
- **安全合规**：OBS 桶私有 + 强制 HTTPS + 最小授权桶策略。
- **一键 IaC**：Terraform 管理 OBS 桶与桶策略，可复现、可销毁。

---

## 5. 涉及云服务

- OBS（对象存储服务）
- 费用中心「数据存储」

---

## 6. 前置条件

- 华为云账号，具备费用中心与 OBS 操作权限（主账号或 `BSS Administrator` / `OBS Administrator`）。
- 若需"按成员账号筛选"，当前账号须为**统一核算主账号**。
- 本地安装：Terraform >= 1.5.0、Python >= 3.8（verify 脚本可选）。
- 凭据通过环境变量提供（**禁止写入文件**）：`HW_ACCESS_KEY`、`HW_SECRET_KEY`、`HW_REGION_NAME`。

---

## 7. 快速开始

```bash
export HW_ACCESS_KEY="<HW_ACCESS_KEY>"
export HW_SECRET_KEY="<HW_SECRET_KEY>"
export HW_REGION_NAME="cn-north-4"

# 预览（默认仅 init + plan，不创建资源）
./deploy.sh --bucket <全局唯一的桶名> --region cn-north-4

# 确认无误后真正创建
./deploy.sh --bucket <全局唯一的桶名> --region cn-north-4 --apply
```

---

## 8. 分步部署

1. 设置华为云 AK/SK/Region 环境变量。
2. 执行 `./deploy.sh --bucket <桶名> --region <区域>` 进行 plan 预览。
3. 确认无误后加 `--apply` 真正创建资源。
4. 在费用中心「数据存储」控制台开启订阅（含短信验证）。
5. 每日 18:30 后运行 verify_bills.py 验证投递。

---

## 9. 使用方法 / 验证

### 使用方法与验证

先在费用中心开启账单数据存储订阅，每日推送后用 `src/subscription/verify_bills.py` 验证投递，详见下列步骤。

1. 在费用中心「数据存储」设置上述桶并开启订阅（含短信验证；统一核算主账号开启成员账号开关）。详见 `docs/deployment-guide.md`。
2. 每日 18:30 推送后，运行验证脚本确认投递：

```bash
pip install esdk-obs-python
export OBS_SERVER="obs.cn-north-4.myhuaweicloud.com"
python3 src/subscription/verify_bills.py --bucket <桶名> --prefix cost-export/ --days 3
# 预期：✅ 检测到 N 个账单对象，数据存储投递生效。
```

部署完成后请按本节步骤自行验证，确认业务功能可用，方可视为交付完成。

---

## 10. 清理资源

```bash
cd infra
terraform destroy -var="bucket_name=<桶名>" -var="region=cn-north-4"
```

并在费用中心「数据存储」点击**关闭**，停止账单推送。

---

## 11. 详细说明

- 架构与能力差异：`docs/architecture.md`
- 分步部署与离线初始化：`docs/deployment-guide.md`

---

## 12. 依赖

### 依赖与参考

- 华为云 Terraform Provider（`huaweicloud` >= 1.96.0）
- `esdk-obs-python`（verify 脚本可选依赖）

---

## 13. FAQ / 故障排除

### FAQ

- **开启「数据存储」时验证失败**：按费用中心指引补充桶策略授权（或设置 `var.account_id` 后在桶策略中显式授权租户域写入）。
- **桶内无账单文件**：确认订阅已开启且勾选了账单类型；每日 18:30 推送，建议 20:00 后取数。
- **非统一核算账号**：只能获取自身账单，"按成员账号筛选"语义调整为全量自身账单。

---

## 14. 贡献指南

欢迎提交 Issue 与 PR。请遵循仓库内现有目录结构与代码风格。

---

## 15. 许可证

本实践采用 MIT No Attribution 许可证。详见 [LICENSE](LICENSE)。

---

## 16. 联系方式 / 维护者
| 项 | 内容 |
|---|---|
| **创建者** | [dgc-git](https://github.com/dgc-git) |
| **维护者** | [dgc-git](https://github.com/dgc-git) |
| **联系方式** | GitHub Issues / PR（见[第 14 节](#14-贡献指南)） |
