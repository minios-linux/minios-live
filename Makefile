.PHONY: all prepare-source orig add-debian check-deps build-package lintian clean

PACKAGE   := minios-live
VERSION   := $(shell dpkg-parsechangelog --show-field Version | sed "s/-[^-]*$$//")
BUILD_DIR := build/$(PACKAGE)-$(VERSION)

all: check-deps build-package

prepare-source:
	@echo "Preparing source for $(PACKAGE) $(VERSION)..."
	@mkdir -p $(BUILD_DIR)
	@rm -rf $(BUILD_DIR)/*
	@cp -r completions docs linux-live po $(BUILD_DIR)/
	@cp LICENSE minios-cmd minios-live $(BUILD_DIR)/

orig: prepare-source
	@echo "Creating orig tarball..."
	@tar czf build/$(PACKAGE)_$(VERSION).orig.tar.gz -C build $(PACKAGE)-$(VERSION)

add-debian: orig
	@echo "Adding debian directory..."
	@cp -r debian $(BUILD_DIR)/

check-deps: add-debian
	@echo "Checking build dependencies..."
	@cd $(BUILD_DIR) && MISSING=$$(dpkg-checkbuilddeps 2>&1 | sed -n 's/^.*Unmet build dependencies: //p'); \
	if [ -n "$$MISSING" ]; then \
		echo "Missing build-deps: $$MISSING"; \
		echo "Installing..."; \
		sudo apt-get update && sudo apt-get install -y $$MISSING; \
	else \
		echo "All build-dependencies satisfied."; \
	fi

build-package: add-debian check-deps
	@echo "Building package..."
	@cd $(BUILD_DIR) && dpkg-buildpackage -us -uc

lintian:
	@echo "Running lintian..."
	@lintian --show-overrides build/$(PACKAGE)_*.changes

clean:
	@echo "Cleaning up..."
	@rm -rf build