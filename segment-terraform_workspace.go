package main

import (
	"os"

	pwl "github.com/julienlevasseur/powerline-go/powerline"
)

const wsFile = "./.terraform/environment"

func segmentTerraformWorkspace(p *powerline) []pwl.Segment {
	stat, err := os.Stat(wsFile)
	if err != nil {
		return []pwl.Segment{}
	}
	if stat.IsDir() {
		return []pwl.Segment{}
	}
	workspace, err := os.ReadFile(wsFile)
	if err != nil {
		return []pwl.Segment{}
	}
	return []pwl.Segment{{
		Name:       "terraform-workspace",
		Content:    string(workspace),
		Foreground: p.theme.TFWsFg,
		Background: p.theme.TFWsBg,
	}}
}
