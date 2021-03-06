# Beta Versioning
BETA_VERSION := $(shell git tag -l --sort=creatordate | grep "^v[0-9]*.[0-9]*.[0-9]*-beta$$" | tail -1)
BETA_MAJOR_VERSION := $(word 1, $(subst ., ,$(BETA_VERSION)))
BETA_MINOR_VERSION := $(word 2, $(subst ., ,$(BETA_VERSION)))
BETA_PATCH_VERSION := $(word 3, $(subst ., ,$(BETA_VERSION)))
BETA_NEXT_VERSION ?= $(BETA_MAJOR_VERSION).$(BETA_MINOR_VERSION).$(shell echo $(BETA_PATCH_VERSION)+1|bc)-beta

# Normal Versioning
VERSION := $(shell git tag -l --sort=creatordate | grep "^v[0-9]*.[0-9]*.[0-9]*$$" | tail -1)
MAJOR_VERSION := $(word 1, $(subst ., ,$(VERSION)))
MINOR_VERSION := $(word 2, $(subst ., ,$(VERSION)))
PATCH_VERSION := $(word 3, $(subst ., ,$(VERSION)))
NEXT_VERSION ?= $(MAJOR_VERSION).$(MINOR_VERSION).$(shell echo $(PATCH_VERSION)+1|bc)
BUILD_DIR = .release
GOLDFLAGS = "-X main.version=$(NEXT_VERSION)"

CLI_FILES = $(shell find cli linter assertion -name \*.go)

default: all

devdeps:
	@echo "=== dev dependencies ==="
	@go get "github.com/gobuffalo/packr/..."
	@go get -u golang.org/x/lint/golint
	@go get "github.com/fzipp/gocyclo"

deps:
	@echo "=== dependencies ==="
	go mod download

gen:
	@echo "=== generating ==="
	@go get "github.com/gobuffalo/packr/..."
	@go generate ./...

lint: gen
	@echo "=== linting ==="
	@go vet ./...
	@go get -u golang.org/x/lint/golint
	@golint $(go list ./... | grep -v /vendor/)

cyclo:
	@echo "=== cyclomatic complexity ==="
	@go get "github.com/fzipp/gocyclo"
	@gocyclo -over 15 assertion linter cli || echo "WARNING: cyclomatic complexity is high"

test: lint cyclo
	@echo "=== testing ==="
	@go test -v ./...

testtf: lint cyclo
	@echo "=== testing Terraform Built In Rules ==="
	@go test -v ./cli/... -run TestTerraformBuiltInRules

testtf12: lint cyclo
	@echo "=== testing Terraform 12 Built In Rules ==="
	@go test -v ./cli/... -run TestTerraform12BuiltInRules

beta-bumpversion:
	@echo "=== promoting $(BETA_NEXT_VERSION) ==="
	@git tag -a -m "$(BETA_VERSION) -> $(BETA_NEXT_VERSION)" $(BETA_NEXT_VERSION)
	@git push --follow-tags origin

bumpversion:
	@echo "=== promoting $(NEXT_VERSION) ==="
	@git tag -a -m "$(VERSION) -> $(NEXT_VERSION)" $(NEXT_VERSION)
	@git push --follow-tags origin

$(BUILD_DIR)/config-lint: $(CLI_FILES)
	@echo "=== building config-lint - $@ ==="
	mkdir -p $(BUILD_DIR)
	GOOS=$(GOOS) GOARCH=$(GOARCH) go build -ldflags=$(GOLDFLAGS) -o $(BUILD_DIR)/config-lint cli/*.go

build: gen $(BUILD_DIR)/config-lint

all: clean deps test build
dev: deps devdeps

clean:
	@echo "=== cleaning ==="
	rm -rf $(BUILD_DIR)
	rm -rf vendor
	rm -f cli/*-packr.go

cover-assertion:
	@cd assertion && go test -coverprofile=coverage.out && go tool cover -html=coverage.out

cover-linter:
	@cd linter && go test -coverprofile=coverage.out && go tool cover -html=coverage.out

cover-cli:
	@cd cli && go test -coverprofile=coverage.out && go tool cover -html=coverage.out

