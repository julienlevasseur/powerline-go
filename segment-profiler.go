package main

import (
	"os"

	pwl "github.com/julienlevasseur/powerline-go/powerline"
)

func segmentProfiler(p *powerline) []pwl.Segment {
	profileName := os.Getenv("profile_name")
	if profileName == "" {
		return []pwl.Segment{}
	}

	return []pwl.Segment{{
		Name:       "profiler",
		Content:    string(profileName),
		Foreground: p.theme.ProfilerFg,
		Background: p.theme.ProfilerBg,
	}}
}
