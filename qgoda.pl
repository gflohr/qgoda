#! /usr/bin/env perl

use strict;

sub usage_error;
sub display_usage;
sub display_version;

use Getopt::Long;

use Qgoda;
use Locale::TextDomain qw(com.cantanea.qgoda);

my %options;
Getopt::Long::Configure('bundling');
GetOptions (
            'w|watch' => \$options{watch},
            'q|quiet' => \$options{quiet},
            'dump-config' => \$options{dump_config},
	        'h|help' => \$options{help},
	        'v|verbose' => \$options{verbose},
            'V|version' => \$options{version}
	    ) or exit 1;

display_usage if $options{help};
display_version if $options{version};

usage_error __"The options '--dump-config' and '--watch' are mutually exclusve."
    if $options{dump_config} && $options{watch};

my $method;
if ($options{build}) {
	$method = 'build';
} elsif ($options{watch}) {
	$method = 'watch';
} elsif ($options{dump_config}) {
	delete $options{verbose};
	$options{quiet} = 1;
	$method = 'dumpConfig';
} else {
	usage_error __"Nothing to do.";
}

Qgoda->new(%options)->$method;

sub display_usage {
    my $msg = __x(q(Usage: {program} [OPTIONS]
Mandatory arguments to long options, are mandatory to short options, too.

Operation mode:
  -b, --build                 build site and exit
  -w, --watch                 watch for changes and build on demand
  -q, --quiet                 quiet mode
  -v, --verbose               display progress on standard error

Informative output:
      --dump-config           dump the cooked configuration
  -h, --help                  display this help and exit
  -V, --version               output version information and exit

In order to build your site one of the options '--build' or '--watch'
is mandatory.

The Qgoda static site generator renders your site by default into the
directory "_site" inside the current working directory.
), program => $0);

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

