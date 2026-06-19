#!/usr/bin/env bash
#==============================================================================
#   FP-Remover — Setup & Dependency Installer
#   Author : archnexus707
#   Tool   : clearshadow.sh + clear_shadow (Go binary)
#==============================================================================
set -e

RED='\033[38;5;196m'; GREEN='\033[38;5;46m'; PURPLE='\033[38;5;129m'
CYAN='\033[38;5;51m'; YELLOW='\033[38;5;226m'; DIM='\033[2m'; R='\033[0m'

banner() {
    echo ""
    echo -e "${RED}\033[1m"
    cat << 'EOF'
    ██████╗██╗     ███████╗ █████╗ ██████╗ 
   ██╔════╝██║     ██╔════╝██╔══██╗██╔══██╗
   ██║     ██║     █████╗  ███████║██████╔╝
   ██║     ██║     ██╔══╝  ██╔══██║██╔══██╗
   ╚██████╗███████╗███████╗██║  ██║██║  ██║
    ╚═════╝╚══════╝╚══════╝╚═╝  ╚═╝╚═╝  ╚═╝
EOF
    echo -e "${PURPLE}\033[1m"
    cat << 'EOF'
   ███████╗██╗  ██╗ █████╗ ██████╗  ██████╗ ██╗    ██╗
   ██╔════╝██║  ██║██╔══██╗██╔══██╗██╔═══██╗██║    ██║
   ███████╗███████║███████║██║  ██║██║   ██║██║ █╗ ██║
   ╚════██║██╔══██║██╔══██║██║  ██║██║   ██║██║███╗██║
   ███████║██║  ██║██║  ██║██████╔╝╚██████╔╝╚███╔███╔╝
   ╚══════╝╚═╝  ╚═╝╚═╝  ╚═╝╚═════╝  ╚═════╝  ╚══╝╚══╝ 
EOF
    echo -e "${R}"
    echo -e "  ${DIM}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${R}"
    echo -e "  🧹 \033[1;37mFP-REMOVER SETUP v2.2\033[0m ${DIM}// archnexus707${R} 💀"
    echo -e "  ${DIM}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${R}"
    echo ""
}

step()  { echo -e "\n  ${PURPLE}[*]${R} ${1}"; }
ok()    { echo -e "  ${GREEN}[OK]${R} ${1}"; }
warn()  { echo -e "  ${YELLOW}[!!]${R} ${1}"; }
fail()  { echo -e "  ${RED}[XX]${R} ${1}"; }

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# ── 1. Bash script system packages ────────────────────────────────
install_bash_deps() {
    step "Installing system packages for clearshadow.sh..."
    sudo apt-get update -qq 2>/dev/null

    local pkgs="coreutils util-linux sqlite3"
    for pkg in $pkgs; do
        if dpkg -l "$pkg" 2>/dev/null | grep -q '^ii'; then
            ok "$pkg (already installed)"
        else
            sudo apt-get install -y "$pkg" 2>/dev/null && ok "$pkg installed" || warn "Failed: $pkg"
        fi
    done
}

# ── 2. Optional forensic tools ────────────────────────────────────
install_optional() {
    step "Installing optional forensic tools..."
    for pkg in wipe secure-delete; do
        if command -v "$pkg" >/dev/null 2>&1; then
            ok "$pkg (already installed)"
        else
            sudo apt-get install -y "$pkg" 2>/dev/null && ok "$pkg installed" || warn "$pkg skipped (optional)"
        fi
    done
}

