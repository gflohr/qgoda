#! /usr/bin/env perl

use strict;

sub usage_error;
sub display_usage;
sub display_version;

use Getopt::Long;

use Qgoda;
use Locale::TextDomain qw(com.cantanea.qgoda);

my %options;
GetOptions (
            'w|watch' => \$options{watch},
            'q|quiet' => \$options{quiet},
	    'h|help' => \$options{help},
	    'v|verbose' => \$options{verbose},
            'V|version' => \$options{version}
	    ) or exit 1;

display_usage if $options{help};
display_version if $options{version};

my $method = $options{watch} ? 'watch' : 'build';
Qgoda->new(%options)->$method;

sub display_usage {
    my $msg = __x('Usage: {program} [OPTIONS]
Mandatory arguments to long options, are mandatory to short options, too.

Operation mode:
  -w, --watch                 watch for changes
  -q, --quiet                 quiet mode
  -v, --verbose               display progress on standard error

Informative output:
  -h, --help                  display this help and exit
  -V, --version               output version information and exit

The Qgoda static site generator renders your site by default into the
directory "_site" inside the current working directory.
', program => $0);

    print $msg;

    exit 0;
}

sub usage_error {
    my $message = shift;
    if ($message) {
        $message =~ s/\s+$//;
        $message = "$0: $message\n";
    }
    else {
        $message = '';
    }
    die <<EOF;
${message}Usage: $0 [OPTIONS]
Try '$0 --help' for more information!
EOF
}

sub display_version {
    my $msg = __x('{program} (Qgoda static site generator) {version}
Copyright (C) {years} Cantanea EOOD (http://www.cantanea.com/).
License GPLv3+: GNU GPL version 3 or later <http://gnu.org/licenses/gpl.html>
This is free software: you are free to change and redistribute it.
There is NO WARRANTY, to the extent permitted by law.
Written by Guido Flohr (http://www.guido-flohr.net/).
', program => $0, years => 2016, version => $Qgoda::VERSION);

    print $msg;

    exit 0;
}

