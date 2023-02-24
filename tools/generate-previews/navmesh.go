package main

import (
	"bufio"
	"fmt"
	"image"
	"image/color"
	"io"
	"math"
	"sort"
	"strings"

	"github.com/tdewolff/canvas"
	"github.com/tdewolff/canvas/renderers"
)

type Navmesh struct {
	Nodes map[int]*NavmeshNode
	Links []NavmeshLink

	MinZ, MaxZ float64 // Defines the interval of possible z axis values of the elements.

	SortedElements []NavmeshElement // List of sorted elements for drawing. Sorted by Z axis and some other stuff to make it deterministic.
}

// NewNavmeshFromReader parses a navmesh from the given reader and returns a Navmesh object.
func NewNavmeshFromReader(r io.Reader) (*Navmesh, error) {
	navmesh := &Navmesh{
		Nodes: map[int]*NavmeshNode{},
		MinZ:  math.Inf(1),
		MaxZ:  math.Inf(-1),
	}

	var lineNumber int
	scanner := bufio.NewScanner(r)
	for scanner.Scan() {
		line := scanner.Text()
		lineNumber++

		splitLine := strings.Split(line, ":")
		if len(splitLine) != 2 {
			return nil, fmt.Errorf("can't parse line %d into a key value pair: %q", lineNumber, line)
		}

		key, value := splitLine[0], splitLine[1]

		switch {
		case strings.ContainsRune(key, '-'):
			// This line defines a link.
			navmeshLink, err := NewNavmeshLinkFromKeyValuePair(key, value)
			if err != nil {
				return nil, fmt.Errorf("failed to parse link at line %d: %w", lineNumber, err)
			}
			navmesh.Links = append(navmesh.Links, navmeshLink)

		default:
			// This line defines a node.
			navmeshNode, err := NewNavmeshNodeFromKeyValuePair(key, value)
			if err != nil {
				return nil, fmt.Errorf("failed to parse node at line %d: %w", lineNumber, err)
			}
			navmesh.Nodes[navmeshNode.ID] = navmeshNode

			if navmesh.MinZ > navmeshNode.Z {
				navmesh.MinZ = navmeshNode.Z
			}
			if navmesh.MaxZ < navmeshNode.Z {
				navmesh.MaxZ = navmeshNode.Z
			}
		}
	}

	if err := scanner.Err(); err != nil {
		return nil, err
	}

	// Generate a list of sorted elements.
	for k := range navmesh.Nodes {
		navmesh.SortedElements = append(navmesh.SortedElements, navmesh.Nodes[k])
	}
	for i := range navmesh.Links {
		navmesh.SortedElements = append(navmesh.SortedElements, &navmesh.Links[i])
	}
	// Sort by ID first, to make the result deterministic.
	sort.Slice(navmesh.SortedElements, func(i, j int) bool {
		return navmesh.SortedElements[i].IDString() < navmesh.SortedElements[j].IDString()
	})
	// Sort bei drawing order.
	sort.Slice(navmesh.SortedElements, func(i, j int) bool {
		return navmesh.SortedElements[i].Order(navmesh) < navmesh.SortedElements[j].Order(navmesh)
	})

	return navmesh, nil
}

var navmeshOriginStyle = canvas.Style{
	FillColor:    canvas.Transparent,
	StrokeColor:  color.RGBA{255, 0, 0, 255},
	StrokeWidth:  1.0,
	StrokeCapper: canvas.ButtCap,
	StrokeJoiner: canvas.MiterJoin,
	DashOffset:   0.0,
	Dashes:       []float64{},
	FillRule:     canvas.NonZero,
}

// ProportionalHeight returns the proportional relative to the highest and lowest navmesh elements.
// A result of 0 means we are at the level of the lowest element.
// A result of 1 means we are at the level of the hightest element.
// Values are clamped between 0 and 1.
func (n *Navmesh) ProportionalHeight(z float64) float64 {
	prop := (z - n.MinZ) / (n.MaxZ - n.MinZ)

	return math.Min(math.Max(prop, 0), 1)
}

// Returns a color depending on the z value.
func (n *Navmesh) ProportionalHeightColor(z float64) color.RGBA {
	a := n.ProportionalHeight(z)
	b := 1 - a

	return color.RGBA{uint8(b * 255), 0, uint8(a * 255), 255}
}

func (n *Navmesh) RenderToFile(filename string, userScale float64) error {
	// Get rekt!
	rect := image.Rectangle{}
	for _, node := range n.Nodes {
		if rect.Empty() {
			rect = node.ImageRect()
		} else {
			rect = rect.Union(node.ImageRect())
		}
	}

	// Set up drawing context.
	const sourceScale = 19.05 // In mm / "source unit".
	totalScale := sourceScale * userScale
	c := canvas.New(float64(rect.Dx())*totalScale, float64(rect.Dy())*totalScale)
	ctx := canvas.NewContext(c)

	// Fill background.
	//ctx.FillColor = canvas.Black
	//ctx.DrawPath(0, 0, canvas.Rectangle(c.W, c.H))

	// Set up coordinate system.
	ctx.Scale(totalScale, totalScale)
	ctx.Translate(-float64(rect.Min.X), -float64(rect.Min.Y))

	// Draw origin and X and Y axes.
	ctx.Style = navmeshOriginStyle
	ctx.MoveTo(0, 0)
	ctx.LineTo(20, 0)
	ctx.Stroke()
	ctx.SetStrokeColor(color.RGBA{0, 255, 0, 255})
	ctx.MoveTo(0, 0)
	ctx.LineTo(0, 20)
	ctx.Stroke()

	// Draw elements in order.
	for _, element := range n.SortedElements {
		element.Draw(n, ctx)
	}

	// Render out into file.
	return renderers.Write(filename, c)
}
