package main

import (
	"flag"
	"log"
	"os"
	"sort"
	"text/tabwriter"

	"github.com/paulbes/makedoc/makedoc"
)

var targetVar string
var verboseVar bool
var colorVar bool

func init() {
	flag.StringVar(&targetVar, "target", "", "only show documentation for given target")
	flag.BoolVar(&verboseVar, "verbose", false, "show verbose output")
	flag.BoolVar(&colorVar, "pretty", false, "make the output pretty")
	flag.Parse()
}

func fail(msg string, args ...interface{}) {
	logErr := log.New(os.Stderr, "", 0)
	logErr.Printf(msg, args...)
	os.Exit(1)
}

func main() {
	files := flag.Args()
	if len(files) == 0 {
		fail("no makefiles provided for parsing")
	}

	docs, err := makedoc.Load(files)
	if err != nil {
		fail("failed to load makefiles: %s", err)
	}

	var targets []string
	if len(targetVar) > 0 {
		if _, hasKey := docs[targetVar]; !hasKey {
			fail("target: %s, doesn't exist", targetVar)
		}
		targets = append(targets, targetVar)
	} else {
		for t := range docs {
			targets = append(targets, t)
		}
	}
	sort.Strings(targets)

	w := new(tabwriter.Writer)
	w.Init(os.Stdout, 0, 8, 2, '\t', tabwriter.AlignRight)
	for _, t := range targets {
		err = makedoc.Pretty(os.Stdout, docs[t], verboseVar, colorVar)
		if err != nil {
			fail("failed to format help: %s", err)
		}
	}
	err = w.Flush()
	if err != nil {
		fail("failed to flush help: %s", err)
	}
}
