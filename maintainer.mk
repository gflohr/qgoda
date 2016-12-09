all :: ReleaseNotes lib/Qgoda/Parser/Liquid.pm

Makefile: maintainer.mk

ReleaseNotes: NEWS
	cat NEWS >$@

SHELL := env YAPP=$(YAPP) $(SHELL)
YAPP ?= "$(INSTALLSITEBIN)/yapp"

lib/Qgoda/Parser/Liquid.pm: Liquid.y
	$(YAPP) -m Qgoda::Parser::Liquid -s -o $@ $<
