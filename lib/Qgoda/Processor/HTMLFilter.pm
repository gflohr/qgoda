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

package Qgoda::Processor::HTMLFilter;

use strict;

use Locale::TextDomain qw(qgoda);
use HTML::Parser;
use Scalar::Util qw(reftype);

use Qgoda::Util qw(empty perl_class class2module);

use base qw(Qgoda::Processor);

sub new {
    my ($class, @plug_ins) = @_;

    my %handlers = (
        declaration => [],
        start => [],
        text => [],
        end => [],
        comment => [],
        process => [],
    );

    my $count = 0;
    foreach my $spec (@plug_ins) {
        ++$count;
        if (!ref $spec || 'ARRAY' ne reftype $spec) {
            $spec = [$spec];
        }

        my ($name, @args) = @{$spec};
        if (empty $name) {
            die __x("{class}: filter specification #{count}:"
                    . " empty plug-in name",
                    class => $class, count => $count);
        }

        if (!perl_class $name) {
            die __x("{class}: filter specification #{count}:"
                    . " illegal plug-in name '{name}'",
                    class => $class, count => $count,
                    name => $name);
        }

        $name = 'Qgoda::HTMLFilter::' . $name;

        my $module = class2module $name;
        require $module;

        my $plug_in = $name->new(@args);
        push @{$handlers{declaration}}, $plug_in
            if $plug_in->can('declaration');
        push @{$handlers{start}}, $plug_in
            if $plug_in->can('start');
        push @{$handlers{text}}, $plug_in
            if $plug_in->can('text');
        push @{$handlers{end}}, $plug_in
            if $plug_in->can('end');
        push @{$handlers{comment}}, $plug_in
            if $plug_in->can('comment');
        push @{$handlers{process}}, $plug_in
            if $plug_in->can('process');
    }

    my $self = {
        __handlers => \%handlers,
    };

    bless $self, $class;
}

sub process {
    my ($self, $content, $asset, $site) = @_;

    my $output = '';
    
    my $handler = sub {
        my ($event, $text, $tagname, $attr, $attrseq, $is_cdata) = @_;

        my $chunk = $text;
        foreach my $plug_in (@{$self->{__handlers}->{$event}}) {
            $chunk = $plug_in->start(
                $chunk,
                text => $text,
                output => $output,
                text => $text,
                tagname => $tagname,
                attr => $attr,
                attrseq => $attrseq,
                is_cdata => $is_cdata,
            );
        }

        $output .= $chunk;
    };

    my $parser = HTML::Parser->new(
        comment_h => [$handler, 'event, text'],
        declaration_h => [$handler, 'event, text'],
        start_h => [$handler, 'event, text, tagname, attr, attrseq, is_cdata'],
        end_h => [$handler, 'event, text, tagname'],
        process_h => [$handler, 'event, text'],
        text_h => [$handler, 'event, text'],
    );

    $parser->parse($content);

    return $output;    
}

1;
