.PHONY: all prepare-source orig add-debian check-deps build-package lintian clean

PACKAGE           := minios-live
VERSION           := $(shell dpkg-parsechangelog --show-field Version | sed "s/-[^-]*$$//")
BUILD_DIR         := build/$(PACKAGE)-$(VERSION)
SOURCE_DATE_EPOCH := $(shell dpkg-parsechangelog --show-field Timestamp)

all: build-package

check-deps:
	@echo "Checking build dependencies..."
	@if dpkg-checkbuilddeps; then \
		echo "All build-dependencies satisfied."; \
	else \
		echo "Install the missing build dependencies and run make again." >&2; \
		exit 1; \
	fi

prepare-source: check-deps
	@echo "Preparing source for $(PACKAGE) $(VERSION)..."
	@rm -rf $(BUILD_DIR)
	@mkdir -p $(BUILD_DIR)
	@cp -a completions docs linux-live manpages po $(BUILD_DIR)/
	@cp LICENSE README.md minios-cmd minios-live $(BUILD_DIR)/

orig: prepare-source
	@echo "Creating reproducible orig tarball..."
	@tar --sort=name \
		--mtime="@$(SOURCE_DATE_EPOCH)" \
		--owner=0 --group=0 --numeric-owner \
		-cf - -C build $(PACKAGE)-$(VERSION) | \
		gzip -n > build/$(PACKAGE)_$(VERSION).orig.tar.gz

add-debian: orig
	@echo "Adding debian directory..."
	@cp -a debian $(BUILD_DIR)/

build-package: add-debian
	@echo "Building package..."
	@cd $(BUILD_DIR) && dpkg-buildpackage -us -uc

lintian:
	@echo "Running lintian..."
	@lintian --show-overrides build/$(PACKAGE)_*.changes

clean:
	@echo "Cleaning package artifacts for $(PACKAGE) $(VERSION)..."
	@rm -rf $(BUILD_DIR)
	@rm -f build/$(PACKAGE)_$(VERSION)*