# ── 3. Go toolchain (for building clear_shadow from source) ───────
install_go() {
    step "Checking Go toolchain..."

    local GO_MIN="1.21"
    local GO_INSTALLED=""

    if command -v go >/dev/null 2>&1; then
        GO_INSTALLED=$(go version 2>/dev/null | grep -oP 'go\K[0-9]+\.[0-9]+' | head -1)
        if [ -n "$GO_INSTALLED" ] && [ "$(printf '%s\n' "$GO_MIN" "$GO_INSTALLED" | sort -V | head -1)" = "$GO_MIN" ]; then
            ok "Go $GO_INSTALLED (>= $GO_MIN required)"
            return 0
        fi
        warn "Go $GO_INSTALLED is too old (need >= $GO_MIN)"
    fi

    echo -e "  ${DIM}Installing Go 1.21+ via apt...${R}"
    if sudo apt-get install -y golang-go 2>/dev/null; then
        ok "Go installed via apt ($(go version 2>/dev/null | awk '{print $3}'))"
        return 0
    fi

    # Fallback: manual download for amd64
    local GO_VER="1.22.0"
    local GO_TAR="go${GO_VER}.linux-amd64.tar.gz"
    local GO_URL="https://go.dev/dl/${GO_TAR}"

    echo -e "  ${DIM}Downloading Go ${GO_VER}...${R}"
    if curl -fsSL "$GO_URL" -o "/tmp/${GO_TAR}" 2>/dev/null; then
        sudo rm -rf /usr/local/go 2>/dev/null || true
        sudo tar -C /usr/local -xzf "/tmp/${GO_TAR}"
        rm -f "/tmp/${GO_TAR}"
        export PATH="/usr/local/go/bin:$PATH"
        echo 'export PATH="/usr/local/go/bin:$PATH"' >> ~/.bashrc 2>/dev/null || true
        ok "Go ${GO_VER} installed to /usr/local/go"
        echo -e "  ${DIM}  Run: export PATH=\"/usr/local/go/bin:\$PATH\" or restart shell${R}"
    else
        warn "Could not install Go — clear_shadow binary build unavailable"
        warn "Use the bash script instead: ./clearshadow.sh"
        return 1
    fi

    return 0
}

# ── 4. UPX (binary packer for stealth builds) ────────────────────
install_upx() {
    step "Checking UPX (binary packer, optional)..."
    if command -v upx >/dev/null 2>&1; then
        ok "UPX $(upx --version 2>&1 | head -1 | awk '{print $2}')"
        return 0
    fi
    sudo apt-get install -y upx-ucl 2>/dev/null && ok "UPX installed" || warn "UPX skipped (optional — build.sh will skip packing)"
}

# ── 5. Verify permissions ─────────────────────────────────────────
check_perms() {
    step "Verifying permissions..."
    chmod +x "$SCRIPT_DIR/clearshadow.sh" 2>/dev/null && ok "clearshadow.sh is executable" || warn "Check clearshadow.sh permissions"
    [ -f "$SCRIPT_DIR/build.sh" ] && chmod +x "$SCRIPT_DIR/build.sh" 2>/dev/null && ok "build.sh is executable" || true
}

# ── 6. Go module download (pre-fetch for offline builds) ──────────
download_go_deps() {
    step "Downloading Go module dependencies..."
    if command -v go >/dev/null 2>&1; then
        cd "$SCRIPT_DIR/src"
        if go mod download 2>/dev/null; then
            ok "Go modules cached"
        else
            warn "Go module download failed — will fetch on build"
        fi
        cd "$SCRIPT_DIR"
    fi
}

# ── Summary ────────────────────────────────────────────────────────
summary() {
    echo ""
    echo -e "  ${GREEN}╔══════════════════════════════════════════════╗${R}"
    echo -e "  ${GREEN}║       FP-REMOVER — Setup Complete            ║${R}"
    echo -e "  ${GREEN}╚══════════════════════════════════════════════╝${R}"
    echo ""
    echo -e "  ${CYAN}━━━ Bash Script (clearshadow.sh v2.1) ━━━${R}"
    echo -e "    ${CYAN}./clearshadow.sh --help${R}          ${DIM}# Show all options${R}"
    echo -e "    ${CYAN}./clearshadow.sh --dry-run${R}        ${DIM}# Preview without wiping${R}"
    echo -e "    ${CYAN}sudo ./clearshadow.sh${R}             ${DIM}# Full anti-forensics sweep${R}"
    echo -e "    ${CYAN}sudo ./clearshadow.sh --passes 7${R}  ${DIM}# DoD-level wipe${R}"
    echo ""
    echo -e "  ${PURPLE}━━━ Go Binary Build (clear_shadow v2.2) ━━━${R}"
    echo -e "    ${PURPLE}./build.sh${R}                       ${DIM}# Cross-compile (linux/win/arm64)${R}"
    echo -e "    ${PURPLE}cd src && go build -o ../clear_shadow .${R} ${DIM}# Quick local build${R}"
    echo ""
    echo -e "  ${DIM}Author : archnexus707  |  Donations: archnexus707@gmail.com${R}"
    echo ""
}

banner
install_bash_deps
install_optional
install_go
install_upx
check_perms
download_go_deps
summary
