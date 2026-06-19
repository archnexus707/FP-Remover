package sweeper

import (
	"fmt"
	"runtime"
	"strings"
	"time"
)

// Config holds all sweep configuration
type Config struct {
	DryRun       bool
	Passes       int
	SelfDestruct bool
	FreeSpace    bool
	SkipModules  map[string]bool
	OnlyModules  map[string]bool
	AuditFile    string
}

// Sweeper orchestrates all anti-forensics operations
type Sweeper struct {
	cfg    Config
	audit  *AuditLog
	target string // "linux" or "windows"
}

// New creates a new Sweeper with the given config
func New(cfg Config) *Sweeper {
	if cfg.AuditFile == "" {
		cfg.AuditFile = fmt.Sprintf("/tmp/clearshadow_audit_%d.log", time.Now().Unix())
	}
	return &Sweeper{
		cfg:    cfg,
		audit:  NewAudit(cfg.AuditFile),
		target: detectOS(),
	}
}

func detectOS() string {
	if runtime.GOOS == "windows" {
		return "windows"
	}
	return "linux"
}

// shouldRun returns true if the named module should execute
func (s *Sweeper) shouldRun(name string) bool {
	if len(s.cfg.OnlyModules) > 0 {
		return s.cfg.OnlyModules[name]
	}
	if s.cfg.SkipModules[name] {
		return false
	}
	return true
}

// Run executes all sweep modules
func (s *Sweeper) Run() {
	start := time.Now()

	// Always run forensic audit first
	s.forensicAudit()

	// Core modules — order matters
	if s.shouldRun("shells") {
		s.sweepShells()
	}
	if s.shouldRun("logs") && s.target == "linux" {
		s.sweepLogs()
	}
	if s.shouldRun("temp") {
		s.sweepTemp()
	}
	if s.shouldRun("browsers") {
		s.sweepBrowsers()
	}
	if s.shouldRun("network") {
		s.sweepNetwork()
	}
	if s.shouldRun("artifacts") {
		s.sweepArtifacts()
	}
	if s.shouldRun("memory") {
		s.sweepMemory()
	}
	if s.shouldRun("timestamps") {
		s.sweepTimestamps()
	}

	// Platform-specific
	if s.target == "windows" {
		s.sweepEventLog()
		s.sweepPrefetch()
		s.sweepRegistry()
	} else {
		s.sweepProcessMemory()
		s.sweepCoreDumps()
		s.sweepConnections()
	}

	// Optional
	if s.cfg.FreeSpace {
		s.sweepFreeSpace()
	}
	s.ssdTrim()
	s.verifyWipe()

	elapsed := time.Since(start)
	fmt.Printf("\n  [OK] Sweep complete in %v\n", elapsed.Round(time.Millisecond))
	s.audit.Log("SWEEP COMPLETE | duration=%v", elapsed)

	if s.cfg.SelfDestruct {
		s.selfDestruct()
	}
}

// ParseModuleList converts "shells,logs,browsers" → map[string]bool
func ParseModuleList(s string) map[string]bool {
	m := make(map[string]bool)
	if s == "" {
		return m
	}
	for _, name := range strings.Split(s, ",") {
		m[strings.TrimSpace(name)] = true
	}
	return m
}
