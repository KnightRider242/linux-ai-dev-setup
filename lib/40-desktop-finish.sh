if ((INSTALL_DESKTOP_APPS)); then
  info "Installing useful Windows-to-Linux desktop applications"
  case "$PKG_FAMILY" in
    apt)
      DESKTOP_PACKAGES=(libreoffice vlc keepassxc filezilla remmina flameshot gparted gnome-disk-utility thunderbird)
      ;;
    dnf|yum)
      DESKTOP_PACKAGES=(libreoffice vlc keepassxc filezilla remmina flameshot gparted gnome-disk-utility thunderbird)
      ;;
    pacman)
      DESKTOP_PACKAGES=(libreoffice-fresh vlc keepassxc filezilla remmina flameshot gparted gnome-disk-utility thunderbird)
      ;;
    zypper)
      DESKTOP_PACKAGES=(libreoffice vlc keepassxc filezilla remmina flameshot gparted gnome-disk-utility MozillaThunderbird)
      ;;
    *) DESKTOP_PACKAGES=() ;;
  esac
  install_packages "${DESKTOP_PACKAGES[@]}"

  if command -v flatpak >/dev/null 2>&1; then
    flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo || true
    FLATPAK_APPS=(
      io.dbeaver.DBeaverCommunity
      com.getpostman.Postman
      com.github.tchx84.Flatseal
      org.zotero.Zotero
    )
    if ! command -v firefox >/dev/null 2>&1; then
      FLATPAK_APPS+=(org.mozilla.firefox)
    fi
    for app in "${FLATPAK_APPS[@]}"; do
      flatpak install -y --noninteractive flathub "$app" || warn "Could not install Flatpak: $app"
    done
  elif ! command -v firefox >/dev/null 2>&1; then
    warn "Firefox was not installed. Install Firefox through your distribution's application store."
  fi
fi

cat > "${WORKSPACE_DIR}/verify_ai_setup.py" <<'PY'
import platform

print(f"Python: {platform.python_version()}")

import numpy as np
import cv2
import torch

print(f"NumPy: {np.__version__}")
print(f"OpenCV: {cv2.__version__}")
print(f"PyTorch: {torch.__version__}")
print(f"CUDA available: {torch.cuda.is_available()}")
print(f"PyTorch CUDA runtime: {torch.version.cuda}")
if torch.cuda.is_available():
    print(f"GPU: {torch.cuda.get_device_name(0)}")
    x = torch.randn(1024, 1024, device="cuda")
    print(f"GPU tensor test: {float(x.mean()):.6f}")
PY

info "Verifying the main AI environment"
"${CONDA_RUN[@]}" python "${WORKSPACE_DIR}/verify_ai_setup.py" \
  || warn "Verification reported a problem. Review the output and ${LOG_FILE}."

cat > "${WORKSPACE_DIR}/QUICKSTART.txt" <<EOF
LINUX AI DEVELOPMENT QUICK START
================================

Open a new terminal, then:

  conda activate ${AI_ENV}
  jupyter lab

Verify AI/GPU:

  conda run -n ${AI_ENV} python ${WORKSPACE_DIR}/verify_ai_setup.py
  nvidia-smi

VS Code:

  code ${WORKSPACE_DIR}
  # In VS Code choose: Python (${AI_ENV})

Codex CLI:

  codex
  # First run lets you sign in with ChatGPT.

Angular:

  ng new my-angular-app
  cd my-angular-app
  ng serve

React with Vite:

  npm create vite@latest my-react-app -- --template react-ts
  cd my-react-app
  npm install
  npm run dev

Databases:

  ${SERVICES_DIR}/start.sh
  ${SERVICES_DIR}/psql.sh
  ${SERVICES_DIR}/mongosh.sh

Database credentials:

  ${SERVICES_DIR}/.env

Do not commit that .env file to Git.
EOF

info "Setup complete"
printf '\nDistribution:      %s\n' "$DISTRO_NAME"
printf 'Package strategy:  %s\n' "$PKG_FAMILY"
printf 'Main environment:  conda activate %s\n' "$AI_ENV"
printf 'PyTorch mode:      %s\n' "$SELECTED_PYTORCH_MODE"
printf 'Quick-start guide: %s\n' "${WORKSPACE_DIR}/QUICKSTART.txt"
printf 'AI verification:   %s\n' "${WORKSPACE_DIR}/verify_ai_setup.py"
printf 'Database services: %s\n' "$SERVICES_DIR"
printf 'Installation log:  %s\n' "$LOG_FILE"
printf '\nOpen a new terminal before using conda/fnm. Run codex once to sign in.\n'
