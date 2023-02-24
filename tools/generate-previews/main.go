package main

import (
	"flag"
	"log"
	"os"
	"path"
)

var flagSrc = flag.String("src", path.Join(".", "..", "..", "data", "d3bot", "navmesh", "map"), "The source where all navmeshes are read from.")
var flagDst = flag.String("dst", path.Join(".", "..", "..", "media", "navmesh-previews"), "The destination where all the navmesh preview files are stored.")

var flagScale = flag.Float64("scale", 0.01, "Scale of the image. Unit depends on the output format used. Raster images are based on 1 pixel / mm. Vector images are output in mm directly.")

// TODO: Add flag for output format

func main() {

	flag.Parse()

	os.MkdirAll(*flagDst, os.ModePerm)

	if err := RenderNavmeshes(*flagSrc, *flagDst, *flagScale); err != nil {
		log.Panic(err)
	}

}
