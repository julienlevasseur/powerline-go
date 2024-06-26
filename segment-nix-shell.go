package main

import (
	"os"

	pwl "github.com/julienlevasseur/powerline-go/powerline"
)

func segmentNixShell(p *powerline) []pwl.Segment {
	var nixShell string
	nixShell, _ = os.LookupEnv("IN_NIX_SHELL")
	if nixShell == "" {
		return []pwl.Segment{}
	}
	return []pwl.Segment{{
		Name:       "nix-shell",
		Content:    "\uf313",
		Foreground: p.theme.NixShellFg,
		Background: p.theme.NixShellBg,
	}}
}
