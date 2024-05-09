package main

import (
	"strings"
	"time"

	pwl "github.com/julienlevasseur/powerline-go/powerline"
)

func segmentTime(p *powerline) []pwl.Segment {
	return []pwl.Segment{{
		Name:       "time",
		Content:    time.Now().Format(strings.TrimSpace(p.cfg.Time)),
		Foreground: p.theme.TimeFg,
		Background: p.theme.TimeBg,
	}}
}
