# makedoc

**Note**: The parser component is stolen from: https://github.com/tj/mmake, and modified to work better with more complex makefiles

Simple `Makefile` documentation reader and writer. You can document a target by preceding it with a section of: `##`

```makefile
## This is the basic help
##
## This is the verbose help and it
## can span as many lines as you want.
##
## The basic and verbose help need to be separated by an empty ##
```

If you specify a `.DEFAULT_GOAL = [yourgoal]` it will be highlighted

```makefile
.DEFAULT_GOAL = help

silent:
	$(info no such target)

## Print out help
##
## Display a short description for all targets
help:
	@echo "Available targets:\n"
	@go run ../main.go -pretty $(MAKEFILE_LIST)

## Print help verbose
##
## Dumps the help including long descriptions
help-verbose:
	@echo "Available targets:\n"
	@go run ../main.go -pretty -verbose $(MAKEFILE_LIST)

## Display an extensive description for a specific target
##
## Display more extensive help for a given target, e.g.,
## `make help-test`
help-%:
	@go run ../main.go -pretty -verbose -target $(*) $(MAKEFILE_LIST)

include more.mk
```
You can run the following command:
```bash
go run main.go -pretty -verbose data/Makefile
```
To get pretty output that is easily digested by a user:
```bash
help                 Print out help
Display a short description for all targets

help-%               Display an extensive description for a specific target
Display more extensive help for a given target, e.g.,
`make help-test`

help-verbose         Print help verbose
Dumps the help including long descriptions
```