#!/bin/bash
#
# File name: diy-part2.sh
# Description: OpenWrt DIY script part 2 (After Update feeds)
#
# 本项目定制(2026-10-31):版本号注入。
# 机制:CONFIG_VERSION_NUMBER 控制固件内版本串(/etc/openwrt_release 等
# 五个文件)与产物文件名前缀;CONFIG_VERSIONOPT 与 CONFIG_VERSION_FILENAMES
# 是 Kconfig 开关,必须为 y 才生效。此处写入 .config,make defconfig 之后
# 全部构建命令自动携带同一版本号,不依赖命令行逐次传参。

set -e

# 决定版本号:优先取工作流传入的 BUILD_VERSION,未传入时用源码检出的 git 短提交号。
if [ -n "${BUILD_VERSION}" ]; then
    VERSION="${BUILD_VERSION}"
else
    VERSION="$(git rev-parse --short HEAD)"
fi

# 写入 CONFIG_VERSION_NUMBER(已有则替换,没有则追加)。
if grep -q '^CONFIG_VERSION_NUMBER=' .config; then
    sed -i "s/^CONFIG_VERSION_NUMBER=.*/CONFIG_VERSION_NUMBER=\"${VERSION}\"/" .config
else
    echo "CONFIG_VERSION_NUMBER=\"${VERSION}\"" >> .config
fi

# 确保版本配置开关生效(Kconfig 布尔项,缺省时补 y)。
grep -q '^CONFIG_VERSIONOPT=y' .config || echo 'CONFIG_VERSIONOPT=y' >> .config
grep -q '^CONFIG_VERSION_FILENAMES=y' .config || echo 'CONFIG_VERSION_FILENAMES=y' >> .config

# 把最终版本号写入 GITHUB_ENV 供后续步骤(产物命名、version.txt、Release tag)使用;
# 本地运行时 GITHUB_ENV 不存在,跳过。
if [ -n "${GITHUB_ENV}" ]; then
    echo "BUILD_VERSION_FINAL=${VERSION}" >> "${GITHUB_ENV}"
fi

echo "diy-part2: build version = ${VERSION}"
