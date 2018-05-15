#! /usr/bin/env perl

use strict;

use utf8;

use Getopt::Long;
use IO::Handle;
use Locale::PO;
use Encode;

sub decompose_po;
sub decompose_po_sg;
sub compose_po;
sub german_handler;
sub american_english_handler;
sub british_english_handler;
sub swiss_german_handler;
sub austrian_german_handler;
sub display_usage;
sub usage_error;

my ($option_language, $option_input, $option_output, $option_help, 
    $option_verbose);
GetOptions (
        'language=s' => \$option_language,
        'input=s' => \$option_input,
        'output=s' => \$option_output,
        'help' => \$option_help,
        'verbose' => \$option_verbose,
        ) or exit 1;

display_usage if $option_help;
usage_error "the option '--language' is mandatory." unless $option_language;
usage_error "the option '--input' is mandatory." unless $option_input;
usage_error "the option '--output' is mandatory." unless $option_output;

my @filters;

if ($option_language =~ /^de_CH$/) {
    push @filters, \&swiss_german_handler;
} elsif ($option_language =~ /^de_AT$/) {
    push @filters, \&austrian_german_handler;
} elsif ($option_language =~ /^en_GB$/) {
    push @filters, \&british_english_handler;
} elsif ($option_language =~ /^en.*$/) {
    push @filters, \&american_english_handler;
} elsif ($option_language =~ /^de/) {
    push @filters, \&german_handler;
} elsif ($option_language =~ /^bg/) {
    push @filters, \&german_handler;
}

my $entries = Locale::PO->load_file_asarray ($option_input) or
    die "cannot read file '$option_input': $!\n";

my $alpine_entries;
my $german_to_alpine = {
    Samstag => 'Sonnabend',
    Januar => "J\xe4nner",
    Februar => "Feber",
};

my $german_to_alpine_re_string = join '|', keys %$german_to_alpine;
my $german_to_alpine_re = qr /($german_to_alpine_re_string)/o;

autoflush STDERR;
print STDERR "$option_language\n";

my $count = 0;
my $file_dirty;
foreach my $entry (@$entries) {
    ++$count;
    print STDERR '.' if 0 == $count % 10 && $option_verbose;

    next if $entry->obsolete;

    foreach my $filter (@filters) {
        $file_dirty = 1 if &$filter ($entry);
    }
}
print STDERR " done.\n" if $option_verbose;

if ($file_dirty) {
    Locale::PO->save_file_fromarray($option_output, $entries, 'utf-8')
        or die "cannot write file '$option_output': $!\n";
}

sub decompose_po {
    my ($entry) = @_;

    my @msgstrs;
    if ($entry->msgid_plural) {
        my $msgstr_n = $entry->msgstr_n;
        foreach my $num (sort keys %$msgstr_n) {
            push @msgstrs, $entry->dequote($msgstr_n->{$num});
        }
    } else {
        @msgstrs = $entry->dequote($entry->msgstr);
    }

    return map { Encode::_utf8_on($_); $_ } @msgstrs;
}

sub decompose_po_sg {
    my ($entry) = @_;

    my @msgids = $entry->dequote($entry->msgid);
    push @msgids, $entry->dequote($entry->msgid_plural) if $entry->msgid_plural;

    return @msgids;
}

sub compose_po {
    my ($entry, @msgstrs) = @_;

    my $dirty;
    if (@msgstrs > 1) {
        # Plural form.
        my $msgstr_n = $entry->msgstr_n;
        foreach my $num (0 .. @msgstrs) {
            my $old = $entry->dequote($msgstr_n->{$num});
            my $new = $msgstrs[$num];
            if ($old ne $new) {
                $dirty = 1;
                $msgstr_n->{$num} = $new;
            }
        }
        $entry->msgstr_n($msgstr_n) if $dirty;
    } else {
        my $old = $entry->dequote($entry->msgstr);
        if ($old ne $msgstrs[0]) {
            $entry->msgstr($msgstrs[0]);
            $dirty = 1;
        }
    }

    return unless $dirty;

    return 1;
}

sub _english_quotes {
    my ($entry, $country) = @_;

    my $msgid = $entry->dequote($entry->msgid);
    return 1 if $msgid eq '';

    my @msgstrs = decompose_po $entry;
    return 1 if length $msgstrs[0];

    my $open_quote = $country eq 'US' ? "\x{201c}" : "\x{2018}";
    my $close_quote = $country eq 'US' ? "\x{201d}" : "\x{2019}";

    my $dirty;
    undef @msgstrs;
    foreach my $msg (decompose_po_sg $entry) {
        $msg =~ s/(\w)'(\w)/$1\x{2019}$2/;
        $msg =~ s/'(.*?)'/${open_quote}$1${close_quote}/g;
        push @msgstrs, $msg;
    }

    return compose_po $entry, @msgstrs;
}

