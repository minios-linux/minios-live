# Executable and build scripts
EXECUTABLES := minios-live minios-cmd
BUILD_SCRIPTS := linux-live
BASH_COMPLETIONS := completions/minios-live completions/minios-cmd

# Directories
BIN_DIR := usr/bin
SHARE_DIR := usr/share
ETC_DIR := etc/minios-live
LOCALE_DIR := usr/share/locale
BASH_COMPLETIONS_DIR := usr/share/bash-completion/completions
MAN_DIR := usr/share/man

# Documentation and localization files
DOC_FILES := $(shell find docs -name "*.md")
MAN_FILES := $(patsubst docs/%.md, man/%.1, $(DOC_FILES))

PO_FILES := $(shell find po -name "*.po" -maxdepth 1)
MO_FILES := $(patsubst %.po,%.mo,$(PO_FILES))

# Build targets
ifeq ($(filter nodoc,$(DEB_BUILD_PROFILES) $(DEB_BUILD_OPTIONS)),)
build: man
endif
build: locale

# Man pages
man: $(MAN_FILES)
man/%.1: docs/%.md
	@mkdir -p $(@D)
	@echo "Generating man file for $<"
	pandoc -s -t man $< -o $@

# Localization
locale: $(MO_FILES)
%.mo: %.po
	@echo "Generating mo file for $<"
	msgfmt -o $@ $<
	chmod 644 $@

# Clean target
clean:
	rm -rf man $(MO_FILES)

# Install target
install: build
	install -d $(DESTDIR)/$(BIN_DIR) \
		$(DESTDIR)/$(SHARE_DIR) \
		$(DESTDIR)/$(ETC_DIR) \
		$(DESTDIR)/$(LOCALE_DIR) \
		$(DESTDIR)/$(BASH_COMPLETIONS_DIR)

	cp $(EXECUTABLES) $(DESTDIR)/$(BIN_DIR)
	cp -r $(BUILD_SCRIPTS) $(DESTDIR)/$(SHARE_DIR)/minios-live
	cp $(DESTDIR)/$(SHARE_DIR)/minios-live/general.conf $(DESTDIR)/$(ETC_DIR)
	cp $(DESTDIR)/$(SHARE_DIR)/minios-live/build.conf $(DESTDIR)/$(ETC_DIR)
	cp $(BASH_COMPLETIONS) $(DESTDIR)/$(BASH_COMPLETIONS_DIR)

	# Copy MO files
	for MO_FILE in $(MO_FILES); do \
		LOCALE=$$(basename $$MO_FILE .mo); \
		echo "Copying mo file $$MO_FILE to $(DESTDIR)/usr/share/locale/$$LOCALE/LC_MESSAGES/minios-live.mo"; \
		install -Dm644 "$$MO_FILE" "$(DESTDIR)/usr/share/locale/$$LOCALE/LC_MESSAGES/minios-live.mo"; \
	done

	# Copy man files
	find man -type f -name '*.1' | while read -r MAN_FILE; do \
		MAN_LANG_DIR=$$(dirname $$MAN_FILE | sed 's/^man//'); \
		MAN_BASENAME=$$(basename $$MAN_FILE); \
		install -d "$(DESTDIR)/$(MAN_DIR)/$$MAN_LANG_DIR/man1"; \
		echo "Copying man file $$MAN_FILE to $(DESTDIR)/$(MAN_DIR)/$$MAN_LANG_DIR/man1/$$MAN_BASENAME"; \
		install -Dm644 "$$MAN_FILE" "$(DESTDIR)/$(MAN_DIR)/$$MAN_LANG_DIR/man1/$$MAN_BASENAME"; \
	done
