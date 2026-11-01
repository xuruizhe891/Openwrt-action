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

# 1. 写入固件版本号 CONFIG_VERSION_NUMBER(.config 与两份配置种子,已有则替换,没有则追加)。
for cfg in .config configs/tl-7dr7230-v2.config configs/tl-7dr7230-v2-diag.config; do
    if [ -f "$cfg" ]; then
        if grep -q '^CONFIG_VERSION_NUMBER=' "$cfg"; then
            sed -i "s/^CONFIG_VERSION_NUMBER=.*/CONFIG_VERSION_NUMBER=\"${VERSION}\"/" "$cfg"
        else
            echo "CONFIG_VERSION_NUMBER=\"${VERSION}\"" >> "$cfg"
        fi
    fi
done

# 2. 确保版本配置开关生效(Kconfig 布尔项,缺省时补 y)。
grep -q '^CONFIG_VERSIONOPT=y' .config || echo 'CONFIG_VERSIONOPT=y' >> .config
grep -q '^CONFIG_VERSION_FILENAMES=y' .config || echo 'CONFIG_VERSION_FILENAMES=y' >> .config

# 3. 核心补齐:写入内核本地版本号 CONFIG_LOCALVERSION(控制内核 vermagic,防止驱动模块版本混用)。
KCFG="target/linux/mediatek/filogic_a73/config-6.6"
if [ -f "$KCFG" ]; then
    if grep -q '^CONFIG_LOCALVERSION=' "$KCFG"; then
        sed -i "s/^CONFIG_LOCALVERSION=.*/CONFIG_LOCALVERSION=\"-${VERSION}\"/" "$KCFG"
    else
        echo "CONFIG_LOCALVERSION=\"-${VERSION}\"" >> "$KCFG"
    fi
    # 读回校验:必须包含 CONFIG_LOCALVERSION="-${VERSION}"
    if ! grep -q "^CONFIG_LOCALVERSION=\"-${VERSION}\"" "$KCFG"; then
        echo "错误: $KCFG 写入 CONFIG_LOCALVERSION 校验失败" >&2
        exit 1
    fi
    echo "diy-part2: kernel CONFIG_LOCALVERSION set to -${VERSION} in ${KCFG}"
fi

# 4. 读回校验 .config 写入结果
if ! grep -q "^CONFIG_VERSION_NUMBER=\"${VERSION}\"" .config; then
    echo "错误: .config 写入 CONFIG_VERSION_NUMBER 校验失败" >&2
    exit 1
fi

# 把最终版本号写入 GITHUB_ENV 供后续步骤(产物命名、version.txt、Release tag)使用;
# 本地运行时 GITHUB_ENV 不存在,跳过。
if [ -n "${GITHUB_ENV}" ]; then
    echo "BUILD_VERSION_FINAL=${VERSION}" >> "${GITHUB_ENV}"
fi

echo "diy-part2: build version = ${VERSION} (all targets updated and verified)"
