info "Installing Miniforge (Conda + Mamba)"
if [[ ! -x "${MINIFORGE_DIR}/bin/conda" ]]; then
  tmp_dir="$(mktemp -d)"
  case "$ARCH" in
    x86_64|amd64) miniforge_arch="x86_64" ;;
    aarch64|arm64) miniforge_arch="aarch64" ;;
    ppc64le) miniforge_arch="ppc64le" ;;
    *) die "Unsupported Miniforge architecture: ${ARCH}" ;;
  esac

  latest_release_url="$(
    curl -fsSLI --retry 3 --retry-delay 2 \
      -o /dev/null -w '%{url_effective}' \
      "https://github.com/conda-forge/miniforge/releases/latest"
  )"
  latest_release_url="${latest_release_url%/}"
  miniforge_version="${latest_release_url##*/}"
  [[ -n "$miniforge_version" && "$miniforge_version" != "latest" ]] \
    || die "Could not determine the latest Miniforge release version."

  installer="Miniforge3-${miniforge_version}-Linux-${miniforge_arch}.sh"
  base_url="https://github.com/conda-forge/miniforge/releases/download/${miniforge_version}"
  curl -fL --retry 3 --retry-delay 2 \
    "${base_url}/${installer}" -o "${tmp_dir}/${installer}"
  curl -fL --retry 3 --retry-delay 2 \
    "${base_url}/${installer}.sha256" -o "${tmp_dir}/${installer}.sha256"
  (
    cd "$tmp_dir"
    sha256sum -c "${installer}.sha256"
  )
  bash "${tmp_dir}/${installer}" -b -p "$MINIFORGE_DIR"
  rm -rf "$tmp_dir"
else
  info "Miniforge already exists at ${MINIFORGE_DIR}"
fi

CONDA_BIN="${MINIFORGE_DIR}/bin/conda"
MAMBA_BIN="${MINIFORGE_DIR}/bin/mamba"
"$CONDA_BIN" init bash >/dev/null
for shell_name in zsh fish; do
  command -v "$shell_name" >/dev/null 2>&1 && "$CONDA_BIN" init "$shell_name" >/dev/null 2>&1 || true
done
"$CONDA_BIN" config --set auto_activate_base false
"$CONDA_BIN" config --set channel_priority strict
"$CONDA_BIN" update -n base -y conda mamba \
  || warn "Miniforge base update failed; the installed conda/mamba versions will be used."

mkdir -p "$WORKSPACE_DIR"
ENV_FILE="${WORKSPACE_DIR}/environment-ai.yml"
cat > "$ENV_FILE" <<EOF
name: ${AI_ENV}
channels:
  - conda-forge
dependencies:
  - python=3.11
  - pip
  - setuptools
  - wheel
  - ipykernel
  - ipywidgets
  - jupyterlab
  - notebook
  - jupyterlab-git
  - numpy
  - scipy
  - pandas
  - polars
  - pyarrow
  - scikit-learn
  - scikit-image
  - matplotlib
  - seaborn
  - plotly
  - pillow
  - imageio
  - imageio-ffmpeg
  - opencv
  - albumentations
  - ffmpeg
  - av
  - h5py
  - sympy
  - networkx
  - tqdm
  - pyyaml
  - requests
  - rich
  - pytest
  - pytest-cov
  - black
  - ruff
  - mypy
  - pre-commit
EOF
