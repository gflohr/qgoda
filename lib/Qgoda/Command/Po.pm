#! /bin/false

# Copyright (C) 2016 Guido Flohr <guido.flohr@cantanea.com>,
# all rights reserved.

# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 3 of the License, or
# (at your option) any later version.

# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

package Qgoda::Command::Po;

use strict;

use Qgoda;

use base 'Qgoda::Command';

sub _run {
    my ($self, $args, $global_options, %options) = @_;

#    Qgoda->new($global_options)->init($args, %options);

    return $self;
}

1;

=head1 NAME

qgoda po - Translation workflow based on PO files

=head1 SYNOPSIS

qgoda po [<global options>] [<target>]

Try 'qgoda --help' for a description of global options.

=head1 DESCRIPTION

You will find tutorial style information for the internationalization (i18n)
of Qgoda sites at L<http://www.qgoda.net/en/docs/i18n/>.  The following 
is rather meant as a quick reference.

Updates, compiles and installs translations.  You need the GNU gettext tools
as a prerequisite.  They are available from your package manager as either
"gettext-tools", "gettext-dev", or just "gettext".  A package "gettext-runtime"
is neither needed nor sufficient.

Everything related to translations resides in the directory F<_po>,
respectively the directory that the configuration variable C<paths.po>
in F<_config.yaml> points to.

The directory is autmatically created and populated when necessary.  It is
necessary, if you use L<Template::Plugin::Gettext> in one of your templates:

    [% USE gtx = Gettext('com.example.www', asset.lingua) %]

Creation of the F<_po> directory is also triggered, if one of your site's
markdown documents refers to another from the document variable C<master>

    ---
    master: /en/about.md
    ---

Additionally, you must set the textdomain of your site in the configuration
variable C<po.textdomain>.  The textdomain is
the name under which translations are saved, usually the reverse domain name
of your site.  The textdomain for L<http://www.qgoda.net/> is C<net.qgoda.www>
for instance.

The F<_po> directory contains the following files:

=over 4

=item B<PACKAGE>

Contains the basic configuration of your site.  It is auto-generated but then
left untouched so that you can edit it to your needs.

In order to reset the file to the latest upstream version, delete it and then
run C<qgoda build> or C<qgoda watch> once.  Alternatively, run C<qgoda po
reset>.

The following configuration variables in F<_config.yaml> are evaluated for
the creation of F<PACKAGE>:

=over 8

=item B<linguas>

An array of language codes, for example:

    linguas: [en, fr, de, bg]

The first value is assumed to be the base language of your site.

=item B<po.textdomain>

Your site's textdomain, for example C<com.example.www>.

=item B<po.msgid_bugs_address>

An email address or web site for issuing errors in translatable strings.
Translators will use that address for reporting problems with translating
your site.  See below for an example.

=item B<po.copyright_holder>

The copyright holder that should be put into the header of the master
translation file F<TEXTDOMAIN.pot>.

=back

Example configuration for F<PACKAGE>:

    linguas: [en, fr, de, bg]
    po:
      textdomain: com.example.www
      msgid_bugs_address: John Doe <po-bugs@example.com>
      copyright_holder: Acme Ltd. <http://www.example.com>

When you change the configuration, you have to either delete the generated
files from the F<_po> directory or run C<qgoda po reset> in order to
update them.

=item B<po-make.pl>

This script is responsible for invoking the necessary helper programs as
needed.  Try C<perl po-make.pl --help> for usage information if you want to
run the program yourself.  The result will be the same as using 
C<qgoda po TARGET>.

=item B<Makefile>

Does essentially the same as B<po-make.pl> but is smarter at dependency
handling.  You can run the Makefile manually with the C<make(1)> command
or use the option C<--make> (see <L/OPTIONS>) or set the configuration
variable C<po.make>.

=item B<MDPOTFILES>

A list of Markdown documents found in your site that are referenced by
documents that have to be translated.  This file is auto-generated and gets
overwritten without warning by C<qgoda build> or C<qgoda watch>.

