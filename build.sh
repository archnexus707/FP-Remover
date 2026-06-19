#!/usr/bin/env bash
set -e

RED='\033[38;5;196m'; GREEN='\033[38;5;46m'; CYAN='\033[38;5;51m'
PURPLE='\033[38;5;129m'; YELLOW='\033[38;5;226m'; PINK='\033[38;5;213m'
WHITE='\033[1;37m'; DIM='\033[2m'; BOLD='\033[1m'; R='\033[0m'

cd "$(dirname "$0")/src"
RELEASE_DIR="../release"
mkdir -p "$RELEASE_DIR"

echo ""
echo -e "${RED}${BOLD}"
cat << 'EOF'
    ██████╗██╗     ███████╗ █████╗ ██████╗ 
   ██╔════╝██║     ██╔════╝██╔══██╗██╔══██╗
   ██║     ██║     █████╗  ███████║██████╔╝
   ██║     ██║     ██╔══╝  ██╔══██║██╔══██╗
   ╚██████╗███████╗███████╗██║  ██║██║  ██║
    ╚═════╝╚══════╝╚══════╝╚═╝  ╚═╝╚═╝  ╚═╝
EOF
echo -e "${PURPLE}${BOLD}"
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
echo -e "  ${PINK}🔥${R} ${WHITE}${BOLD}APT-GRADE STEALTH BUILD${R} ${DIM}// archnexus707${R}  ${PINK}🔥${R}"
echo -e "  ${DIM}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${R}"
echo ""
echo -e "  ${DIM}Hardening: strip + no-buildid + UPX + XOR+AES + anti-sandbox${R}"
echo ""

LDFLAGS="-s -w -buildid= -X main.buildTime=$(date +%s)"
GCFLAGS="all=-l"

# ── Function: build + pack target ────────────────────────────────
build_target() {
    local name="$1" goos="$2" goarch="$3" exe="$4"
    echo -e "${CYAN}[*] Compiling ${name}...${R}"

    echo -e "  ${DIM}[$(date +%H:%M:%S)]${R} ${CYAN}⏳${R} Compiling..."
    CGO_ENABLED=0 GOOS="$goos" GOARCH="$goarch" \
        go build -trimpath \
        -ldflags="${LDFLAGS}" \
        -gcflags="${GCFLAGS}" \
        -o "${RELEASE_DIR}/${exe}" .

    local size_before=$(stat -c%s "${RELEASE_DIR}/${exe}" 2>/dev/null || echo 0)

    # Layer: UPX packing with maximum compression
    if command -v upx >/dev/null 2>&1; then
        upx --best --lzma --force --quiet "${RELEASE_DIR}/${exe}" 2>/dev/null || true
        local size_after=$(stat -c%s "${RELEASE_DIR}/${exe}" 2>/dev/null || echo 0)
        local reduction=$((100 - size_after * 100 / size_before))
        echo -e "${GREEN}[+] ${name}: $(numfmt --to=iec $size_after 2>/dev/null || echo ${size_after}B)${R} ${DIM}(-${reduction}% packed)${R}"
    else
        echo -e "${GREEN}[+] ${name}: $(numfmt --to=iec $size_before 2>/dev/null || echo ${size_before}B)${R}"
    fi
}

# ── Linux amd64 ──────────────────────────────────────────────────
build_target "Linux x64" "linux" "amd64" "clear_shadow"

# ── Linux arm64 ──────────────────────────────────────────────────
build_target "Linux ARM64" "linux" "arm64" "clear_shadow_arm64"

# ── Windows amd64 ────────────────────────────────────────────────
build_target "Windows x64" "windows" "amd64" "clear_shadow.exe"

# ── Scramble timestamps ──────────────────────────────────────────
for f in "$RELEASE_DIR"/clear_shadow*; do
    [ -f "$f" ] && touch -t 202401010000 "$f" 2>/dev/null || true
done

# ── SHA256 hashes ────────────────────────────────────────────────
echo ""
echo -e "  ${PURPLE}SHA256 Checksums:${R}"
for f in "$RELEASE_DIR"/clear_shadow*; do
    [ -f "$f" ] && sha256sum "$f" | while read h f; do echo -e "  ${DIM}${h:0:16}...  $(basename $f)${R}"; done
done

echo ""
echo -e "  ${GREEN}╔══════════════════════════════════════════╗${R}"
echo -e "  ${GREEN}║   ◆  APT STEALTH BUILD COMPLETE  ◆      ║${R}"
echo -e "  ${GREEN}╚══════════════════════════════════════════╝${R}"
echo ""
echo -e "  ${DIM}Hardening applied:${R}"
echo -e "  ${DIM}  [1] Symbol stripping (-s -w)${R}"
echo -e "  ${DIM}  [2] Build ID removed${R}"
echo -e "  ${DIM}  [3] UPX LZMA packing${R}"
echo -e "  ${DIM}  [4] Source-level XOR+AES string encryption${R}"
echo -e "  ${DIM}  [5] Anti-sandbox + anti-debug checks${R}"
echo -e "  ${DIM}  [6] Timestamp forged to 2024-01-01${R}"
echo -e "  ${DIM}  [7] Trimpath (no build paths in binary)${R}"
echo ""
