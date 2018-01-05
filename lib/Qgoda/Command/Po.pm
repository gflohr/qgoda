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

use Locale::TextDomain 1.28 qw(qgoda);
use File::Spec;
use File::Temp;
use File::Copy qw(copy);
use File::Path qw(make_path);
use Cwd qw(getcwd);

use Qgoda;
use Qgoda::Util qw(empty write_file);
use Qgoda::CLI;

use base 'Qgoda::Command';

my $seed_repo = 'file://' . $ENV{HOME} . '/perl/Template-Plugin-Gettext-Seed';

sub _run {
    my ($self, $args, $global_options, %options) = @_;

    Qgoda::CLI->commandUsageError('po', __"no target specified",
                                  'po [OPTIONS] TARGET')
        if !@$args;
    
    Qgoda::CLI->commandUsageError('po', __"only one target may be specified",
                                  'po [OPTIONS] TARGET')
        if 1 != @$args;
    
    my $target = $args->[0];

    my $qgoda = Qgoda->new($global_options);

    my $config = $qgoda->config;
    my $logger = $qgoda->logger;

    my $textdomain = $config->{po}->{textdomain};
    $logger->fatal(__"configuration variable 'po.textdomain' not set")
        if empty $textdomain;
    my $linguas = $config->{linguas};
    $logger->fatal(__"configuration variable 'linguas' not set or empty")
        if empty $linguas || !@$linguas;

    my @missing;
    if ('reset' eq $target) {
        @missing = qw(Makefile PACKAGE PLFILES GitIgnore QgodaINC);
    } else {
        @missing = $self->__checkFiles;
    }

    foreach my $missing (@missing) {
        my $method = '__addMissing' . $missing;
        $self->$method;
    }
    return $self if 'reset' eq $target;

    my $here = getcwd;
    if (!defined $here) {
        $logger->fatal(__x("cannot get current working directory: {error}",
                           error => $!));        
    }

    my $podir = $config->{paths}->{po};
    if (!chdir $podir) {
        $logger->fatal(__x("cannot change directory to '{directory}': {error}",
                           directory => $podir, error => $!));
    }

    return $self->__make($target) if !empty $config->{po}->{make};

    my %methods = (
        pot => '__makePOT',
        'update-po' => '__makeUpdatePO',
        'update-mo' => '__makeUpdateMO',
        install => '__makeInstall',
        all => '__makeAll',
    );

    my $method = $methods{lc $target};

    unless ($method && $self->can($method)) {
        my $msg = __x("unsupported target '{target}'", target => $target);

        Qgoda::CLI->commandUsageError('po', $msg, 'po [OPTIONS] TARGET');
    }

    return $self->$method($here);
}

sub __checkFiles {
    my ($self) = @_;

    my $qgoda = Qgoda->new;

    my $config = $qgoda->config;
    my $logger = $qgoda->logger;

    my $podir = $config->{paths}->{po};

    my @missing;

    $logger->debug(__"checking for missing files in po directory");
    my $makefile = File::Spec->catfile($podir, 'Makefile');
    push @missing, 'Makefile' if !-e $makefile;

    my $package = File::Spec->catfile($podir, 'PACKAGE');
    push @missing, 'PACKAGE' if !-e $package;

    my $plfiles = File::Spec->catfile($podir, 'PLFILES');
    push @missing, 'PLFILES' if !-e $plfiles;

    my $git_ignore = File::Spec->catfile($podir, '.gitignore');
    push @missing, 'GitIgnore' if !-e $git_ignore;

    my $qgoda_inc = File::Spec->catfile($podir, 'qgoda.inc');
    push @missing, 'QgodaINC' if !-e $qgoda_inc;

    return @missing;
}

