---
title: Master Document
name: master-document
description: Test for po mechanism
---
Multiple lines
in one
paragraph.

<qgoda:xgettext>
Block

with

embedded

new lines.
</qgoda:xgettext>

<qgoda:no-xgettext>
```perl
my $qgoda = Qgoda->new;
```
</qgoda:no-xgettext>

Empty lines above should be ignored.

<!--TRANSLATORS: A translator comment.
    xgettext:msgctxt= my -->
This entry has the context "my" and a translator comment.
