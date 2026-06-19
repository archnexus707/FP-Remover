package main

import (
	"clear_shadow/sweeper"
	"flag"
	"fmt"
	"os"
	"runtime"
)

var (
	dryRun       = flag.Bool("dry-run", false, "Preview only — no changes made")
	passes       = flag.Int("passes", 3, "Shred passes (DoD=7)")
	selfDestruct = flag.Bool("self-destruct", false, "Remove binary after execution")
	freeSpace    = flag.Bool("free-space", false, "Overwrite free disk space")
	skipModules  = flag.String("skip", "", "Skip modules: shells,logs,browsers,temp,network,artifacts,memory,timestamps (comma-separated)")
	onlyModules  = flag.String("only", "", "Only run these modules (comma-separated)")
	auditFile    = flag.String("audit", "", "Audit log path")
	showVersion  = flag.Bool("version", false, "Show version")
	noStealth    = flag.Bool("no-stealth", false, "Skip anti-analysis delays (dev mode)")
)

func isRoot() bool {
	if runtime.GOOS == "windows" {
		_, err := os.Open("\\\\.\\PHYSICALDRIVE0")
		return err == nil
	}
	return os.Getuid() == 0
}

func main() {
	flag.Parse()

	if *showVersion {
		fmt.Println("clear_shadow v2.2 — archnexus707")
		return
	}

	if !*noStealth && !*dryRun {
		sweeper.InitStealth()
	}

	fmt.Println()
	fmt.Println("   \033[38;5;196m╔═══════════════════════════════════════════════════════════════╗")
	fmt.Println("   ║    \033[38;5;51m░▒▓█\033[38;5;196m  CLEAR SHADOW v2.2 — FOOTPRINT ERASER  \033[38;5;51m█▓▒░\033[38;5;196m    ║")
	fmt.Println("   ║\033[0m       Cross-Platform | SSD-Aware | Anti-Forensics         \033[38;5;196m║")
	fmt.Println("   ╚═══════════════════════════════════════════════════════════════╝\033[0m")
	fmt.Println()
	fmt.Printf("   \033[2m💀 archnexus707  |  OS: %s/%s  |  Passes: %d  |  Dry-Run: %v\033[0m\n\n",
		runtime.GOOS, runtime.GOARCH, *passes, *dryRun)

	cfg := sweeper.Config{
		DryRun:       *dryRun,
		Passes:       *passes,
		SelfDestruct: *selfDestruct,
		FreeSpace:    *freeSpace,
		SkipModules:  sweeper.ParseModuleList(*skipModules),
		OnlyModules:  sweeper.ParseModuleList(*onlyModules),
		AuditFile:    *auditFile,
	}

	if !cfg.DryRun && !isRoot() {
		fmt.Println("  \033[38;5;208m⚠  Running as non-root — partial wipe only\033[0m")
		fmt.Println("  \033[38;5;208m⚠  Re-run with sudo for full sweep\033[0m")
		fmt.Println()
	}

	s := sweeper.New(cfg)
	s.Run()
}
