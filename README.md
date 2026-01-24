# 📦 CodeBox - OpenCode Docker Environment

A containerized OpenCode environment. This setup allows you to run OpenCode in a Docker container with automatic updates, multi-architecture support, and dynamic mounting of your current working directory into the container.

Docker is required to use CodeBox.


## Features

- **Isolated workspace** - Only your current directory and specific OpenCode directories are mounted into the container, limiting access to other host files for safer operation
- **Run from anywhere** - Launch OpenCode from any project directory with automatic mounting
- Easily update to the latest version of OpenCode using the `--upgrade` option
- Persistent configuration across containers
- Multi-architecture support (ARM64/x86_64)
- Dynamic UID/GID matching for seamless file permissions
- Non-root user security
- Separate OpenCode configuration directory that can be integrated with your dotfiles

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

At least one authentication method is required (API key or OAuth) for providers like OpenCode Zen, Anthropic, OpenAI, GitHub Copilot, etc.

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
# Use a custom container root path (temporary override)
codebox --name WORKSPACE

# Update the Docker image to latest OpenCode version
codebox --upgrade

# Show help
codebox -h

# Combined options
codebox --upgrade --name PROJECT --version
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
codebox --version          # Passed to OpenCode
codebox --continue         # Passed to OpenCode
codebox --upgrade --version  # --upgrade for codebox, --version for OpenCode
```

### Container Path Structure

When you run `codebox` from any directory, the container creates a path structure:

```
/${CODEBOX_NAME}/hostname/directory-name
```

For example (with default `CODEBOX_NAME=BOX`):
- From `~/my-project` on machine `helix`: `/BOX/helix/my-project`
- From `~/workspace/app` on machine `helix`: `/BOX/helix/app`

This makes it clear you're in a containerized environment and shows which machine and project you're working on.

## How It Works

The `codebox` function:
- Runs from **any directory** (mounts current directory dynamically)
- Auto-detects your **UID/GID** for correct file permissions
- Auto-rebuilds when UID/GID or CODEBOX_NAME changes
- Mounts your OpenCode config, auth, and history
- Checks for `.env` file and guides you if missing

## OpenCode Directories

OpenCode uses several directories on your host system for different purposes:

| Directory | Purpose | Size (typical) |
|-----------|---------|----------------|
| `~/.local/share/opencode` | **Data**: Auth tokens, logs, session data | ~195 MB |
| `~/.cache/opencode` | **Cache**: Temporary files, downloads | ~15 MB |
| `~/.config/opencode` | **Config**: Settings, agents, etc | ~4 MB |
| `~/.local/state/opencode` | **State**: History, UI state, Favorites | ~14 KB |
| `~/.opencode/bin/opencode` | **Binary**: OpenCode executable | - |

These directories are automatically created when OpenCode is first installed. To see what would be removed during uninstallation:

```bash
opencode uninstall --dry-run
```

### Volume Mounts

When you run `codebox`, these directories are mounted into the container:

| Host | Container | Purpose |
|------|-----------|---------|
| Current directory | `/${CODEBOX_NAME}/hostname/dirname` | Your project files (dynamic) |
| `~/.config/opencode` | `/home/dev/.config/opencode` | Settings, preferences |
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

**GitHub Copilot:**
- Use the `/connect` command within OpenCode to link your GitHub account
- Follow the on-screen authentication prompts

Once connected, authentication tokens are stored in `~/.local/share/opencode` and persist across container sessions.

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

### Customize Container Root Path

The default container root is `/BOX`. You can customize this by setting `CODEBOX_NAME` in `.env`:

```bash
# Use a different root directory name
CODEBOX_NAME=WORKSPACE
```

This will create paths like `/WORKSPACE/hostname/dirname` inside the container.

## Updating OpenCode

To update to the latest version:

```bash
codebox --upgrade
```

## Troubleshooting


### Check Version

```bash
codebox --version
```

### Debug Container

Run with shell access for debugging:

```bash
./codebox.sh --bash
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
