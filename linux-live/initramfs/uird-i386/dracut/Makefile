-include dracut-version.sh

DRACUT_MAIN_VERSION ?= $(shell env GIT_CEILING_DIRECTORIES=$(CWD)/.. git describe --abbrev=0 --tags --always 2>/dev/null || :)
ifeq ($(DRACUT_MAIN_VERSION),)
DRACUT_MAIN_VERSION = $(DRACUT_VERSION)
endif
DRACUT_FULL_VERSION ?= $(shell env GIT_CEILING_DIRECTORIES=$(CWD)/.. git describe --tags --always 2>/dev/null || :)
ifeq ($(DRACUT_FULL_VERSION),)
DRACUT_FULL_VERSION = $(DRACUT_VERSION)
endif

-include Makefile.inc

prefix ?= /usr
libdir ?= ${prefix}/lib
datadir ?= ${prefix}/share
pkglibdir ?= ${libdir}/dracut
sysconfdir ?= ${prefix}/etc
bindir ?= ${prefix}/bin
mandir ?= ${prefix}/share/man
CFLAGS ?= -O2 -g -Wall
CFLAGS += -std=gnu99 -D_FILE_OFFSET_BITS=64 -Wformat -Werror=format-security -Wp,-D_FORTIFY_SOURCE=2 $(KMOD_CFLAGS)
bashcompletiondir ?= ${datadir}/bash-completion/completions
pkgconfigdatadir ?= $(datadir)/pkgconfig

man1pages = lsinitrd.1

man5pages = dracut.conf.5

man7pages = dracut.cmdline.7 \
            dracut.bootup.7 \
            dracut.modules.7

man8pages = dracut.8 \
            dracut-catimages.8 \
            mkinitrd.8 \
            mkinitrd-suse.8 \
            modules.d/98dracut-systemd/dracut-cmdline.service.8 \
            modules.d/98dracut-systemd/dracut-initqueue.service.8 \
            modules.d/98dracut-systemd/dracut-mount.service.8 \
            modules.d/98dracut-systemd/dracut-shutdown.service.8 \
            modules.d/98dracut-systemd/dracut-pre-mount.service.8 \
            modules.d/98dracut-systemd/dracut-pre-pivot.service.8 \
            modules.d/98dracut-systemd/dracut-pre-trigger.service.8 \
            modules.d/98dracut-systemd/dracut-pre-udev.service.8

manpages = $(man1pages) $(man5pages) $(man7pages) $(man8pages)

.PHONY: install clean archive rpm srpm testimage test all check AUTHORS doc dracut-version.sh

all: dracut-version.sh dracut.pc dracut-install skipcpio/skipcpio

DRACUT_INSTALL_OBJECTS = \
        install/dracut-install.o \
        install/hashmap.o\
        install/log.o \
        install/strv.o \
        install/util.o

# deps generated with gcc -MM
install/dracut-install.o: install/dracut-install.c install/log.h install/macro.h \
	install/hashmap.h install/util.h
install/hashmap.o: install/hashmap.c install/util.h install/macro.h install/log.h \
	install/hashmap.h
install/log.o: install/log.c install/log.h install/macro.h install/util.h
install/util.o: install/util.c install/util.h install/macro.h install/log.h
install/strv.o: install/strv.c install/strv.h install/util.h install/macro.h install/log.h

install/dracut-install: $(DRACUT_INSTALL_OBJECTS)
	$(CC) $(LDFLAGS) -o $@ $(DRACUT_INSTALL_OBJECTS) $(LDLIBS) $(FTS_LIBS) $(KMOD_LIBS)

logtee: logtee.c
	$(CC) $(LDFLAGS) -o $@ $<

dracut-install: install/dracut-install
	ln -fs $< $@

SKIPCPIO_OBJECTS= \
	skipcpio/skipcpio.o

skipcpio/skipcpio.o: skipcpio/skipcpio.c
skipcpio/skipcpio: skipcpio/skipcpio.o

indent:
	indent -i8 -nut -br -linux -l120 install/dracut-install.c
	indent -i8 -nut -br -linux -l120 skipcpio/skipcpio.c

doc: $(manpages) dracut.html

ifneq ($(enable_documentation),no)
all: doc
endif

%: %.xml
	@rm -f -- "$@"
	xsltproc -o "$@" -nonet http://docbook.sourceforge.net/release/xsl/current/manpages/docbook.xsl $<

%.xml: %.asc
	@rm -f -- "$@"
	asciidoc -a "version=$(DRACUT_FULL_VERSION)" -d manpage -b docbook -o "$@" $<

dracut.8: dracut.usage.asc dracut.8.asc

