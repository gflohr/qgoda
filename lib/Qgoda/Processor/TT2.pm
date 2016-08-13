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

package Qgoda::Processor::TT2;

use strict;

use Template;
use Locale::TextDomain qw(com.cantanea.qgoda);

use Qgoda::Util qw(empty);

use base qw(Qgoda::Processor);

my %instances;

sub new {
	my ($class, %options) = @_;
	
	my $self = bless {}, $class;
	$self->{__options} = \%options;

    require Qgoda;
    my $qgoda = Qgoda->new;
    my $srcdir = $qgoda->config->{srcdir};
    
    # FIXME! Merge options with those from the configuration!
    $self->{__tt} = Template->new({
        INCLUDE_PATH => [File::Spec->join($srcdir, '_views')],
        PLUGIN_BASE => ['Qgoda::TT2::Plugin'],
    }) or die Template->error;

	return $self;
}

sub process {
	my ($self, $asset, $site, $content) = @_;

    my $view = $asset->{view};
    die __"no view specified" if empty $view;

    my $vars = {
        asset => $asset,
        site => $site,
        config => $site->{config},
    };

    my $cooked;
    if (!empty $asset->{content} && $self->{__options}->{'cook-content'}) {
        $self->{__tt}->process(\$asset->{content}, $vars, \$cooked)
            or die $self->{__tt}->error, "\n" if !defined $cooked;
    	$asset->{content} = $cooked;
    	undef $cooked;
    }
    $self->{__tt}->process($view, $vars, \$cooked)
        or die $self->{__tt}->error, "\n" if !defined $cooked;

    return $cooked;
}

# Reminder for a future xgettext for TT.
#$Template::Parser::DEBUG = 1;
#my %options = (
#    INTERPOLATE => 1,
#    DEBUG => Template::Constants::DEBUG_DIRS(),
#);
#my $vars = { world => 'Guido' };
#my $tt = Template->new({
#    %options,
#    PARSER => Qgoda::Processor::Template::XGettext->new(\%options),
#});
#$tt->process('junk.tt', $vars) or die $tt->error;
#
#package Qgoda::Processor::Template::XGettext;
#
#use base qw(Template::Parser);
#
#sub split_text {
#    my ($self, $text) = @_;
#
#    my $retval = $self->SUPER::split_text($text) or return;
#
#    use Data::Dump;
#    warn Data::Dump::dump($retval);
#
#    return $retval;
#}

1;

=head1 NAME

Qgoda::Processor::TT2 - Qgoda Processor For the Template Toolkit Version 2
