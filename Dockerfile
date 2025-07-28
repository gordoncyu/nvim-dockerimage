FROM python:3.12-slim

ARG DEBIAN_FRONTEND=noninteractive

#── build‑time identity (override via --build-arg) ─────────────────
ARG BUILD_USER=nvim
ARG BUILD_UID=1000
ARG BUILD_GID=1000

#── 1. OS packages ────────────────────────────────────────────────
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        git curl ca-certificates unzip tar build-essential \
        gnupg apt-transport-https \
        xz-utils \
        ripgrep \
        ranger \
        nodejs npm && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

#── 1a. Create unprivileged build user and switch ────────────────
RUN groupadd -g ${BUILD_GID} ${BUILD_USER} && \
    useradd -m -u ${BUILD_UID} -g ${BUILD_GID} -s /bin/bash ${BUILD_USER}
USER ${BUILD_UID}:${BUILD_GID}
ENV HOME=/home/${BUILD_USER}
WORKDIR $HOME

#── 1b. Per‑user toolchain paths ────────────────────────────────
ENV DOTNET_ROOT=${HOME}/.dotnet
ENV CARGO_HOME=${HOME}/.cargo
ENV PATH=${HOME}/.local/bin:${CARGO_HOME}/bin:${DOTNET_ROOT}:${PATH}

#── 2. Install .NET SDK 8.0 (user‑local) ────────────────────────
RUN curl -SL https://dot.net/v1/dotnet-install.sh -o dotnet-install.sh && \
    chmod +x dotnet-install.sh && \
    ./dotnet-install.sh --channel 8.0 && \
    rm dotnet-install.sh

#── 3. Install Rust + Cargo (user‑local) ────────────────────────
RUN curl https://sh.rustup.rs -sSf | sh -s -- -y

#── 3b. tree‑sitter CLI (required by nvim‑treesitter for some grammars) ───────────
RUN cargo install --locked tree-sitter-cli

#── 4. Python deps for bootstrap (user‑local) ───────────────────
RUN pip3 install --user --no-cache-dir pyyaml pynvim

#── 3. Install Neovim AppImage (no FUSE) ──────────────────────────
#    The URL defaults to what’s in YAML but can be overridden.
ARG NVIM_APPIMAGE_URL="https://github.com/neovim/neovim/releases/download/v0.11.3/nvim-linux-x86_64.appimage"
RUN mkdir -p $HOME/.local/bin $HOME/.local/share $HOME/.local/lib && \
    curl -L -o /tmp/nvim.appimage "${NVIM_APPIMAGE_URL}" && \
    chmod +x /tmp/nvim.appimage && \
    /tmp/nvim.appimage --appimage-extract >/dev/null && \
    cp -a squashfs-root/usr/share/nvim      $HOME/.local/share/ && \
    cp -a squashfs-root/usr/lib             $HOME/.local/lib/ && \
    cp -a squashfs-root/usr/bin/nvim        $HOME/.local/bin/ && \
    $HOME/.local/bin/nvim --headless -u NONE +q && \
    rm -rf /tmp/nvim.appimage squashfs-root

#── 5. Copy manifest + bootstrap script, run bootstrap ────────────
COPY nvim-build.yaml      /tmp/
COPY build_nvim_assets.py /tmp/
RUN python3 /tmp/build_nvim_assets.py /tmp/nvim-build.yaml

#── 6. Entrypoint ────────────────────────────────────────────────
# ENTRYPOINT ["nvim"]
CMD ["bash"]

