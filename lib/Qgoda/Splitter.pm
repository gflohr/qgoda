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

package Qgoda::Splitter;

use strict;

use Locale::TextDomain qw('qgoda');
use Scalar::Util qw(reftype);

use Qgoda::Util qw(empty front_matter read_body safe_yaml_load);

sub new {
    my ($class, $path) = @_;

    my $front_matter = front_matter $path;
    if (!defined $front_matter) {
        my $error = $! ? $! : __"no front matter";
        die __x("error reading front matter from '{filename}': {error}\n",
                filename => $path. error => $error);    
    }

    my $meta = safe_yaml_load $front_matter;
    my %front_lines;
    my $lineno = 1;
    foreach my $line (split /\n/, $front_matter) {
        ++$lineno;
        my $data = eval { safe_yaml_load $line };
        if (!$@ && $data && ref $data && 'HASH' eq reftype $data) {
            my @keys = keys %$data;
            foreach my $key (keys %$data) {
                $front_lines{$key} = $lineno if exists $meta->{$key};
            }
        }
    }
   
   $DB::single = 1;
    my $body = read_body $path, '';
    if (!defined $body) {
        my $error = $! ? $! : __"no body found";
        die __x("error reading body from '{filename}': {error}\n",
                filename => $path. error => $error);    
    }

    my @first =  grep { !empty } split /
                (
                <qgoda-xgettext>(?:.*?)<\/qgoda-xgettext>
                |
                <qgoda-no-xgettext>(?:.*?)<\/qgoda-no-xgettext>
                |
                [ \011-\015]*
                \n
                [ \011-\015]*
                \n
                [ \011-\015]*
                )
                /sx, $body;

    my @chunks;
    foreach my $chunk (@first) {
        if ($chunk =~ /^[ \011-\015]+$/) {
            push @chunks, $chunk;
        } else {
            my $head = $chunk =~ s/^([ \011-\015]+)// ? $1 : undef;
            my $tail = $chunk =~ s/([ \011-\015]+)$// ? $1 : undef;
            push @chunks, $head if !empty $head;
            push @chunks, $chunk if !empty $chunk;
            push @chunks, $tail if !empty $tail;
        }
    }

    my $lineno = 3 + $front_matter =~ y/\n/\n/;
    my @entries;
    foreach my $chunk (@chunks) {
        if ($chunk =~ /[^ \011-\015]+$/) {
            if ($chunk =~ /^<qgoda-xgettext>(.*?)<\/qgoda-xgettext>$/s) {
                push @entries, {
                    text => $1,
                    lineno => $lineno,
                    type => 'block',
                }
            } elsif ($chunk =~ /^<qgoda-no-xgettext>(.*?)<\/qgoda-no-xgettext>$/s) {
                push @entries, {
                    text => $1,
                    lineno => $lineno,
                    type => 'exclude',
                }
            } else {
                push @entries, {
                    text => $chunk,
                    lineno => $lineno,
                    type => 'paragraph',
                }
            }
        } else {
                push @entries, {
                    text => $chunk,
                    lineno => $lineno,
                    type => 'whitespace',
                }
        }

        $lineno += $chunk =~ y/\n/\n/;
    }

    # Parse HTML comments.  Maybe this should be optional.
    foreach my $entry (@entries) {
        if ($entry->{text} =~ s{^[ \011-\015]*<!--(.*?)-->[ \011-\015]*}{}s) {
            # We only extract message context hints as they are non-standard.
            my $comment = $1;
            if ($comment =~ s{xgettext:msgctxt=(.*)}{}) {
                my $msgctxt = $1;
                $msgctxt =~ s{^[ \011-\015]*}{};
                $msgctxt =~ s{[ \011-\015]*$}{};
                $entry->{msgctxt} = $msgctxt if !empty $msgctxt;
            }

            $comment =~ s{^[ \011-\015]*}{};
            $comment =~ s{[ \011-\015]*$}{};
            
            $entry->{comment} = $comment if !empty $comment;

            # Change to whitespace, if nothing left.
            $entry->{type} = 'whitespace' if empty $entry->{text};
        }
    }

    bless {
        __meta => $meta,
        __body => $body,
        __entries => \@entries,
        __front_lines => \%front_lines
    }, $class;
}

sub meta {
    shift->{__meta};
}

sub metaLineNumber {
    my ($self, $key) = @_;

    return $self->{__front_lines}->{$key} 
        if exists $self->{__front_lines}->{$key};

    return;
}

sub entries {
    my ($self) = @_;

    grep { 'whitespace' ne $_->{type} } 
    grep { 'exclude' ne $_->{type} } 
    @{$self->{__entries}};
}

sub reassemble {
    my ($self, $callback) = @_;

    my $output = '';
    foreach my $entry (@{$self->{__entries}}) {
        if ('whitespace' eq $entry->{type}) {
            $output .= $entry->{text};
        } elsif ('block' eq $entry->{type}) {
            $output .= "<qgoda-xgettext>"
                . $callback->($entry->{text})
                . "</qgoda-xgettext>";
        } elsif ('exclude' eq $entry->{type}) {
            $output .= "<qgoda-no-xgettext>"
                . $callback->($entry->{text})
                . "</qgoda-no-xgettext>";
        } else {
            $output .= $callback->($entry->{text});
        }
    }

    return $output;
}

1;
