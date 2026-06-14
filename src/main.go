package main

import (
	"clear_shadow/sweeper"
	"flag"
	"fmt"
	"os"
	"runtime"
)

const banner = `
   ╔═══════════════════════════════════════════════════════════════╗
   ║     ░▒▓█  CLEAR SHADOW — RED TEAM FOOTPRINT ERASER  █▓▒░    ║
   ║          Cross-Platform | SSD-Aware | Anti-Forensics         ║
   ╚═══════════════════════════════════════════════════════════════╝
                        archnexus_707`

var (
	dryRun       = flag.Bool("dry-run", false, "Preview only — no changes made")
	passes       = flag.Int("passes", 3, "Shred passes (DoD=7)")
	selfDestruct = flag.Bool("self-destruct", false, "Remove binary after execution")
	freeSpace    = flag.Bool("free-space", false, "Overwrite free disk space")
	skipModules  = flag.String("skip", "", "Skip modules: shells,logs,browsers,temp,network,artifacts,memory,timestamps (comma-separated)")
	onlyModules  = flag.String("only", "", "Only run these modules (comma-separated)")
	auditFile    = flag.String("audit", "", "Audit log path")
	showVersion  = flag.Bool("version", false, "Show version")
)

func main() {
	flag.Parse()

	// Safe flags — no stealth delay, no operations
	if *showVersion {
		fmt.Println("clear_shadow v2.2 — archnexus_707")
		return
	}

	// Anti-analysis initialization (silent exit if sandbox detected)
	sweeper.InitStealth()

	fmt.Println(banner)
	fmt.Printf("\n  OS: %s/%s  |  Passes: %d  |  Dry-Run: %v\n\n",
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

	if !cfg.DryRun && os.Geteuid() != 0 {
		fmt.Println("  [!!] Running as non-root — partial wipe only")
		fmt.Println("  [!!] Re-run with sudo for full sweep\n")
	}

	s := sweeper.New(cfg)
	s.Run()
}
