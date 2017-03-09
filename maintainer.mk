all :: ReleaseNotes lib/Qgoda/Migrator/Jekyll/LiquidParser.pm lib/Qgoda/Init.pm

Makefile: maintainer.mk

ReleaseNotes: NEWS
	cat NEWS >$@

SHELL := env YAPP=$(YAPP) $(SHELL)
YAPP ?= "$(INSTALLSITEBIN)/yapp"

lib/Qgoda/Migrator/Jekyll/LiquidParser.pm: LiquidParser.y
	$(YAPP) -v -m Qgoda::Migrator::Jekyll::LiquidParser -s -o $@ $<

lib/Qgoda/Init.pm: lib/Qgoda/Init.pm.in maintainer.mk
	perl -pe 's{\@([-_a-z./]+)\@}{`cat data/$$1`}gxe' lib/Qgoda/Init.pm.in >$@
