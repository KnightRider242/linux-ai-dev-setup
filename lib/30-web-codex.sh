info "Installing Node.js LTS with fnm and Angular/React development tools"
if ! command -v fnm >/dev/null 2>&1 && [[ ! -x "${HOME}/.local/share/fnm/fnm" ]]; then
  fnm_installer="$(mktemp)"
  curl -fsSL https://fnm.vercel.app/install -o "$fnm_installer"
  bash "$fnm_installer"
  rm -f "$fnm_installer"
fi
export PATH="${HOME}/.local/share/fnm:${PATH}"
if command -v fnm >/dev/null 2>&1 || [[ -x "${HOME}/.local/share/fnm/fnm" ]]; then
  FNM_BIN="$(command -v fnm 2>/dev/null || printf '%s' "${HOME}/.local/share/fnm/fnm")"
  eval "$("$FNM_BIN" env --shell bash)"
  "$FNM_BIN" install --lts
  "$FNM_BIN" use lts/latest
  CURRENT_NODE="$(node --version | sed 's/^v//')"
  "$FNM_BIN" default "$CURRENT_NODE"
  npm install --global npm@latest pnpm yarn typescript tsx @angular/cli
else
  warn "fnm was not detected. Trying the distribution Node.js package."
  case "$PKG_FAMILY" in
    apt|dnf|yum|pacman|zypper) install_packages nodejs npm ;;
  esac
  command -v npm >/dev/null 2>&1 \
    && npm install --global pnpm yarn typescript tsx @angular/cli \
    || warn "Node.js tools could not be installed."
fi

info "Installing OpenAI Codex CLI"
CODEX_INSTALLER="$(mktemp)"
if curl -fsSL https://chatgpt.com/codex/install.sh -o "$CODEX_INSTALLER" && sh "$CODEX_INSTALLER"; then
  :
elif command -v npm >/dev/null 2>&1; then
  warn "Codex install script failed; trying the official npm package."
  npm install --global @openai/codex
else
  warn "Codex CLI could not be installed."
fi
rm -f "$CODEX_INSTALLER"

if ((INSTALL_VSCODE_EXTENSIONS)) && command -v code >/dev/null 2>&1; then
  info "Installing VS Code extensions"
  VSCODE_EXTENSIONS=(
    ms-python.python
    ms-python.vscode-pylance
    ms-toolsai.jupyter
    charliermarsh.ruff
    ms-python.black-formatter
    ms-vscode.cpptools
    ms-vscode.cmake-tools
    ms-vscode-remote.remote-ssh
    ms-vscode-remote.remote-containers
    ms-azuretools.vscode-docker
    dbaeumer.vscode-eslint
    esbenp.prettier-vscode
    angular.ng-template
    bradlc.vscode-tailwindcss
    mongodb.mongodb-vscode
    ms-ossdata.vscode-pgsql
    humao.rest-client
    redhat.vscode-yaml
    tamasfe.even-better-toml
    editorconfig.editorconfig
    eamodio.gitlens
    github.vscode-pull-request-github
    streetsidesoftware.code-spell-checker
    openai.chatgpt
  )
  for extension in "${VSCODE_EXTENSIONS[@]}"; do
    code --install-extension "$extension" --force || warn "Could not install VS Code extension: $extension"
  done
elif ((INSTALL_VSCODE_EXTENSIONS)); then
  warn "VS Code command 'code' was not found, so extensions were skipped."
fi