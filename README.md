# OpenWrt Builder(TL-7DR7230 v2)

基于 [P3TERX/Actions-OpenWrt](https://github.com/P3TERX/Actions-OpenWrt) 模板改造的公开编译仓库:workflow 从私有源码仓库检出源码,构建 TL-7DR7230 v2 固件,产物发布到本仓库的 Artifacts 与 Releases。

## 与模板的差异

- 源码来自私有仓库(经 actions/checkout 带凭证检出),不从公开地址 clone;本仓库不放 `.config`,构建配置取源码仓库的 `configs/tl-7dr7230-v2.config`。
- 版本号经 workflow 输入注入(`version`,留空时用源码 git 短提交号),同时进固件内版本串与产物文件名。
- 构建日志单独归档为 artifact(`build.log` 加 `logs/` 目录,保留 90 天),排障用。
- Releases 全部保留,不自动删旧;运行记录不主动清理(靠平台 90 天保留期)。

## 配置

本仓库 Secrets:

| Secret 名 | 用途 | 权限 |
|---|---|---|
| `SOURCE_REPO_TOKEN` | checkout 步骤检出私有源码仓库 | fine-grained PAT,源码仓库 Contents: read |

私有源码仓库侧(如需 push 自动触发):在私有源码仓库的 Secrets 配置 `BUILD_REPO_DISPATCH_TOKEN`(fine-grained PAT,本编译仓库 Contents: write),供其 push 触发的转发 workflow 调用本仓库的 repository dispatch 端点。

workflow 的 `env` 段 `SOURCE_REPO` 需填私有源码仓库的实际 `owner/仓库名`。

## 触发

- 手动:Actions 页 Run workflow,可填 `version`(版本号)与 `ref`(源码分支或提交)。
- 自动:私有源码仓库 push 后向本仓库发 repository_dispatch(event_type: `source-push`,client_payload 可带 `ref` 与 `version`)。

## 产物

- `firmware-<版本号><设备>` artifact 与 Release 资产:sysupgrade.itb、initramfs(-recovery.itb)、preloader.bin、bl31-uboot.fip、json_info_files/、manifest、version.txt。
- `build-logs-<版本号>` artifact:构建日志(build.log 与 logs/ 目录)。
- 版本号留空时回退为源码 git 短提交号;同一版本号重复发布会更新同一 Release,版本号由使用方保证唯一。

## Credits

- [P3TERX/Actions-OpenWrt](https://github.com/P3TERX/Actions-OpenWrt)(模板来源)
- [softprops/action-gh-release](https://github.com/softprops/action-gh-release)

## License

[MIT](https://github.com/P3TERX/Actions-OpenWrt/blob/main/LICENSE) © [**P3TERX**](https://p3terx.com)
