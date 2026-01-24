# OpenCode Configuration Example

## Overview

This directory contains example configuration files for OpenCode:

- **`opencode.json`** - Main configuration file with examples of keybinds, models, agents, and permissions
- **`AGENTS.md`** - Programming context profile template that helps agents understand your coding preferences and project structure

## Usage with Docker

This directory can be copied to your dotfiles or another location of your choice, allowing your custom OpenCode settings to be version-controlled and used consistently across multiple servers.

To use this directory with OpenCode running in Docker, set the `HOST_OPENCODE_CONFIG_DIR` environment variable in your `.env` file:

```bash
# If a directory is provided, the configuration will persist across sessions. 
# This can be the standard host location (~/.config/opencode) or any directory 
# you choose, such as a folder managed in your dotfiles or tracked in git.
HOST_OPENCODE_CONFIG_DIR=/path/to/your/config/directory
```

When `HOST_OPENCODE_CONFIG_DIR` is set, that path is mounted to `~/.config/opencode` inside the Docker container, making your configuration available to OpenCode.

## Configuration Precedence

OpenCode loads configuration from multiple sources in this order (later sources override earlier ones):

1. **Remote config** - Organizational defaults from `.well-known/opencode`
2. **Global config** - User preferences from `~/.config/opencode/`
3. **Custom config** - Overrides via `OPENCODE_CONFIG` environment variable
4. **Project config** - Project-specific settings from `opencode.json` in the project root
5. **Inline config** - Runtime overrides via `OPENCODE_CONFIG_CONTENT` environment variable

Since `HOST_OPENCODE_CONFIG_DIR` is mounted to `~/.config/opencode` inside the Docker container, your configuration directory acts as the **global config** layer. This means:

- It overrides any remote organizational defaults
- It can be overridden by project-specific `opencode.json` files
- Settings are merged together (not replaced), with later configs only overriding conflicting keys

## Allowed Configuration Files and Directories

The following files and directories are supported in an OpenCode config directory:

### Files

- **`opencode.json`** or **`opencode.jsonc`** - Main configuration file for themes, models, keybinds, tools, permissions, and more
  - [Configuration documentation](https://opencode.ai/docs/config/)

- **`AGENTS.md`** - Programming context profile that provides agents with information about your coding style, preferences, and project context
  - [Rules documentation](https://opencode.ai/docs/rules/)

### Directories

- **`agents/`** - Custom agent definitions (markdown files)
  - [Agents documentation](https://opencode.ai/docs/agents/)

- **`commands/`** - Custom command definitions for repetitive tasks (markdown files)
  - [Commands documentation](https://opencode.ai/docs/commands/)

- **`formatters/`** - Code formatter configurations
  - [Formatters documentation](https://opencode.ai/docs/formatters/)

- **`plugins/`** - Custom plugins that extend OpenCode functionality (JavaScript/TypeScript files)
  - [Plugins documentation](https://opencode.ai/docs/plugins/)

- **`skills/`** - Agent skill definitions for specialized tasks
  - [Skills documentation](https://opencode.ai/docs/skills/)

- **`themes/`** - Custom theme definitions
  - [Themes documentation](https://opencode.ai/docs/themes/)

- **`tools/`** - Custom tool definitions
  - [Custom Tools documentation](https://opencode.ai/docs/custom-tools/)

Note: Directory names should use the **plural form** (e.g., `agents/`, `commands/`). Singular names (e.g., `agent/`, `command/`) are also supported for backwards compatibility.

## Learn More

- [OpenCode Documentation](https://opencode.ai/docs/)
- [Configuration Schema](https://opencode.ai/config.json)
