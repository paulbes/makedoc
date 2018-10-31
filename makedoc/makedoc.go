package makedoc

import (
	"bytes"
	"fmt"
	"io"
	"io/ioutil"
	"os"
	"regexp"

	"github.com/fatih/color"
	"github.com/paulbes/makedoc/parser"
)

// DocElement represents a single target
// and its corresponding documentation
type DocElement struct {
	Target           string
	ShortDescription string
	LongDescription  string
	IsDefault        bool
}

// DocElements contains all targets
// and their corresponding documentation
type DocElements map[string]DocElement

// Load the documentation of the provided makefiles
func Load(files []string) (DocElements, error) {
	all := DocElements{}
	for _, f := range files {
		var buf bytes.Buffer
		file, err := os.Open(f)
		if err != nil {
			return nil, err
		}
		tee := io.TeeReader(file, &buf)
		defaultGoal, err := DefaultGoal(tee)
		if err != nil {
			return nil, err
		}
		docs, err := Parse(&buf)
		if err != nil {
			return nil, err
		}
		for _, d := range docs {
			if d.Target == defaultGoal {
				d.IsDefault = true
			}
			all[d.Target] = d
		}
	}
	return all, nil
}

// Parse a provided makefile and return the individual
// document elements
func Parse(reader io.Reader) ([]DocElement, error) {
	p := parser.New()
	nodes, err := p.Parse(reader)
	if err != nil {
		return nil, err
	}

	re := regexp.MustCompile(`[\n]{2}`)

	var docs []DocElement
	for _, n := range nodes {
		switch t := n.(type) {
		case parser.Comment:
			descriptions := re.Split(t.Value, 2)
			if len(descriptions) == 1 {
				descriptions = append(descriptions, "")
			}
			docs = append(docs, DocElement{
				Target:           t.Target,
				ShortDescription: descriptions[0],
				LongDescription:  descriptions[1],
			})
		}
	}

	return docs, nil
}

// DefaultGoal attempts to find the default goal within a provided file
func DefaultGoal(reader io.Reader) (string, error) {
	re := regexp.MustCompile(`\.DEFAULT_GOAL\s*[?=:]{1,2}\s*(?P<target>.*)`)
	c, err := ioutil.ReadAll(reader)
	if err != nil {
		return "", err
	}
	found := re.FindStringSubmatch(string(c))
	if len(found) > 0 {
		for i, name := range re.SubexpNames() {
			if name == "target" {
				return found[i], nil
			}
		}
	}
	return "", nil
}

// Pretty adds color to the output
func Pretty(output io.Writer, d DocElement, verbose, colorize bool) error {
	if !colorize {
		color.NoColor = true
	}
	t := color.GreenString(d.Target)
	if d.IsDefault {
		t = color.BlueString(d.Target)
	}
	out := fmt.Sprintf("%-30s%s\n", t, color.CyanString(d.ShortDescription))
	if verbose && len(d.LongDescription) > 0 {
		out = fmt.Sprintf("%s%s\n\n", out, d.LongDescription)
	}
	_, err := output.Write([]byte(out))
	return err
}
