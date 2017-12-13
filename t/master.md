---
title: Master Document
name: master-document
description: Test for po mechanism
---
Multiple lines
in one
paragraph.

<!--QGODA-XGETTEXT-->
Block

with

embedded

new lines.
<!--/QGODA-XGETTEXT-->

<!--QGODA-NO-XGETTEXT-->
```perl
my $qgoda = Qgoda->new;
```
<!--/QGODA-NO-XGETTEXT-->

Empty lines above should be ignored.
