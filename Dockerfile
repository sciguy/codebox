# opencode-dev/Dockerfile
# CodeBox: A secure development container for running OpenCode agentically on a mounted workspace,
# with git + common CLI tools, running as a non-root user.
#
# Build arguments:
#   - USERNAME: The non-root user name (default: dev)
#   - UID: User ID for the non-root user (default: 1000)
#   - GID: Group ID for the non-root user (default: 1000)
#   - OPENCODE_VERSION: Version to install, or "latest" (default: latest)
#   - CODEBOX_NAME: Container root directory name (default: BOX)
#
# Usage:
#   Use the provided codebox.sh script to build and run the container easily

FROM ubuntu:24.04

# Metadata labels following OCI standards
LABEL org.opencontainers.image.title="CodeBox: OpenCode Development Container"
LABEL org.opencontainers.image.description="Secure development container for running OpenCode with git and common CLI tools"
LABEL org.opencontainers.image.vendor="Custom"
LABEL org.opencontainers.image.source="https://github.com/anomalyco/opencode"
LABEL org.opencontainers.image.documentation="https://opencode.ai/docs"
LABEL maintainer="custom-build"

ENV DEBIAN_FRONTEND=noninteractive
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# ========================================
# Install core tools for agentic coding workflows
# ========================================
ARG DOCKER_PACKAGES=
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    ubuntu-keyring \
    curl \
    git \
    bash \
    ripgrep \
    less \
    jq \
    tzdata \
    ${DOCKER_PACKAGES} \
 && rm -rf /var/lib/apt/lists/*

# ========================================
# Create a non-root user that can write to the container root
# Ubuntu 24.04 comes with 'ubuntu' user at UID/GID 1000, so we handle this gracefully
# ========================================
ARG USERNAME=dev
ARG UID=1000
ARG GID=1000
ARG CODEBOX_NAME=BOX

# Store build-time values as environment variables for inspection
ENV UID=${UID}
ENV GID=${GID}
ENV CODEBOX_NAME=${CODEBOX_NAME}

RUN \
    # Check if the GID already exists, if not create it
    if ! getent group ${GID} >/dev/null; then \
        groupadd -g ${GID} ${USERNAME}; \
    else \
        # If GID exists but with different name, use existing group
        EXISTING_GROUP=$(getent group ${GID} | cut -d: -f1); \
        echo "Using existing group: ${EXISTING_GROUP} (${GID})"; \
    fi && \
    # Check if the UID already exists, if not create the user
    if ! getent passwd ${UID} >/dev/null; then \
        useradd -m -u ${UID} -g ${GID} -s /bin/bash ${USERNAME}; \
    else \
        # If UID exists, check if it's the user we want
        EXISTING_USER=$(getent passwd ${UID} | cut -d: -f1); \
        if [ "${EXISTING_USER}" != "${USERNAME}" ]; then \
            echo "User ${EXISTING_USER} already exists with UID ${UID}"; \
            # Rename the existing user if it's 'ubuntu' and we want 'dev'
            if [ "${EXISTING_USER}" = "ubuntu" ] && [ "${USERNAME}" = "dev" ]; then \
                usermod -l ${USERNAME} ${EXISTING_USER}; \
                groupmod -n ${USERNAME} ${EXISTING_USER} 2>/dev/null || true; \
                usermod -d /home/${USERNAME} -m ${USERNAME} 2>/dev/null || true; \
            fi; \
        fi; \
    fi

# ========================================
# Create workspace and config directories with proper permissions
# ========================================
RUN mkdir -p /${CODEBOX_NAME} /home/${USERNAME}/.config/opencode \
 && chown -R ${UID}:${GID} /${CODEBOX_NAME} /home/${USERNAME}/.config

# ========================================
# Install OpenCode from GitHub releases
# Automatically detects platform (amd64/arm64) and downloads the appropriate binary
# ========================================
ARG TARGETARCH
ARG OPENCODE_VERSION=latest
RUN ARCH="${TARGETARCH}" && \
    if [ -z "${ARCH}" ]; then \
      if command -v dpkg >/dev/null 2>&1; then \
        ARCH=$(dpkg --print-architecture); \
      else \
        ARCH=$(uname -m); \
      fi; \
    fi && \
    case "${ARCH}" in \
      amd64|x86_64) ARCH="x64" ;; \
      arm64|aarch64) ARCH="arm64" ;; \
    esac && \
    if [ -z "${ARCH}" ]; then \
      echo "Unsupported architecture for OpenCode download" >&2; \
      exit 1; \
    fi && \
    # Construct download URL based on version
    if [ "${OPENCODE_VERSION}" = "latest" ]; then \
      DOWNLOAD_URL="https://github.com/anomalyco/opencode/releases/latest/download/opencode-linux-${ARCH}.tar.gz"; \
    else \
      DOWNLOAD_URL="https://github.com/anomalyco/opencode/releases/download/${OPENCODE_VERSION}/opencode-linux-${ARCH}.tar.gz"; \
    fi && \
    echo "Downloading OpenCode from: ${DOWNLOAD_URL}" && \
    # Download and install
    curl -fsSL "${DOWNLOAD_URL}" -o /tmp/opencode.tar.gz && \
    tar -xzf /tmp/opencode.tar.gz -C /usr/local/bin && \
    chmod 0755 /usr/local/bin/opencode && \
    rm /tmp/opencode.tar.gz && \
    # Verify installation
    opencode --version

# ========================================
# Switch to non-root user
# ========================================
USER ${USERNAME}
WORKDIR /${CODEBOX_NAME}

# ========================================
# Configure git for container usage
# ========================================
ENV GIT_CONFIG_GLOBAL=/home/${USERNAME}/.gitconfig

# ========================================
# Copy custom bashrc snippet and append to .bashrc
# ========================================
COPY --chown=${UID}:${GID} dotfiles/docker.bashrc /tmp/docker.bashrc

# ========================================
# Copy custom entrypoint script
# ========================================
COPY --chown=${UID}:${GID} entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# TODO:
# in .env have option for custom gitconfig, gitignore, bash_aliases paths
# then copy from those paths instead of symlinking from dotfiles (below)


# ========================================
# Create symlinks for bash aliases, git config, and gitignore
# ========================================
RUN ln -sf /home/${USERNAME}/config/dotfiles/bash_aliases /home/${USERNAME}/.bash_aliases \
 && ln -sf /home/${USERNAME}/config/dotfiles/gitconfig /home/${USERNAME}/.gitconfig \
 && ln -sf /home/${USERNAME}/config/dotfiles/gitignore /home/${USERNAME}/.gitignore \
 && sed -i '5a\\n# Enable aliases in non-interactive shells for OpenCode\nshopt -s expand_aliases\nif [ -f ~/.bash_aliases ]; then\n    . ~/.bash_aliases\nfi\n' /home/${USERNAME}/.bashrc \
 && sed -i '/^case \$- in/,/^esac$/s/^/#/' /home/${USERNAME}/.bashrc \
 && echo -e "\n# ========================================" >> /home/${USERNAME}/.bashrc \
 && echo "# Custom Docker bashrc content" >> /home/${USERNAME}/.bashrc \
 && echo "# ========================================" >> /home/${USERNAME}/.bashrc \
 && cat /tmp/docker.bashrc >> /home/${USERNAME}/.bashrc \
 && rm /tmp/docker.bashrc

# ========================================
# Set BASH_ENV to source bashrc for non-interactive shells
# ========================================
ENV BASH_ENV=/home/${USERNAME}/.bashrc

# ========================================
# Define volumes for data persistence
# ========================================
# Workspace volume - mount your project here (dynamic path under /${CODEBOX_NAME})
VOLUME ["/${CODEBOX_NAME}"]
# OpenCode config volume - persists settings and cache
VOLUME ["/home/${USERNAME}/.config/opencode"]

# ========================================
# Health check to verify OpenCode is functioning
# ========================================
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
  CMD opencode --version || exit 1

# ========================================
# Set OpenCode as the entrypoint
# ========================================
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
