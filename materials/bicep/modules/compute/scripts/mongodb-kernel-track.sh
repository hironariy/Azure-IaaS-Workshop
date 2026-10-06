#!/bin/bash
# shellcheck shell=bash
# =============================================================================
# MongoDB DB VM kernel-track helper (Issue #26)
# =============================================================================
# Installed on each DB VM as /usr/local/sbin/blogapp-kernel-track by the DB tier
# CustomScript (materials/bicep/modules/compute/db-tier.bicep). It can also be
# run on an existing DB VM with Azure Run Command (see troubleshooting runbook):
#
#   az vm run-command invoke -g <rg> -n vm-db-az2-prod --command-id RunShellScript \
#     --scripts @materials/bicep/modules/compute/scripts/mongodb-kernel-track.sh \
#     --parameters migrate
#
# WHY
#   MongoDB 8.0.x refuses to start on Linux kernel 6.19 or newer because of a
#   TCMalloc/rseq incompatibility (https://jira.mongodb.org/browse/SERVER-121912,
#   https://www.mongodb.com/community/forums/t/mongodb-8-x-and-linux-kernel-6-19/337547).
#   Ubuntu 24.04 Azure images track the *rolling* `linux-azure` kernel, which
#   moved to 7.0 (https://discourse.ubuntu.com/t/kernel-7-0-is-now-the-default-for-ubuntu-24-04-lts-on-azure/88459).
#   This helper moves the VM to the *long-term* Azure kernel track
#   `linux-azure-lts-24.04` (6.8 series, security maintained for the life of
#   Ubuntu 24.04 LTS), following Canonical's "Migrate kernel variants" guide:
#   https://ubuntu.com/cloud/public-cloud/docs/all-clouds-how-to/migrate-kernel-variants/
#
#   AWS analogy: on EC2 you would make the same decision by staying on a
#   specific Amazon Linux kernel line instead of the newest one. Managed
#   services (Amazon DocumentDB / RDS) hide this because AWS owns the host OS.
#
# DESIGN (idempotent, never removes the running kernel)
#   1. prepare          Pin apt away from the rolling track and >= 6.19 kernels,
#                       install linux-azure-lts-24.04, remove the rolling metas.
#   2. schedule-switch  The 6.8 kernel has a LOWER version than 6.17/7.0, and
#                       GRUB boots the highest version by default. So boot it
#                       once via a GRUB_DEFAULT drop-in that names the exact
#                       6.8 menu entry id, then schedule a delayed reboot
#                       (CustomScript must not reboot synchronously:
#                       https://learn.microsoft.com/azure/virtual-machines/extensions/custom-script-linux#troubleshooting).
#   3. finalize         Runs after the reboot (oneshot systemd unit) once the
#                       6.8 kernel is running: purge non-LTS kernels, reset
#                       GRUB_DEFAULT=0 (= newest installed kernel = newest 6.8),
#                       so future LTS security updates are picked automatically.
#   + check-mongod      mongod ExecStartPre guard that prints an actionable
#                       error instead of a start loop on an incompatible kernel.
#                       It does NOT bypass MongoDB's own startup check.
#
# REMOVE THIS PINNING when a MongoDB release supports Linux >= 6.19 and the
# workshop has been re-validated on it (delete the apt preferences file and
# reinstall `linux-azure`).
# =============================================================================

# Azure Run Command may start scripts with /bin/sh; this script needs bash.
if [ -z "${BASH_VERSION:-}" ]; then exec /bin/bash "$0" "$@"; fi

set -euo pipefail

