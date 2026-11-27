#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
verify_bills.py —— 验证费用中心「数据存储」是否已按日将数据推送到 OBS 桶。

本脚本验证 OBS 桶内是否出现了每日推送的
数据文件（如 Spendings(ByResource)_YYYYMMDD、Resource_Expenditures_YYYYMMDD）。

凭据从环境变量注入（不落盘，符合安全红线）：
  HW_ACCESS_KEY / HW_SECRET_KEY / HW_REGION_NAME
  OBS_SERVER   —— OBS 终端节点，如 obs.cn-north-4.myhuaweicloud.com

依赖：pip install esdk-obs-python
"""
import os
import sys
import argparse
from datetime import date, timedelta

try:
    from obs import ObsClient
except ImportError:
    sys.exit("缺少依赖，请先执行: pip install esdk-obs-python")


def main():
    parser = argparse.ArgumentParser(description="列出 OBS 桶内每日账单对象")
    parser.add_argument("--bucket", required=True, help="目的 OBS 桶名")
    parser.add_argument("--prefix", default="cost-export/", help="对象前缀")
    parser.add_argument("--days", type=int, default=3, help="回看最近 N 天")
    args = parser.parse_args()

    ak = os.environ.get("HW_ACCESS_KEY")
    sk = os.environ.get("HW_SECRET_KEY")
    region = os.environ.get("HW_REGION_NAME", "cn-north-4")
    server = os.environ.get("OBS_SERVER", f"obs.{region}.myhuaweicloud.com")

    if not (ak and sk):
        sys.exit("请通过环境变量注入 HW_ACCESS_KEY / HW_SECRET_KEY")

    client = ObsClient(access_key_id=ak, secret_access_key=sk, server=server)

    print(f"桶: {args.bucket}  前缀: {args.prefix}  区域: {region}")
    print("-" * 60)
    found = 0
    for back in range(args.days):
        day = (date.today() - timedelta(days=back)).strftime("%Y%m%d")
        prefix = f"{args.prefix}{day}"
        resp = client.listObjects(args.bucket, prefix=prefix)
        if resp.status < 300 and resp.body and resp.body.contents:
            for obj in resp.body.contents:
                print(f"  {obj.key}  ({obj.size} bytes)")
                found += 1
        else:
            print(f"  {day}: 无对象（status={resp.status}）")

    print("-" * 60)
    if found > 0:
        print(f"✅ 检测到 {found} 个账单对象，数据存储投递生效。")
    else:
        print("⏳ 暂未检测到账单对象。费用中心每天 18:30 推送，建议 20:00 后重试；")
        print("   并确认已在费用中心「数据存储」开启订阅且勾选了账单类型。")


if __name__ == "__main__":
    main()
