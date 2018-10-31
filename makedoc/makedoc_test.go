package makedoc

import (
	"bytes"
	"testing"

	"github.com/stretchr/testify/assert"
)

func TestParse(t *testing.T) {
	testCases := []struct {
		name    string
		content string
		expect  []DocElement
	}{
		{
			name: "One target with comment",
			content: `
## Okay
okay:
	$(info yo)

bob:
	$(info hi bob)

## Something does this
##
## And then it does that
##
## And then this
something:
	$(info hi there)
			`,
			expect: []DocElement{
				{
					Target:           "okay",
					ShortDescription: "Okay",
				},
				{
					Target:           "something",
					ShortDescription: "Something does this",
					LongDescription:  "And then it does that\n\nAnd then this",
				},
			},
		},
	}
	for _, tc := range testCases {
		buf := bytes.NewBuffer([]byte(tc.content))
		got, err := Parse(buf)
		assert.Nil(t, err, tc.name)
		assert.Equal(t, tc.expect, got, tc.name)
	}
}

func TestLoad(t *testing.T) {
	testCases := []struct {
		name   string
		files  []string
		expect DocElements
	}{
		{
			name:  "Load all",
			files: []string{"../data/more.mk"},
			expect: DocElements{
				"test": {
					Target:           "test",
					ShortDescription: "Test your project",
					LongDescription:  "This target makes it possible to test your project",
				},
			},
		},
	}
	for _, tc := range testCases {
		got, err := Load(tc.files)
		assert.Nil(t, err, tc.name)
		assert.Equal(t, tc.expect, got, tc.name)
	}
}

func TestPretty(t *testing.T) {
	testCases := []struct {
		name    string
		element DocElement
		verbose bool
		expect  string
	}{
		{
			name: "Pretty",
			element: DocElement{
				Target:           "something",
				ShortDescription: "something else",
			},
			expect: "something                     something else\n",
		},
		{
			name: "Pretty verbose",
			element: DocElement{
				Target:           "something",
				ShortDescription: "something else",
				LongDescription:  "something more",
			},
			verbose: true,
			expect:  "something                     something else\nsomething more\n\n",
		},
	}
	for _, tc := range testCases {
		buf := bytes.NewBuffer(nil)
		err := Pretty(buf, tc.element, tc.verbose, false)
		assert.Nil(t, err, tc.name)
		assert.Equal(t, tc.expect, buf.String(), tc.name)
	}
}

func TestDefaultGoal(t *testing.T) {
	testCases := []struct {
		name    string
		content string
		expect  string
	}{
		{
			name: "no goal",
			content: `
test:
	$(info test)
`,
			expect: "",
		},
		{
			name: "goal",
			content: `
.DEFAULT_GOAL = test
test:
	$(info test)
`,
			expect: "test",
		},
	}
	for _, tc := range testCases {
		buf := bytes.NewBufferString(tc.content)
		got, err := DefaultGoal(buf)
		assert.Nil(t, err, tc.name)
		assert.Equal(t, tc.expect, got)
	}
}
