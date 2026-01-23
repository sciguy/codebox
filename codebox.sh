#!/usr/bin/env bash
set -Eeuo pipefail

# OpenCode Docker script - run from any directory
# Usage: codebox [options] [opencode-arguments]
# Options:
#   -n, --name NAME    Use NAME as the container root directory (temporary override)
#   -u, --update       Rebuild docker and update OpenCode before starting container
#   -b, --bash         Open an interactive bash session instead of running OpenCode
#   -o, --oauth        Enable OAuth callback port (127.0.0.1:1455) for OpenAI sign-in
#   -f, --force        Continue even in protected directories
#   -h, --help         Show this help and OpenCode help
main() {
    # Parse command line arguments first
    local CLI_CODEBOX_NAME=""
    local OPENCODE_ARGS=()
    local UPDATE_REQUESTED=false
    local HELP_REQUESTED=false
    local BASH_MODE=false
    local FORCE_MODE=false
    local OAUTH_ENABLED=false

    while [[ $# -gt 0 ]]; do
        case $1 in
            -n|--name)
                CLI_CODEBOX_NAME="$2"
                shift 2
                ;;
            -u|--update)
                UPDATE_REQUESTED=true
                shift
                ;;
            -b|--bash)
                BASH_MODE=true
                shift
                ;;
            -o|--oauth)
                OAUTH_ENABLED=true
                shift
                ;;
            -f|--force)
                FORCE_MODE=true
                shift
                ;;
            -h|--help)
                HELP_REQUESTED=true
                OPENCODE_ARGS+=("$1")
                shift
                ;;
            *)
                OPENCODE_ARGS+=("$1")
                shift
                ;;
        esac
    done

    # Path to your OpenCode Docker installation (script directory)
    local SCRIPT_SOURCE="${BASH_SOURCE[0]}"
    local SCRIPT_PATH=""
    if command -v realpath >/dev/null 2>&1; then
        SCRIPT_PATH=$(realpath "$SCRIPT_SOURCE")
    else
        SCRIPT_PATH=$(readlink -f "$SCRIPT_SOURCE")
    fi
    local OPENCODE_DOCKER_DIR="$(dirname "$SCRIPT_PATH")"

    if [ -z "$OPENCODE_DOCKER_DIR" ]; then
        echo "Warning: failed to resolve OpenCode Docker directory" >&2
        exit 1
    fi

    if [ "$HELP_REQUESTED" = true ]; then
        echo "---------------------------------------------------------------"
        echo "📦 codebox - OpenCode Docker Launcher"
        echo "---------------------------------------------------------------"
        echo "Usage: codebox [options] [opencode-arguments]"
        echo "Options:"
        echo "  -n, --name NAME    Use NAME as the container root directory (temporary override)"
        echo "  -u, --update       Rebuild docker and update OpenCode before starting container"
        echo "  -b, --bash         Open an interactive bash session instead of running OpenCode"
        echo "  -o, --oauth        Enable OAuth callback port (127.0.0.1:1455) for OpenAI sign-in"
        echo "  -f, --force        Continue even in protected directories"
        echo "  -h, --help         Show this help and OpenCode help"
        echo "---------------------------------------------------------------"
    fi

    # IMPORTANT: Capture current directory BEFORE any operations
    local WORKSPACE_DIR="$PWD"
    local PROTECTED_DIRS=("$HOME")

    # Load additional protected directories from .env if present
    if [ -f "$OPENCODE_DOCKER_DIR/.env" ]; then
        local PROTECTED_DIRS_ENV=$(grep "^PROTECTED_DIRS=" "$OPENCODE_DOCKER_DIR/.env" 2>/dev/null | cut -d= -f2)
        if [ -n "$PROTECTED_DIRS_ENV" ]; then
            # Split colon-separated paths and add to PROTECTED_DIRS array
            IFS=':' read -ra ADDITIONAL_DIRS <<< "$PROTECTED_DIRS_ENV"
            for dir in "${ADDITIONAL_DIRS[@]}"; do
                if [ -n "$dir" ]; then
                    PROTECTED_DIRS+=("$dir")
                fi
            done
        fi
    fi

    # Check if running in a protected directory
    NEEDS_FORCE=false
    FORCE_REASON=""

    # Check exact matches with PROTECTED_DIRS (e.g., $HOME itself)
    for PROTECTED_DIR in "${PROTECTED_DIRS[@]}"; do
        if [ "$WORKSPACE_DIR" = "$PROTECTED_DIR" ]; then
            NEEDS_FORCE=true
            FORCE_REASON="Running in protected directory: $PROTECTED_DIR"
            break
        fi
    done

    # Check if WORKSPACE_DIR is outside $HOME (parent or sibling)
    if [ "$NEEDS_FORCE" = false ]; then
        case "$WORKSPACE_DIR" in
            "$HOME"/*)
                # Inside HOME - safe, no force needed
                ;;
            *)
                # Outside HOME - requires force
                NEEDS_FORCE=true
                FORCE_REASON="Running outside your home directory"
                ;;
        esac
    fi

    # Enforce or warn
    if [ "$NEEDS_FORCE" = true ]; then
        if [ "$FORCE_MODE" = true ]; then
            echo "---------------------------------------------------------------"
            echo "⚠️  Running in 'force' mode, use caution."
            echo "    Reason: $FORCE_REASON"
            echo "---------------------------------------------------------------"
            echo ""
        else
            echo "---------------------------------------------------------------"
            echo "⚠️  $FORCE_REASON"
            echo "    This can be dangerous. To continue anyway, rerun with:"
            echo "    codebox --force"
            echo "---------------------------------------------------------------"
            echo ""
            exit 1
        fi
    fi

    # Capture hostname and working directory name for dynamic container path
    local WORKSPACE_NAME="$(basename "$WORKSPACE_DIR")"
    local CONTAINER_HOSTNAME="$(hostname)"

    # Auto-detect current user's UID/GID
    export USER_UID=$(id -u)
    export USER_GID=$(id -g)

    # Username in container (from .env or default)
    local USERNAME="${USERNAME:-dev}"

    # Check if OpenCode Docker directory exists
    if [ ! -d "$OPENCODE_DOCKER_DIR" ]; then
        echo "Error: OpenCode Docker directory not found at $OPENCODE_DOCKER_DIR"
        exit 1
    fi

    # Derive RELATIVE_PATH from OPENCODE_DOCKER_DIR relative to $HOME
    local RELATIVE_PATH=""
    if [[ "$OPENCODE_DOCKER_DIR" == "$HOME/"* ]]; then
        RELATIVE_PATH="${OPENCODE_DOCKER_DIR#"$HOME"/}"
        if [ -z "$RELATIVE_PATH" ]; then
            echo "Error: OPENCODE_DOCKER_DIR must be inside \$HOME and include at least one subdirectory" >&2
            exit 1
        fi
    else
        echo "Error: OPENCODE_DOCKER_DIR must be under \$HOME to derive RELATIVE_PATH" >&2
        exit 1
    fi

    # Check if .env exists
    if [ ! -f "$OPENCODE_DOCKER_DIR/.env" ]; then
        echo "⚠️  Warning: .env file not found at $OPENCODE_DOCKER_DIR/.env"
        echo "Creating .env from $OPENCODE_DOCKER_DIR/.env.example..."
        cp "$OPENCODE_DOCKER_DIR/.env.example" "$OPENCODE_DOCKER_DIR/.env"
        echo ""
        echo "📝 Please edit .env and add your API keys (if needed) before continuing"
        echo "   vim $OPENCODE_DOCKER_DIR/.env"
        echo ""
        exit 1
    fi

    # Load CODEBOX_NAME from .env if not already set in environment
    # Priority: 1. CLI argument (-n), 2. Shell environment, 3. .env file, 4. default (BOX)
    local CODEBOX_NAME=""
    if [ -n "$CLI_CODEBOX_NAME" ]; then
        CODEBOX_NAME="$CLI_CODEBOX_NAME"
    elif [ -n "${CODEBOX_NAME_ENV:-}" ]; then
        # Allow persistent setting via CODEBOX_NAME_ENV to avoid pollution
        CODEBOX_NAME="${CODEBOX_NAME_ENV}"
    else
        CODEBOX_NAME=$(grep "^CODEBOX_NAME=" "$OPENCODE_DOCKER_DIR/.env" 2>/dev/null | cut -d= -f2)
    fi
    CODEBOX_NAME="${CODEBOX_NAME:-BOX}"
    local CONTAINER_WORKDIR="/${CODEBOX_NAME}/${CONTAINER_HOSTNAME}/${WORKSPACE_NAME}"

    if [ "$UPDATE_REQUESTED" = true ]; then
        echo "---------------------------------------------------------------"
        echo "🔄 Updating OpenCode Docker container..."
        echo "---------------------------------------------------------------"
        # Extract build args from .env
        local DOCKER_PACKAGES=$(grep "^DOCKER_PACKAGES=" "$OPENCODE_DOCKER_DIR/.env" 2>/dev/null | cut -d= -f2)
        local OPENCODE_VERSION=$(grep "^OPENCODE_VERSION=" "$OPENCODE_DOCKER_DIR/.env" 2>/dev/null | cut -d= -f2)
        OPENCODE_VERSION="${OPENCODE_VERSION:-latest}"
        docker build \
            --pull \
            --no-cache \
            --build-arg UID="$USER_UID" \
            --build-arg GID="$USER_GID" \
            --build-arg OPENCODE_VERSION="$OPENCODE_VERSION" \
            --build-arg USERNAME="${USERNAME:-dev}" \
            --build-arg CODEBOX_NAME="$CODEBOX_NAME" \
            --build-arg DOCKER_PACKAGES="$DOCKER_PACKAGES" \
            -t opencode-dev:latest \
            "$OPENCODE_DOCKER_DIR" || exit 1
        echo ""
        echo "✅ Update complete!"
        echo ""
    fi

    # Check if image exists or if it was built with different UID/GID/CODEBOX_NAME
    IMAGE_UID=$(docker inspect opencode-dev:latest 2>/dev/null | grep -o '"UID=[^"]*"' | head -1 | cut -d= -f2 | tr -d '"' || echo "")
    IMAGE_CODEBOX=$(docker inspect opencode-dev:latest 2>/dev/null | grep -o '"CODEBOX_NAME=[^"]*"' | head -1 | cut -d= -f2 | tr -d '"' || echo "")

    NEEDS_REBUILD=false
    REBUILD_REASON=""

    if [ -z "$IMAGE_UID" ] || [ "$IMAGE_UID" != "$USER_UID" ]; then
        NEEDS_REBUILD=true
        REBUILD_REASON="UID/GID mismatch (image: ${IMAGE_UID:-none}, current: $USER_UID)"
    fi

    if [ -n "$IMAGE_CODEBOX" ] && [ "$IMAGE_CODEBOX" != "$CODEBOX_NAME" ]; then
        NEEDS_REBUILD=true
        if [ -n "$REBUILD_REASON" ]; then
            REBUILD_REASON="$REBUILD_REASON; CODEBOX_NAME changed (image: $IMAGE_CODEBOX, current: $CODEBOX_NAME)"
        else
            REBUILD_REASON="CODEBOX_NAME changed (image: $IMAGE_CODEBOX, current: $CODEBOX_NAME)"
        fi
    fi

    if [ "$NEEDS_REBUILD" = true ]; then
        echo "---------------------------------------------------------------"
        echo "🏗️  Building OpenCode Docker Image"
        echo "    Reason: $REBUILD_REASON"
        echo "    UID=$USER_UID, GID=$USER_GID, CODEBOX_NAME=$CODEBOX_NAME"
        echo "---------------------------------------------------------------"
        # Extract build args from .env
        local DOCKER_PACKAGES=$(grep "^DOCKER_PACKAGES=" "$OPENCODE_DOCKER_DIR/.env" 2>/dev/null | cut -d= -f2)
        local OPENCODE_VERSION=$(grep "^OPENCODE_VERSION=" "$OPENCODE_DOCKER_DIR/.env" 2>/dev/null | cut -d= -f2)
        OPENCODE_VERSION="${OPENCODE_VERSION:-latest}"
        docker build \
            --build-arg UID="$USER_UID" \
            --build-arg GID="$USER_GID" \
            --build-arg OPENCODE_VERSION="$OPENCODE_VERSION" \
            --build-arg USERNAME="${USERNAME:-dev}" \
            --build-arg CODEBOX_NAME="$CODEBOX_NAME" \
            --build-arg DOCKER_PACKAGES="$DOCKER_PACKAGES" \
            -t opencode-dev:latest \
            "$OPENCODE_DOCKER_DIR"
    fi

    # Check if HOST_OPENCODE_CONFIG_DIR is set in .env
    local HOST_OPENCODE_CONFIG_DIR=$(grep "^HOST_OPENCODE_CONFIG_DIR=" "$OPENCODE_DOCKER_DIR/.env" 2>/dev/null | cut -d= -f2)

    # Run OpenCode with current directory as workspace
    echo "---------------------------------------------------------------"
    if [ "$BASH_MODE" = true ]; then
        echo "📦 Starting bash session in: $WORKSPACE_DIR"
    else
        echo "📦 Starting OpenCode in: $WORKSPACE_DIR"
    fi
    echo "   Container path: $CONTAINER_WORKDIR"
    echo "   (UID=$USER_UID, GID=$USER_GID, CODEBOX_NAME=$CODEBOX_NAME)"
    echo "   Environment: $OPENCODE_DOCKER_DIR/.env"

    # Read SHOW_MOUNTS setting (default to true if not set)
    local SHOW_MOUNTS=$(grep "^SHOW_MOUNTS=" "$OPENCODE_DOCKER_DIR/.env" 2>/dev/null | cut -d= -f2)
    SHOW_MOUNTS="${SHOW_MOUNTS:-true}"

    # Display volume mounts if enabled
    if [ "$SHOW_MOUNTS" = "true" ]; then
        echo "   Volume mounts:"
        echo "     - $WORKSPACE_DIR → $CONTAINER_WORKDIR"
        if [ -n "$HOST_OPENCODE_CONFIG_DIR" ]; then
            echo "     - ${HOST_OPENCODE_CONFIG_DIR} → /home/${USERNAME}/.config/opencode"
        fi
        echo "     - ${HOME}/.local/share/opencode → /home/${USERNAME}/.local/share/opencode"
        echo "     - ${HOME}/.local/state/opencode → /home/${USERNAME}/.local/state/opencode"
        if [ "$OAUTH_ENABLED" = true ]; then
            echo "   OAuth callback: http://127.0.0.1:1455"
        fi
    fi

    echo "---------------------------------------------------------------"
    echo ""
    local CONFIG_MOUNT_ARGS=()
    if [ -n "$HOST_OPENCODE_CONFIG_DIR" ]; then
        CONFIG_MOUNT_ARGS=(-v "${HOST_OPENCODE_CONFIG_DIR}:/home/${USERNAME}/.config/opencode")
    fi

    # Build docker run command with common arguments
    local DOCKER_ARGS=(
        --rm -it
        --cap-drop ALL
        --security-opt no-new-privileges
        --env-file "$OPENCODE_DOCKER_DIR/.env"
        -e CODEBOX_NAME="${CODEBOX_NAME}"
        -e BASH_ENV="/home/${USERNAME}/.bashrc"
        -w "$CONTAINER_WORKDIR"
        -v "$WORKSPACE_DIR:$CONTAINER_WORKDIR"
        "${CONFIG_MOUNT_ARGS[@]}"
        -v "${HOME}/.local/share/opencode:/home/${USERNAME}/.local/share/opencode"
        -v "${HOME}/.local/state/opencode:/home/${USERNAME}/.local/state/opencode"
    )

    # Add OAuth port binding if requested
    if [ "$OAUTH_ENABLED" = true ]; then
        DOCKER_ARGS+=(-p 127.0.0.1:1455:1455)
    fi

    # Add bash-specific args if in bash mode
    if [ "$BASH_MODE" = true ]; then
        DOCKER_ARGS+=(--entrypoint /bin/bash)
    fi

    # Run the container
    docker run "${DOCKER_ARGS[@]}" opencode-dev:latest "${OPENCODE_ARGS[@]}"

}

main "$@"
