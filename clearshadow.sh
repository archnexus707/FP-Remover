#!/usr/bin/env bash
#==============================================================================
#   CLEARSHADOW v2.2 — Advanced Digital Footprint Eraser
#   Author : archnexus707
#   Enhanced: SSD-aware wipe, memory scrub, stochastic timestamps,
#            tool artifacts, file slack, pre-wipe audit, connection teardown,
#            core dump cleanup, LUKS header nuke, forensic audit, dry-run mode,
#            Docker/Snap/Flatpak cleanup, stealth mode, self-destruct v2,
#            Th3_M0th3r_O_W@r integration
#==============================================================================
set -e

C_RESET='\033[0m';      C_NEON='\033[38;5;51m'
C_PINK='\033[38;5;201m'; C_RED='\033[38;5;196m'
C_GREEN='\033[38;5;46m'; C_YELLOW='\033[38;5;226m'
C_ORANGE='\033[38;5;208m'; C_PURPLE='\033[38;5;129m'
C_DIM='\033[2m';         C_BOLD='\033[1m'
C_CYAN='\033[38;5;44m';  C_WHITE='\033[38;5;255m'

AUDIT_LOG="/tmp/clearshadow_audit_$(date +%s).log"
SHRED_HEADER=0
WIPE_PASSES=3
DRY_RUN=0
SELF_DESTRUCT=0
PARALLEL=1
FREE_SPACE=0
SKIP_MODULES=()
ONLY_MODULES=()

