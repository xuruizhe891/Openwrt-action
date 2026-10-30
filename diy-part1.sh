#!/bin/bash
#
# File name: diy-part1.sh
# Description: OpenWrt DIY script part 1 (Before Update feeds)
#
# 本项目定制(2026-10-31):源码仓库自带 feeds 配置(feeds.conf 与 feeds/
# 目录随私有源码仓库检出),不追加第三方 feed 源。
# (原模板此处追加 helloworld 代理插件 feed,与本项目无关,已移除。)

set -e

echo "diy-part1: 本项目无 feeds 追加项,使用源码仓库自带 feeds 配置。"
