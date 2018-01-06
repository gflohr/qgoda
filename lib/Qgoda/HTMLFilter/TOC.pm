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

package Qgoda::HTMLFilter::TOC;

use strict;

use Qgoda;
use Qgoda::Util qw(html_escape slugify empty write_file);
use Locale::TextDomain qw(qgoda);

use base qw(Qgoda::Processor);

sub new {
    my ($class, %args) = @_;

    my $content_tag = exists $args{content_tag} 
        ? $args{content_tag} : 'qgoda-content';
    my $toc_tag = exists $args{toc_tag} 
        ? $args{toc_tag} : 'qgoda-toc';
    my $start = exists $args{start} ? $args{start} : 2;
    my $end = exists $args{end} ? $args{end} : 6;    my $self = {
        __content_tag => $content_tag,
        __toc_tag => $toc_tag,
        __start => $start,
        __end => $end,
        __template => $args{template},
    };

    bless $self, $class;
}

sub start_document {
    my ($self, $chunk, %args) = @_;

    delete $self->{__active};

    return $chunk;
}

sub end_document {
    my ($self, $chunk, %args) = @_;

    delete $self->{__active};

    return $chunk;
}

sub start {
    my ($self, $chunk, %args) = @_;

    if ($args{tagname} eq $self->{__content_tag}) {
        $self->{__active} = 1;
        $self->{__headlines} = [];
        $self->{__slugs} ||= {};
        $self->{__items} = [];
        $self->{__path} = [0];

        return $chunk;
    } elsif ($args{tagname} eq $self->{__toc_tag}) {
        # Normalize.
        return "<$self->{__toc_tag} />";
    }

    return $chunk if !$self->{__active};

    return $chunk if $args{tagname} !~ /^h([[1-9][0-9]*)$/;
    my $level = $1;
    return $chunk if $level < $self->{__start};
    return $chunk if $level > $self->{__end};

    $chunk .= '<qgoda-toc-marker />';

    return $chunk;
}

sub end {
    my ($self, $chunk, %args) = @_;

    if ($args{tagname} eq $self->{__content_tag}) {
        return '' if !$self->{__active};
        $self->{__active} = 0;

        return '' if ${$args{output}} !~ m{<$self->{__toc_tag} />};

$DB::single = 1;
        my $toc = $self->__generateTOC($args{asset});
        ${$args{output}} =~ s{<$self->{__toc_tag} />}{$toc}g;

        return '';
    }

    return $chunk if !$self->{__active};

    return $chunk if $args{tagname} !~ /^h([[1-9][0-9]*)$/;
    my $hlevel = $1;
    return $chunk if $hlevel < $self->{__start};
    return $chunk if $hlevel > $self->{__end};

    return $chunk if ${$args{output}} !~ s{<qgoda-toc-marker />(.*)}{}s;

    my $text = $1;
    my $level = $hlevel - $self->{__start} + 1;
    my $depth = @{$self->{__path}};

    my $valid = 1;
    if ($depth > $level) {
        foreach ($level .. $depth - 1) {
            pop @{$self->{__path}};
        }
        ++$self->{__path}->[-1];
    } elsif ($depth + 1 == $level) {
        push @{$self->{__path}}, 1;
    } elsif ($depth == $level) {
        ++$self->{__path}->[-1];
    } else {
        undef $valid;
    }

    if ($valid) {
        my $slug = $text;
        $slug =~ s{<.*?>}{}s;
        $slug = html_escape slugify $slug;
        while ($self->{__slugs}->{$slug}) {
            $slug .= '-';
        }
        $self->{__slugs}->{$slug} = 1;
        
        ${$args{output}} .= qq{<a href="#" name="$slug" id="$slug"></a>};
        push @{$self->{__items}}, {
           slug => $slug,
           path => [@{$self->{__path}}],
           text => $text
        };
    }

    ${$args{output}} .= $text;

    return $chunk;
}

sub __deepen {
    my ($self, $items) = @_;

    return [] unless $items && @$items;

    my $root = {
        children => [],
    };

    foreach my $item (@$items) {
        my @path = @{$item->{path}};
        $item->{children} = [];
        my $cursor = $root->{children};
        for (my $i = 0; $i < $#path; ++$i) {
            $cursor = $cursor->[$path[$i] - 1]->{children};
        }
        $cursor->[$path[-1] - 1] = $item;
    }

    foreach my $item (@$items) {
        delete $item->{children} if !@{$item->{children}};
    }

    return $root->{children};
}

sub __generateTOC {
    my ($self, $asset) = @_;

    my $root = $self->__deepen($self->{__items});

    return '' if !@$root;

    my $template = $self->{__template};
    if (empty $template) {
        $template = $self->__generateDefaultTemplate;
    }

    my $qgoda = Qgoda->new;
    my $processor = $qgoda->getProcessor('Qgoda::Processor::TT2');
    my $content = qq{[% INCLUDE $template %]};
    $asset->{toc} = $root;

    return $processor->process($content, $asset);
}

sub __generateDefaultTemplate {
    my ($self) = @_;

    my $config = Qgoda->new->config;

    my $template = 'components/toc.html';
    my $template_file = File::Spec->catfile($config->{paths}->{views},
                                            $template);
    return $template if -e $template_file;
    my $level_template_file = File::Spec->catfile($config->{paths}->{views},
                                                  'components/toc/level.html');
    
    my $logger = Qgoda->new->logger;
    $logger->warning(__x("writing default template '{template}'",
                         template => $level_template_file));
    my ($code, $level_code) = split "===\n", join '', <DATA>;
    if (!write_file $level_template_file, $level_code) {
        die __x("error writing template file '{template}': {error}\n",
                template => $level_template_file, error => $!);
    }
    $logger->warning(__x("writing default template '{template}'",
                         template => $template_file));
    if (!write_file $template_file, $code) {
        die __x("error writing template file '{template}': {error}\n",
                template => $template_file, error => $!);
    }

    return $template;
}

1;

__DATA__
[% USE gtx = Gettext(config.po.textdomain, asset.lingua) %]
[% IF asset.toc.size %]
<div class="toc">
  <div class="toc-title">[% gtx.gettext('Table Of Contents') %]</div>
  [% INCLUDE components/toc/level.html 
      items = asset.toc
      depth = 1 %]
</div>
[% END %]
===
<ul class="toclevel-[% depth %]">
[% FOREACH item IN items %]
  <li class="toclevel-[% depth %]">
    [% item.path.join('.') %]
    <a href="#[% item.slug %]">[% item.text %]</a>
    [% IF item.children %]
      [% INCLUDE components/toc/level.html
           items = item.children
           depth = depth + 1 %]
    [% END %]
  </li>
[% END %]
</ul>
