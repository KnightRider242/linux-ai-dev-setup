# Linux AI + Web Development Setup

This package configures a Linux workstation for:

- NVIDIA-backed PyTorch AI, deep-learning, and computer-vision research
- A reusable Miniforge/Conda environment named `ai-dev`
- Optional separate TensorFlow (`ai-tf`) and JAX (`ai-jax`) environments
- JupyterLab, Hugging Face, OpenCV, Ultralytics, MLflow, W&B, Optuna, ONNX, Gradio, and Streamlit
- Angular and React/TypeScript development using Node.js LTS
- FastAPI and Python database development
- PostgreSQL and MongoDB containers using Podman or an existing Docker installation
- Official Visual Studio Code where supported, with a portable Microsoft build fallback
- OpenAI Codex CLI
- Firefox and useful Windows-to-Linux migration applications

## Distribution support

| Distribution family | Package strategy | Examples |
|---|---|---|
| Debian/Ubuntu | `apt` | Ubuntu, Debian, Linux Mint, Pop!_OS, Kali |
| Fedora/RHEL | `dnf` | Fedora, Nobara, Rocky, AlmaLinux |
| Older RHEL-like | `yum` | CentOS/RHEL systems still using Yum |
| Arch | `pacman` | Arch, Manjaro, EndeavourOS, Garuda |
| openSUSE/SLE | `zypper` | Tumbleweed, Leap, SLE |
| Other glibc Linux | Portable mode | User-space tools are installed; system packages are skipped |

The script detects the package manager rather than relying only on the distribution name. Unavailable distro packages are skipped individually instead of terminating the complete installation.

### Important limits

No single mutable shell script can safely install system packages on literally every Linux distribution.

- **Alpine/musl:** not supported because Miniforge and the selected binary AI packages require glibc. Use an Ubuntu or Fedora container/VM.
- **NixOS:** not guaranteed because of its declarative package model and non-standard runtime paths. A Nix-native configuration is preferable.
- **Silverblue, Kinoite, Bazzite, and other rpm-ostree systems:** system package layering is skipped. The portable parts may work, but Toolbox or Distrobox is the safer development approach.
- **Jetson/aarch64 NVIDIA systems:** use NVIDIA JetPack-specific PyTorch packages. The automatic CUDA wheel selection is intended primarily for x86-64 workstations.
- The script does not install or replace the NVIDIA kernel driver.

## Recommended command

First inspect what the script detects:

```bash
chmod +x linux-ai-dev-setup.sh
./linux-ai-dev-setup.sh --dry-run
```

Then run the setup as your normal desktop user:

```bash
./linux-ai-dev-setup.sh
```

Do not prefix the command with `sudo`. The script requests `sudo` or `doas` only for system-level packages.

## Common options

Install PyTorch plus separate TensorFlow and JAX environments:

```bash
./linux-ai-dev-setup.sh --full-ai
```

Install the CUDA compiler/toolkit inside the Conda environment for custom CUDA extensions:

```bash
./linux-ai-dev-setup.sh --with-cuda-toolkit
```

Combine both:

```bash
./linux-ai-dev-setup.sh --full-ai --with-cuda-toolkit
```

Force a particular PyTorch build when automatic GPU detection is unsuitable:

```bash
./linux-ai-dev-setup.sh --pytorch-mode cu130
./linux-ai-dev-setup.sh --pytorch-mode cu126
./linux-ai-dev-setup.sh --pytorch-mode cpu
```

Other useful options:

```text
--system-upgrade       Upgrade existing OS packages before setup
--skip-update          Skip package metadata refresh
--skip-desktop-apps    Skip optional graphical applications
--skip-databases       Skip PostgreSQL and MongoDB containers
--skip-vscode          Skip VS Code and its extensions
--skip-vscode-ext      Install VS Code but not the extensions
```

On Arch-family distributions, package installation uses `pacman -Syu` by default to avoid an unsupported partial upgrade.

## What is installed

### Main `ai-dev` Conda environment

