all :: ReleaseNotes lib/Qgoda/Migrator/Jekyll/LiquidParser.pm lib/Qgoda/Init.pm

Makefile: maintainer.mk

ReleaseNotes: NEWS
	cat NEWS >$@

YAPP = yapp

lib/Qgoda/Migrator/Jekyll/LiquidParser.pm: LiquidParser.y
	$(YAPP) -v -m Qgoda::Migrator::Jekyll::LiquidParser -s -o $@ $<
