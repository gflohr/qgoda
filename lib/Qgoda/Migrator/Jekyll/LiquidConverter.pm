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

package Qgoda::Migrator::Jekyll::LiquidConverter;

use strict;

use Locale::TextDomain qw(qgoda);

use Qgoda;
use Qgoda::Util qw(empty trim);

#use base qw (Qgoda::Migrator::Jekyll::LiquidParser);

sub convert {
    my ($self, $filename, $input, $logger, %options) = @_;

    $options{tt2_start} ||= '[%';
    $options{tt2_end} ||= '%]';

    $self->{__options} = \%options;
    $self->{__logger} = $logger;
    $self->{__output} = '';

    my $lineno = 1 + $options{offset};
    # No need for a stack because there is no nesting.
    my $state = 'INITIAL';
    my $last_token = __"beginning of file";
    my $whitespace = sub {
        while ($input =~ s/^[ \x09-\x0d]*\n//) {
            ++$lineno;
        }
        $input =~ s/^[ \x09-\x0d]*//;
        return if empty $input;

        return 1;
    };

    my $next_char = sub {
        $input =~ s/(.)//;
        return CDATA => $1;
    };

    # Re-quote a double-quoted string.
    my $drequote = sub {
        my ($string) = @_;

        $string =~ s/\\/\\\\/g;

        return qq{"$string"};
    };

    # Re-quote a single-quoted string;
    my $srequote = sub {
        my ($string) = @_;

        $string =~ s/\\/\\\\/g;

        return qq{'$string'};
    };

    my $lexer = sub {
        return '', undef if empty $input;

        if ('INITIAL' eq $state) {
            $input =~ s/([^\n\{]*)//;
            return CDATA => $1 if !empty $1;

            if ($input =~ s/^\n//) {
                ++$lineno;
                return CDATA => "\n";
            } elsif ($input =~ s/^\{\{//) {
                $state = 'OBJECT';
                return SO => '{{';
            } elsif ($input =~ s/^\{\%//) {
                $state = 'TAG';
                return ST => '{%';
            } else {
                return $next_char->();
            }
        } elsif ('TAG' eq $state) {
            $whitespace->() or return '', undef;

            if ($input =~ s/^([-a-zA-Z0-9_]+)//) {
                $state = 'IN-TAG';
                return DIRECTIVE => $1;
            } else {
                return $next_char->();
            }
        } elsif ('IN-TAG' eq $state) {
            $whitespace->() or return '', undef;

            if ($input =~ s/^"(.*?)"//) {
                return DQUOTE => $drequote->($1);
            } elsif ($input =~ s/^'(.*?)'//) {
                return SQUOTE => $srequote->($1);
            } else {
                return $next_char->();
            }
        } else {
            die "unhandled state $state";
        }
    };

    my $lexer_wrapper = sub {
        my ($token, $content) = $lexer->();
        $last_token = $content;

        return $token, $content;
    };

    my $error = sub {
        $state = 0;

        my $location = $last_token;
        $self->logger->error(__x("{filename}:{lineno}: Syntax error at or"
                                 . " near '{location}'!",
                                 filename => $filename,
                                 lineno => $lineno,
                                 location => $location));
    };

    $self->YYParse(yylex => $lexer_wrapper, yyerror => $error);

    # FIXME! Check for errors!
    return $self->{__output};
}

sub addOutput {
    my ($self, $chunk) = @_;

    $self->{__output} .= $chunk;

    return $self;
}

sub startTag {
    my ($self) = @_;

    return $self->{__options}->{tt2_start};
}

sub endTag {
    my ($self) = @_;

    return $self->{__options}->{tt2_end};
}

sub addPlugin {
    my ($self, $plugin) = @_;

    $self->{__plugins}->{$plugin} = 1;

    return $self;
}

sub parse {
    my ($self, $filename) = @_;

    my $logger = $self->logger;
    my $input = read_file $filename
        or $logger->fatal(__x("cannot read '{filename}': {error}"));

    my $lineno = 1;
    my $state = 0;

    my $lexer = sub {
        return '', undef if empty $input;

        if ($state == 0) {
            $input =~ s/([^\n\{]*)//;
            return CDATA => $1 if !empty $1;

            if ("\n" eq $1) {
                ++$lineno;
                return CDATA => "\n";
            } elsif ($input =~ s/^\{\{//) {
                return SE => '{{';
            } elsif ($input =~ s/^\{\%//) {
                return SE => '{%';
            } else {
                die;
            }
        }
    };
    my $error = sub {
        $logger->error(__"Syntax error!\n");
    };

    $self->YYParse(yylex => $lexer, yyerror => $error);
}

sub logger {
    shift->{__logger};
}

1;
