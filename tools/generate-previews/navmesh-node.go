package main

import (
	"fmt"
	"image"
	"image/color"
	"strconv"
	"strings"

	"github.com/tdewolff/canvas"
)

type NavmeshNode struct {
	ID int // The ID of the node.

	X, Y, Z float64          // The origin of the node.
	Area    *NavmeshNodeArea // The area of the node, if there is any.
}

func NewNavmeshNodeFromKeyValuePair(key, value string) (*NavmeshNode, error) {
	node := &NavmeshNode{}

	id, err := strconv.Atoi(key)
	if err != nil {
		return node, fmt.Errorf("invalid key %q", key)
	}
	node.ID = id

	valueEntries := strings.Split(value, ",")
	for _, valueEntry := range valueEntries {
		if valueEntry == "" {
			continue
		}

		valueEntrySplit := strings.Split(valueEntry, "=")
		if len(valueEntrySplit) != 2 {
			return node, fmt.Errorf("can't parse parameter of node %d", node.ID)
		}

		valueEntryKey, valueEntryValue := valueEntrySplit[0], valueEntrySplit[1]
		switch valueEntryKey {
		case "X":
			if node.X, err = strconv.ParseFloat(valueEntryValue, 64); err != nil {
				return node, fmt.Errorf("failed to parse %q value: %w", valueEntryKey, err)
			}
		case "Y":
			if node.Y, err = strconv.ParseFloat(valueEntryValue, 64); err != nil {
				return node, fmt.Errorf("failed to parse %q value: %w", valueEntryKey, err)
			}
		case "Z":
			if node.Z, err = strconv.ParseFloat(valueEntryValue, 64); err != nil {
				return node, fmt.Errorf("failed to parse %q value: %w", valueEntryKey, err)
			}
		case "AreaXMin":
			if node.Area == nil {
				node.Area = &NavmeshNodeArea{}
			}
			if float, err := strconv.ParseFloat(valueEntryValue, 64); err == nil {
				node.Area.AreaXMin = float
			} else {
				return node, fmt.Errorf("failed to parse %q value: %w", valueEntryKey, err)
			}
		case "AreaXMax":
			if node.Area == nil {
				node.Area = &NavmeshNodeArea{}
			}
			if float, err := strconv.ParseFloat(valueEntryValue, 64); err == nil {
				node.Area.AreaXMax = float
			} else {
				return node, fmt.Errorf("failed to parse %q value: %w", valueEntryKey, err)
			}
		case "AreaYMin":
			if node.Area == nil {
				node.Area = &NavmeshNodeArea{}
			}
			if float, err := strconv.ParseFloat(valueEntryValue, 64); err == nil {
				node.Area.AreaYMin = float
			} else {
				return node, fmt.Errorf("failed to parse %q value: %w", valueEntryKey, err)
			}
		case "AreaYMax":
			if node.Area == nil {
				node.Area = &NavmeshNodeArea{}
			}
			if float, err := strconv.ParseFloat(valueEntryValue, 64); err == nil {
				node.Area.AreaYMax = float
			} else {
				return node, fmt.Errorf("failed to parse %q value: %w", valueEntryKey, err)
			}
		}
	}

	// Store Z height in area, if there is one.
	if node.Area != nil {
		node.Area.Z = node.Z
	}

	return node, nil
}

// ImageRect returns the rectangle that this element occupies in the final unscaled image.
// This rectangle contains the area and the origin with a slight padding.
func (n *NavmeshNode) ImageRect() image.Rectangle {
	rect := image.Rect(int(n.X), int(n.Y), int(n.X), int(n.Y)).Inset(-5)

	if n.Area != nil {
		rect = rect.Union(n.Area.ImageRect())
	}

	return rect
}

func (n *NavmeshNode) IDString() string {
	return strconv.Itoa(n.ID)
}

var navmeshNodeCenterStyle = canvas.Style{
	FillColor:    canvas.Transparent, // Color is based on proportional height value.
	StrokeColor:  canvas.Transparent,
	StrokeWidth:  1.0,
	StrokeCapper: canvas.ButtCap,
	StrokeJoiner: canvas.MiterJoin,
	DashOffset:   0.0,
	Dashes:       []float64{},
	FillRule:     canvas.NonZero,
}

// Draw outputs the element to the given canvas context.
func (n *NavmeshNode) Draw(navmesh *Navmesh, ctx *canvas.Context) {
	if n.Area != nil {
		n.Area.Draw(navmesh, ctx)
	}

	ctx.Style = navmeshNodeCenterStyle
	col := navmesh.ProportionalHeightColor(n.Z)
	col = color.RGBA{col.R / 4, col.G / 4, col.B / 4, col.A / 4}
	ctx.FillColor = col
	circle := canvas.Circle(5)
	ctx.DrawPath(n.X, n.Y, circle)
}

// Returns a value that can be used in a less function for sorting.
func (n *NavmeshNode) Order(navmesh *Navmesh) float64 {
	return n.Z
}
