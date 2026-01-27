# 📦 CodeBox - OpenCode Docker Environment

A bash script that runs OpenCode in a Docker container. It dynamically mounts your current working directory, matches your user permissions, and keeps configuration persistent across sessions.


## Features

- **Run from anywhere** - Launch OpenCode from any project directory with automatic mounting
- **Isolated workspace** - Only your current directory and OpenCode data directories are mounted into the container
- **Easy updates** - Update to the latest OpenCode version with `--update`
- **Persistent data and state** - Auth tokens, history, and session data persist across container restarts
- **Dynamic UID/GID matching** - Automatic detection ensures seamless file permissions without manual configuration
- **Multi-architecture support** - Works on ARM64 (Apple Silicon, ARM servers) and x86_64
- **Non-root container security** - Runs as non-root user with dropped capabilities and privilege restrictions
- **OAuth authentication support** - Built-in port forwarding for OpenAI and GitHub Copilot sign-in
- **Customizable config directory** - Mount your own OpenCode config for dotfiles integration
- **Bash debug mode** - Open an interactive shell for troubleshooting with `--bash`


## Prerequisites

- Docker installed
- Permission to build Docker images

If you run into permission errors, see the [Troubleshooting](#troubleshooting) section.


## Quick Setup

### 1. Clone the Repository

```bash
# HTTPS
git clone https://github.com/sciguy/codebox.git ~/codebox
cd ~/codebox

# SSH
git clone git@github.com:sciguy/codebox.git ~/codebox
cd ~/codebox
```

### 2. Create Environment File

The `.env` file must be located in the `codebox` repository directory. You can copy it manually, or it will be automatically created from `.env.example` on first launch:

```bash
cp .env.example .env
```

### 3. Configure API Keys (Optional)

If you have API keys for providers like Anthropic or OpenAI, you can add them to the `.env` file:

```bash
vim .env  # Add your API keys
```

Alternatively, you can use OAuth authentication for supported providers (see [OAuth & Provider Authentication](#oauth--provider-authentication) section).


### 4. Start Using OpenCode

Navigate to any project directory and run:

```bash
path/to/codebox.sh              # Start OpenCode in current directory
path/to/codebox.sh --version    # Check OpenCode version
path/to/codebox.sh --help       # Show OpenCode help
```

For easier access from anywhere, see the **Shell Integration** section below.

## Shell Integration

Add the following function to your `.bashrc` or `.zshrc` to run CodeBox from any directory:

```bash
# CodeBox - OpenCode Docker Environment
# Update CODEBOX_PATH to match where you cloned the repository
CODEBOX_PATH="$HOME/codebox"
if [ -f "$CODEBOX_PATH/codebox.sh" ]; then
  codebox() {
    "$CODEBOX_PATH/codebox.sh" "$@"
  }
fi
```

After adding this and reloading your shell (`source ~/.bashrc`), you can use `codebox` from anywhere.

Alternative setup with a symlink from your user bin directory:

```bash
mkdir -p "$HOME/bin"
ln -s "$HOME/codebox/codebox.sh" "$HOME/bin/codebox"
chmod +x "$HOME/codebox/codebox.sh"
```

Make sure `$HOME/bin` is in your `PATH` (for example, add `export PATH="$HOME/bin:$PATH"` to your shell config).


## Usage

The following examples assume you have set up the shell integration function. If not, replace `codebox` with `path/to/codebox.sh`.

### Basic Commands

```bash
# Navigate to any project
cd ~/my-project

# Run OpenCode
codebox

# Run with OpenCode arguments
codebox --version
codebox --continue
```

### Advanced Options

```bash
# Update the Docker image to latest OpenCode version
codebox --upgrade

# Show help
codebox -h

# Combined options
codebox --upgrade --version
```

### Complete Options Reference

```
---------------------------------------------------------------
📦 codebox - OpenCode Docker Launcher
---------------------------------------------------------------
Usage: codebox [options] [opencode-arguments]

Options:
  -n, --name NAME    Use NAME as the container root directory (temporary override)
  -u, --update       Rebuild docker and update OpenCode before starting container
  -b, --bash         Open an interactive bash session instead of running OpenCode
  -o, --oauth        Enable OAuth callback port (127.0.0.1:1455) for OpenAI sign-in
  -f, --force        Continue even in protected directories
  -h, --help         Show this help and OpenCode help
---------------------------------------------------------------
```

Any additional arguments not recognized by codebox are passed directly to OpenCode. For example:

```bash
codebox --version            # Passed to OpenCode
codebox --continue           # Passed to OpenCode
codebox --upgrade --version  # --upgrade for codebox, --version for OpenCode
```

### Container Path Structure

When you run `codebox` from any directory, the container creates a path structure:

```
/${CODEBOX_NAME}/hostname/directory-name
```

For example (with default `CODEBOX_NAME=BOX`):

| Host directory | Hostname | Container path |
| --- | --- | --- |
| `~/my-project` | `helix` | `/BOX/helix/my-project` |
| `~/workspace/app` | `helix` | `/BOX/helix/app` |

This makes it clear you're in a containerized environment and shows which machine and project you're working on.

You can temporarily override the container root for a single session with `--name`:

```bash
codebox --name WORKSPACE
```

To make it persistent, set `CODEBOX_NAME` in your `.env` file:

```bash
CODEBOX_NAME=WORKSPACE
```

## How It Works

The `codebox` function:
- Runs from **any directory** (mounts current directory dynamically)
- Auto-detects your **UID/GID** for correct file permissions
- Auto-rebuilds when UID/GID or CODEBOX_NAME changes
- Mounts your OpenCode config, auth, and history
- Checks for `.env` file and guides you if missing

## OpenCode Directories

OpenCode uses several directories for different purposes:

| Directory | Purpose | CodeBox location |
|-----------|---------|-----------------|
| `~/.config/opencode` | **Config**: Settings, agents, etc | Optional host mount |
| `~/.local/share/opencode` | **Data**: Auth tokens, logs, session data | Mounted from host |
| `~/.local/state/opencode` | **State**: History, UI state, Favorites | Mounted from host |
| `~/.cache/opencode` | **Cache**: Temporary files, downloads | Container only |
| `~/.opencode/bin/opencode` | **Binary**: OpenCode executable | Container only |

Directories mounted on the host will be automatically created if needed on first run of codebox.

```bash
# To get a list of directories used by OpenCode
codebox uninstall --dry-run
# 'uninstall --dry-run' is passed through to opencode
```

### Volume Mounts

When you run `codebox`, these directories are mounted into the container:

| Host | Container | Purpose |
|------|-----------|---------|
| Current directory | `/${CODEBOX_NAME}/hostname/dirname` | Your project files (dynamic) |
| [`HOST_OPENCODE_CONFIG_DIR`](#opencode-config-directory) | `/home/dev/.config/opencode` | Settings, preferences |
| `~/.local/share/opencode` | `/home/dev/.local/share/opencode` | Auth tokens, logs |
| `~/.local/state/opencode` | `/home/dev/.local/state/opencode` | History, state |

## Configuration

### API Keys

Edit `.env` (or wherever you cloned the repository) and add API keys for your chosen provider(s):

```bash
ANTHROPIC_API_KEY=your_key
OPENAI_API_KEY=your_key
```


### OAuth & Provider Authentication

Some providers require OAuth authentication instead of API keys:

**OpenAI OAuth:**
1. Start codebox with the `--oauth` flag to enable the OAuth callback server:
   ```bash
   codebox --oauth
   ```
2. Inside OpenCode, run the `/connect` command
3. OpenCode will provide an OpenAI authentication URL
4. Copy this URL and open it in your host machine's web browser
5. Complete the authentication in your browser
6. Return to OpenCode - the connection will be established

If you are connecting from a remote server, set up SSH port forwarding so the OAuth callback can reach your local browser:
```bash
ssh -L 1455:localhost:1455 SERVER
```

**GitHub Copilot:**
- Use the `/connect` command within OpenCode to link your GitHub account
- Follow the on-screen authentication prompts

Once connected, authentication tokens are stored in `~/.local/share/opencode` and persist across container sessions.

### OpenCode Config Directory

The `config.opencode.example/` directory provides a ready-made OpenCode configuration you can copy into your own config directory. This is useful if you want a version-controlled setup with `opencode.json`, `AGENTS.md`, and optional subdirectories like `agents/`, `commands/`, or `themes/`.

To use it with CodeBox, copy the folder to a location you control and set `HOST_OPENCODE_CONFIG_DIR` in `.env` to that absolute path. When set, CodeBox mounts it to `~/.config/opencode` inside the container, so your OpenCode configuration persists across sessions and acts as the global config layer.

Example using the default OpenCode config path:

```bash
cp -R config.opencode.example ~/.config/opencode
```

```bash
# Must be an absolute path
HOST_OPENCODE_CONFIG_DIR=/home/your-username/.config/opencode
```

For details on supported files, directory structure, and precedence, see `config.opencode.example/README.md` and the `OpenCode Config Directory` section in `.env.example`.

### Timezone

If session timestamps appear in UTC, set your local timezone in `.env` so the container formats times correctly:

```bash
TZ=America/Edmonton
```

### Git Configuration

Add to `.env` for proper commit attribution:

```bash
GIT_AUTHOR_NAME="Your Name"
GIT_AUTHOR_EMAIL="your.email@example.com"
GIT_COMMITTER_NAME="Your Name"
GIT_COMMITTER_EMAIL="your.email@example.com"
```

## Updating OpenCode

To update to the latest version:

```bash
codebox --upgrade
```

## Troubleshooting

### Permission denied while building

If you see an error like this when CodeBox tries to build the image, your user likely does not have permission to access the Docker daemon:

```
ERROR: permission denied while trying to connect to the Docker daemon socket at unix:///var/run/docker.sock: Get "http://%2Fvar%2Frun%2Fdocker.sock/_ping": dial unix /var/run/docker.sock: connect: permission denied
```

On most Linux systems, the typical fix is to add your user to the `docker` group, then log out and back in:

```bash
sudo usermod -aG docker $USER
```

After re-login, re-run `codebox` and the build should proceed.


### Check Version

```bash
codebox --version
```

### Debug Container

Run with shell access for debugging:

```bash
codebox --bash
```

## Cross-Platform Support

The setup automatically adapts to each system's UID/GID:
- Auto-detects UID/GID on every run
- Works on Mac (ARM64), Linux servers, and WSL
- No manual configuration needed

## Files

- `Dockerfile` - Container definition with multi-arch support
- `codebox.sh` - Main script for building and running the container
- `.env.example` - Environment template
- `.env` - Your config (git-ignored, create from .env.example)
- `README.md` - This file


## Security

- Runs as non-root user (UID/GID matches your host user)
- `.env` file excluded from git
- No sensitive data in container

## Resources

- [OpenCode Documentation](https://opencode.ai/docs)
- [OpenCode GitHub](https://github.com/anomalyco/opencode)
- [OpenCode Releases](https://github.com/anomalyco/opencode/releases)

## License

CodeBox and OpenCode are licensed under MIT