sub __addMissingPACKAGE {
    my ($self) = @_;

    my $qgoda = Qgoda->new;
    my $logger = $qgoda->logger;
    my $config = $qgoda->config;
    my $po_config = $config->{po};

    my $podir = $config->{paths}->{po};

    my $package = File::Spec->catfile($podir, 'PACKAGE');
    $logger->info(__x("creating '{filename}'", filename => $package));

    my $header_comment = $self->__comment(__(<<EOF));
Makefile snippet holding package-dependent information.  Please adhere
to Makefile syntax!
EOF

    my $linguas_comment = $self->__comment(__(<<EOF));
Space-separated list of language codes.  Omit the base language!
EOF
    chomp $linguas_comment;

    my @linguas = @{$config->{linguas}};
    shift @linguas;
    my $linguas = join ' ', @linguas;    

    my $textdomain_comment = $self->__comment(__(<<EOF));
Textdomain of the site, for example reverse domain name.
EOF
    chomp $textdomain_comment;
    my $textdomain = $po_config->{textdomain};

    my $msgid_bugs_address_comment = $self->__comment(__(<<EOF));
Where to send msgid bug reports?
EOF
    chomp $msgid_bugs_address_comment;
    my $msgid_bugs_address = $po_config->{msgid_bugs_address};
    $msgid_bugs_address = __"Please set MSGID_BUGS_ADDRESS in 'PACKAGE'"
        if empty $msgid_bugs_address;
    
    my $copyright_holder_comment = $self->__comment(__(<<EOF));
Initial copyright holder added to pot and po files.
EOF
    chomp $copyright_holder_comment;
    my $copyright_holder = $po_config->{copyright_holder};
    $copyright_holder = __"Please set COPYRIGHT_HOLDER in 'PACKAGE'"
        if empty $copyright_holder;

    my $override_comment = $self->__comment(__(<<EOF));
Override these default values as needed.
EOF
    chomp $override_comment;

    my $xgettext_line = empty $po_config->{xgettext}
        ? "#XGETTEXT = xgettext" : "XGETTEXT = $config->{po}->{xgettext}";
    my $xgettext_tt2_line = empty $po_config->{xgettext_tt2}
        ? "#XGETTEXT_TT2 = xgettext-tt2" 
        : "XGETTEXT = $config->{po}->{xgettext_tt2}";
    my $msgmerge_line = empty $po_config->{msgmerge}
        ? "#MSGMERGE = msgmerge" : "MSGMERGE = $config->{po}->{msgmerge}";
    my $msgfmt_line = empty $po_config->{msgfmt}
        ? "#MSGFMT = msgfmt" : "MSGFMT = $config->{po}->{msgfmt}";
    my $qgoda_line = empty $po_config->{qgoda}
        ? "QGODA = qgoda" : "QGODA = $config->{po}->{qgoda}";

    my $contents = <<EOF;
$header_comment
$linguas_comment
LINGUAS = $linguas

$textdomain_comment
TEXTDOMAIN = $textdomain

$msgid_bugs_address_comment
MSGID_BUGS_ADDRESS = $msgid_bugs_address

$copyright_holder_comment
COPYRIGHT_HOLDER = $copyright_holder

$override_comment
$xgettext_line
$xgettext_tt2_line
$msgmerge_line
$msgfmt_line
$qgoda_line
EOF

    if (!write_file $package, $contents) {
        $logger->fatal(__x("error writing '{filename}': {error}",
                           filename => $package,
                           error => $!));
    }

    return $self;
}

sub __addMissingMakefile {
    my ($self) = @_;

    # Fail early if Git is not installed.
    require Git;

    my $qgoda = Qgoda->new;
    my $logger = $qgoda->logger;
    my $config = $qgoda->config;
    my $po_config = $config->{po};

    my $podir = $config->{paths}->{po};

    my $makefile = File::Spec->catfile($podir, 'Makefile');
    $logger->info(__x("creating '{filename}'", filename => $makefile));
    $logger->info(__x("cloning git repository '{repo}'",
                      repo => $seed_repo));

    my $tmp = File::Temp->newdir;
    $logger->debug(__x("created temporary directory '{dir}'",
                       dir => $tmp));

    Git::command('clone', '--depth', '1', $seed_repo, $tmp);

    my $remote = File::Spec->catfile($tmp, 'po', 'Makefile');
    $logger->debug(__x("copying '{from}' to '{to}'",
                       from => $remote, to => $makefile));

    if (!copy $remote, $podir) {
        $logger->fatal(__x("error copying '{from}' to '{to}'",
                           from => $remote, to => $makefile))
    }

    return $self;
}

sub __addMissingPLFILES {
    my ($self) = @_;

    my $qgoda = Qgoda->new;
    my $logger = $qgoda->logger;
    my $config = $qgoda->config;

    my $podir = $config->{paths}->{po};

    my $plfiles = File::Spec->catfile($podir, 'PLFILES');
    $logger->info(__x("creating '{filename}'", filename => $plfiles));

    if (!write_file $plfiles, '') {
        $logger->fatal(__x("error writing '{filename}': {error}",
                           filename => $plfiles,
                           error => $!));
    }

    return $self;
}

