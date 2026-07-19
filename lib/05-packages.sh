version_ge() {
  [[ "$(printf '%s\n%s\n' "$2" "$1" | sort -V | head -n1)" == "$2" ]]
}

ensure_line() {
  local line="$1" file="$2"
  touch "$file"
  grep -Fqx "$line" "$file" 2>/dev/null || printf '%s\n' "$line" >> "$file"
}

mkdir -p "${HOME}/.local/bin"
export PATH="${HOME}/.local/bin:${PATH}"
ensure_line 'export PATH="$HOME/.local/bin:$PATH"' "${HOME}/.profile"

refresh_metadata() {
  ((REFRESH_METADATA)) || return 0
  info "Refreshing package metadata"
  case "$PKG_FAMILY" in
    apt)
      "${PRIV[@]}" apt-get update
      ;;
    dnf)
      if [[ "$DISTRO_ID" == "nobara" ]] && command -v nobara-sync >/dev/null 2>&1; then
        # Nobara's updater must run as the regular user.
        nobara-sync cli || warn "nobara-sync did not complete cleanly."
      else
        "${PRIV[@]}" dnf makecache --refresh -y
      fi
      ;;
    yum)
      "${PRIV[@]}" yum makecache -y
      ;;
    zypper)
      "${PRIV[@]}" zypper --non-interactive refresh
      ;;
    pacman)
      # Avoid pacman -Sy without a full upgrade. Package installation below uses -Syu.
      info "Arch-family metadata will be refreshed together with package installation."
      ;;
    immutable-rpm)
      warn "Immutable rpm-ostree system detected. System package layering is skipped; portable user-space setup will continue."
      ;;
    portable)
      warn "No supported mutable package manager detected. Portable user-space setup will continue."
      ;;
  esac
}

upgrade_system() {
  ((SYSTEM_UPGRADE)) || return 0
  info "Upgrading installed operating-system packages"
  case "$PKG_FAMILY" in
    apt) "${PRIV[@]}" env DEBIAN_FRONTEND=noninteractive apt-get upgrade -y ;;
    dnf)
      if [[ "$DISTRO_ID" == "nobara" ]] && command -v nobara-sync >/dev/null 2>&1; then
        if ((REFRESH_METADATA)); then
          info "Nobara was already updated by nobara-sync during metadata refresh."
        else
          nobara-sync cli
        fi
      else
        "${PRIV[@]}" dnf upgrade --refresh -y
      fi
      ;;
    yum) "${PRIV[@]}" yum update -y ;;
    pacman) "${PRIV[@]}" pacman -Syu --noconfirm ;;
    zypper) "${PRIV[@]}" zypper --non-interactive update ;;
    *) warn "System upgrade is not automated for package strategy: ${PKG_FAMILY}" ;;
  esac
}

install_packages() {
  local packages=("$@")
  ((${#packages[@]})) || return 0
  case "$PKG_FAMILY" in
    apt)
      if ! "${PRIV[@]}" env DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends "${packages[@]}"; then
        warn "Grouped apt installation failed; retrying package-by-package."
        local pkg
        for pkg in "${packages[@]}"; do
          "${PRIV[@]}" env DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends "$pkg" \
            || warn "Skipped unavailable/problematic package: $pkg"
        done
      fi
      ;;
    dnf)
      if ! "${PRIV[@]}" dnf install -y "${packages[@]}"; then
        warn "Grouped dnf installation failed; retrying package-by-package."
        local pkg
        for pkg in "${packages[@]}"; do
          "${PRIV[@]}" dnf install -y "$pkg" || warn "Skipped unavailable/problematic package: $pkg"
        done
      fi
      ;;
    yum)
      if ! "${PRIV[@]}" yum install -y "${packages[@]}"; then
        warn "Grouped yum installation failed; retrying package-by-package."
        local pkg
        for pkg in "${packages[@]}"; do
          "${PRIV[@]}" yum install -y "$pkg" || warn "Skipped unavailable/problematic package: $pkg"
        done
      fi
      ;;
    pacman)
      local pacman_args=(-S --needed --noconfirm)
      ((REFRESH_METADATA)) && pacman_args=(-Syu --needed --noconfirm)
      if ! "${PRIV[@]}" pacman "${pacman_args[@]}" "${packages[@]}"; then
        warn "Grouped pacman installation failed; retrying package-by-package."
        local pkg
        for pkg in "${packages[@]}"; do
          "${PRIV[@]}" pacman -S --needed --noconfirm "$pkg" || warn "Skipped unavailable/problematic package: $pkg"
        done
      fi
      ;;
    zypper)
      if ! "${PRIV[@]}" zypper --non-interactive install --no-recommends "${packages[@]}"; then
        warn "Grouped zypper installation failed; retrying package-by-package."
        local pkg
        for pkg in "${packages[@]}"; do
          "${PRIV[@]}" zypper --non-interactive install --no-recommends "$pkg" \
            || warn "Skipped unavailable/problematic package: $pkg"
        done
      fi
      ;;
    *)
      warn "Skipping system packages in ${PKG_FAMILY} mode: ${packages[*]}"
      ;;
  esac
}
