refresh_metadata
upgrade_system

info "Installing compilers, Python prerequisites, CV/media libraries, containers, Firefox, and common CLI tools"
case "$PKG_FAMILY" in
  apt)
    SYSTEM_PACKAGES=(
      git git-lfs curl wget ca-certificates gnupg openssl rsync unzip zip p7zip-full tar xz-utils bzip2
      jq tree ripgrep fd-find fzf bat tmux htop lsof strace shellcheck
      build-essential cmake ninja-build gdb clang clang-tools pkg-config
      python3 python3-pip python3-dev python3-venv pipx
      libssl-dev libffi-dev zlib1g-dev libbz2-dev liblzma-dev libreadline-dev libsqlite3-dev
      libjpeg-dev libpng-dev libtiff-dev libopenexr-dev libeigen3-dev
      libgl1-mesa-dev libx11-dev libxext-dev libxrender-dev libgtk-3-dev ffmpeg
      podman podman-compose buildah skopeo postgresql-client libpq-dev firefox flatpak
    )
    ;;
  dnf|yum)
    SYSTEM_PACKAGES=(
      git git-lfs curl wget ca-certificates gnupg2 openssl rsync unzip zip p7zip p7zip-plugins tar xz bzip2
      jq tree ripgrep fd-find fzf bat tmux htop btop lsof strace shellcheck
      gcc gcc-c++ make cmake ninja-build gdb clang clang-tools-extra pkgconf-pkg-config
      python3 python3-pip python3-devel pipx
      openssl-devel libffi-devel zlib-devel bzip2-devel xz-devel readline-devel sqlite-devel
      libjpeg-turbo-devel libpng-devel libtiff-devel openexr-devel eigen3-devel
      mesa-libGL-devel libX11-devel libXext-devel libXrender-devel gtk3-devel ffmpeg
      podman podman-compose buildah skopeo postgresql libpq-devel firefox flatpak
    )
    ;;
  pacman)
    SYSTEM_PACKAGES=(
      base-devel git git-lfs curl wget ca-certificates gnupg openssl rsync unzip zip p7zip tar xz bzip2
      jq tree ripgrep fd fzf bat tmux htop btop lsof strace shellcheck
      cmake ninja gdb clang pkgconf python python-pip pipx
      libffi zlib bzip2 xz readline sqlite libjpeg-turbo libpng libtiff openexr eigen mesa
      libx11 libxext libxrender gtk3 ffmpeg
      podman podman-compose buildah skopeo postgresql firefox flatpak
    )
    ;;
  zypper)
    SYSTEM_PACKAGES=(
      git git-lfs curl wget ca-certificates gpg2 openssl rsync unzip zip p7zip tar xz bzip2
      jq tree ripgrep fd fzf bat tmux htop lsof strace ShellCheck
      gcc gcc-c++ make cmake ninja gdb clang pkg-config
      python3 python3-pip python3-devel pipx
      libopenssl-devel libffi-devel zlib-devel libbz2-devel xz-devel readline-devel sqlite3-devel
      libjpeg8-devel libpng16-devel libtiff-devel openexr-devel eigen3-devel
      Mesa-libGL-devel libX11-devel libXext-devel libXrender-devel gtk3-devel ffmpeg
      podman podman-compose buildah skopeo postgresql postgresql-devel MozillaFirefox flatpak
    )
    ;;
  *) SYSTEM_PACKAGES=() ;;
esac
install_packages "${SYSTEM_PACKAGES[@]}"

# Debian uses alternate executable names for these packages.
if command -v fdfind >/dev/null 2>&1 && ! command -v fd >/dev/null 2>&1; then
  ln -sfn "$(command -v fdfind)" "${HOME}/.local/bin/fd"
fi
if command -v batcat >/dev/null 2>&1 && ! command -v bat >/dev/null 2>&1; then
  ln -sfn "$(command -v batcat)" "${HOME}/.local/bin/bat"
fi

for required_cmd in curl git tar sha256sum; do
  command -v "$required_cmd" >/dev/null 2>&1 \
    || die "Required command '$required_cmd' is missing. Install it with your distribution package manager and rerun."
done

command -v git-lfs >/dev/null 2>&1 && git lfs install --skip-repo || true
if command -v pipx >/dev/null 2>&1; then
  pipx ensurepath || true
fi
