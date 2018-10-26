#! /bin/false

# Copyright (C) 2016-2018 Guido Flohr <guido.flohr@cantanea.com>,
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

package Qgoda::CLI;

use strict;

use IO::Handle;
use Locale::TextDomain qw(qgoda);
use Getopt::Long 2.36 qw(GetOptionsFromArray);

use Qgoda;
use Qgoda::Util qw(perl_class class2module);

sub new {
    my ($class, $argv) = @_;

    $argv ||= [@ARGV];

    my (@args, $cmd);

    # Split arguments into global options like '--verbose', a command,
    # and command-specific options.  We simplify this by stipulating that
    # global options cannot take any arguments.  So the first command-line
    # argument that does not start with a hyphen is the command, the rest
    # are options and arguments for that command.
    while (@$argv) {
        my $arg = shift @$argv;
        if ($arg =~ /^-[-a-zA-Z0-9]/) {
            push @args, $arg;
        } else {
            $cmd = $arg;
            last;
        }
    }

    bless {
        __global_options => \@args,
        __cmd => $cmd,
        __cmd_args => [@$argv],
    }, $class;
}

sub dispatch {
    my ($self) = @_;

    autoflush STDOUT, 1;
    autoflush STDERR, 1;

    my %options;
    Getopt::Long::Configure('bundling');
    {
        local $SIG{__WARN__} = sub {
            $SIG{__WARN__} = 'DEFAULT';
            $self->usageError(shift);
        };

        GetOptionsFromArray($self->{__global_options},
            'log-stderr' => \$options{log_stderr},
            'q|quiet' => \$options{quiet},
            'h|help' => \$options{help},
            'v|verbose' => \$options{verbose},
            'V|version' => \$options{version},
        );
    }

    $self->displayUsage if $options{help};
    $self->displayVersion if $options{version};

    my $cmd = $self->{__cmd}
        or $self->usageError(__"no command given!");
    $cmd =~ s/-/::/g;
    $self->usageError(__x("invalid command name '{command}'",
                          command => $self->{__cmd}))
        if !perl_class $cmd;

    $cmd = join '::', map {
        ucfirst $_;
    } split /::/, $cmd;

    my $class = 'Qgoda::Command::' . $cmd;
    my $module = class2module $class;

    eval { require $module };
    if ($@) {
        if ($@ =~ m{^Can't locate $module in \@INC}) {
            $self->usageError(__x("unknown command '{command}'",
                                  command => $self->{__cmd}));
        } else {
            my $msg = $@;
            chomp $msg;
            die __x("{program}: {command}: {error}\n",
                    program => $0,
                    command => $self->{__cmd},
                    error => $msg);
        }
    }

    return $class->new->run($self->{__cmd_args}, \%options);
}

sub displayUsage {
    my $msg = __x(<<EOF, program => $0);
Usage: {program} COMMAND [OPTIONS]
EOF

    $msg .= "\n";

    $msg .= __<<EOF;
Mandatory arguments to long options, are mandatory to short options, too.
EOF

    $msg .= "\n";

    $msg .= __<<EOF;
The following commands are currently supported:
EOF

    $msg .= "\n";

    $msg .= __<<EOF;
  build                       build site and exit
  watch                       build, then watch for changes and build on demand
  config                      dump the current configuration and exit
  schema                      dump the configuration JSON schema and exit
  init                        initialize a new qgoda site
  dump                        dump the site structure as JSON (implies --quiet)
  markdown                    process Markdown
  xgettext                    extract translatable strings from Markdown
                              files
  po                          various commands for processing translations
EOF

    $msg .= "\n";

    $msg .= __<<EOF;
Operation mode:
  -q, --quiet                 quiet mode
  -v, --verbose               verbosely log what is going on 
      --log-stderr            log to standard error instead of standard out
EOF

    $msg .= "\n";

    $msg .= __<<EOF;
Informative output:
  -h, --help                  display this help and exit
  -V, --version               output version information and exit
EOF

    $msg .= "\n";

    $msg .= __x(<<EOF, program => $0);
Try '{program} --help' for more information or visit
http://www.qgoda.net/en/docs/ for extensive documentation.
EOF

    print $msg;

    exit 0;
}

sub commandUsageError {
    my ($class, $cmd, $message, $usage) = @_;

    if ($message) {
        $message =~ s/\s+$//;
        if (defined $cmd) {
            $message = "$0 $cmd: $message\n";
        } else {
            $message = "$0: $message\n";
        }
    } else {
        $message = '';
    }

    if (defined $usage) {
        $message .= __x(<<EOF, program => $0, command => $cmd, usage => $usage);
Usage: {program} [GLOBAL_OPTIONS] {usage}
Try '{program} {command} --help' for more information!
EOF
    } elsif (defined $cmd) {
        $message .= __x(<<EOF, program => $0, command => $cmd);
Usage: {program} [GLOBAL_OPTIONS] {command} [OPTIONS]
Try '{program} {command} --help' for more information!
EOF
    } else {
        $message .= __x(<<EOF, program => $0);
Usage: {program} [GLOBAL_OPTIONS] COMMAND [OPTIONS]
Try '{program} --help' for more information!
EOF
    }

    die $message;
}

sub usageError {
    my ($class, $message) = @_;

    return $class->commandUsageError(undef, $message);
}

sub displayVersion {
    my $msg = __x('{program} (Qgoda static site generator) {version}
Copyright (C) {years} Cantanea EOOD (http://www.cantanea.com/).
License GPLv3+: GNU GPL version 3 or later <http://gnu.org/licenses/gpl.html>
This is free software: you are free to change and redistribute it.
There is NO WARRANTY, to the extent permitted by law.
Written by Guido Flohr (http://www.guido-flohr.net/).
', program => $0, years => 2016-2018, version => $Qgoda::VERSION);

    print $msg;

    exit 0;
}

1;