sub __addMissingGitIgnore {
    my ($self) = @_;

    my $qgoda = Qgoda->new;
    my $logger = $qgoda->logger;
    my $config = $qgoda->config;

    my $podir = $config->{paths}->{po};

    my $gitignore = File::Spec->catfile($podir, '.gitignore');
    $logger->info(__x("creating '{filename}'", filename => $gitignore));

    my $ignore_list = <<EOF;
/*.gmo
/*.mo
EOF

    if (!write_file $gitignore, $ignore_list) {
        $logger->fatal(__x("error writing '{filename}': {error}",
                           filename => $gitignore,
                           error => $!));
    }

    return $self;
}

sub __addMissingQgodaINC {
    my ($self) = @_;

    my $qgoda = Qgoda->new;
    my $logger = $qgoda->logger;
    my $config = $qgoda->config;

    my $podir = $config->{paths}->{po};

    my $qgoda_inc = File::Spec->catfile($podir, 'qgoda.inc');
    $logger->info(__x("creating '{filename}'", filename => $qgoda_inc));

    my $include = <<'EOF';
# Makefile snippet for Qgoda.  Extract all strings from Markdown files that
# serve as the base for translated documents.

MDPOTFILES = $(srcdir)/MDPOTFILES \
        $(shell cat $(srcdir)/MDPOTFILES)

$(srcdir)/markdown.pot: $(srcdir)/MDPOTFILES $(MDPOTFILES)
	$(QGODA) xgettext --output=$(srcdir)/markdown.pox --from-code="utf-8" \
		--add-comments=TRANSLATORS: --files-from=$(srcdir)/MDPOTFILES \
		--copyright-holder='$(COPYRIGHT_HOLDER)' --force-po \
		--msgid-bugs-address='$(MSGID_BUGS_ADDRESS)' && \
	rm -f $@ && mv $(srcdir)/markdown.pox $@
EOF

    if (!write_file $qgoda_inc, $include) {
        $logger->fatal(__x("error writing '{filename}': {error}",
                           filename => $qgoda_inc,
                           error => $!));
    }

    return $self;
}

sub __comment {
    my ($self, $text) = @_;

    $text =~ s/^/# /gm;

    return $text;
}

sub __expandCommand {
    my ($self, $cmd) = @_;

    if (ref $cmd) {
        return @$cmd;
    }

    return $cmd;
}

sub __command {
    my ($self, @args) = @_;

    my @pretty;
    foreach my $arg (@args) {
        my $pretty = $arg;
        $pretty =~ s{(["\\\$])}{\\$1}g;
        $pretty = qq{"$pretty"} if $pretty =~ /[ \t]/;
        push @pretty, $pretty;
    }

    my $pretty = join ' ', @pretty;
    my $logger = Qgoda->new->logger;

    $logger->info(__x("execute: {cmd}", cmd => $pretty));;

    system @args;
}

sub __fatalCommand {
    my ($self, @args) = @_;

    return $self if 0 == $self->__command(@args);

    my $logger = Qgoda->new->logger;

    if ($? == -1) {
        $logger->fatal(__x("failed to execute: {error}", error => $!));;
    } elsif ($? & 127) {
        $logger->fatal(__x("died with signal {signo}", signo => $? & 127));
    }

    $logger->fatal(__x("error {number}", $? >> 8));
}

sub __safeRename {
    my ($self, $from, $to) = @_;

    my $qgoda = Qgoda->new;
    my $logger = $qgoda->logger;

    $logger->info(__x("rename '{from}' to '{to}'",
                      from => $from, to => $to));
    
    return $self if rename $from, $to;

    $logger->fatal(__x("error renaming '{from}' to '{to}': {error}",
                       from => $from, to => $to, error => $!));    
}

sub __outOfDate {
    my ($self, $target, @deps) = @_;

    my @ref = stat $target or return 1;

    foreach my $dep (@deps) {
        my @stat = stat $dep or return 1;
        return 1 if $stat[9] > $ref[9];
    }

    return;
}

sub __filelist {
    my ($self, $filelist) = @_;

    my $fh;
    if (!open $fh, '<', $filelist) {
        my $logger = Qgoda->new->logger;

        $logger->fatal(__x("error reading '{filename}': {error}",
                           filename => $filelist, error => $!));
    }

    return grep { length } map { s/^[ \r\t]*//; s/[ \t\r\n]*$//; $_ } <$fh>;
}

sub __make {
    my ($self, $target) = @_;

    my $qgoda = Qgoda->new;
    my $config = $qgoda->config;
    my $logger = $qgoda->logger;

    my $make = $config->{po}->{make};

    $self->__fatalCommand($make, $target);

    return $self;
}

