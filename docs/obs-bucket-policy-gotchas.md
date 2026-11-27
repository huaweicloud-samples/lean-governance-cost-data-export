# OBS 桶策略配置要点

> 适用场景：配置 OBS 桶策略（如 EnforceTLS 强制 HTTPS、服务主体授权）时，JSON 结构有**四处要点**，写法不符会报 `MalformedPolicy`。

## 配置要点与常见错误

| 策略项 | OBS 配置 | 错写后果 |
|---|---|---|
| **Version** | 必须 `"2008-10-17"`（不接受 2012/2018） | `MalformedPolicy: Invalid Version` |
| **条件键** | 使用 `SecureTransport` | `MalformedPolicy: Policy has invalid condition` |
| **条件值** | 必须是字符串数组 `["false"]`（JSON 布尔 `false` 会被拒） | `MalformedPolicy: Policy has invalid condition` |
| **Principal** | 使用 `{"ID":["*"]}`（裸 `"*"` 不被接受） | principal 无效 |

## 正确示例：拒绝所有非 HTTPS 请求（等价EnforceTLS）

```json
{
"Version": "2008-10-17",
"Statement": [
{
"Sid": "EnforceTLS",
"Effect": "Deny",
"Principal": { "ID": ["*"] },
"Action": ["*"],
"Resource": ["<bucket>", "<bucket>/*"],
"Condition": { "Bool": { "SecureTransport": ["false"] } }
}
]
}
```

## 实测证据（本仓库 2026-08-14 部署）

- 初次 `apply`：`Invalid Version 2018-10-17` → 改为 `2008-10-17`。
- 二次 `apply`：`Policy has invalid condition` → 根因是条件键写法不受支持 + 值为布尔 `false`；改为 `SecureTransport` + 值 `["false"]` + `Principal={"ID":["*"]}` 后 `Creation complete`。

## 参考来源

- 华为云官方「证书托管」文档给出等价 JSON：`"Condition":{"Bool":{"SecureTransport":["false"]}}`。
- 桶策略参数说明：条件键 `SecureTransport` 同 `g:SecureTransport`，类型标注为 Boolean，但**以字符串数组形式传入**（`["true"]` / `["false"]`）。