readonly HELPER_PATH=/usr/local/sbin/blogapp-kernel-track
readonly LTS_META=linux-azure-lts-24.04
readonly LTS_SERIES=6.8
# Rolling (and edge) Azure kernel metapackages. Only installed ones are removed;
# all of them are blocked by the apt preferences file below.
readonly ROLLING_METAS=(
  linux-azure linux-image-azure linux-headers-azure linux-tools-azure
  linux-cloud-tools-azure linux-modules-extra-azure
  linux-azure-edge linux-image-azure-edge linux-headers-azure-edge
  linux-tools-azure-edge linux-cloud-tools-azure-edge
)
# Per-version kernel package prefixes (package = <prefix>-<uname -r>)
readonly KERNEL_PKG_PREFIXES=(
  linux-image linux-image-unsigned linux-modules linux-modules-extra
  linux-headers linux-tools linux-cloud-tools linux-buildinfo
)
readonly APT_PIN_FILE=/etc/apt/preferences.d/blogapp-mongodb-kernel-track
readonly GRUB_DROPIN=/etc/default/grub.d/99-blogapp-kernel-track.cfg
readonly GRUB_CFG=/boot/grub/grub.cfg
readonly MONGOD_DROPIN=/etc/systemd/system/mongod.service.d/10-blogapp-kernel-guard.conf
readonly FINALIZE_UNIT_NAME=blogapp-kernel-track-finalize.service
readonly FINALIZE_UNIT=/etc/systemd/system/${FINALIZE_UNIT_NAME}
readonly REBOOT_UNIT_NAME=blogapp-kernel-track-reboot
readonly STATE_DIR=/var/lib/blogapp
readonly FINALIZE_MARKER=${STATE_DIR}/kernel-track-finalize-pending
readonly APT_OPTS=(-o DPkg::Lock::Timeout=600)

export DEBIAN_FRONTEND=noninteractive

log() { echo "[blogapp-kernel-track] $*"; }
err() { echo "[blogapp-kernel-track] ERROR: $*" >&2; }
die() { err "$*"; exit 1; }

require_root() {
  [ "$(id -u)" -eq 0 ] || die "this subcommand must run as root (use sudo)"
}

# "7.0.0-1014-azure" -> 0 if kernel >= 6.19 (incompatible with MongoDB 8.0)
is_incompatible_kernel() {
  local major minor _rest
  IFS=. read -r major minor _rest <<<"$1"
  minor=${minor%%[^0-9]*}
  [[ "$major" =~ ^[0-9]+$ && "$minor" =~ ^[0-9]+$ ]] || return 1
  (( major > 6 || (major == 6 && minor >= 19) ))
}

# 0 if the given kernel release belongs to the 6.8 LTS series
is_lts_kernel() {
  [[ "$1" == "${LTS_SERIES}."* ]]
}

pkg_installed() {
  [ "$(dpkg-query -W -f='${db:Status-Status}' "$1" 2>/dev/null || true)" = "installed" ]
}

# Installed Azure kernel releases (uname -r format), oldest -> newest
installed_kernel_versions() {
  dpkg-query -W -f='${db:Status-Status} ${Package}\n' 'linux-image-*' 2>/dev/null |
    awk '$1 == "installed" { print $2 }' |
    sed -E -n 's/^linux-image-(unsigned-)?([0-9]+\.[0-9]+\.[0-9]+-[0-9]+-azure)$/\2/p' |
    sort -uV
}

newest_lts_version() {
  installed_kernel_versions | grep -E "^${LTS_SERIES//./\\.}\." | tail -n 1 || true
}

update_grub_checked() {
  # Never edit grub.cfg directly; regenerate it from /etc/default/grub(.d).
  # LC_ALL=C keeps generated menu titles in English (ids are locale independent).
  LC_ALL=C update-grub
  grub-script-check "$GRUB_CFG"
}

write_grub_default() {
  local value=$1
  mkdir -p "$(dirname "$GRUB_DROPIN")"
  cat > "${GRUB_DROPIN}.tmp" <<EOF
# Managed by ${HELPER_PATH} (Issue #26). Files in /etc/default/grub.d are read
# after /etc/default/grub, and 99-* is read last, so this value wins.
# GRUB_DEFAULT=0 means "newest installed kernel" (= newest 6.8 LTS kernel once
# the non-LTS kernels are purged). Reference:
# https://www.gnu.org/software/grub/manual/grub/html_node/Simple-configuration.html
GRUB_DEFAULT="${value}"
EOF
  mv "${GRUB_DROPIN}.tmp" "$GRUB_DROPIN"
}

