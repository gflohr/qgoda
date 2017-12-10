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

package Qgoda::Splitter;

use strict;

use Locale::TextDomain qw('com.cantanea.qgoda');
use YAML::XS;
use Scalar::Util qw(reftype);

use Qgoda::Util qw(empty front_matter read_body);

sub new {
    my ($class, $path) = @_;

    my $front_matter = front_matter $path;
    if (!defined $front_matter) {
        my $error = $! ? $! : __"no front matter";
        die __x("error reading front matter from '{filename}': {error}\n",
                filename => $path. error => $error);    
    }

    my $meta = YAML::XS::Load($front_matter);
    my %front_lines;
    my $lineno = 1;
    foreach my $line (split /\n/, $front_matter) {
        ++$lineno;
        my $data = eval { YAML::XS::Load($line) };
        if (!$@ && $data && ref $data && 'HASH' eq reftype $data) {
            my @keys = keys %$data;
            foreach my $key (keys %$data) {
                $front_lines{$key} = $lineno if exists $meta->{$key};
            }
        }
    }
    
    my $body = read_body $path, '';
    if (!defined $body) {
        my $error = $! ? $! : __"no body found";
        die __x("error reading body from '{filename}': {error}\n",
                filename => $path. error => $error);    
    }

    my @first =  grep { !empty } split /
                (
                <!--QGODA-XGETTEXT-->(?:.*?)<!--\/QGODA-XGETTEXT-->
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
            my $head = $1 if $chunk =~ s/^([ \011-\015]+)//;        
            my $tail = $1 if $chunk =~ s/([ \011-\015]+)$//;
            push @chunks, $head if !empty $head;
            push @chunks, $chunk if !empty $chunk;
            push @chunks, $tail if !empty $tail;
        }
    }

    my $lineno = 3 + $front_matter =~ y/\n/\n/;
    my @entries;
    foreach my $chunk (@chunks) {
        if ($chunk =~ /[^ \011-\015]+$/) {
            if ($chunk =~ /^<!--QGODA-XGETTEXT-->(.*?)<!--\/QGODA-XGETTEXT-->$/s) {
                push @entries, {
                    text => $1,
                    lineno => $lineno,
                    type => 'block',
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

sub chunks {
    my ($self) = @_;

    map { $_->{text} } grep { 'whitespace' ne $_->{type} } @{$self->{__entries}};
}

sub reassemble {
    my ($self, $callback) = @_;

    my $output = '';
    foreach my $entry (@{$self->{__entries}}) {
        if ('whitespace' eq $entry->{type}) {
            $output .= $entry->{text};
        } elsif ('block' eq $entry->{type}) {
            $output .= "<!--QGODA-XGETTEXT-->"
                . $callback->($entry->{text})
                . "<!--/QGODA-XGETTEXT-->";
        } else {
            $output .= $callback->($entry->{text});
        }
    }

    return $output;
}

1;