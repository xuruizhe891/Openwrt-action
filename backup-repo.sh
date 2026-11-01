#!/usr/bin/env bash
# backup-repo.sh — Openwrt-action 公开编译仓库破坏性操作前快照脚本
# 复刻自 immortalwrt-mt798x-6.6/backup-repo.sh(2026-11-01),按本仓形态适配:
#   仓库无构建缓存(build_dir/staging_dir 不存在),全仓打包含 .git( workflow 历史小体积);
#   备份目录用备份盘现有 repo-backups/(与 798x 的 repo-backups-1016 平级);
#   本仓无 kimi-code hook 配置,hook 备份校验注释行按 798x 同构脚本理解。
# 用法:bash backup-repo.sh(任意目录可执行;把本仓整体打包到外置备份盘)
# 行为:打包 → 备份后自校验(打包期间写入检测 + tar 完整性校验)→ 校验结论写备份日志 → 轮转旧包。
# 失败处理:任何一步失败,包文件改名为 <原名>_fail.tar 保留,不删除文件;
#       备份日志没有 verify_tar=ok 结论行的备份,备份校验一律不认。
# 校验结论行(写在备份日志尾部):
#       consistency=clean 或 consistency=changed:N —— 打包期间有没有新写入;
#       verify_tar=ok 或 verify_tar=fail —— tar -tf 全量读回,归档结构是否完整。
# 想改什么动哪几行:
#   - 想改保留份数:改 KEEP_COUNT(只作用于自动备份;手动命名与 *_fail.tar 永不自动删除);
#   - 想改备份盘:改 BACKUP_ROOT 与 MOUNT_POINT。
set -euo pipefail

REPO_PARENT="/mnt/sda3"
REPO_NAME="Openwrt-action"
REPO_PATH="${REPO_PARENT}/${REPO_NAME}"
BACKUP_ROOT="/media/rz/284A-3698/repo-backups"
MOUNT_POINT="/media/rz/284A-3698"
LOCK_FILE="/tmp/openwrt-action-backup.lock"
STAMP="$(date +%Y%m%d-%H%M%S)"
OUT="${BACKUP_ROOT}/${REPO_NAME}-auto-${STAMP}.tar"
LOG_DIR="${BACKUP_ROOT}/logs"
LOG="${LOG_DIR}/backup-${STAMP}.log"
KEEP_COUNT=96

# 失败兜底:退出码非零且包文件还在(打包中断留下的半份)时改名 _fail 保留,不删。
on_exit() {
  local rc=$?
  if [ "${rc}" -ne 0 ] && [ -f "${OUT}" ]; then
    mv -f "${OUT}" "${OUT%.tar}_fail.tar" 2>/dev/null || true
  fi
}
trap on_exit EXIT

if ! mountpoint -q "${MOUNT_POINT}"; then
  echo "ERROR: external disk is not mounted at ${MOUNT_POINT}" >&2
  exit 1
fi

exec 9>"${LOCK_FILE}"
if ! flock -n 9; then
  echo "ERROR: another backup is already running" >&2
  exit 1
fi

mkdir -p "${BACKUP_ROOT}" "${LOG_DIR}"

{
  echo "time=${STAMP}"
  echo "repo=${REPO_PATH}"
  echo "branch=$(git -C "${REPO_PATH}" branch --show-current 2>/dev/null || echo unknown)"
  echo "head=$(git -C "${REPO_PATH}" rev-parse HEAD 2>/dev/null || echo unknown)"
  echo "out=${OUT}"

  if [ ! -d "${REPO_PATH}/.git" ]; then
    echo "ERROR: repo not found: ${REPO_PATH}" >&2
    exit 1
  fi

  if ! mountpoint -q "${MOUNT_POINT}"; then
    echo "ERROR: external disk is not mounted at ${MOUNT_POINT}" >&2
    exit 1
  fi

  df -h "${BACKUP_ROOT}"

  # 打包窗口写入检测的起点(时间标记,检测完成即删)
  WRITE_MARK=$(mktemp)
  touch "${WRITE_MARK}"

  # 全仓打包含 .git(workflow 仓库体积小,无构建缓存可排除)
  tar \
    -cf "${OUT}" \
    -C "${REPO_PARENT}" "${REPO_NAME}"

  sync "${OUT}" 2>/dev/null || sync

  # 一致性检测:时间标记之后被修改/新建的文件,即打包期间的写入。本仓全仓打包,检测不排目录。
  # 判读:clean=读取全程无并发写,归档是某个时刻的一致视图;changed=清单中的文件在打包期间被写。
  # 已知噪音:git 只读命令可能刷新 .git/index 的时间戳——清单出现 .git/index 多为无害,
  #   .git/objects 出现才需警惕。删除操作本检测列不出,tar 自带的
  #   "file changed as we read it" 警告补充该面。
  CHANGED_LIST=$(find "${REPO_PATH}" -newer "${WRITE_MARK}" -print 2>/dev/null || true)
  rm -f "${WRITE_MARK}"
  if [ -z "${CHANGED_LIST}" ]; then
    echo "consistency=clean"
  else
    echo "consistency=changed:$(printf '%s\n' "${CHANGED_LIST}" | wc -l)个文件在打包期间被写(清单如下)"
    printf '%s\n' "${CHANGED_LIST}"
  fi

  # 完整性校验:tar -tf 全量读回,截断/损坏/半份都会检出;失败改名 _fail 并终止。
  if tar -tf "${OUT}" >/dev/null 2>&1; then
    echo "verify_tar=ok(tar -tf 全量读回校验通过)"
  else
    echo "verify_tar=fail(tar -tf 校验失败,包不可信)"
    mv -f "${OUT}" "${OUT%.tar}_fail.tar" 2>/dev/null || true
    echo "backup failed: tar verify failed"
    exit 1
  fi

  ls -lh "${OUT}"

  # 轮转:只删最旧的自动备份;手动命名的备份与 *_fail.tar 永不自动删除(冗余保留,积累需人工清理)。
  mapfile -t old_backups < <(ls -1t "${BACKUP_ROOT}/${REPO_NAME}-auto-"*.tar 2>/dev/null | grep -v '_fail\.tar$' | tail -n +$((KEEP_COUNT + 1)) || true)
  if [ "${#old_backups[@]}" -gt 0 ]; then
    printf '%s\n' "${old_backups[@]}" | xargs -r rm -f --
    echo "removed_old_backups=${#old_backups[@]}"
  else
    echo "removed_old_backups=0"
  fi

  echo "done"
} 2>&1 | tee "${LOG}"
