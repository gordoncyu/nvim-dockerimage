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

#── 1b. Install .NET SDK 8.0 ───────────────────────────────────────
RUN curl -SL https://dot.net/v1/dotnet-install.sh -o dotnet-install.sh && \
    chmod +x dotnet-install.sh && \
    ./dotnet-install.sh --channel 8.0 --install-dir /usr/share/dotnet && \
    ln -s /usr/share/dotnet/dotnet /usr/bin/dotnet && \
    rm dotnet-install.sh

ENV DOTNET_ROOT=/usr/share/dotnet

#── 2. Python deps for bootstrap ──────────────────────────────────
RUN pip3 install --no-cache-dir pyyaml pynvim

#── 3. Install Neovim AppImage (no FUSE) ──────────────────────────
#    The URL defaults to what’s in YAML but can be overridden.
ARG NVIM_APPIMAGE_URL="https://github.com/neovim/neovim/releases/download/v0.11.3/nvim-linux-x86_64.appimage"
RUN curl -L -o /tmp/nvim.appimage "${NVIM_APPIMAGE_URL}" \
   && chmod +x /tmp/nvim.appimage \
    && /tmp/nvim.appimage --appimage-extract >/dev/null \
    && cp -a squashfs-root/usr/share/nvim      /usr/local/share/ \
    && cp -a squashfs-root/usr/lib             /usr/local/        \
    && cp -a squashfs-root/usr/bin/nvim        /usr/local/bin/    \
    && nvim --headless -u NONE +q \
    && ln -s /usr/local/bin/nvim /usr/bin/nvim \
    && rm -rf /tmp/nvim.appimage squashfs-root

#── 4. Create image user ──────────────────────────────────────────
RUN groupadd -g ${BUILD_GID} ${BUILD_USER} && \
    useradd  -m -u ${BUILD_UID} -g ${BUILD_GID} -s /bin/bash ${BUILD_USER}
USER ${BUILD_UID}:${BUILD_GID}
WORKDIR /home/${BUILD_USER}

#── 5. Copy manifest + bootstrap script, run bootstrap ────────────
COPY nvim-build.yaml      /tmp/
COPY build_nvim_assets.py /tmp/
RUN python3 /tmp/build_nvim_assets.py /tmp/nvim-build.yaml

#── 6. Entrypoint ────────────────────────────────────────────────
# ENTRYPOINT ["nvim"]
CMD ["bash"]

