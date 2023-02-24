package main

import (
	"fmt"
	"image/color"
	"strconv"
	"strings"

	"github.com/tdewolff/canvas"
)

type NavmeshLink struct {
	From, To int // The links that are connected by this link by their ID.
}

func NewNavmeshLinkFromKeyValuePair(key, value string) (NavmeshLink, error) {
	link := NavmeshLink{}

	keySplit := strings.Split(key, "-")
	if len(keySplit) != 2 {
		return link, fmt.Errorf("can't parse key of link")
	}

	from, err := strconv.Atoi(keySplit[0])
	if err != nil {
		return link, fmt.Errorf("invalid link from value %q", keySplit[0])
	}
	to, err := strconv.Atoi(keySplit[1])
	if err != nil {
		return link, fmt.Errorf("invalid link to value %q", keySplit[1])
	}
	link.From, link.To = from, to

	valueEntries := strings.Split(value, ",")
	for _, valueEntry := range valueEntries {
		if valueEntry == "" {
			continue
		}

		valueEntrySplit := strings.Split(valueEntry, "=")
		if len(valueEntrySplit) != 2 {
			return link, fmt.Errorf("can't parse parameter of link %s", key)
		}

		/*valueEntryKey, valueEntryValue := valueEntrySplit[0], valueEntrySplit[1]
		switch valueEntryKey {
		case "SomeFloatValue":
		if float, err := strconv.ParseFloat(valueEntryValue, 64); err == nil {
			link.SomeFloatValue = &float
		} else {
			return link, fmt.Errorf("failed to parse %q value: %w", valueEntryKey, err)
		}
		}*/
	}

	return link, nil
}

func (n *NavmeshLink) IDString() string {
	return fmt.Sprintf("%d-%d", n.From, n.To)
}

var navmeshLinkStyle = canvas.Style{
	FillColor:    canvas.Transparent,
	StrokeColor:  canvas.Transparent, // Color is based on proportional height value.
	StrokeWidth:  1.0,
	StrokeCapper: canvas.ButtCap,
	StrokeJoiner: canvas.MiterJoin,
	DashOffset:   0.0,
	Dashes:       []float64{},
	FillRule:     canvas.NonZero,
}

// Draw outputs the element to the given canvas context.
func (n *NavmeshLink) Draw(navmesh *Navmesh, ctx *canvas.Context) {
	node1, ok := navmesh.Nodes[n.From]
	if !ok {
		return
	}
	node2, ok := navmesh.Nodes[n.To]
	if !ok {
		return
	}

	ctx.Style = navmeshLinkStyle
	col := navmesh.ProportionalHeightColor((node1.Z + node2.Z) / 2)
	col = color.RGBA{col.R / 4, col.G / 4, col.B / 4, col.A / 4}
	ctx.StrokeColor = col
	ctx.MoveTo(node1.X, node1.Y)
	ctx.LineTo(node2.X, node2.Y)
	ctx.Stroke()
}

// Returns a value that can be used in a less function for sorting.
func (n *NavmeshLink) Order(navmesh *Navmesh) float64 {
	node1, ok := navmesh.Nodes[n.From]
	if !ok {
		return 0
	}
	node2, ok := navmesh.Nodes[n.To]
	if !ok {
		return 0
	}

	// Just be between node1 and node2, but slightly above if both are at the same height.
	return (node1.Order(navmesh)+node2.Order(navmesh))/2 + 0.001
}
