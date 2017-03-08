all :: ReleaseNotes lib/Qgoda/Migrator/Jekyll/LiquidParser.pm

Makefile: maintainer.mk

ReleaseNotes: NEWS
	cat NEWS >$@

SHELL := env YAPP=$(YAPP) $(SHELL)
YAPP ?= "$(INSTALLSITEBIN)/yapp"

lib/Qgoda/Migrator/Jekyll/LiquidParser.pm: LiquidParser.y
	$(YAPP) -v -m Qgoda::Migrator::Jekyll::LiquidParser -s -o $@ $<