dracut.html: dracut.asc $(manpages) dracut.css dracut.usage.asc
	@rm -f -- dracut.xml
	asciidoc -a "mainversion=$(DRACUT_MAIN_VERSION)" \
		-a "version=$(DRACUT_FULL_VERSION)" \
		-a numbered \
		-d book -b docbook -o dracut.xml dracut.asc
	@rm -f -- dracut.html
	xsltproc -o dracut.html --xinclude -nonet \
		--stringparam custom.css.source dracut.css \
		--stringparam generate.css.header 1 \
		http://docbook.sourceforge.net/release/xsl/current/xhtml/docbook.xsl dracut.xml
	@rm -f -- dracut.xml

dracut.pc: Makefile.inc Makefile
	@echo "Name: dracut" > dracut.pc
	@echo "Description: dracut" >> dracut.pc
	@echo "Version: $(DRACUT_FULL_VERSION)" >> dracut.pc
	@echo "dracutdir=$(pkglibdir)" >> dracut.pc
	@echo "dracutmodulesdir=$(pkglibdir)/modules.d" >> dracut.pc
	@echo "dracutconfdir=$(pkglibdir)/dracut.conf.d" >> dracut.pc

install: all
	mkdir -p $(DESTDIR)$(pkglibdir)
	mkdir -p $(DESTDIR)$(bindir)
	mkdir -p $(DESTDIR)$(sysconfdir)
	mkdir -p $(DESTDIR)$(pkglibdir)/modules.d
	mkdir -p $(DESTDIR)$(mandir)/man1 $(DESTDIR)$(mandir)/man5 $(DESTDIR)$(mandir)/man7 $(DESTDIR)$(mandir)/man8
	install -m 0755 dracut.sh $(DESTDIR)$(bindir)/dracut
	install -m 0755 dracut-catimages.sh $(DESTDIR)$(bindir)/dracut-catimages
	install -m 0755 mkinitrd-dracut.sh $(DESTDIR)$(bindir)/mkinitrd
	install -m 0755 lsinitrd.sh $(DESTDIR)$(bindir)/lsinitrd
	install -m 0644 dracut.conf $(DESTDIR)$(sysconfdir)/dracut.conf
	mkdir -p $(DESTDIR)$(sysconfdir)/dracut.conf.d
	mkdir -p $(DESTDIR)$(pkglibdir)/dracut.conf.d
	install -m 0755 dracut-init.sh $(DESTDIR)$(pkglibdir)/dracut-init.sh
	install -m 0755 dracut-functions.sh $(DESTDIR)$(pkglibdir)/dracut-functions.sh
	install -m 0755 dracut-version.sh $(DESTDIR)$(pkglibdir)/dracut-version.sh
	ln -fs dracut-functions.sh $(DESTDIR)$(pkglibdir)/dracut-functions
	install -m 0755 dracut-logger.sh $(DESTDIR)$(pkglibdir)/dracut-logger.sh
	install -m 0755 dracut-initramfs-restore.sh $(DESTDIR)$(pkglibdir)/dracut-initramfs-restore
	cp -arx modules.d $(DESTDIR)$(pkglibdir)