sub _german_quotes {
    my ($entry, $country) = @_;

    my $msgid = $entry->dequote($entry->msgid);
    return 1 if $msgid eq '';

    my @msgstrs = decompose_po $entry;

    my %open = (
        DE => "\x{201e}",
        CH => "\x{ab}",
    );
    my %closed = (
        DE => "\x{201c}",
        CH => "\x{bb}",
    );

    my $open_quote = $open{$country} || $open{DE};
    my $closed_quote = $closed{$country} || $open{DE};

    my $dirty;
    foreach my $msg (@msgstrs) {
        $msg =~ s/(\w)'(\w)/$1\x{2019}$2/;
        $msg =~ s/(["'])(.*?)\1/${open_quote}$2${closed_quote}/g;
        $msg =~ s/($open{DE})(.*?)$closed{DE}/${open_quote}$2${closed_quote}/g;
    }

    return compose_po $entry, @msgstrs;
}

sub _swiss_sharp_s {
    my ($entry, $country) = @_;

    my $msgid = $entry->dequote($entry->msgid);
    return 1 if $msgid eq '';

    my @msgstrs = decompose_po $entry;

    my $dirty;
    foreach my $msg (@msgstrs) {
        $msg =~ s/\x{df}/ss/;
    }

    return compose_po $entry, @msgstrs;
}

sub american_english_handler {
    return _english_quotes shift, 'US';
}

sub british_english_handler {
    return _english_quotes shift, 'GB';
}

sub _alpine_german {
    my ($entry) = @_;
 
    unless ($alpine_entries) {
        $alpine_entries = Locale::PO->load_file_asarray('de.po')
            or die "cannot read file 'de.po': $!\n";
    }

    my $msgid = $entry->dequote($entry->msgid);
    return unless length $msgid;

    # Already translated?
    my @msgstrs = decompose_po $entry;
    return if length $msgstrs[0];

    # Get the German translation for it.
    undef @msgstrs;
    foreach my $alpine_entry (@$alpine_entries) {
        my $alpine_msgid = $alpine_entry->dequote($alpine_entry->msgid);
        next if $alpine_msgid ne $msgid;
        my $alpine_msgctxt = $alpine_entry->msgctxt;
        next if $alpine_msgctxt ne $entry->msgctxt;
        @msgstrs = decompose_po $alpine_entry;
        return if !length $msgstrs[0];
    }
    return unless @msgstrs;

    foreach my $msgstr (@msgstrs) {
        $msgstr =~ s/$german_to_alpine_re/$german_to_alpine->{$1}/gs;
    }

    my $dirty = compose_po $entry, @msgstrs;

    return if !$dirty;

    return 1;
}

sub austrian_german_handler {
    my ($entry) = @_;

    my $dirty = _alpine_german $entry, 'AT';
    $dirty = 1 if _german_quotes $entry, 'AT';

    return if !$dirty;

    return 1;
}

sub swiss_german_handler {
    my ($entry) = @_;

    my $dirty = _alpine_german $entry, 'CH';
    $dirty = 1 if _german_quotes $entry, 'CH';
    $dirty = 1 if _swiss_sharp_s $entry, 'CH';

    return if !$dirty;

    return 1;
}

sub german_handler {
    return _german_quotes shift, 'DE';
}

sub display_usage {
    print <<EOF;
Usage: $0 [OPTIONS]
Mandatory arguments to long options, are mandatory to short options, too.

  -l, --language=LANGUAGE     The translations are in language LANGUAGE
  -i, --input=INPUT           Read input from file INPUT
  -o, --output=OUTPUT         Write output to file OUTPUT
  -h, --help                  Display this help and exit
  -v, --verbose               Display progress on standard error

Reads a PO file and writes it back after some language-dependent
cosmetic corrections.
EOF
}

sub usage_error {
    my $message = shift;
    if ($message) {
        $message =~ s/\s+$//;
        $message = "$0: $message\n";
    } else {
        $message = '';
    }
    die <<EOF;
${message}Usage: $0 [OPTIONS]
Try '$0 --help' for more information!
EOF
}