sub __makePOT {
     my ($self) = @_;

    my $qgoda = Qgoda->new;
    my $logger = $qgoda->logger;
    my $po_config = $qgoda->config->{po};

    # FIXME! Check dependencies!
    my ($pox, $pot) = ('plfiles.pox', 'plfiles.pot');
    my @options = split / /, Locale::TextDomain->options;
    my @cmd = ($self->__expandCommand($po_config->{xgettext}),
               "--output=$pox", "--from-code=utf-8",
               "--add-comments=TRANSLATORS:", "--files-from=PLFILES",
               "--copyright-holder='$po_config->{copyright_holder}'",
               "--force-po",
               "--msgid-bugs-address='$po_config->{msgid_bugs_address}'",
               @options);
    $self->__fatalCommand(@cmd);
    $logger->info(__x("unlink '{filename}'", filename => $pot));
    unlink $pot;
    $self->__safeRename($pox, $pot);

    ($pox, $pot) = ("markdown.pox", 
                    "markdown.pot");
    @cmd = ($self->__expandCommand($po_config->{qgoda}), "xgettext",
               "--output=$pox", "--from-code=utf-8",
               "--add-comments=TRANSLATORS:", "--files-from=MDPOTFILES",
               "--copyright-holder='$po_config->{copyright_holder}'",
               "--force-po",
               "--msgid-bugs-address='$po_config->{msgid_bugs_address}'");
    $self->__fatalCommand(@cmd);
    $logger->info(__x("unlink '{filename}'", filename => $pot));
    unlink $pot;
    $self->__safeRename($pox, $pot);

    ($pox, $pot) = ("$po_config->{textdomain}.pox", 
                    "$po_config->{textdomain}.pot");
    @cmd = ($self->__expandCommand($po_config->{xgettext_tt2}),
               "--output=$pox", "--from-code=utf-8",
               "--add-comments=TRANSLATORS:", "--files-from=POTFILES",
               "--copyright-holder='$po_config->{copyright_holder}'",
               "--force-po",
               "--msgid-bugs-address='$po_config->{msgid_bugs_address}'");
    $self->__fatalCommand(@cmd);
    $logger->info(__x("unlink '{filename}'", filename => $pot));
    unlink $pot;
    $self->__safeRename($pox, $pot);

    return $self;
}

sub __makeUpdatePO {
    my ($self) = @_;

    my $qgoda = Qgoda->new;
    my $logger = $qgoda->logger;
    my $config = $qgoda->config;
    my $po_config = $config->{po};

    my @deps = $self->__filelist('PLFILES');
    push @deps, $self->__filelist('MDPOTFILES');
    push @deps, $self->__filelist('POTFILES');
    push @deps, 'PLFILES', 'MDPOTFILES', 'POTFILES';
    $self->__makePOT if $self->__outOfDate("$config->{po}->{textdomain}.pot", 
                                           @deps);

    my @linguas = @{$config->{linguas}};
    shift @linguas;

    my $errors = 0;
    foreach my $lang (@linguas) {
        $logger->info(__x("merging {filename}", filename => "$lang.po"));

        $self->__safeRename("$lang.po", "$lang.old.po");

        my @cmd = ($self->__expandCommand($po_config->{msgmerge}), 
                   "$lang.old.po", "$po_config->{textdomain}.pot", 
                   '--previous',
                   '-o', "$lang.po");
        if (0 == $self->__command(@cmd)) {
            $logger->info(__x("unlink '{filename}'", 
                              filename => "$lang.old.po"));
            unlink "$lang.old.po";
        } else {
            ++$errors;
            $logger->error(__x("Merging {filename} failed",
                               filename => "$lang.po"));
            $self->__safeRename("$lang.old.po", "$lang.po");
        }
    }

    exit 1 if $errors;

    return $self;
}

sub __makeUpdateMO {
    my ($self) = @_;

    my $qgoda = Qgoda->new;
    my $logger = $qgoda->logger;
    my $config = $qgoda->config;
    my $po_config = $config->{po};

    my @linguas = @{$config->{linguas}};
    shift @linguas;

    my @deps = $self->__filelist('PLFILES');
    push @deps, $self->__filelist('MDPOTFILES');
    push @deps, $self->__filelist('POTFILES');
    push @deps, 'PLFILES', 'MDPOTFILES', 'POTFILES';

    foreach my $lang (@linguas) {
        if ($self->__outOfDate("$lang.po", @deps)) {
            $self->__makeUpdatePO;
            last;
        }
    }

    foreach my $lang (@linguas) {
        $self->__makeUpdatePO if $self->__outOfDate("$lang.po", @deps);
        my @cmd = ($self->__expandCommand($po_config->{msgfmt}), "--check",
                   "--statistics", "--verbose",
                   '-o', "$lang.gmo", "$lang.po");
        $self->__fatalCommand(@cmd);
    }

    return $self;
}