ifneq ($(enable_documentation),no)
	for i in $(man1pages); do install -m 0644 $$i $(DESTDIR)$(mandir)/man1/$${i##*/}; done
	for i in $(man5pages); do install -m 0644 $$i $(DESTDIR)$(mandir)/man5/$${i##*/}; done
	for i in $(man7pages); do install -m 0644 $$i $(DESTDIR)$(mandir)/man7/$${i##*/}; done
	for i in $(man8pages); do install -m 0644 $$i $(DESTDIR)$(mandir)/man8/$${i##*/}; done
	ln -fs dracut.cmdline.7 $(DESTDIR)$(mandir)/man7/dracut.kernel.7
endif
	if [ -n "$(systemdsystemunitdir)" ]; then \
		mkdir -p $(DESTDIR)$(systemdsystemunitdir); \
		ln -srf $(DESTDIR)$(pkglibdir)/modules.d/98dracut-systemd/dracut-shutdown.service $(DESTDIR)$(systemdsystemunitdir)/dracut-shutdown.service; \
		mkdir -p $(DESTDIR)$(systemdsystemunitdir)/sysinit.target.wants; \
		ln -s ../dracut-shutdown.service \
		$(DESTDIR)$(systemdsystemunitdir)/sysinit.target.wants/dracut-shutdown.service; \
		mkdir -p $(DESTDIR)$(systemdsystemunitdir)/initrd.target.wants; \
		for i in \
		    dracut-cmdline.service \
		    dracut-initqueue.service \
		    dracut-mount.service \
		    dracut-pre-mount.service \
		    dracut-pre-pivot.service \
		    dracut-pre-trigger.service \
		    dracut-pre-udev.service \
		    ; do \
			ln -srf $(DESTDIR)$(pkglibdir)/modules.d/98dracut-systemd/$$i $(DESTDIR)$(systemdsystemunitdir); \
			ln -s ../$$i \
			$(DESTDIR)$(systemdsystemunitdir)/initrd.target.wants/$$i; \
		done \
	fi
	if [ -f install/dracut-install ]; then \
		install -m 0755 install/dracut-install $(DESTDIR)$(pkglibdir)/dracut-install; \
	fi
	if [ -f skipcpio/skipcpio ]; then \
		install -m 0755 skipcpio/skipcpio $(DESTDIR)$(pkglibdir)/skipcpio; \
	fi
	mkdir -p $(DESTDIR)${prefix}/lib/kernel/install.d
	install -m 0755 50-dracut.install $(DESTDIR)${prefix}/lib/kernel/install.d/50-dracut.install
	install -m 0755 51-dracut-rescue.install $(DESTDIR)${prefix}/lib/kernel/install.d/51-dracut-rescue.install
	mkdir -p $(DESTDIR)${bashcompletiondir}
	install -m 0644 dracut-bash-completion.sh $(DESTDIR)${bashcompletiondir}/dracut
	install -m 0644 lsinitrd-bash-completion.sh $(DESTDIR)${bashcompletiondir}/lsinitrd
	mkdir -p $(DESTDIR)${pkgconfigdatadir}
	install -m 0644 dracut.pc $(DESTDIR)${pkgconfigdatadir}/dracut.pc

dracut-version.sh:
	@rm -f dracut-version.sh
	@echo "DRACUT_VERSION=$(DRACUT_FULL_VERSION)" > dracut-version.sh

clean:
	$(RM) *~
	$(RM) */*~
	$(RM) */*/*~
	$(RM) $(manpages:%=%.xml) dracut.xml
	$(RM) test-*.img
	$(RM) dracut-*.rpm dracut-*.tar.bz2 dracut-*.tar.xz
	$(RM) dracut-version.sh
	$(RM) dracut-install install/dracut-install $(DRACUT_INSTALL_OBJECTS)
	$(RM) skipcpio/skipcpio $(SKIPCPIO_OBJECTS)
	$(RM) $(manpages) dracut.html
	$(MAKE) -C test clean

dist: dracut-$(DRACUT_MAIN_VERSION).tar.xz

dracut-$(DRACUT_MAIN_VERSION).tar.xz: doc syncheck
	@echo "DRACUT_VERSION=$(DRACUT_MAIN_VERSION)" > dracut-version.sh
	git archive --format=tar $(DRACUT_MAIN_VERSION) --prefix=dracut-$(DRACUT_MAIN_VERSION)/ > dracut-$(DRACUT_MAIN_VERSION).tar
	mkdir -p dracut-$(DRACUT_MAIN_VERSION)
	for i in $(manpages) dracut.html dracut-version.sh; do [ "$${i%/*}" != "$$i" ] && mkdir -p "dracut-$(DRACUT_MAIN_VERSION)/$${i%/*}"; cp "$$i" "dracut-$(DRACUT_MAIN_VERSION)/$$i"; done
	tar --owner=root --group=root -rf dracut-$(DRACUT_MAIN_VERSION).tar $$(find dracut-$(DRACUT_MAIN_VERSION) -type f)
	rm -fr -- dracut-$(DRACUT_MAIN_VERSION).tar.xz dracut-$(DRACUT_MAIN_VERSION)
	xz -9 dracut-$(DRACUT_MAIN_VERSION).tar
	rm -f -- dracut-$(DRACUT_MAIN_VERSION).tar

rpm: dracut-$(DRACUT_MAIN_VERSION).tar.xz syncheck
	rpmbuild=$$(mktemp -d -p /var/tmp rpmbuild-dracut.XXXXXX); src=$$(pwd); \
	cp dracut-$(DRACUT_MAIN_VERSION).tar.xz "$$rpmbuild"; \
	LC_MESSAGES=C $$src/git2spec.pl $(DRACUT_MAIN_VERSION) "$$rpmbuild" < dracut.spec > $$rpmbuild/dracut.spec; \
	(cd "$$rpmbuild"; \
	wget https://www.gnu.org/licenses/lgpl-2.1.txt; \
	rpmbuild --define "_topdir $$PWD" --define "_sourcedir $$PWD" \
	        --define "_specdir $$PWD" --define "_srcrpmdir $$PWD" \
		--define "_rpmdir $$PWD" -ba dracut.spec; ) && \
	( mv "$$rpmbuild"/{,$$(uname -m)/}*.rpm $(DESTDIR).; rm -fr -- "$$rpmbuild"; ls $(DESTDIR)*.rpm )

srpm: dracut-$(DRACUT_MAIN_VERSION).tar.xz syncheck
	rpmbuild=$$(mktemp -d -t rpmbuild-dracut.XXXXXX); src=$$(pwd); \
	cp dracut-$(DRACUT_MAIN_VERSION).tar.xz "$$rpmbuild"; \
	LC_MESSAGES=C $$src/git2spec.pl $(DRACUT_MAIN_VERSION) "$$rpmbuild" < dracut.spec > $$rpmbuild/dracut.spec; \
	(cd "$$rpmbuild"; \
	[ -f $$src/lgpl-2.1.txt ] && cp $$src/lgpl-2.1.txt . || wget https://www.gnu.org/licenses/lgpl-2.1.txt; \
	rpmbuild --define "_topdir $$PWD" --define "_sourcedir $$PWD" \
	        --define "_specdir $$PWD" --define "_srcrpmdir $$PWD" \
		--define "_rpmdir $$PWD" -bs dracut.spec; ) && \
	( mv "$$rpmbuild"/*.src.rpm $(DESTDIR).; rm -fr -- "$$rpmbuild"; ls $(DESTDIR)*.rpm )

syncheck:
	@ret=0;for i in dracut-initramfs-restore.sh modules.d/*/*.sh; do \
                [ "$${i##*/}" = "module-setup.sh" ] && continue; \
                read line < "$$i"; [ "$${line#*bash*}" != "$$line" ] && continue; \
		[ $$V ] && echo "posix syntax check: $$i"; bash --posix -n "$$i" ; ret=$$(($$ret+$$?)); \
		[ $$V ] && echo "checking for [[: $$i"; if grep -Fq '[[ ' "$$i" ; then ret=$$(($$ret+1)); echo "$$i contains [["; fi; \
		[ $$V ] && echo "checking for echo -n: $$i"; if grep -Fq 'echo -n ' "$$i" ; then ret=$$(($$ret+1)); echo "$$i contains echo -n"; fi \
	done;exit $$ret
	@ret=0;for i in *.sh mkinitrd-dracut.sh modules.d/*/*.sh \
	                modules.d/*/module-setup.sh; do \
		[ $$V ] && echo "bash syntax check: $$i"; bash -n "$$i" ; ret=$$(($$ret+$$?)); \
	done;exit $$ret

check: all syncheck rpm
	@[ "$$EUID" == "0" ] || { echo "'check' must be run as root! Please use 'sudo'."; exit 1; }
	@$(MAKE) -C test check

testimage: all
	./dracut.sh -N -l -a debug -f test-$(shell uname -r).img $(shell uname -r)
	@echo wrote  test-$(shell uname -r).img

debugtestimage: all
	./dracut.sh --debug -l -a debug -f test-$(shell uname -r).img $(shell uname -r)
	@echo wrote  test-$(shell uname -r).img

testimages: all
	./dracut.sh -l -a debug --kernel-only -f test-kernel-$(shell uname -r).img $(shell uname -r)
	@echo wrote  test-$(shell uname -r).img
	./dracut.sh -l -a debug --no-kernel -f test-dracut.img $(shell uname -r)
	@echo wrote  test-dracut.img

debughostimage: all
	./dracut.sh --debug -H -l -f test-$(shell uname -r).img $(shell uname -r)
	@echo wrote  test-$(shell uname -r).img

hostimage: all
	./dracut.sh -H -l -f test-$(shell uname -r).img $(shell uname -r)
	@echo wrote  test-$(shell uname -r).img

efi: all
	./dracut.sh --uefi -H -l -f linux-$(shell uname -r).efi $(shell uname -r)
	@echo wrote linux-$(shell uname -r).efi

AUTHORS:
	git shortlog  --numbered --summary -e |while read a rest || [ -n "$$rest" ]; do echo $$rest;done > AUTHORS

dracut.html.sign: dracut-$(DRACUT_MAIN_VERSION).tar.xz dracut.html
	gpg-sign-all dracut-$(DRACUT_MAIN_VERSION).tar.xz dracut.html

upload: dracut.html.sign
	kup put dracut-$(DRACUT_MAIN_VERSION).tar.xz dracut-$(DRACUT_MAIN_VERSION).tar.sign /pub/linux/utils/boot/dracut/
	kup put dracut.html dracut.html.sign /pub/linux/utils/boot/dracut/