=item B<POTFILES>

A list of templates that use the L<Template::Plugin::Gettext> plug-in with
your configured textdomain.

If you use another textdomain, qgoda will produce a warning and not include
the referring files here.

Note, that this file will normally also contain a line for F<./MDPOTFILES>.
This line has the effect that all translatable strings in Markdown files
are also included in the master translation catalog.

=item B<qgoda.yaml>

Contains information about additional commands that have to be run by
F<po-make.pl>.  The file is auto-generated when missing but then left
untouched.

In order to reset the file to the latest upstream version, delete it and then
run C<qgoda build> or C<qgoda watch> once.  Alternatively, run C<qgoda po
reset>.

=item B<qgoda.inc>

Contains additional Makefile snippets needed by the Qgoda translation workflow.
The file is only needed, when you use the F<Makefile>.

=item B<*.po>

For example F<fr.po>, F<de.po> and so on.  You need one PO file for every
language you have configured.  Failure to do so will result in an error.

The simplest way of creating such a file from scratch is with the command:

    msginit --locale=fr --input=TEXTDOMAIN.pot

Replace "fr" with the language you need and F<TEXTDOMAIN.pot> with the 
name of the master translation catalog that you have configured.

Note that you have to run <qgoda po pot> at least once before you can
create PO files.

=item B<*.gmo>

Contains compiled translations.  These files are generated and you can safely
delete them, whenever you want.

=item B<.gitignore>

Tells C<git(1)> which files to ignore.  This file is auto-generated when
missing but then left untouched.

In order to reset the file to the latest upstream version, delete it and then
run C<qgoda build> or C<qgoda watch> once.  Alternatively, run C<qgoda po
reset>.

The master translation catalog F<TEXTDOMAIN.pot> is a generated file and
generated files should normally be ignored by version control systems.  No
rule without an exception, master translation catalogs are conventionally not
put into the ignore list.  Rationale: Translators should not need any tools
needed for creating F<.pot> and F<.po> files.

=back

=head1 TARGETS

=over 4

=item B<pot>

Updates or creates the master translation catalog F<TEXTDOMAIN.pot>.

=item B<update-po>

Updates all F<.po> files by merging in the current strings found in 
F<TEXTDOMAIN.pot>.  Note that you have to I<create> the F<.po> files
yourself (try C<msginit --help>).

This target implicitely includes the B<pot> target (see above).

=item B<update-mo>

Compiles the F<.po> files containing the translations.  Additionally a
syntactic check is performed on the translation files and statistics about
translated, untranslated and fuzzy entries is printed out.

This target implicitely includes the B<update-po> and all preceding targets.

=item B<install>

Installs translations.  Running C<qgoda build> or C<qgoda watch> will now
use these translations when rendering your site.

This target implicitely includes the B<update-mo> and all preceding targets.

=item B<all>

Does all of the above.  Use this target if you just want to ensure that 
everything is up-to-date and documents are translated to the extent that
translations are available.

=item B<reset>

Overwrites the files F<po-make.pl> and F<Makefile>
L<https://github.com/gflohr/Template-Plugin-Gettext-Seed/> and resets
F<PACKAGE>, F<qgoda.yaml>, F<qgoda.inc>, and F<.gitignore> to a vanilla
state.

=back

=head1 OPTIONS

=over 4

=item --make

Use the F<Makefile> instead of the pure Perl version F<po-make.pl> for
generating files.

The configuration variable C<po.make> must point to the C<make(1)> executable
on your system:

    po:
      make: make

Just "make" from your C<$PATH> is usually just fine, but sometime you will
want to use C<gmake>, C<nmake>, C</opt/local/bin/make> or similar instead.

=item -h, --help

Show this help page and exit.

=back

=head1 SEE ALSO

L<http://www.qgoda.net/en/docs/i18n/>, git(1)

=head1 QGODA

Part of L<Qgoda|http://www.qgoda.net/>.