write_apt_pin() {
  mkdir -p "$(dirname "$APT_PIN_FILE")"
  cat > "${APT_PIN_FILE}.tmp" <<'EOF'
# Managed by /usr/local/sbin/blogapp-kernel-track (Issue #26)
# MongoDB 8.0 cannot start on Linux >= 6.19 (SERVER-121912). Keep DB VMs on the
# Ubuntu 24.04 long-term Azure kernel track (linux-azure-lts-24.04, 6.8 series).
# Pin-Priority -1 = "never install". Package names may be regexes (apt_preferences(5)):
# https://manpages.ubuntu.com/manpages/noble/man5/apt_preferences.5.html

# 1) Rolling / edge Azure kernel metapackages must not come back
Package: linux-azure linux-image-azure linux-headers-azure linux-tools-azure linux-cloud-tools-azure linux-modules-extra-azure linux-azure-edge linux-image-azure-edge linux-headers-azure-edge linux-tools-azure-edge linux-cloud-tools-azure-edge
Pin: version *
Pin-Priority: -1

# 2) Defense in depth: never install an Azure kernel >= 6.19 on a DB VM
Package: /^linux-(image|image-unsigned|modules|modules-extra|headers|tools|cloud-tools|buildinfo)-(6\.(19|[2-9][0-9])|([7-9]|[1-9][0-9])\.[0-9]+)\.[0-9]+-[0-9]+-azure$/
Pin: version *
Pin-Priority: -1
EOF
  mv "${APT_PIN_FILE}.tmp" "$APT_PIN_FILE"
  log "apt pin written: $APT_PIN_FILE"
}

# Simulate an apt removal and fail if it would remove anything unexpected
assert_safe_removal() {
  local action=$1; shift
  local sim unexpected
  sim=$(apt-get "${APT_OPTS[@]}" -s "$action" "$@" 2>&1) || { echo "$sim" >&2; die "apt-get -s $action failed"; }
  unexpected=$(echo "$sim" | awk '$1 == "Remv" || $1 == "Purg" { print $2 }' |
    grep -E "^(${LTS_META//./\\.}|linux-image-azure-lts-24\.04|mongodb-|ubuntu-|cloud-init|walinuxagent)" || true)
  if [ -n "$unexpected" ]; then
    echo "$sim" >&2
    die "refusing: apt would also remove: $(echo "$unexpected" | tr '\n' ' ')"
  fi
}

cmd_prepare() {
  require_root
  write_apt_pin
  apt-get "${APT_OPTS[@]}" update
  log "Installing ${LTS_META} (Ubuntu 24.04 long-term Azure kernel, ${LTS_SERIES} series)"
  apt-get "${APT_OPTS[@]}" -y install --install-recommends "$LTS_META"

  local to_remove=() p
  for p in "${ROLLING_METAS[@]}"; do
    if pkg_installed "$p"; then to_remove+=("$p"); fi
  done
  if [ "${#to_remove[@]}" -gt 0 ]; then
    log "Removing rolling kernel metapackages: ${to_remove[*]}"
    assert_safe_removal remove "${to_remove[@]}"
    # Removing a metapackage does not remove any kernel image.
    apt-get "${APT_OPTS[@]}" -y remove "${to_remove[@]}"
  else
    log "No rolling kernel metapackages installed"
  fi

  pkg_installed "$LTS_META" || die "${LTS_META} is not installed"
  [ -n "$(newest_lts_version)" ] || die "no ${LTS_SERIES}.x Azure kernel image is installed"
  log "LTS kernel available: $(newest_lts_version)"
}

cmd_install_units() {
  require_root
  local self
  self=$(readlink -f "$0")
  if [ "$self" != "$HELPER_PATH" ]; then
    install -D -m 0755 "$self" "$HELPER_PATH"
    log "Installed helper to $HELPER_PATH"
  fi

  mkdir -p "$(dirname "$MONGOD_DROPIN")"
  cat > "$MONGOD_DROPIN" <<EOF
# Managed by ${HELPER_PATH} (Issue #26)
# Fails fast with an actionable message when MongoDB 8.0 would start on Linux
# >= 6.19. This is an extra check; MongoDB's own startup check stays active.
[Service]
ExecStartPre=${HELPER_PATH} check-mongod
EOF

  cat > "$FINALIZE_UNIT" <<EOF
# Managed by ${HELPER_PATH} (Issue #26)
[Unit]
Description=Finish switching this MongoDB VM to the Ubuntu 24.04 LTS Azure kernel track
Documentation=https://github.com/hironariy/Azure-IaaS-Workshop/issues/26
ConditionPathExists=${FINALIZE_MARKER}
After=local-fs.target

[Service]
Type=oneshot
ExecStart=${HELPER_PATH} finalize
TimeoutStartSec=900

[Install]
WantedBy=multi-user.target
EOF
  systemctl daemon-reload
  systemctl enable "$FINALIZE_UNIT_NAME" >/dev/null
  log "Installed mongod kernel guard and ${FINALIZE_UNIT_NAME}"
}

