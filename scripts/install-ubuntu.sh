#!/usr/bin/env bash
#
# System-wide installer for powerline-go on Ubuntu.
#
# - Downloads the release binary matching the machine architecture, verifies
#   its SHA-256 checksum and installs it to /usr/local/bin/powerline-go.
# - Installs prompt hooks for bash, zsh and fish (for the shells present on the
#   system), so every user gets the powerline-go prompt in interactive shells.
#
# Usage (as root):
#   ./install-ubuntu.sh                 install the latest release
#   ./install-ubuntu.sh -v v1.26        install a specific release
#   ./install-ubuntu.sh --no-shells     only install the binary
#   ./install-ubuntu.sh --no-fonts      do not install the fonts-powerline package
#   ./install-ubuntu.sh --uninstall     remove the binary and all shell hooks
#
# A user can opt out of the system prompt by exporting POWERLINE_GO_DISABLE=1
# before the hook runs (e.g. in ~/.profile, or ~/.zshenv for zsh), or override
# the arguments passed to powerline-go with POWERLINE_GO_ARGS.

set -euo pipefail

REPO="julienlevasseur/powerline-go"
BIN_PATH="/usr/local/bin/powerline-go"
CONF_DIR="/etc/powerline-go"
BASH_RC="/etc/bash.bashrc"
ZSH_RC="/etc/zsh/zshrc"
FISH_CONF_D="/etc/fish/conf.d"
MARK_BEGIN="# >>> powerline-go >>>"
MARK_END="# <<< powerline-go <<<"

VERSION="latest"
INSTALL_SHELLS=1
INSTALL_FONTS=1
UNINSTALL=0

log() { printf '==> %s\n' "$*"; }
die() { printf 'error: %s\n' "$*" >&2; exit 1; }

usage() {
    sed -n '/^# Usage/,/^$/p' "$0" | sed 's/^# \{0,1\}//'
    exit "${1:-0}"
}

while [ $# -gt 0 ]; do
    case "$1" in
        -v|--version) [ $# -ge 2 ] || die "$1 needs a value"; VERSION="$2"; shift 2 ;;
        --no-shells)  INSTALL_SHELLS=0; shift ;;
        --no-fonts)   INSTALL_FONTS=0; shift ;;
        --uninstall)  UNINSTALL=1; shift ;;
        -h|--help)    usage 0 ;;
        *)            printf 'unknown option: %s\n' "$1" >&2; usage 1 ;;
    esac
done

[ "$(id -u)" -eq 0 ] || die "this script must be run as root"

# Remove a previously installed marked block from a file.
remove_block() {
    local file="$1"
    [ -f "$file" ] || return 0
    sed -i "/^${MARK_BEGIN}\$/,/^${MARK_END}\$/d" "$file"
}

# Append a marked block sourcing $2 to $1, replacing any previous one.
add_source_block() {
    local file="$1" snippet="$2"
    remove_block "$file"
    cat >>"$file" <<EOF
${MARK_BEGIN}
[ -r ${snippet} ] && . ${snippet}
${MARK_END}
EOF
}

if [ "$UNINSTALL" -eq 1 ]; then
    log "Removing powerline-go"
    rm -f "$BIN_PATH" "$FISH_CONF_D/powerline-go.fish"
    rm -rf "$CONF_DIR"
    remove_block "$BASH_RC"
    remove_block "$ZSH_RC"
    log "Done. Open a new shell to get your previous prompt back."
    exit 0
fi

# --- Dependencies ----------------------------------------------------------

packages=(curl ca-certificates)
[ "$INSTALL_FONTS" -eq 1 ] && packages+=(fonts-powerline)
log "Installing dependencies: ${packages[*]}"
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq --no-install-recommends "${packages[@]}" >/dev/null

# --- Binary ----------------------------------------------------------------

case "$(dpkg --print-architecture)" in
    amd64) arch="amd64" ;;
    arm64) arch="arm64" ;;
    armhf) arch="arm" ;;
    i386)  arch="386" ;;
    *)     die "unsupported architecture: $(dpkg --print-architecture)" ;;
esac
asset="powerline-go-linux-${arch}"

if [ "$VERSION" = "latest" ]; then
    base_url="https://github.com/${REPO}/releases/latest/download"
