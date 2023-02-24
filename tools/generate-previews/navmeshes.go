package main

import (
	"fmt"
	"io/fs"
	"os"
	"path/filepath"
	"strings"
)

func RenderNavmeshes(srcDir, dstDir string, userScale float64) error {
	err := filepath.WalkDir(srcDir, func(path string, d fs.DirEntry, err error) error {
		if err != nil {
			return err
		}

		// Ignore directories.
		if d.IsDir() {
			return nil
		}
		// Ignore non txt files.
		if filepath.Ext(d.Name()) != ".txt" {
			return nil
		}
		// Ignore map parameter files.
		if strings.HasSuffix(d.Name(), ".params.txt") {
			return nil
		}

		// Open and parse navmesh.
		file, err := os.Open(path)
		if err != nil {
			return err
		}
		defer file.Close()

		navmesh, err := NewNavmeshFromReader(file)
		if err != nil {
			return fmt.Errorf("failed to read navmesh from %q: %w", d.Name(), err)
		}

		// Render and save image.
		dstPath := filepath.Join(dstDir, filepath.Base(d.Name()))
		dstPath = strings.TrimSuffix(dstPath, filepath.Ext(dstPath)) + ".svg"

		if err := navmesh.RenderToFile(dstPath, userScale); err != nil {
			return fmt.Errorf("render error: %w", err)
		}

		return nil
	})
	if err != nil {
		return err
	}

	return nil
}