cmd_is_lts_running() {
  is_lts_kernel "$(uname -r)"
}

# Return "<submenu id>><entry id>" (or "<entry id>") for the given kernel
grub_entry_id() {
  local version=$1 vre submenu entry
  vre=${version//./\\.}
  submenu=$(grep -oE "^submenu .*\\\$menuentry_id_option '[^']+'" "$GRUB_CFG" |
    grep -oE "'gnulinux-advanced-[^']+'" | head -n 1 | tr -d "'" || true)
  entry=$(grep -oE "menuentry .*\\\$menuentry_id_option 'gnulinux-${vre}-advanced-[^']+'" "$GRUB_CFG" |
    grep -oE "'gnulinux-${vre}-advanced-[^']+'" | head -n 1 | tr -d "'" || true)
  [ -n "$entry" ] || return 1
  if [ -n "$submenu" ]; then echo "${submenu}>${entry}"; else echo "$entry"; fi
}

cmd_schedule_switch() {
  require_root
  local delay_min=${1:-2} target entry_id
  [[ "$delay_min" =~ ^[0-9]+$ ]] || die "delay must be minutes (integer)"
  target=$(newest_lts_version)
  [ -n "$target" ] || die "no ${LTS_SERIES}.x kernel installed; run 'prepare' first"
  [ -f "/boot/vmlinuz-${target}" ] || die "/boot/vmlinuz-${target} not found"

  # Make sure grub.cfg lists the 6.8 kernel, then select it by menu entry id
  update_grub_checked
  entry_id=$(grub_entry_id "$target") || die "GRUB menu entry for ${target} not found in ${GRUB_CFG}"
  write_grub_default "$entry_id"
  update_grub_checked
  grep -qF "$entry_id" "$GRUB_CFG" || die "GRUB default ${entry_id} not present after update-grub"
  log "GRUB will boot ${target} (${entry_id})"

  mkdir -p "$STATE_DIR"
  touch "$FINALIZE_MARKER"
  systemctl enable "$FINALIZE_UNIT_NAME" >/dev/null 2>&1 || true

  # Delayed reboot so the CustomScript / Run Command can report success first.
  systemctl stop "${REBOOT_UNIT_NAME}.timer" >/dev/null 2>&1 || true
  systemctl reset-failed "${REBOOT_UNIT_NAME}.service" >/dev/null 2>&1 || true
  systemd-run --quiet --unit "$REBOOT_UNIT_NAME" --on-active="${delay_min}min" \
    --timer-property=AccuracySec=5s /bin/systemctl reboot
  log "Running kernel $(uname -r) is not on the ${LTS_SERIES} LTS track."
  log "Reboot scheduled in ${delay_min} minute(s); mongod starts automatically on ${target}."
}

cmd_finalize() {
  require_root
  local running v base p purge=() extra
  running=$(uname -r)
  if ! is_lts_kernel "$running"; then
    err "still running ${running}, not the ${LTS_SERIES} LTS kernel; nothing purged."
    err "Check the GRUB default ('$0 status') and reboot, or see the troubleshooting runbook."
    exit 1
  fi

  for v in $(installed_kernel_versions); do
    [ "$v" = "$running" ] && continue
    is_lts_kernel "$v" && continue
    for p in "${KERNEL_PKG_PREFIXES[@]}"; do
      if pkg_installed "${p}-${v}"; then purge+=("${p}-${v}"); fi
    done
    # Version-specific helper packages, e.g. linux-azure-7.0-headers-7.0.0-1014
    base=${v%-azure}
    while IFS= read -r extra; do
      [ -n "$extra" ] && purge+=("$extra")
    done < <(dpkg-query -W -f='${db:Status-Status} ${Package}\n' 'linux-azure-*' 2>/dev/null |
      awk '$1 == "installed" { print $2 }' |
      grep -E "^linux-azure(-[0-9]+\.[0-9]+)?-(headers|tools|cloud-tools)-${base//./\\.}$" || true)
  done

  if [ "${#purge[@]}" -gt 0 ]; then
    log "Purging non-LTS kernels (not running): ${purge[*]}"
    assert_safe_removal purge "${purge[@]}"
    apt-get "${APT_OPTS[@]}" -y purge "${purge[@]}"
  else
    log "No non-LTS kernels installed"
  fi

  write_grub_default 0
  update_grub_checked
  rm -f "$FINALIZE_MARKER"
  log "Kernel track finalized: running ${running}; GRUB_DEFAULT=0 -> newest ${LTS_SERIES}.x kernel"
}

cmd_check_mongod() {
  local rel mver
  rel=$(uname -r)
  if is_incompatible_kernel "$rel"; then
    mver=$(dpkg-query -W -f='${Version}' mongodb-org-server 2>/dev/null || echo unknown)
    if [[ "$mver" == 8.0.* ]]; then
      err "mongod ${mver} cannot run on kernel ${rel}: MongoDB 8.0 does not support Linux >= 6.19 (SERVER-121912)."
      err "This DB VM must boot the Ubuntu 24.04 LTS Azure kernel (${LTS_SERIES}.x)."
      err "Diagnose: sudo ${HELPER_PATH} status ; fix: troubleshooting runbook section 7.1 (Issue #26)."
      exit 1
    fi
  fi
  exit 0
}

cmd_migrate() {
  cmd_prepare
  cmd_install_units
  if cmd_is_lts_running; then
    cmd_finalize
  else
    cmd_schedule_switch "${1:-1}"
  fi
}

cmd_status() {
  local p
  echo "running kernel : $(uname -r)"
  if is_incompatible_kernel "$(uname -r)"; then
    echo "                 -> INCOMPATIBLE with MongoDB 8.0 (>= 6.19)"
  elif is_lts_kernel "$(uname -r)"; then
    echo "                 -> OK (${LTS_SERIES} LTS track)"
  else
    echo "                 -> not on the ${LTS_SERIES} LTS track"
  fi
  echo "installed      : $(installed_kernel_versions | tr '\n' ' ')"
  echo -n "metapackages   :"
  for p in "$LTS_META" "${ROLLING_METAS[@]}"; do
    if pkg_installed "$p"; then echo -n " $p"; fi
  done
  echo
  echo "apt pin        : $([ -f "$APT_PIN_FILE" ] && echo "$APT_PIN_FILE" || echo missing)"
  echo "GRUB_DEFAULT   :"
  grep -Hs '^[[:space:]]*GRUB_DEFAULT=' /etc/default/grub /etc/default/grub.d/*.cfg | sed 's/^/  /' || true
  echo "finalize       : $([ -f "$FINALIZE_MARKER" ] && echo pending || echo done/not-needed)"
  echo "mongod         : $(systemctl is-active mongod 2>/dev/null || true)"
  echo "mongodb-server : $(dpkg-query -W -f='${Version}' mongodb-org-server 2>/dev/null || echo not-installed)"
}

usage() {
  cat <<EOF
Usage: $0 <command>
  prepare            install ${LTS_META}, remove rolling kernel metas, write apt pin
  install-units      install helper, mongod ExecStartPre guard and finalize unit
  is-lts-running     exit 0 if the running kernel is ${LTS_SERIES}.x
  schedule-switch [min]  boot the newest ${LTS_SERIES}.x kernel after a delayed reboot (default 2)
  finalize           (on ${LTS_SERIES}.x) purge non-LTS kernels, set GRUB_DEFAULT=0
  check-mongod       mongod ExecStartPre guard
  migrate [min]      prepare + install-units + finalize or schedule-switch (existing VMs)
  status             show kernel track diagnostics
EOF
}

main() {
  local cmd=${1:-status}
  if [ "$#" -gt 0 ]; then shift; fi
  case "$cmd" in
    prepare)         cmd_prepare ;;
    install-units)   cmd_install_units ;;
    is-lts-running)  cmd_is_lts_running ;;
    schedule-switch) cmd_schedule_switch "$@" ;;
    finalize)        cmd_finalize ;;
    check-mongod)    cmd_check_mongod ;;
    migrate)         cmd_migrate "$@" ;;
    status)          cmd_status ;;
    -h|--help|help)  usage ;;
    *)               usage >&2; exit 2 ;;
  esac
}

main "$@"
