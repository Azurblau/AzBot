package main

import "github.com/tdewolff/canvas"

type NavmeshElement interface {
	Draw(navmesh *Navmesh, ctx *canvas.Context) // Draw outputs the element to the given canvas context.
	Order(navmesh *Navmesh) float64             // Returns a value that can be used in a less function for sorting.
	IDString() string                           // Returns the element ID as a string.
}
