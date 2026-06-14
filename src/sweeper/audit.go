package sweeper

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"sync"
	"time"
)

// AuditLog handles the forensic audit trail
type AuditLog struct {
	mu   sync.Mutex
	file *os.File
}

func NewAudit(path string) *AuditLog {
	f, err := os.OpenFile(path, os.O_CREATE|os.O_WRONLY|os.O_APPEND, 0600)
	if err != nil {
		f, _ = os.OpenFile("/tmp/clearshadow_audit.log", os.O_CREATE|os.O_WRONLY|os.O_APPEND, 0600)
	}
	return &AuditLog{file: f}
}

func (a *AuditLog) Log(format string, args ...interface{}) {
	a.mu.Lock()
	defer a.mu.Unlock()
	if a.file == nil {
		return
	}
	ts := time.Now().Format("15:04:05")
	msg := fmt.Sprintf(format, args...)
	fmt.Fprintf(a.file, "%s | %s\n", ts, msg)
}

func (a *AuditLog) Close() {
	if a.file != nil {
		a.file.Close()
	}
}

// ── Forensic Audit ──────────────────────────────────────────────

func (s *Sweeper) forensicAudit() {
	section("PRE-WIPE AUDIT", "Scanning for recoverable forensic artifacts")

	var shellEntries, browserURLs, sshHosts int

	// Count shell histories
	shellFiles := []string{
		"~/.bash_history", "~/.zsh_history", "~/.zhistory", "~/.fish_history",
	}
	for _, sf := range shellFiles {
		path := expand(sf)
		data, err := os.ReadFile(path)
		if err == nil {
			lines := 0
			for _, b := range data {
				if b == '\n' {
					lines++
				}
			}
			shellEntries += lines
		}
	}

	// Count SSH hosts
	khPath := expand("~/.ssh/known_hosts")
	data, err := os.ReadFile(khPath)
	if err == nil {
		for _, b := range data {
			if b == '\n' {
				sshHosts++
			}
		}
	}

	total := shellEntries + browserURLs + sshHosts
	fmt.Printf("  Forensic footprint before wipe:\n")
	fmt.Printf("  ├─ Shell history entries: %d\n", shellEntries)
	fmt.Printf("  ├─ SSH known hosts: %d\n", sshHosts)
	fmt.Printf("  └─ Total artifacts: %d\n", total)
	s.audit.Log("PRE-AUDIT: shells=%d ssh=%d", shellEntries, sshHosts)
}

// ── Post-Wipe Verification ─────────────────────────────────────

func (s *Sweeper) verifyWipe() {
	section("POST-WIPE VERIFICATION", "Checking for remaining artifacts")
	remaining := 0

	checks := []string{"~/.bash_history", "~/.zsh_history", "~/.fish_history"}
	for _, c := range checks {
		path := expand(c)
		info, err := os.Stat(path)
		if err == nil && info.Size() > 0 {
			remaining++
		}
	}

	if remaining == 0 {
		okMsg("All artifacts verified clean")
	} else {
		warnMsg(fmt.Sprintf("%d artifacts remain — re-run as root", remaining))
	}
	s.audit.Log("POST-AUDIT: remaining=%d", remaining)
}

// ── Command execution ──────────────────────────────────────────

var cmdMu sync.Mutex

func runCmd(name string, args ...string) {
	cmdMu.Lock()
	defer cmdMu.Unlock()
	cmd := exec.Command(name, args...)
	cmd.Stdout = nil
	cmd.Stderr = nil
	cmd.Run() // Fire and forget
}

// ── Platform detection ─────────────────────────────────────────

func isLinux() bool {
	_, err := os.Stat("/proc/version")
	return err == nil
}

func isWindows() bool {
	_, err := os.Stat("C:\\Windows\\System32\\cmd.exe")
	return err == nil
}

// ── File walk helpers ──────────────────────────────────────────

func walkAndWipe(root string, patterns []string, passes int, dryRun bool) {
	filepath.Walk(root, func(path string, info os.FileInfo, err error) error {
		if err != nil || info.IsDir() {
			return nil
		}
		name := info.Name()
		for _, pat := range patterns {
			matched, _ := filepath.Match(pat, name)
			if matched {
				if dryRun {
					fmt.Printf("  [DRY] Would wipe: %s\n", path)
				} else {
					wipeFile(path, passes)
				}
				break
			}
		}
		return nil
	})
}
