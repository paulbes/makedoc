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