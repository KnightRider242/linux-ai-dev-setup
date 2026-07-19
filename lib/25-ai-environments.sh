conda_env_exists() {
  "$CONDA_BIN" env list | awk '{print $1}' | grep -Fxq "$1"
}

info "Creating/updating Conda environment: ${AI_ENV}"
if conda_env_exists "$AI_ENV"; then
  "$MAMBA_BIN" env update -n "$AI_ENV" -f "$ENV_FILE" --prune -y
else
  "$MAMBA_BIN" env create -f "$ENV_FILE" -y
fi

CONDA_RUN=("$CONDA_BIN" run -n "$AI_ENV")
"${CONDA_RUN[@]}" python -m pip install --upgrade pip setuptools wheel

NVIDIA_DRIVER=""
GPU_COMPUTE_CAP=""
if command -v nvidia-smi >/dev/null 2>&1; then
  NVIDIA_DRIVER="$(nvidia-smi --query-gpu=driver_version --format=csv,noheader 2>/dev/null | head -n1 | tr -d '[:space:]' || true)"
  GPU_COMPUTE_CAP="$(nvidia-smi --query-gpu=compute_cap --format=csv,noheader 2>/dev/null | head -n1 | tr -d '[:space:]' || true)"
  info "NVIDIA driver: ${NVIDIA_DRIVER:-unknown}; GPU compute capability: ${GPU_COMPUTE_CAP:-unknown}"
else
  warn "nvidia-smi was not found. CPU PyTorch will be installed unless --pytorch-mode overrides it."
fi

select_pytorch_mode() {
  if [[ "$PYTORCH_MODE" != "auto" ]]; then
    printf '%s' "$PYTORCH_MODE"
    return
  fi
  if [[ -z "$NVIDIA_DRIVER" || ! "$ARCH" =~ ^(x86_64|amd64)$ ]]; then
    printf 'cpu'
  elif [[ -n "$GPU_COMPUTE_CAP" ]] && version_ge "$GPU_COMPUTE_CAP" "12.0" && ! version_ge "$NVIDIA_DRIVER" "580.0"; then
    warn "Blackwell-class GPU detected with a pre-580 driver. Upgrade the NVIDIA driver for CUDA 13 wheels; using CPU PyTorch for now."
    printf 'cpu'
  elif [[ -n "$GPU_COMPUTE_CAP" ]] && ! version_ge "$GPU_COMPUTE_CAP" "7.5"; then
    printf 'cu126'
  elif version_ge "$NVIDIA_DRIVER" "580.0"; then
    printf 'cu130'
  elif version_ge "$NVIDIA_DRIVER" "525.60.13"; then
    printf 'cu126'
  else
    warn "NVIDIA driver is too old for the selected supported CUDA wheels; using CPU PyTorch."
    printf 'cpu'
  fi
}

SELECTED_PYTORCH_MODE="$(select_pytorch_mode)"
info "Installing PyTorch mode: ${SELECTED_PYTORCH_MODE}"
case "$SELECTED_PYTORCH_MODE" in
  cu130)
    "${CONDA_RUN[@]}" python -m pip install --upgrade torch torchvision torchaudio \
      --index-url https://download.pytorch.org/whl/cu130
    ;;
  cu126)
    "${CONDA_RUN[@]}" python -m pip install --upgrade torch torchvision torchaudio \
      --index-url https://download.pytorch.org/whl/cu126
    ;;
  cpu)
    "${CONDA_RUN[@]}" python -m pip install --upgrade torch torchvision torchaudio \
      --index-url https://download.pytorch.org/whl/cpu
    ;;
esac

info "Installing deep-learning, computer-vision, experiment-tracking, and backend libraries"
"${CONDA_RUN[@]}" python -m pip install --upgrade \
  transformers datasets accelerate evaluate sentencepiece safetensors huggingface-hub \
  timm lightning torchmetrics tensorboard kornia einops torchinfo \
  optuna hydra-core onnx onnxruntime \
  psycopg[binary] sqlalchemy alembic pymongo motor \
  fastapi 'uvicorn[standard]' pydantic-settings httpx

"${CONDA_RUN[@]}" python -m pip install --upgrade \
  ultralytics wandb mlflow gradio streamlit labelme \
  || warn "One or more optional AI applications failed; the core environment remains usable."

"${CONDA_RUN[@]}" python -m ipykernel install --user --name "$AI_ENV" --display-name "Python (${AI_ENV})"

if ((INSTALL_CUDA_TOOLKIT)); then
  info "Installing CUDA toolkit/nvcc inside ${AI_ENV}"
  case "$SELECTED_PYTORCH_MODE" in
    cu130) "$MAMBA_BIN" install -n "$AI_ENV" -y -c nvidia cuda-toolkit=13 ;;
    *) "$MAMBA_BIN" install -n "$AI_ENV" -y -c nvidia cuda-toolkit=12.6 ;;
  esac
fi

if ((INSTALL_TENSORFLOW)); then
  info "Creating/updating separate TensorFlow environment: ai-tf"
  if conda_env_exists ai-tf; then
    "$MAMBA_BIN" install -n ai-tf -y python=3.11 pip ipykernel jupyterlab numpy pandas matplotlib
  else
    "$MAMBA_BIN" create -n ai-tf -y python=3.11 pip ipykernel jupyterlab numpy pandas matplotlib
  fi
  "$CONDA_BIN" run -n ai-tf python -m pip install --upgrade pip
  if [[ -n "$NVIDIA_DRIVER" && "$ARCH" =~ ^(x86_64|amd64)$ ]]; then
    "$CONDA_BIN" run -n ai-tf python -m pip install --upgrade 'tensorflow[and-cuda]'
  else
    "$CONDA_BIN" run -n ai-tf python -m pip install --upgrade tensorflow
  fi
  "$CONDA_BIN" run -n ai-tf python -m ipykernel install --user --name ai-tf --display-name "Python (ai-tf)"
fi

if ((INSTALL_JAX)); then
  info "Creating/updating separate JAX environment: ai-jax"
  if conda_env_exists ai-jax; then
    "$MAMBA_BIN" install -n ai-jax -y python=3.11 pip ipykernel jupyterlab numpy scipy matplotlib
  else
    "$MAMBA_BIN" create -n ai-jax -y python=3.11 pip ipykernel jupyterlab numpy scipy matplotlib
  fi
  "$CONDA_BIN" run -n ai-jax python -m pip install --upgrade pip
  case "$SELECTED_PYTORCH_MODE" in
    cu130) "$CONDA_BIN" run -n ai-jax python -m pip install --upgrade 'jax[cuda13]' ;;
    cu126) "$CONDA_BIN" run -n ai-jax python -m pip install --upgrade 'jax[cuda12]' ;;
    *) "$CONDA_BIN" run -n ai-jax python -m pip install --upgrade jax ;;
  esac
  "$CONDA_BIN" run -n ai-jax python -m ipykernel install --user --name ai-jax --display-name "Python (ai-jax)"
fi
