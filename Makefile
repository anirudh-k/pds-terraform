.PHONY: fmt validate check

fmt:
	terraform fmt -recursive

validate:
	terraform validate

check: fmt validate
