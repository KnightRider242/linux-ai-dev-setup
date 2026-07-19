#!/usr/bin/env bash
# Cross-distribution Linux workstation bootstrap for AI/deep-learning,
# computer vision, Angular/React, PostgreSQL/MongoDB, VS Code, Firefox,
# Miniforge (Conda/Mamba), and OpenAI Codex CLI.
#
# Supported package-manager families:
#   - Debian/Ubuntu/Mint/Pop!_OS/Kali: apt
#   - Fedora/Nobara/RHEL-like: dnf or yum
#   - Arch/Manjaro/EndeavourOS: pacman
#   - openSUSE Leap/Tumbleweed/SLE: zypper
# Other glibc-based distributions use portable mode for user-space tools.
# Designed to be rerunnable.

set -Eeuo pipefail
IFS=$'\n\t'

SCRIPT_VERSION="2.0.0"
AI_ENV="${AI_ENV:-ai-dev}"
MINIFORGE_DIR="${MINIFORGE_DIR:-${HOME}/miniforge3}"
WORKSPACE_DIR="${WORKSPACE_DIR:-${HOME}/ai-workspace}"
SERVICES_DIR="${SERVICES_DIR:-${HOME}/dev-services}"
LOG_DIR="${XDG_STATE_HOME:-${HOME}/.local/state}/linux-ai-dev-setup"
LOG_FILE="${LOG_DIR}/setup-$(date +%Y%m%d-%H%M%S).log"

REFRESH_METADATA=1
SYSTEM_UPGRADE=0
INSTALL_DESKTOP_APPS=1
INSTALL_DB_CONTAINERS=1
INSTALL_VSCODE=1
INSTALL_VSCODE_EXTENSIONS=1
INSTALL_TENSORFLOW=0
INSTALL_JAX=0
INSTALL_CUDA_TOOLKIT=0
DRY_RUN=0
PYTORCH_MODE="auto"

mkdir -p "$LOG_DIR"
exec > >(tee -a "$LOG_FILE") 2>&1

info() { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }
warn() { printf '\n\033[1;33mWARNING: %s\033[0m\n' "$*" >&2; }
die()  { printf '\n\033[1;31mERROR: %s\033[0m\n' "$*" >&2; exit 1; }

on_error() {
  local exit_code=$?
  warn "Setup stopped at line ${BASH_LINENO[0]} with exit code ${exit_code}. See: ${LOG_FILE}"
  exit "$exit_code"
}
trap on_error ERR

usage() {
  cat <<EOF
Cross-distribution Linux AI development setup v${SCRIPT_VERSION}

Usage: ./linux-ai-dev-setup.sh [options]

Options:
  --full-ai              Also create separate TensorFlow and JAX environments
  --with-tensorflow      Create the ai-tf environment
  --with-jax             Create the ai-jax environment
  --with-cuda-toolkit    Install nvcc/CUDA toolkit inside ai-dev
  --pytorch-mode MODE    auto, cpu, cu126, or cu130 (default: auto)
  --system-upgrade       Upgrade installed OS packages before setup
  --skip-update          Skip package metadata refresh (compatibility option)
  --skip-desktop-apps    Skip optional desktop applications
  --skip-databases       Skip PostgreSQL/MongoDB development containers
  --skip-vscode          Skip VS Code installation
  --skip-vscode-ext      Skip VS Code extension installation
  --dry-run              Detect the system and print the selected strategy only
  -h, --help             Show this help

Environment overrides:
  AI_ENV, MINIFORGE_DIR, WORKSPACE_DIR, SERVICES_DIR

Default AI environment: ${AI_ENV}
EOF
}