- Python 3.11
- PyTorch, TorchVision, and TorchAudio
- JupyterLab and an `ai-dev` Jupyter kernel
- NumPy, SciPy, Pandas, Polars, PyArrow, and scikit-learn
- OpenCV, scikit-image, Albumentations, Pillow, ImageIO, AV, and FFmpeg
- Transformers, Datasets, Accelerate, Evaluate, TIMM, and SentencePiece
- Lightning, TorchMetrics, TensorBoard, Kornia, and Einops
- Ultralytics, ONNX, ONNX Runtime, MLflow, W&B, Optuna, Gradio, and Streamlit
- FastAPI, Uvicorn, SQLAlchemy, Alembic, Psycopg, PyMongo, and Motor
- Ruff, Black, MyPy, Pytest, and pre-commit

### Web development

- Node.js LTS through `fnm`
- npm, pnpm, Yarn, TypeScript, TSX, and Angular CLI
- React projects through Vite

### IDE and CLI

- Visual Studio Code
- Python, Pylance, Jupyter, Ruff, Black, C/C++, CMake, Angular, ESLint, Prettier, PostgreSQL, MongoDB, GitHub, and Codex extensions
- OpenAI Codex CLI
- Git, Git LFS, CMake, Ninja, Clang/GCC, GDB, ShellCheck, ripgrep, fd, fzf, tmux, and common utilities

### Containers and databases

The installer installs **Podman**, `podman-compose`, Buildah, and Skopeo when they are available from the distribution repositories. It does not install Docker Engine automatically. If Docker is already installed, the generated service scripts can use it as a fallback.

Container-engine selection order:

1. `podman-compose`
2. `podman compose`
3. `docker compose`

The setup creates isolated development services in `~/dev-services`:

- PostgreSQL 17
- MongoDB 8

Credentials are generated locally in:

```text
~/dev-services/.env
```

Do not commit that file to Git.

### Desktop applications

The script attempts to install:

- Firefox
- LibreOffice
- VLC
- KeePassXC
- FileZilla
- Remmina
- Flameshot
- GParted
- Thunderbird
- DBeaver Community
- Postman
- Flatseal
- Zotero

Package availability varies by distribution. Flatpak is used for several cross-distribution applications when available.

## After installation

Open a new terminal, then run:

```bash
conda activate ai-dev
jupyter lab
```

Verify PyTorch, OpenCV, and GPU access:

```bash
conda run -n ai-dev python ~/ai-workspace/verify_ai_setup.py
nvidia-smi
```

Open the research workspace:

```bash
code ~/ai-workspace
```

Start Codex and sign in with ChatGPT:

```bash
codex
```

Create an Angular application:

```bash
ng new my-angular-app
cd my-angular-app
ng serve
```

Create a React TypeScript application:

```bash
npm create vite@latest my-react-app -- --template react-ts
cd my-react-app
npm install
npm run dev
```

Start the databases:

```bash
~/dev-services/start.sh
```

Open database shells:

```bash
~/dev-services/psql.sh
~/dev-services/mongosh.sh
```

## Files created in your home directory

```text
~/miniforge3/                         Miniforge installation
~/ai-workspace/environment-ai.yml     Reusable Conda environment definition
~/ai-workspace/verify_ai_setup.py     AI/GPU verification script
~/ai-workspace/QUICKSTART.txt         Generated quick-start instructions
~/dev-services/compose.yml            PostgreSQL and MongoDB services
~/dev-services/.env                   Generated database credentials
~/.local/state/linux-ai-dev-setup/    Installation logs
```

## Repository contents

```text
linux-ai-dev-setup.sh   Main cross-distribution installer
README.md               Installation, usage, and troubleshooting guide
SHA256SUMS.txt          Integrity hashes for tracked release files
```

## Safety notes

- Run `--dry-run` before the first installation.
- Review the script before executing it on a production workstation.
- Run it as a normal user, not with `sudo`.
- The installer does not replace the NVIDIA kernel driver.
- Database passwords are generated locally and stored in `~/dev-services/.env`.
- Re-running the script is supported; existing environments and tools are updated where practical.

## Upstream installation references

- [Miniforge](https://github.com/conda-forge/miniforge)
- [Visual Studio Code on Linux](https://code.visualstudio.com/docs/setup/linux)
- [PyTorch local installation](https://docs.pytorch.org/get-started/locally/)
- [OpenAI Codex CLI](https://github.com/openai/codex)
