all :: ReleaseNotes lib/Qgoda/Migrator/Jekyll/LiquidParser.pm lib/Qgoda/Init.pm

Makefile: maintainer.mk

ReleaseNotes: NEWS
	cat NEWS >$@

SHELL := env YAPP=$(YAPP) $(SHELL)
YAPP ?= "$(INSTALLSITEBIN)/yapp"

lib/Qgoda/Migrator/Jekyll/LiquidParser.pm: LiquidParser.y
	$(YAPP) -v -m Qgoda::Migrator::Jekyll::LiquidParser -s -o $@ $<

Init_DEPS = \
        lib/Qgoda/Init.pm.in \
        maintainer.mk \
        share/* \
        share/*/* \
        share/*/*/* \
        share/*/*/*/*
lib/Qgoda/Init.pm: $(Init_DEPS) 
	perl -pe 's{\@([-_a-z0-9./]+)\@}{`cat share/$$1`}gxe' lib/Qgoda/Init.pm.in >$@