while (($#)); do
  case "$1" in
    --full-ai)
      INSTALL_TENSORFLOW=1
      INSTALL_JAX=1
      ;;
    --with-tensorflow) INSTALL_TENSORFLOW=1 ;;
    --with-jax) INSTALL_JAX=1 ;;
    --with-cuda-toolkit) INSTALL_CUDA_TOOLKIT=1 ;;
    --pytorch-mode)
      shift
      (($#)) || die "--pytorch-mode requires: auto, cpu, cu126, or cu130"
      PYTORCH_MODE="$1"
      ;;
    --system-upgrade) SYSTEM_UPGRADE=1 ;;
    --skip-update) REFRESH_METADATA=0 ;;
    --skip-desktop-apps) INSTALL_DESKTOP_APPS=0 ;;
    --skip-databases) INSTALL_DB_CONTAINERS=0 ;;
    --skip-vscode)
      INSTALL_VSCODE=0
      INSTALL_VSCODE_EXTENSIONS=0
      ;;
    --skip-vscode-ext) INSTALL_VSCODE_EXTENSIONS=0 ;;
    --dry-run) DRY_RUN=1 ;;
    -h|--help) usage; exit 0 ;;
    *) die "Unknown option: $1" ;;
  esac
  shift
done

case "$PYTORCH_MODE" in
  auto|cpu|cu126|cu130) ;;
  *) die "Invalid --pytorch-mode '${PYTORCH_MODE}'. Use auto, cpu, cu126, or cu130." ;;
esac

[[ -r /etc/os-release ]] || die "/etc/os-release was not found."
# shellcheck disable=SC1091
source /etc/os-release
DISTRO_ID="${ID:-unknown}"
DISTRO_LIKE="${ID_LIKE:-}"
DISTRO_NAME="${PRETTY_NAME:-Linux}"
ARCH="$(uname -m)"
LIBC_FAMILY="unknown"
if getconf GNU_LIBC_VERSION >/dev/null 2>&1; then
  LIBC_FAMILY="glibc"
elif ldd --version 2>&1 | grep -qi musl; then
  LIBC_FAMILY="musl"
fi

PKG_FAMILY="portable"
if command -v rpm-ostree >/dev/null 2>&1; then
  PKG_FAMILY="immutable-rpm"
elif command -v apt-get >/dev/null 2>&1; then
  PKG_FAMILY="apt"
elif command -v dnf >/dev/null 2>&1; then
  PKG_FAMILY="dnf"
elif command -v yum >/dev/null 2>&1; then
  PKG_FAMILY="yum"
elif command -v pacman >/dev/null 2>&1; then
  PKG_FAMILY="pacman"
elif command -v zypper >/dev/null 2>&1; then
  PKG_FAMILY="zypper"
fi

PRIV=()
if ((EUID != 0)); then
  if command -v sudo >/dev/null 2>&1; then
    PRIV=(sudo)
  elif command -v doas >/dev/null 2>&1; then
    PRIV=(doas)
  elif [[ "$PKG_FAMILY" != "portable" && "$PKG_FAMILY" != "immutable-rpm" ]]; then
    die "Neither sudo nor doas is installed. Install one, or run the script as root."
  fi
else
  warn "Running as root installs user-space tools under ${HOME}. A normal desktop user is recommended."
fi

info "Detected ${DISTRO_NAME} (${ARCH}, ${LIBC_FAMILY}); package strategy: ${PKG_FAMILY}"
info "Log file: ${LOG_FILE}"

if ((DRY_RUN)); then
  cat <<EOF

Dry-run summary
---------------
Distribution:       ${DISTRO_NAME}
Architecture:       ${ARCH}
C library:          ${LIBC_FAMILY}
Package strategy:   ${PKG_FAMILY}
AI environment:     ${AI_ENV}
Miniforge path:     ${MINIFORGE_DIR}
PyTorch mode:       ${PYTORCH_MODE}
TensorFlow env:     ${INSTALL_TENSORFLOW}
JAX env:            ${INSTALL_JAX}
CUDA toolkit:       ${INSTALL_CUDA_TOOLKIT}
VS Code:            ${INSTALL_VSCODE}
Desktop apps:       ${INSTALL_DESKTOP_APPS}
Database services:  ${INSTALL_DB_CONTAINERS}
EOF
  exit 0
fi

if [[ "$LIBC_FAMILY" == "musl" ]]; then
  die "Miniforge and the selected binary AI stack require glibc. Alpine/musl is not supported by this installer; use an Ubuntu/Fedora container or VM."
fi

if ((${#PRIV[@]})); then
  "${PRIV[@]}" -v 2>/dev/null || true
fi
