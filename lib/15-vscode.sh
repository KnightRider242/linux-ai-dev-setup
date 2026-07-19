install_vscode_manual() {
  local vscode_arch
  case "$ARCH" in
    x86_64|amd64) vscode_arch="x64" ;;
    aarch64|arm64) vscode_arch="arm64" ;;
    armv7l|armhf) vscode_arch="armhf" ;;
    *) warn "No official VS Code portable build mapping for architecture: ${ARCH}"; return 1 ;;
  esac

  info "Installing official VS Code into the user account"
  local tmp_dir archive install_dir
  tmp_dir="$(mktemp -d)"
  archive="${tmp_dir}/vscode.tar.gz"
  install_dir="${HOME}/.local/opt/vscode"
  curl -fL "https://update.code.visualstudio.com/latest/linux-${vscode_arch}/stable" -o "$archive"
  rm -rf "$install_dir"
  mkdir -p "$install_dir"
  tar -xzf "$archive" -C "$install_dir" --strip-components=1
  ln -sfn "${install_dir}/bin/code" "${HOME}/.local/bin/code"

  mkdir -p "${HOME}/.local/share/applications"
  cat > "${HOME}/.local/share/applications/visual-studio-code.desktop" <<EOF
[Desktop Entry]
Name=Visual Studio Code
Comment=Code Editing. Redefined.
GenericName=Text Editor
Exec=${install_dir}/code %F
Icon=${install_dir}/resources/app/resources/linux/code.png
Type=Application
StartupNotify=false
StartupWMClass=Code
Categories=TextEditor;Development;IDE;
MimeType=application/x-code-workspace;
Actions=new-empty-window;
Keywords=vscode;

[Desktop Action new-empty-window]
Name=New Empty Window
Exec=${install_dir}/code --new-window %F
Icon=${install_dir}/resources/app/resources/linux/code.png
EOF
  rm -rf "$tmp_dir"
}

install_vscode() {
  command -v code >/dev/null 2>&1 && { info "VS Code is already installed"; return 0; }
  info "Installing Visual Studio Code"

  case "$PKG_FAMILY" in
    apt)
      if [[ "$ARCH" =~ ^(x86_64|amd64|aarch64|arm64|armv7l|armhf)$ ]]; then
        curl -fsSL https://packages.microsoft.com/keys/microsoft.asc \
          | gpg --dearmor \
          | "${PRIV[@]}" tee /usr/share/keyrings/microsoft.gpg >/dev/null
        "${PRIV[@]}" tee /etc/apt/sources.list.d/vscode.sources >/dev/null <<'EOF'
Types: deb
URIs: https://packages.microsoft.com/repos/code
Suites: stable
Components: main
Architectures: amd64 arm64 armhf
Signed-By: /usr/share/keyrings/microsoft.gpg
EOF
        "${PRIV[@]}" apt-get update
        "${PRIV[@]}" env DEBIAN_FRONTEND=noninteractive apt-get install -y code \
          || install_vscode_manual
      else
        install_vscode_manual
      fi
      ;;
    dnf|yum)
      if [[ "$ARCH" == "x86_64" || "$ARCH" == "amd64" ]]; then
        local rpm_pkg_cmd="$PKG_FAMILY"
        "${PRIV[@]}" rpm --import https://packages.microsoft.com/keys/microsoft.asc
        "${PRIV[@]}" tee /etc/yum.repos.d/vscode.repo >/dev/null <<'EOF'
[code]
name=Visual Studio Code
baseurl=https://packages.microsoft.com/yumrepos/vscode
enabled=1
autorefresh=1
type=rpm-md
gpgcheck=1
gpgkey=https://packages.microsoft.com/keys/microsoft.asc
EOF
        if [[ "$rpm_pkg_cmd" == "dnf" ]]; then
          "${PRIV[@]}" dnf makecache --refresh -y
          "${PRIV[@]}" dnf install -y code || install_vscode_manual
        else
          "${PRIV[@]}" yum makecache -y
          "${PRIV[@]}" yum install -y code || install_vscode_manual
        fi
      else
        install_vscode_manual
      fi
      ;;
    zypper)
      if [[ "$ARCH" == "x86_64" || "$ARCH" == "amd64" ]]; then
        "${PRIV[@]}" rpm --import https://packages.microsoft.com/keys/microsoft.asc
        "${PRIV[@]}" tee /etc/zypp/repos.d/vscode.repo >/dev/null <<'EOF'
[code]
name=Visual Studio Code
baseurl=https://packages.microsoft.com/yumrepos/vscode
enabled=1
autorefresh=1
type=rpm-md
gpgcheck=1
gpgkey=https://packages.microsoft.com/keys/microsoft.asc
EOF
        "${PRIV[@]}" zypper --non-interactive refresh
        "${PRIV[@]}" zypper --non-interactive install code || install_vscode_manual
      else
        install_vscode_manual
      fi
      ;;
    *)
      install_vscode_manual
      ;;
  esac
}

if ((INSTALL_VSCODE)); then
  install_vscode || warn "VS Code installation failed; the remaining setup will continue."
fi
