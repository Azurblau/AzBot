package main

import (
	"image"
	"image/color"
	"math"

	"github.com/tdewolff/canvas"
)

type NavmeshNodeArea struct {
	AreaXMin, AreaXMax, AreaYMin, AreaYMax float64 // The boundaries of the navmesh area.

	Z float64
}

// ImageRect returns the rectangle that this element occupies in the final unscaled image.
func (a *NavmeshNodeArea) ImageRect() image.Rectangle {
	rect := image.Rect(int(a.AreaXMin), int(a.AreaYMin), int(math.Ceil(a.AreaXMax)), int(math.Ceil(a.AreaYMax)))

	return rect.Inset(-3)
}

var navmeshNodeAreaStyle = canvas.Style{
	FillColor:    canvas.Transparent, // Color is based on proportional height value.
	StrokeColor:  canvas.Transparent, // Color is based on proportional height value.
	StrokeWidth:  1.0,
	StrokeCapper: canvas.ButtCap,
	StrokeJoiner: canvas.MiterJoin,
	DashOffset:   0.0,
	Dashes:       []float64{},
	FillRule:     canvas.NonZero,
}

// Draw outputs the element to the given canvas context.
func (n *NavmeshNodeArea) Draw(navmesh *Navmesh, ctx *canvas.Context) {
	ctx.Style = navmeshNodeAreaStyle
	col := navmesh.ProportionalHeightColor(n.Z)
	col = color.RGBA{col.R / 4, col.G / 4, col.B / 4, col.A / 4}
	ctx.FillColor = col
	ctx.StrokeColor = col
	ctx.DrawPath(n.AreaXMin, n.AreaYMin, canvas.Rectangle(n.AreaXMax-n.AreaXMin, n.AreaYMax-n.AreaYMin))
}