sub __makeInstall {
    my ($self, $srcdir) = @_;

    my $qgoda = Qgoda->new;
    my $logger = $qgoda->logger;
    my $config = $qgoda->config;
    my $po_config = $config->{po};

    my @linguas = @{$config->{linguas}};
    shift @linguas;

    my @deps = $self->__filelist('PLFILES');
    push @deps, $self->__filelist('MDPOTFILES');
    push @deps, $self->__filelist('POTFILES');
    push @deps, 'PLFILES', 'MDPOTFILES', 'POTFILES';
    push @deps, map { "$_.po" } @linguas;

    foreach my $lang (@linguas) {
        if ($self->__outOfDate("$lang.gmo", @deps)) {
            $self->__makeUpdateMO;
            last;
        }
    }

    my $targetdir = File::Spec->catfile($srcdir, 'LocaleData');
    foreach my $lang (@linguas) {
        my $destdir = File::Spec->catfile($targetdir, $lang, 'LC_MESSAGES');
        if (!-e $destdir) {
            $logger->info(__x("create directory '{directory}'",
                              directory => $destdir));
            make_path $destdir if !-e $destdir;
        }
        my $dest = File::Spec->catfile($destdir, "$po_config->{textdomain}.mo");
        $logger->info(__x("copy '{from}' to '{to}'",
                          from => "$lang.gmo", to => $dest));
        if (!copy "$lang.gmo", "$dest") {
            $logger->fatal(__x("canot copy '{from}' to '{to}': {error}",
                              from => "$lang.gmo", to => $dest, error => $!));
            
        }
    }

    return $self;
}

sub __makeAll {
    my ($self, $srcdir) = @_;

    $self->__makePOT($srcdir);
    $self->__makeUpdatePO($srcdir);
    $self->__makeUpdateMO($srcdir);
    $self->__makeInstall($srcdir);
}

1;

=head1 NAME

qgoda po - Translation workflow based on PO files

=head1 SYNOPSIS

    qgoda po [<global options>] pot
    qgoda po [<global options>] update-po
    qgoda po [<global options>] update-mo
    qgoda po [<global options>] install

Or for all of the above:

    qgoda po [<global options>] all

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
of your site.  The textdomain for L<http://www.qgoda.net/> is for example
C<net.qgoda.www>.

The F<_po> directory contains the following files:

=over 4

=item B<PACKAGE>

Contains the basic configuration of your site suitable for a Makefile and it
is only needed if you use the Makefile.  The file is 
auto-generated but then left untouched so that you can edit it to your needs.

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

=item B<po.xgettext>

The xgettext(1) program on your system, defaults to just "xgettext".

=item B<po.xgettext_tt2>

The xgettext-tt2(1) program on your system, defaults to just "xgettext-tt2".

=item B<po.qgoda>

The qgoda(1) program on your system, defaults to just "qgoda".

=item B<po.msgmerge>

The msgmerge(1) program on your system, defaults to just "msgmerge".

=item B<po.msgfmt>

The msgfmt(1) program on your system, defaults to just "msgfmt".

=back

For all configuration variables above that expect a command name, you can
use a single value or a list, if you want to pass options to the command.

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

=item B<PLFILES>

A list of Perl source files for your site.  If missing, an empty file is
automatically generated but you have to maintain it manually.

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

=item -h, --help

Show this help page and exit.

=back

=head1 CONFIGURATION

If you set the configuration variable C<po.make> to the name of a make(1)
executable on your system, the Makefile in F<_po> is executed instead of
emulating the Makefile behavior with Perl.

The Makefile includes all files in the C<_po> directory that match C<*.inc>
so that you can easily extend it.

=head1 SEE ALSO

L<http://www.qgoda.net/en/docs/i18n/>, L<xgettext-tt2>, 
L<Template::Plugin::Gettext>, xgettext(1), msgmerge(1), msgfmt(1), git(1)

=head1 QGODA

Part of L<Qgoda|http://www.qgoda.net/>.
