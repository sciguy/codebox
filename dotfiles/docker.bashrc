#------------------------------------------------------------------------------
# Custom Prompt with Dynamic Hostname (for CodeBox in bash mode)
# Example: [dev@BOX.helix: working_dir]$
#------------------------------------------------------------------------------

# Set custom host based on workspace at shell initialization
# Extracts workspace name from /${CODEBOX_NAME}/workspace_name/... path structure
WORKSPACE_NAME=$(pwd | sed -n "s|^/${CODEBOX_NAME:-BOX}/\([^/]*\).*|\1|p")
CUSTOM_HOST="${CODEBOX_NAME:-BOX}.${WORKSPACE_NAME:-root}"

# Set default editor
export EDITOR=vim

# Prompt settings (check out https://wiki.archlinux.org/index.php/Color_Bash_Prompt)
if (( EUID == 0 )); then
  PS1="[\[\e[31m\]\u\[\e[37m\]@\[\e[38;5;208m\]${CUSTOM_HOST}\[\e[00m\]: \[\033[01;34m\]\W\[\033[00m\]]\[\e[31m\]\$\[\e[37m\] "
else
  PS1="[\u@\[\e[38;5;208m\]${CUSTOM_HOST}\[\e[00m\]: \[\033[01;34m\]\W\[\033[00m\]]\$ "
fi
