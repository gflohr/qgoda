all :: ReleaseNotes

Makefile: maintainer.mk

ReleaseNotes: NEWS
	cat NEWS >$@