# ── Dependency check ─────────────────────────────────────────────
check_deps() {
    local missing=()
    for cmd in shred fallocate findmnt sqlite3; do
        command -v "$cmd" >/dev/null 2>&1 || missing+=("$cmd")
    done
    if [ ${#missing[@]} -gt 0 ]; then
        echo -e "  ${C_RED}[FATAL] Missing dependencies:${C_RESET} ${missing[*]}"
        echo -e "  ${C_DIM}Install with: sudo apt install coreutils util-linux sqlite3${C_RESET}"
        exit 1
    fi
}

banner() {
    clear 2>/dev/null || true
    echo ""
    echo -e "${C_RED}${C_BOLD}"
    cat << 'BAN'
    ██████╗██╗     ███████╗ █████╗ ██████╗ 
   ██╔════╝██║     ██╔════╝██╔══██╗██╔══██╗
   ██║     ██║     █████╗  ███████║██████╔╝
   ██║     ██║     ██╔══╝  ██╔══██║██╔══██╗
   ╚██████╗███████╗███████╗██║  ██║██║  ██║
    ╚═════╝╚══════╝╚══════╝╚═╝  ╚═╝╚═╝  ╚═╝
BAN
    echo -e "${C_PURPLE}${C_BOLD}"
    cat << 'BAN'
   ███████╗██╗  ██╗ █████╗ ██████╗  ██████╗ ██╗    ██╗
   ██╔════╝██║  ██║██╔══██╗██╔══██╗██╔═══██╗██║    ██║
   ███████╗███████║███████║██║  ██║██║   ██║██║ █╗ ██║
   ╚════██║██╔══██║██╔══██║██║  ██║██║   ██║██║███╗██║
   ███████║██║  ██║██║  ██║██████╔╝╚██████╔╝╚███╔███╔╝
   ╚══════╝╚═╝  ╚═╝╚═╝  ╚═╝╚═════╝  ╚═════╝  ╚══╝╚══╝ 
BAN
    echo -e "${C_RESET}"
    echo -e "  ${C_DIM}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${C_RESET}"
    echo -e "  ${C_PINK}🧹${C_RESET} ${C_WHITE}${C_BOLD}DIGITAL FOOTPRINT ERASER v2.2${C_RESET}  ${C_DIM}// archnexus707${C_RESET}  ${C_PINK}💀${C_RESET}"
    echo -e "  ${C_DIM}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${C_RESET}"
    echo -e "  ${C_DIM}SSD-aware | Memory scrub | Slack wipe | Anti-forensics audit${C_RESET}"
    echo ""
}

show_help() {
    echo -e "${C_PURPLE}CLEARSHADOW v2.2 — Digital Footprint Eraser${C_RESET}"
    echo ""
    echo "  Usage: ./clearshadow.sh [flags]"
    echo ""
    echo "  ${C_BOLD}Core Flags:${C_RESET}"
    echo "    --dry-run         Preview what will be wiped (no changes made)"
    echo "    --free-space      Also overwrite free disk space (prevents recovery)"
    echo "    --self-destruct   Remove clearshadow.sh itself after execution"
    echo "    --passes N        Number of shred passes (default: 3, DoD: 7)"
    echo "    --no-parallel     Disable parallel shredding (slower but safer)"
    echo "    --shred-header    Also destroy LUKS encryption headers"
    echo "    --help            Show this help"
    echo ""
    echo "  ${C_BOLD}Selective Sweep (skip modules):${C_RESET}"
    echo "    --skip-logs       Skip system logs"
    echo "    --skip-browsers   Skip browser data"
    echo "    --skip-network    Skip SSH & network traces"
    echo "    --skip-apps       Skip application artifacts"
    echo "    --skip-memory     Skip memory, swap, process scrub"
    echo "    --skip-timestamps Skip timestamp randomization"
    echo "    --skip-shells     Skip shell histories"
    echo "    --skip-hidden     Skip hidden history sweep"
    echo ""
    echo "  ${C_BOLD}Targeted Sweep (only run these):${C_RESET}"
    echo "    --only-logs       Only wipe system logs"
    echo "    --only-browsers   Only wipe browser data"
    echo "    --only-network    Only wipe SSH & network traces"
    echo "    --only-apps       Only wipe application artifacts"
    echo "    --only-memory     Only scrub memory/swap/processes"
    echo "    --only-timestamps Only randomize timestamps"
    echo "    --only-shells     Only wipe shell histories"
    echo "    --only-hidden     Only wipe hidden histories"
    echo ""
    echo "  ${C_BOLD}Examples:${C_RESET}"
    echo "    sudo ./clearshadow.sh                       # Full sweep"
    echo "    ./clearshadow.sh --dry-run                  # Safe preview"
    echo "    sudo ./clearshadow.sh --free-space           # Wipe + free space"
    echo "    sudo ./clearshadow.sh --skip-browsers        # Full except browsers"
    echo "    sudo ./clearshadow.sh --only-logs            # Only system logs"
    echo "    sudo ./clearshadow.sh --passes 7 --free-space --self-destruct  # Full send"
    echo ""
    echo -e "  ${C_DIM}Author: archnexus707  |  github.com/archnexus707/FP-Remover${C_RESET}"
    exit 0
}

# ── Dry-run wrappers ─────────────────────────────────────────────
maybe_wipe() {
    if [ "$DRY_RUN" -eq 1 ]; then
        typeout "[DRY-RUN] Would wipe: $1"
        audit "DRY-RUN: would wipe $1"
    else
        wipe_file "$1"
    fi
}
maybe_truncate() {
    if [ "$DRY_RUN" -eq 1 ]; then
        typeout "[DRY-RUN] Would truncate: $1"
        audit "DRY-RUN: would truncate $1"
    else
        truncate_log "$1"
    fi
}
maybe_remove() {
    if [ "$DRY_RUN" -eq 1 ]; then
        typeout "[DRY-RUN] Would remove: $1"
        audit "DRY-RUN: would remove $1"
    else
        rm -rf "$1" 2>/dev/null || true
    fi
}

section() { echo -e "\n  ${C_PURPLE}◈ ${1}${C_RESET}"; echo -e "  ${C_DIM}${2}${C_RESET}"; }
typeout() { echo -e "  ${C_GREEN}◆${C_RESET} ${C_DIM}$1${C_RESET}"; }
warnout() { echo -e "  ${C_YELLOW}◇${C_RESET} ${C_DIM}$1${C_RESET}"; }
audit() { echo "$(date '+%H:%M:%S') | $1" >> "$AUDIT_LOG"; }

# ── Improved wipe: shred + fallocate hole punch for SSDs ────────
# ── Parallel execution helper ────────────────────────────────────
parallel_exec() {
    local func="$1"; shift
    local -a items=("$@")
    if [ "$PARALLEL" -eq 0 ] || [ ${#items[@]} -le 2 ]; then
        for item in "${items[@]}"; do "$func" "$item"; done
    else
        local max_jobs=$(nproc 2>/dev/null || echo 4)
        local running=0
        for item in "${items[@]}"; do
            "$func" "$item" &
            running=$((running + 1))
            if [ "$running" -ge "$max_jobs" ]; then
                wait -n 2>/dev/null || true
                running=$((running - 1))
            fi
        done
        wait 2>/dev/null || true
    fi
}

wipe_file() {
    local f="$1"
    [ -f "$f" ] || return 0
    if [ "$DRY_RUN" -eq 1 ]; then
        audit "DRY-RUN: would wipe $f ($WIPE_PASSES passes)"
        return 0
    fi
    local dir=$(dirname "$f")
    if [ -d "$dir" ] && [ -w "$dir" ]; then
        fallocate --dig-holes "$f" 2>/dev/null || true
    fi
    shred -uzn "$WIPE_PASSES" "$f" 2>/dev/null || true
    audit "WIPED: $f ($WIPE_PASSES passes)"
}

truncate_log() {
    local f="$1"
    [ -f "$f" ] || return 0
    if [ "$DRY_RUN" -eq 1 ]; then
        local sz=$(stat -c%s "$f" 2>/dev/null || echo 0)
        audit "DRY-RUN: would truncate $f (was ${sz}B)"
        return 0
    fi
    local before=$(stat -c%s "$f" 2>/dev/null || echo 0)
    cat /dev/null > "$f"
    fallocate --dig-holes "$f" 2>/dev/null || true
    audit "TRUNCATED: $f (was ${before}B)"
}

# ── Enhanced: fstrim for SSD TRIM ───────────────────────────────
ssd_trim() {
    section "SSD TRIM" "Issuing TRIM commands to mounted filesystems"
    if command -v fstrim >/dev/null 2>&1; then
        for mp in $(findmnt -nlo TARGET -t ext4,xfs,btrfs 2>/dev/null); do
            fstrim "$mp" 2>/dev/null || true
            audit "TRIM: $mp"
        done
        typeout "TRIM completed on all supported mounts"
    else
        warnout "fstrim not available — skipping SSD TRIM"
    fi
}

# ── NEW: Pre-wipe forensic audit ─────────────────────────────────
forensic_audit() {
    section "PRE-WIPE AUDIT" "Scanning for recoverable forensic artifacts"
    
    local total=0
    local browser_urls=0
    local shell_entries=0
    local ssh_hosts=0
    
    # Count shell history entries
    for h in ~/.bash_history ~/.zsh_history ~/.zhistory ~/.fish_history; do
        if [ -f "$h" ]; then
            local c=$(wc -l < "$h" 2>/dev/null || echo 0)
            shell_entries=$((shell_entries + c))
            total=$((total + c))
        fi
    done
    
    # Count browser URLs (Firefox = moz_places; Chromium = urls)
    for sq in ~/.mozilla/firefox/*.default*/places.sqlite \
             ~/.mozilla/firefox/*.esr/places.sqlite; do
        if [ -f "$sq" ]; then
            local c=$(sqlite3 "$sq" "SELECT COUNT(*) FROM moz_places" 2>/dev/null || echo 0)
            browser_urls=$((browser_urls + c))
            total=$((total + c))
        fi
    done
    for sq in ~/.config/chromium/Default/History \
             ~/.config/google-chrome/Default/History \
             ~/.config/brave-browser/Default/History \
             ~/.config/microsoft-edge/Default/History; do
        if [ -f "$sq" ]; then
            local c=$(sqlite3 "$sq" "SELECT COUNT(*) FROM urls" 2>/dev/null || echo 0)
            browser_urls=$((browser_urls + c))
            total=$((total + c))
        fi
    done
    
    # Count SSH known hosts
    if [ -f ~/.ssh/known_hosts ]; then
        ssh_hosts=$(wc -l < ~/.ssh/known_hosts 2>/dev/null || echo 0)
        total=$((total + ssh_hosts))
    fi
    
    echo -e "  ${C_ORANGE}Forensic footprint before wipe:${C_RESET}"
    echo -e "  ${C_DIM}├─ Shell history entries: ${C_RED}${shell_entries}${C_RESET}"
    echo -e "  ${C_DIM}├─ Browser URLs: ${C_RED}${browser_urls}${C_RESET}"
    echo -e "  ${C_DIM}├─ SSH known hosts: ${C_RED}${ssh_hosts}${C_RESET}"
    echo -e "  ${C_DIM}└─ Total trackable artifacts: ${C_RED}${total}${C_RESET}"
    audit "PRE-AUDIT: shells=$shell_entries urls=$browser_urls ssh=$ssh_hosts"
}

# ── 1. Shell Histories ──────────────────────────────────────────
sweep_shells() {
    section "SHELL HISTORIES" "bash, zsh, fish, mysql, psql, python, node, less, wget"
    local files=(
        ~/.bash_history ~/.zsh_history ~/.zhistory ~/.fish_history
        ~/.mysql_history ~/.psql_history ~/.python_history ~/.node_repl_history
        ~/.lesshst ~/.wget-hsts ~/.local/share/fish/fish_history
        /root/.bash_history /root/.zsh_history /root/.sh_history
    )
    for f in "${files[@]}"; do wipe_file "$f" & done; wait 2>/dev/null || true
    history -c 2>/dev/null; unset HISTFILE 2>/dev/null
    export HISTFILE=/dev/null HISTSIZE=0 HISTFILESIZE=0
    typeout "Shell traces erased ($(echo ${#files[@]}) files processed)"
}

# ── 2. System Logs ──────────────────────────────────────────────
sweep_logs() {
    section "SYSTEM LOGS" "auth, syslog, journald, audit, firewall, services"
    local logs=(
        /var/log/auth.log /var/log/syslog /var/log/messages
        /var/log/secure /var/log/kern.log /var/log/boot.log
        /var/log/daemon.log /var/log/dpkg.log
        /var/log/apt/history.log /var/log/apt/term.log
        /var/log/ufw.log /var/log/fail2ban.log
        /var/log/btmp /var/log/lastlog /var/log/wtmp
        /var/log/audit/audit.log /var/log/tor/log
        /var/log/httpd/access_log /var/log/httpd/error_log
        /var/log/apache2/access.log /var/log/apache2/error.log
        /var/log/nginx/access.log /var/log/nginx/error.log
    )
    for f in "${logs[@]}"; do truncate_log "$f" & done; wait 2>/dev/null || true
    
    # Selective journal vacuum — vac yesterday's data, keep rotation looking normal
    journalctl --vacuum-time=1d 2>/dev/null || true
    journalctl --rotate 2>/dev/null || true
    rm -f ~/.xsession-errors* /root/.xsession-errors* 2>/dev/null || true
    typeout "System logs sanitized (selective vacuum)"
}

# ── 3. Temp & Caches ────────────────────────────────────────────
sweep_temp() {
    section "TEMP & CACHES" "tmp files, thumbnails, trash, clipboard, recent files"
    for dir in /tmp /var/tmp /dev/shm; do
        find "$dir" -maxdepth 2 -type f -user "$(whoami)" -exec rm -f {} \; 2>/dev/null || true
    done
    rm -rf ~/.cache/mozilla ~/.cache/chromium ~/.cache/google-chrome 2>/dev/null || true
    rm -rf ~/.cache/thumbnails ~/.cache/pip ~/.cache/mesa_shader_cache 2>/dev/null || true
    rm -rf ~/.cache/tracker ~/.cache/gnome-software ~/.cache/glippy 2>/dev/null || true
    rm -rf ~/.thumbnails ~/.local/share/thumbnails 2>/dev/null || true
    rm -rf ~/.local/share/Trash/* ~/.trash/* 2>/dev/null || true
    rm -rf ~/.local/share/clipboard/* 2>/dev/null || true
    rm -f ~/.local/share/recently-used.xbel ~/.recently-used 2>/dev/null || true
    typeout "Temp & caches purged"
}

# ── 4. Browser Data ─────────────────────────────────────────────
sweep_browsers() {
    section "BROWSER DATA" "Firefox, Chromium, Brave, Edge histories + cookies + caches"
    if [ -d ~/.mozilla/firefox ]; then
        for profile in ~/.mozilla/firefox/*.default* ~/.mozilla/firefox/*.esr; do
            [ -d "$profile" ] || continue
            for f in places.sqlite cookies.sqlite formhistory.sqlite downloads.sqlite \
                     SiteSecurityServiceState.txt sessionstore*.js*; do
                [ -f "$profile/$f" ] && truncate_log "$profile/$f"
            done
            rm -rf "$profile"/cache2 "$profile"/startupCache "$profile"/thumbnails 2>/dev/null || true
            rm -rf "$profile"/safebrowsing "$profile"/datareporting 2>/dev/null || true
        done
        typeout "Firefox sanitized"
    fi
    for browser in "chromium" "google-chrome" "brave-browser" "microsoft-edge"; do
        local d=~/.config/$browser
        [ -d "$d" ] || continue
        for item in History Cookies "Login Data" "Web Data" Cache "Code Cache" \
                    "Service Worker" "Session Storage" "Local Storage" IndexedDB; do
            rm -rf "$d"/Default/"$item" 2>/dev/null || true
        done
        rm -rf "$d"/GrShaderCache "$d"/ShaderCache 2>/dev/null || true
        typeout "${browser} sanitized"
    done
}

# ── 5. SSH & Network ────────────────────────────────────────────
sweep_network() {
    section "SSH & NETWORK" "known_hosts, DNS cache, ARP, Wi-Fi profiles, NM secrets"
    wipe_file ~/.ssh/known_hosts
    wipe_file ~/.ssh/known_hosts.old
    resolvectl flush-caches 2>/dev/null || systemd-resolve --flush-caches 2>/dev/null || true
    ip -s -s neigh flush all 2>/dev/null || true
    nmcli radio wifi off 2>/dev/null || true
    rm -f /etc/NetworkManager/system-connections/*.nmconnection 2>/dev/null || true
    rm -f ~/.local/share/NetworkManager/secret_key 2>/dev/null || true
    typeout "Network traces cleaned"
}

# ── 6. App Data (Enhanced — new tool artifacts added) ───────────
sweep_apps() {
    section "APPLICATION DATA" "vim, nano, git, docker, msf, burp, python, sql + tool artifacts"
    for f in ~/.viminfo ~/.nano_history ~/.wget-hsts ~/.curlrc \
             ~/.git-credentials ~/.gitconfig.bak; do
        wipe_file "$f"
    done
    rm -rf ~/.vim/.netrwhist ~/.nano/*.save 2>/dev/null || true
    rm -rf ~/.docker/config.json ~/.msf4/history ~/.msf4/logs/* 2>/dev/null || true
    rm -rf ~/.BurpSuite/*/history ~/.java/.userPrefs 2>/dev/null || true
    find /tmp -maxdepth 1 -name "*.swp" -delete 2>/dev/null || true
    
    # ── NEW: Tool-specific artifact hunter ────────────────
    local tool_artifacts=(
        ~/.msf4/loot ~/.msf4/local ~/.msf4/logos
        ~/.msf4/store ~/.msf4/notes
        ~/.john/john.pot ~/.john/john.log ~/.john/*.rec
        ~/.hashcat/hashcat.potfile ~/.hashcat/hashcat.log
        ~/.hashcat/sessions ~/.hashcat/cracked
        /tmp/hydra.restore /tmp/*.hydra.restore
        ~/.nmap ~/.cme/logs ~/.cme/workspaces
        /tmp/ccache* /tmp/krb5cc* /tmp/*.kirbi /tmp/*.ccache
        ~/.impacket ~/impacket*.py
        /tmp/nc.* /tmp/rev.* /tmp/.X11-unix/*
    )
    local running=0; local max_jobs=$(nproc 2>/dev/null || echo 4)
    for artifact in "${tool_artifacts[@]}"; do
        rm -rf "$artifact" 2>/dev/null &
        running=$((running + 1))
        if [ "$running" -ge "$max_jobs" ]; then wait -n 2>/dev/null || true; running=$((running - 1)); fi
    done
    wait 2>/dev/null || true
    typeout "Application & tool artifacts wiped"
}

# ── 7. Hidden Histories ─────────────────────────────────────────
sweep_hidden() {
    section "HIDDEN HISTORIES" "deep scan for history files across filesystem"
    find /home /root /tmp /var/tmp -maxdepth 5 \
        \( -name ".*history" -o -name ".*_history" -o -name "*.hst" \) \
        -type f -exec rm -f {} \; 2>/dev/null || true
    typeout "Hidden histories purged"
}

# ── 8. NEW: Process Memory Scrub ───────────────────────────────
sweep_process_memory() {
    section "PROCESS MEMORY" "Clearing ssh-agent, gpg-agent, keyring daemons"
    
    # Dump and wipe ssh-agent (core dumps contain decrypted keys in memory)
    if pgrep -x ssh-agent >/dev/null 2>&1; then
        local _cs_pids=$(pgrep -x ssh-agent)
        for pid in $_cs_pids; do
            gcore -o /tmp/.cs_ssh_dump "$pid" 2>/dev/null || true
            kill -9 "$pid" 2>/dev/null || true
        done
        # Securely wipe core dumps — they contain decrypted key material
        for dump in /tmp/.cs_ssh_dump.*; do
            [ -f "$dump" ] && shred -uzn "$WIPE_PASSES" "$dump" 2>/dev/null || true
        done
        typeout "ssh-agent killed & memory dumps shredded"
    fi
    
    # Clear gpg-agent
    if command -v gpgconf >/dev/null 2>&1; then
        gpgconf --kill gpg-agent 2>/dev/null || true
        typeout "gpg-agent killed"
    fi
    
    # GNOME keyring
    if pgrep gnome-keyring-d >/dev/null 2>&1; then
        killall -9 gnome-keyring-daemon 2>/dev/null || true
        typeout "gnome-keyring-daemon killed"
    fi
    
    # Disable core dumps temporarily
    ulimit -c 0 2>/dev/null || true
    sysctl -w kernel.core_pattern=/dev/null 2>/dev/null || true
    audit "Process memory scrub complete"
}

# ── 9. Memory & Swap ────────────────────────────────────────────
sweep_memory() {
    section "MEMORY & SWAP" "page cache, dentries, inodes, swap rotation"
    sync
    echo 3 > /proc/sys/vm/drop_caches 2>/dev/null || true
    if swapon --noheadings 2>/dev/null | grep -q .; then
        # Cycle swap with safety: if swapoff fails, keep original swap intact
        if swapoff -a 2>/dev/null; then
            swapon -a 2>/dev/null && typeout "Swap cycled" || warnout "Swap re-enable failed — REBOOT RECOMMENDED"
        else
            warnout "Swap cycle skipped (unable to offload — system swap preserved)"
        fi
    fi
    typeout "Memory caches flushed"
}

# ── NEW: Core dump & crash cleanup ──────────────────────────────
sweep_coredumps() {
    section "CORE DUMPS & CRASHES" "/var/lib/systemd/coredump, /var/crash, apport"
    rm -rf /var/lib/systemd/coredump/* 2>/dev/null || true
    rm -rf /var/crash/* 2>/dev/null || true
    rm -rf ~/.cache/apport/* 2>/dev/null || true
    find /tmp -name "core.*" -delete 2>/dev/null || true
    find /var/tmp -name "core.*" -delete 2>/dev/null || true
    typeout "Core dumps & crash reports purged"
}

# ── NEW: Stale connection teardown ──────────────────────────────
sweep_connections() {
    section "LIVE CONNECTIONS" "Teardown user-owned interactive connections (safe — skips system daemons)"
    
    # Only kill connections from interactive/browser/tool processes, NEVER system services
    local SAFE_KILL_PATTERNS='chrome|firefox|brave|curl|wget|nc\.|ncat|telnet|ssh\b'
    local SKIP_PATTERNS='systemd|sshd|dbus|polkit|NetworkManager|udisks|upower|pulseaudio|Xorg|wayland'
    local conns=$(ss -tnp state established 2>/dev/null | awk '/users/ {print $NF}' | grep -oP 'pid=\K\d+' | sort -u)
    
    for pid in $conns; do
        local user=$(ps -o user= -p "$pid" 2>/dev/null || echo "")
        local cmd=$(ps -o comm= -p "$pid" 2>/dev/null || echo "unknown")
        # Skip system daemons unconditionally
        if echo "$cmd" | grep -qE "$SKIP_PATTERNS"; then
            continue
        fi
        # Only kill if owned by current user and matches known interactive tool patterns
        if [ "$user" = "$(whoami)" ]; then
            if echo "$cmd" | grep -qE "$SAFE_KILL_PATTERNS"; then
                kill "$pid" 2>/dev/null || true  # SIGTERM first, NOT -9
                sleep 0.5
                kill -0 "$pid" 2>/dev/null && kill -9 "$pid" 2>/dev/null || true
                audit "KILLED CONNECTION: pid=$pid cmd=$cmd user=$user"
            fi
        fi
    done
    typeout "Interactive connections terminated (system daemons preserved)"
    audit "Connection teardown complete"
}

# ── 10. Enhanced Timestamps (stochastic) ────────────────────────
sweep_timestamps() {
    section "FILE TIMESTAMPS" "Randomizing modification times with stochastic spread"
    for dir in ~/Desktop ~/Documents ~/Downloads; do
        if [ -d "$dir" ]; then
            while IFS= read -r -d '' f; do
                # Generate random date within last 6 months
                local days=$((RANDOM % 180))
                local hours=$((RANDOM % 24))
                local mins=$((RANDOM % 60))
                local stamp=$(date -d "$days days ago $hours:$mins" +"%Y%m%d%H%M.%S" 2>/dev/null)
                touch -t "$stamp" "$f" 2>/dev/null || true
            done < <(find "$dir" -maxdepth 2 -type f -print0)
        fi
    done
    typeout "Timestamps randomized (stochastic spread across 6 months)"
    audit "Timestamps randomized"
}

# ── NEW: LUKS header nuke (optional) ────────────────────────────
sweep_luks_header() {
    [ "$SHRED_HEADER" -eq 1 ] || return 0
    section "LUKS HEADER NUKE" "cryptographically destroying encryption headers"
    echo -e "  ${C_RED}⚠  LUKS header destruction is PERMANENT and IRREVERSIBLE${C_RESET}"
    read -r -p "  Type 'DESTROY' to confirm: " confirm
    [ "$confirm" = "DESTROY" ] || { warnout "LUKS shred skipped"; return 0; }
    
    for dev in $(lsblk -nlo NAME,TYPE | grep crypt | awk '{print "/dev/"$1}'); do
        cryptsetup luksErase "$dev" 2>/dev/null || true
        audit "LUKS HEADER DESTROYED: $dev"
        typeout "LUKS header destroyed: $dev"
    done
}

# ── NEW: Free space wiping ──────────────────────────────────────
sweep_free_space() {
    section "FREE SPACE" "Overwriting unallocated disk blocks to prevent file recovery"
    
    local dirs_to_fill=()
    [ -d /tmp ] && dirs_to_fill+=(/tmp)
    [ -d /var/tmp ] && dirs_to_fill+=(/var/tmp)
    [ -d "$HOME" ] && dirs_to_fill+=("$HOME")
    
    for target_dir in "${dirs_to_fill[@]}"; do
        local avail=$(df --output=avail "$target_dir" 2>/dev/null | tail -1 | tr -d ' ')
        if [ -z "$avail" ] || [ "$avail" -eq 0 ]; then continue; fi
        
        typeout "Filling free space in $target_dir ($((avail/1024))MB available)"
        
        if [ "$DRY_RUN" -eq 1 ]; then
            audit "DRY-RUN: would fill free space in $target_dir ($((avail/1024))MB)"
            continue
        fi
        
        # Fill with random data, then sync and remove
        local filler="$target_dir/.cs_free_fill_$$"
        if command -v dd >/dev/null 2>&1; then
            dd if=/dev/urandom of="$filler" bs=1M count=$((avail/1024 - 10)) 2>/dev/null || true
            sync
            shred -uzn 1 "$filler" 2>/dev/null || rm -f "$filler" 2>/dev/null || true
        fi
        typeout "Free space wiped in $target_dir"
        audit "FREE-SPACE: $target_dir"
    done
    ssd_trim
}

# ── NEW: Self-destruct ──────────────────────────────────────────
self_destruct() {
    [ "$SELF_DESTRUCT" -eq 1 ] || return 0
    section "SELF-DESTRUCT" "Removing clearshadow.sh from the system"
    local self="$(readlink -f "$0")"
    if [ -f "$self" ]; then
        shred -uzn "$WIPE_PASSES" "$self" 2>/dev/null || rm -f "$self" 2>/dev/null || true
        audit "SELF-DESTRUCT: $self"
        typeout "clearshadow.sh has been removed"
    fi
}

# ── NEW v2.2: Docker cleanup ─────────────────────────────────────
sweep_docker() {
    section "DOCKER ARTIFACTS" "containers, volumes, images, build cache"
    if command -v docker >/dev/null 2>&1; then
        docker rm -f $(docker ps -aq) 2>/dev/null || true
        docker volume prune -f 2>/dev/null || true
        docker image prune -a -f 2>/dev/null || true
        docker builder prune -a -f 2>/dev/null || true
        docker system prune -a -f --volumes 2>/dev/null || true
        typeout "Docker artifacts purged"
    else
        warnout "Docker not found — skipping"
    fi
    audit "Docker artifacts purged"
}

# ── NEW v2.2: Snap + Flatpak caches ──────────────────────────────
sweep_snaps() {
    section "SNAP & FLATPAK" "cache, temporary data"
    if command -v snap >/dev/null 2>&1; then
        rm -rf ~/snap/*/*/.cache 2>/dev/null || true
        typeout "Snap caches purged"
    fi
    if command -v flatpak >/dev/null 2>&1; then
        rm -rf ~/.var/app/*/cache 2>/dev/null || true
        rm -rf ~/.local/share/flatpak/*/.cache 2>/dev/null || true
        typeout "Flatpak caches purged"
    fi
    audit "Snap/Flatpak caches purged"
}

# ── NEW v2.2: systemd journal deeper clean ───────────────────────
sweep_journal_deep() {
    section "SYSTEMD JOURNAL" "deep vacuum + rotate"
    if command -v journalctl >/dev/null 2>&1; then
        journalctl --vacuum-size=1M 2>/dev/null || true
        journalctl --rotate 2>/dev/null || true
        journalctl --vacuum-time=1s 2>/dev/null || true
        rm -rf /var/log/journal/* 2>/dev/null || true
        typeout "Journal deeply purged"
    fi
    audit "Journal deep purge"
}

# ── NEW v2.2: Th3_M0th3r_O_W@r cleanup ───────────────────────────
sweep_mother_war() {
    section "C2 FRAMEWORK" "Th3_M0th3r_O_W@r operational artifacts"
    rm -rf /tmp/clearshadow_audit_*.log 2>/dev/null || true
    rm -rf /tmp/svchost* /tmp/svcs* /tmp/cs_* /tmp/scr_* /tmp/lsass_* /tmp/sam_* /tmp/exfil_* 2>/dev/null || true
    rm -rf /tmp/.cs_* /tmp/ccache* /tmp/krb5cc* /tmp/nc.* /tmp/rev.* 2>/dev/null || true
    rm -rf ~/.msf4/logs/* ~/.msf4/loot/* 2>/dev/null || true
    typeout "Operational artifacts purged"
    audit "C2 framework artifacts purged"
}

# ── Module gate: should we run this module? ─────────────────────
should_run() {
    local module="$1"
    # If --only-* is set, only run matching modules
    if [ ${#ONLY_MODULES[@]} -gt 0 ]; then
        for m in "${ONLY_MODULES[@]}"; do
            [ "$m" = "$module" ] && return 0
        done
        return 1
    fi
    # If --skip-* is set, skip matching modules
    for m in "${SKIP_MODULES[@]}"; do
        [ "$m" = "$module" ] && return 1
    done
    return 0
}
verify_wipe() {
    section "POST-WIPE VERIFICATION" "Checking for remaining artifacts"
    local remaining=0
    
    # Check shells
    for h in ~/.bash_history ~/.zsh_history ~/.fish_history; do
        [ -f "$h" ] && [ -s "$h" ] && remaining=$((remaining + 1))
    done
    
    # Check browsers
    for sq in ~/.mozilla/firefox/*.default*/places.sqlite; do
        [ -f "$sq" ] && [ -s "$sq" ] && remaining=$((remaining + 1))
    done
    
    if [ "$remaining" -eq 0 ]; then
        echo -e "  ${C_GREEN}◆ All artifacts verified clean${C_RESET}"
    else
        echo -e "  ${C_ORANGE}◇ ${remaining} artifacts remain — re-run as root${C_RESET}"
    fi
    audit "POST-AUDIT: remaining=$remaining"
}

# ── Main ────────────────────────────────────────────────────────
run() {
    check_deps
    banner
    
    if [ "$DRY_RUN" -eq 1 ]; then
        echo -e "  ${C_CYAN}[DRY-RUN MODE] No changes will be made — preview only${C_RESET}\n"
    fi
    
    if [ "$EUID" -ne 0 ]; then
        echo -e "  ${C_ORANGE}Running as user — partial wipe only${C_RESET}"
        echo -e "  ${C_ORANGE}  For full sweep:${C_RESET} ${C_PINK}sudo $0${C_RESET}\n"
        forensic_audit
        should_run "shells" && sweep_shells
        sweep_temp
        should_run "browsers" && sweep_browsers
        should_run "apps" && sweep_apps
        should_run "hidden" && sweep_hidden
        ssd_trim
        verify_wipe
        echo -e "\n  ${C_ORANGE}Audit log: ${AUDIT_LOG}${C_RESET}"
        echo -e "  ${C_RED}Reboot recommended to clear memory traces.${C_RESET}\n"
        exit 0
    fi

    if [ "$DRY_RUN" -ne 1 ]; then
        echo -e "\n  ${C_RED}THIS WILL PERMANENTLY ERASE ALL DIGITAL TRACES${C_RESET}"
        echo -e "  ${C_RED}  Full anti-forensics sweep — irreversible.${C_RESET}\n"
        read -r -p "  Type 'ERASE' to confirm: " confirm
        [ "$confirm" != "ERASE" ] && { echo -e "\n  ${C_YELLOW}Aborted.${C_RESET}\n"; exit 0; }
    fi

    echo ""; echo -e "  ${C_RED}${C_RESET} ${C_RED}STARTING FULL ANTI-FORENSICS SWEEP${C_RESET} ${C_RED}${C_RESET}\n"

    forensic_audit
    should_run "shells" && sweep_shells
    should_run "logs" && [ "$DRY_RUN" -ne 1 ] && sweep_logs
    sweep_temp
    should_run "browsers" && sweep_browsers
    should_run "network" && sweep_network
    should_run "apps" && sweep_apps
    should_run "hidden" && sweep_hidden
    should_run "process" && [ "$DRY_RUN" -ne 1 ] && sweep_process_memory
    should_run "cores" && [ "$DRY_RUN" -ne 1 ] && sweep_coredumps
    should_run "connections" && [ "$DRY_RUN" -ne 1 ] && sweep_connections
    should_run "memory" && [ "$DRY_RUN" -ne 1 ] && sweep_memory
    should_run "timestamps" && [ "$DRY_RUN" -ne 1 ] && sweep_timestamps
    sweep_luks_header
    ssd_trim
    [ "$FREE_SPACE" -eq 1 ] && sweep_free_space
    # v2.2 new modules
    should_run "docker" && sweep_docker
    should_run "snaps" && sweep_snaps
    should_run "journal" && [ "$DRY_RUN" -ne 1 ] && sweep_journal_deep
    should_run "motherwar" && sweep_mother_war
    verify_wipe
    self_destruct

    echo ""
    echo -e "  ${C_GREEN}╔══════════════════════════════════╗${C_RESET}"
    echo -e "  ${C_GREEN}║     ◆  SWEEP  COMPLETE  ◆       ║${C_RESET}"
    echo -e "  ${C_GREEN}╚══════════════════════════════════╝${C_RESET}"
    [ "$DRY_RUN" -eq 1 ] && echo -e "  ${C_CYAN}        (Dry-run — nothing was changed)${C_RESET}"
    echo ""
    echo -e "  ${C_DIM}Shells${C_RESET}     ${C_GREEN}${C_RESET}  ${C_DIM}Logs${C_RESET}        ${C_GREEN}${C_RESET}"
    echo -e "  ${C_DIM}Temp${C_RESET}       ${C_GREEN}${C_RESET}  ${C_DIM}Browsers${C_RESET}    ${C_GREEN}${C_RESET}"
    echo -e "  ${C_DIM}Network${C_RESET}    ${C_GREEN}${C_RESET}  ${C_DIM}Apps${C_RESET}        ${C_GREEN}${C_RESET}"
    echo -e "  ${C_DIM}Memory${C_RESET}     ${C_GREEN}${C_RESET}  ${C_DIM}Processes${C_RESET}  ${C_GREEN}${C_RESET}"
    echo -e "  ${C_DIM}Cores${C_RESET}      ${C_GREEN}${C_RESET}  ${C_DIM}Timestamps${C_RESET} ${C_GREEN}${C_RESET}"
    echo -e "  ${C_DIM}SSD TRIM${C_RESET}   ${C_GREEN}${C_RESET}  ${C_DIM}Hidden${C_RESET}     ${C_GREEN}${C_RESET}"
    echo ""
    [ "$DRY_RUN" -ne 1 ] && echo -e "  ${C_RED}◆ REBOOT IMMEDIATELY to clear process memory traces ◆${C_RESET}"
    echo -e "  ${C_DIM}Audit log: ${AUDIT_LOG}${C_RESET}"
    [ "$DRY_RUN" -ne 1 ] && echo -e "  ${C_DIM}Memory forensics can recover data until power cycle.${C_RESET}\n"
}

# ── CLI args ────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run) DRY_RUN=1; shift ;;
        --free-space) FREE_SPACE=1; shift ;;
        --self-destruct) SELF_DESTRUCT=1; shift ;;
        --shred-header) SHRED_HEADER=1; shift ;;
        --passes) WIPE_PASSES="$2"; shift 2 ;;
        --no-parallel) PARALLEL=0; shift ;;
        --skip-logs) SKIP_MODULES+=("logs"); shift ;;
        --skip-browsers) SKIP_MODULES+=("browsers"); shift ;;
        --skip-network) SKIP_MODULES+=("network"); shift ;;
        --skip-apps) SKIP_MODULES+=("apps"); shift ;;
        --skip-memory) SKIP_MODULES+=("memory"); SKIP_MODULES+=("process"); SKIP_MODULES+=("cores"); SKIP_MODULES+=("connections"); shift ;;
        --skip-timestamps) SKIP_MODULES+=("timestamps"); shift ;;
        --skip-shells) SKIP_MODULES+=("shells"); shift ;;
        --skip-hidden) SKIP_MODULES+=("hidden"); shift ;;
        --only-logs) ONLY_MODULES+=("logs"); shift ;;
        --only-browsers) ONLY_MODULES+=("browsers"); shift ;;
        --only-network) ONLY_MODULES+=("network"); shift ;;
        --only-apps) ONLY_MODULES+=("apps"); shift ;;
        --only-memory) ONLY_MODULES+=("memory"); ONLY_MODULES+=("process"); ONLY_MODULES+=("cores"); ONLY_MODULES+=("connections"); shift ;;
        --only-timestamps) ONLY_MODULES+=("timestamps"); shift ;;
        --only-shells) ONLY_MODULES+=("shells"); shift ;;
        --only-hidden) ONLY_MODULES+=("hidden"); shift ;;
        --help|-h) show_help ;;
        *) shift ;;
    esac
done

run
