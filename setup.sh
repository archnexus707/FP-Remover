#!/usr/bin/env bash
#==============================================================================
#   FP-Remover — Setup & Dependency Installer
#   Author : archnexus707
#   Tool   : clearshadow.sh — Advanced Digital Footprint Eraser
#==============================================================================
set -e

RED='\033[38;5;196m'; GREEN='\033[38;5;46m'; PURPLE='\033[38;5;129m'
CYAN='\033[38;5;51m'; YELLOW='\033[38;5;226m'; DIM='\033[2m'; R='\033[0m'

banner() {
    echo ""
    echo -e "${RED}   ╔═══════════════════════════════════════════════════════════════╗${R}"
    echo -e "${RED}   ║     ░▒▓█  FP-REMOVER — DIGITAL FOOTPRINT ERASER SETUP  █▓▒░  ║${R}"
    echo -e "${RED}   ╚═══════════════════════════════════════════════════════════════╝${R}"
    echo ""
    echo -e "  ${DIM}Author: archnexus707  |  github.com/archnexus707/FP-Remover${R}"
    echo ""
}

step()  { echo -e "\n  ${PURPLE}[*]${R} ${1}"; }
ok()    { echo -e "  ${GREEN}[OK]${R} ${1}"; }
warn()  { echo -e "  ${YELLOW}[!!]${R} ${1}"; }
fail()  { echo -e "  ${RED}[XX]${R} ${1}"; }

# ── 1. System packages ─────────────────────────────────────────
install_deps() {
    step "Installing required system packages..."
    
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

# ── 2. Optional tools ──────────────────────────────────────────
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

# ── 3. Verify permissions ──────────────────────────────────────
check_perms() {
    step "Verifying permissions..."
    chmod +x "$(dirname "$0")/clearshadow.sh" 2>/dev/null && ok "clearshadow.sh is executable" || warn "Check permissions"
}

# ── Summary ─────────────────────────────────────────────────────
summary() {
    echo ""
    echo -e "  ${GREEN}╔══════════════════════════════════════════════╗${R}"
    echo -e "  ${GREEN}║       FP-REMOVER — Setup Complete            ║${R}"
    echo -e "  ${GREEN}╚══════════════════════════════════════════════╝${R}"
    echo ""
    echo -e "  ${DIM}Quick start:${R}"
    echo -e "    ${CYAN}./clearshadow.sh --help${R}          ${DIM}# Show all options${R}"
    echo -e "    ${CYAN}./clearshadow.sh --dry-run${R}        ${DIM}# Preview without wiping${R}"
    echo -e "    ${CYAN}sudo ./clearshadow.sh${R}             ${DIM}# Full anti-forensics sweep${R}"
    echo -e "    ${CYAN}sudo ./clearshadow.sh --passes 7${R}  ${DIM}# DoD-level wipe${R}"
    echo ""
    echo -e "  ${DIM}Author : archnexus707  |  Donations welcome${R}"
    echo ""
}

banner
install_deps
install_optional
check_perms
summary