else
    base_url="https://github.com/${REPO}/releases/download/${VERSION}"
fi

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

log "Downloading ${asset} (${VERSION})"
curl -fsSL --retry 3 -o "$tmp/$asset" "$base_url/$asset" \
    || die "could not download $base_url/$asset"
curl -fsSL --retry 3 -o "$tmp/checksums.txt" "$base_url/checksums.txt" \
    || die "could not download $base_url/checksums.txt"

log "Verifying checksum"
(cd "$tmp" && grep " ${asset}\$" checksums.txt | sha256sum -c --quiet -) \
    || die "checksum verification failed for $asset"

install -m 0755 "$tmp/$asset" "$BIN_PATH"
log "Installed $BIN_PATH"

# --- Shell hooks -----------------------------------------------------------

if [ "$INSTALL_SHELLS" -eq 0 ]; then
    log "Skipping shell configuration (--no-shells)"
    exit 0
fi

install -d -m 0755 "$CONF_DIR"

cat >"$CONF_DIR/powerline-go.bash" <<'EOF'
# powerline-go prompt for bash, installed system-wide by install-ubuntu.sh.
if [ -n "${PS1-}" ] && [ "${TERM-}" != "linux" ] && [ -z "${POWERLINE_GO_DISABLE-}" ] \
    && [ -x /usr/local/bin/powerline-go ]; then
    _powerline_go_ps1() {
        local status=$?
        # shellcheck disable=SC2086 # POWERLINE_GO_ARGS is intentionally word-split
        PS1="$(/usr/local/bin/powerline-go -shell bash -error "$status" \
            -jobs "$(jobs -p | wc -l)" ${POWERLINE_GO_ARGS-})"
    }
    case ";${PROMPT_COMMAND-};" in
        *";_powerline_go_ps1;"*) ;;
        *) PROMPT_COMMAND="_powerline_go_ps1${PROMPT_COMMAND:+;$PROMPT_COMMAND}" ;;
    esac
fi
EOF

cat >"$CONF_DIR/powerline-go.zsh" <<'EOF'
# powerline-go prompt for zsh, installed system-wide by install-ubuntu.sh.
if [[ -o interactive ]] && [[ "${TERM-}" != "linux" ]] && [[ -z "${POWERLINE_GO_DISABLE-}" ]] \
    && [[ -x /usr/local/bin/powerline-go ]]; then
    function _powerline_go_precmd() {
        PS1="$(/usr/local/bin/powerline-go -shell zsh -error $? \
            -jobs ${${(%):%j}:-0} ${=POWERLINE_GO_ARGS-})"
    }
    if (( ! ${precmd_functions[(I)_powerline_go_precmd]} )); then
        precmd_functions+=(_powerline_go_precmd)
    fi
fi
EOF

chmod 0644 "$CONF_DIR"/powerline-go.*

add_source_block "$BASH_RC" "$CONF_DIR/powerline-go.bash"
log "Configured bash ($BASH_RC)"

if [ -d /etc/zsh ]; then
    add_source_block "$ZSH_RC" "$CONF_DIR/powerline-go.zsh"
    log "Configured zsh ($ZSH_RC)"
else
    log "zsh not installed; hook kept in $CONF_DIR/powerline-go.zsh for later"
fi

if [ -d /etc/fish ]; then
    install -d -m 0755 "$FISH_CONF_D"
    cat >"$FISH_CONF_D/powerline-go.fish" <<'EOF'
# powerline-go prompt for fish, installed system-wide by install-ubuntu.sh.
if status is-interactive; and test "$TERM" != linux; and not set -q POWERLINE_GO_DISABLE; and test -x /usr/local/bin/powerline-go
    function fish_prompt
        set -l last_status $status
        eval /usr/local/bin/powerline-go -shell bare -error $last_status -jobs (count (jobs -p)) $POWERLINE_GO_ARGS
    end
end
EOF
    chmod 0644 "$FISH_CONF_D/powerline-go.fish"
    log "Configured fish ($FISH_CONF_D/powerline-go.fish)"
fi

log "Done. Open a new terminal to use the powerline-go prompt."
log "Your terminal font needs Powerline glyphs (e.g. 'Powerline' patched or Nerd Fonts)."
