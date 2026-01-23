#!/bin/bash
set -e

# Check if the first argument is bash (for bash mode)
if [ "$1" = "bash" ] || [ "$1" = "/bin/bash" ]; then
    exec "$@"
fi

# Show loading message for OpenCode mode
echo "---------------------------------------------------------------"
echo "⏳ Initializing OpenCode, please wait..."
echo "---------------------------------------------------------------"
echo ""

# Execute opencode with all arguments
exec opencode "$@"
