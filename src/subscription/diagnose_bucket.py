#!/usr/bin/env python3
# -*- coding: utf-8 -*-
import os
import sys
from obs import ObsClient

ak = os.environ.get("HW_ACCESS_KEY")
sk = os.environ.get("HW_SECRET_KEY")
region = os.environ.get("HW_REGION_NAME", "cn-north-4")
bucket = "cur-filtered-export-260814-5fdb15"
server = f"obs.{region}.myhuaweicloud.com"

if not (ak and sk):
    sys.exit("请设置 HW_ACCESS_KEY / HW_SECRET_KEY 环境变量")

client = ObsClient(access_key_id=ak, secret_access_key=sk, server=server)

print(f"=== 桶: {bucket} ({region}) ===\n")

print("--- 1. 桶 ACL ---")
acl_resp = client.getBucketAcl(bucket)
print(f"status={acl_resp.status}")
if acl_resp.body and acl_resp.body.grants:
    for g in acl_resp.body.grants:
        print(f"  grantee={g.grantee}  permission={g.permission}")
else:
    print("  (无 grants 或解析为空)")

print("\n--- 2. 桶策略 ---")
policy_resp = client.getBucketPolicy(bucket)
print(f"status={policy_resp.status}")
print(f"policy={policy_resp.body.policy if policy_resp.body else 'None'}")

print("\n--- 3. 全部对象列表（无前缀）---")
list_resp = client.listObjects(bucket, prefix="", max_keys=100)
print(f"status={list_resp.status}")
if list_resp.body and list_resp.body.contents:
    for obj in list_resp.body.contents:
        print(f"  {obj.key} ({obj.size} bytes)")
    print(f"共 {len(list_resp.body.contents)} 个对象")
else:
    print("  暂无对象")

print("\n--- 4. cost-export/ 前缀对象 ---")
list_resp2 = client.listObjects(bucket, prefix="cost-export/", max_keys=100)
print(f"status={list_resp2.status}")
if list_resp2.body and list_resp2.body.contents:
    for obj in list_resp2.body.contents:
        print(f"  {obj.key} ({obj.size} bytes)")
    print(f"共 {len(list_resp2.body.contents)} 个对象")
else:
    print("  暂无对象")
