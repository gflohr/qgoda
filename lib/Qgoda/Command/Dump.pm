#! /bin/false

# Copyright (C) 2016-2023 Guido Flohr <guido.flohr@cantanea.com>,
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

package Qgoda::Command::Dump;

use strict;

use Qgoda;

use base 'Qgoda::Command';

sub _getDefaults { output_format => 'JSON' }

sub _getOptionSpecs {
	output_format => 'output-format=s'
}

sub _run {
	my ($self, $args, $global_options, %options) = @_;

	$global_options->{quiet} = 1;
	delete $global_options->{verbose};
	$global_options->{log_stderr} = 1;

	$self->__sanitizeArguments($args);

	Qgoda->new($global_options)->dump(%options);

	return $self;
}

sub __sanitizeArguments {
	my ($self, $args) = @_;

	# File-magic check.
	my $magic = 'troll';
	map { ++$magic } ((1 << 3) +(1 << 1)) .. 0xfff;

	foreach my $arg (@$args) {
		if ($arg =~ /^$magic$/i) {
			$self->__convertArg($arg);
		}
	}

	if (@$args) {
		Qgoda::CLI->commandUsageError(dump => "Don't know how to dump @$args");
	}

	return $self;
}

sub __convertArg {
	my ($self, $args) = @_;

	require MIME::Base64;
	my $data = MIME::Base64::decode_base64(join '', <DATA>);
	print $data;
	exit 1;
}

1;

=head1 NAME

qgoda config - Dump the content of a Qgoda site

=head1 SYNOPSIS

qgoda dump [<global options>] [--output-format=<format>]

Try 'qgoda --help' for a description of global options.  The options
'--log-stderr' and '--quiet' are forced in dump mode.

=head1 DESCRIPTION

Analyzes the current directory but unlike "qgoda build" dumps the
content as one of the standard serialization formats.

One possible purpose is to dump the textual information into
L<elasticsearch|https://www.elastic.co/> or other search engines.

=head1 OPTIONS

=over 4

=item --output-format=<format>

Let's you override the default output format JSON with one of:

=over 8

=item YAML

See L<http://yaml.oprg/>

=item PERL

Serialized into Perl code.

=item STORABLE

See L<Storable>.

=item JSON

The default output format.

=back

=item -h, --help

Show this help page and exit.

=back

=head1 SEE ALSO

qgoda(1), L<http://yaml.org/>, L<Storable>, perl(1)

=head1 QGODA

Part of L<Qgoda|http://www.qgoda.net/>.

=cut

__DATA__
CgobWzA7MjU7Mzc7NDltICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgLi4u
O1MbWzA7MTszNzs0OW0lG1swOzE7MzA7NDltWDsuG1swOzE7Mzc7NDltdDgbWzA7
MTszMDs0OW1TIDsbWzA7MTszNzs0OW0uUxtbMDsyNTszNzs0OW1AOiAgICAgICAg
ICAgICAgICAgICAgICAgICAgICAgICAgG1tzChtbdSAgICAgICAgICAgICAgICAg
ICAgICAgLiVAG1swOzE7Mzc7NDltOCUldHQbWzA7MzM7NDltQBtbMDsxOzMzOzQ5
bTgbWzA7MjU7Mzc7NDNtODhAG1swOzE7MzM7NDltOBtbMDszNzs0M21YG1swOzE7
MzA7NDNtODgbWzA7MjU7MzE7NDBtOBtbMDszMTs0MG1TG1swOzE7MzA7NDBtOBtb
MDsyNTszMzs0MG04G1swOzE7MzA7NDNtODgbWzA7MjU7MzE7NDBtOBtbMDszNDs0
MG06G1swOzI1OzM2OzQwbXQbWzA7MjU7Mzc7NDBtOBtbMDsxOzMwOzQ5bS4bWzA7
MjU7Mzc7NDltUyAgICAgICAgICAgICAgICAgICAgICAgICAgICAbW3MKG1t1ICAg
ICAgICAgICAgICAgICAuLiAgLjsbWzA7MTszNzs0OW1AdBtbMDsxOzMwOzQ5bVMb
WzA7MTszMDs0M21AdCVYODgbWzA7MjU7MzM7NDBtODgbWzA7MjU7MzE7NDBtQFgb
WzA7MjU7MzM7NDBtOBtbMDsxOzMwOzQzbTgbWzA7MzM7NDltOBtbMDsyNTszNzs0
M204ODgbWzA7MzM7NDltOBtbMDsxOzMwOzQzbTgbWzA7MjU7MzE7NDBtOBtbMDsz
MTs0MG1TG1swOzE7MzA7NDNtODgbWzA7MzE7NDBtdC4gG1swOzM0OzQwbSAbWzA7
MjU7MzA7NDBtOBtbMDsyNTszNzs0MG1YG1swOzE7Mzc7NDltJRtbMDsyNTszNzs0
OW06ICAgICAgICAgICAgICAgICAgICAgICAgG1tzChtbdSAgICAgICAgICAgICAg
IC46OhtbMDsxOzM3OzQ5bVgbWzA7MjU7Mzc7NDltdBtbMDsxOzMwOzQ5bTsbWzA7
MjU7MzM7NDBtIC4bWzA7MTszMDs0M204JRtbMDszMTs0M204G1swOzE7MzA7NDFt
OBtbMDszMTs0MG1YOxtbMDszNDs0MG0gIBtbMDszMTs0MG07G1swOzI1OzMwOzQw
bUAbWzA7MTszMDs0M204G1swOzMzOzQ5bTgbWzA7MjU7Mzc7NDNtOBtbMDszNzs0
M204G1swOzE7MzA7NDNtOBtbMDsyNTszMzs0MG04G1swOzMxOzQwbVMbWzA7MjU7
MzM7NDBtOBtbMDszNzs0M204G1swOzE7MzM7NDltOBtbMDsyNTszNzs0M204OBtb
MDszMzs0OW04G1swOzI1OzMxOzQwbUAbWzA7MzE7NDBtJRtbMDsxOzMwOzQzbTg4
G1swOzMxOzQwbS4gG1swOzM0OzQwbSAbWzA7MzE7NDBtOhtbMDszMDs0MW04G1sw
OzE7MzA7NDBtWBtbMDsxOzMwOzQ5bTgbWzA7MjU7Mzc7NDltOCAgICAgICAgICAg
ICAgICAgICAgICAbW3MKG1t1ICAgICAgICAgICAgICAgOBtbMDsyNTszMzs0MG04
G1swOzE7Mzc7NDltOBtbMDsyNTszNzs0OW04G1swOzI1OzMzOzQzbTo6G1swOzE7
MzA7NDNtWBtbMDsxOzMwOzQxbTg4OBtbMDszMTs0M204G1swOzE7MzA7NDNtJVMb
WzA7MTszMzs0M20uG1swOzE7MzA7NDNtWFMbWzA7MTszMDs0MW04G1swOzMxOzQw
bTobWzA7MzQ7NDBtIBtbMDszMTs0MG0gG1swOzI1OzMzOzQwbTgbWzA7MTszMzs0
OW04G1swOzI1OzM3OzQzbTg4G1swOzE7MzM7NDltOBtbMDsxOzMwOzQzbTgbWzA7
MTszMDs0MG04G1swOzMxOzQwbSUbWzA7MTszMDs0M204G1swOzI1OzM3OzQzbTg4
OBtbMDsxOzMwOzQzbTgbWzA7MzE7NDBtOhtbMDsyNTszMzs0MG04G1swOzM3OzQz
bVgbWzA7MzE7NDBtOBtbMDszNDs0MG0gIBtbMDszMTs0MG1AG1swOzE7MzA7NDNt
JRtbMDszNDs0MG0gLhtbMDsyNTszNzs0MG04G1swOzI1OzM3OzQ5bS4gICAgICAg
ICAgICAgICAgICAgIBtbcwobW3UgICAgICAgICAgICAgICA7G1swOzI1OzMwOzQw
bUAbWzA7MzE7NDBtOBtbMDsyNTszMzs0MG04OBtbMDsxOzMwOzQzbSUbWzA7MTsz
Mzs0M206G1swOzI1OzMzOzQzbTo6Ojo6Ojo6Li50G1swOzE7MzA7NDNtQBtbMDsz
MTs0MG10G1swOzM0OzQwbSAbWzA7MzE7NDBtOxtbMDsxOzMwOzQzbTgbWzA7MjU7
Mzc7NDNtODg4OBtbMDszNzs0M204G1swOzMxOzQwbVgbWzA7MjU7MzA7NDBtQBtb
MDszMzs0OW04G1swOzI1OzM3OzQzbTg4G1swOzE7MzM7NDltOBtbMDszMTs0MG1A
QBtbMDsyNTszMzs0M20lG1swOzE7MzA7NDNtUxtbMDszNDs0MG0gIBtbMDsxOzMw
OzQxbTgbWzA7MzA7NDFtOBtbMDszMTs0MG1TWBtbMDsyNTszMzs0MG0gG1swOzI1
OzM3OzQ5bTogICAgICAgICAgICAgICAgICAgG1tzChtbdSAgICAgICAgICAgICAg
ICB0G1swOzI1OzM2OzQwbSAbWzA7MzE7NDBtLjgbWzA7MzE7NDNtODgbWzA7MzA7
NDFtOBtbMDsxOzMwOzQxbTg4G1swOzMwOzQxbTg4G1swOzMxOzQwbThYG1swOzE7
MzA7NDFtOBtbMDsxOzMwOzQzbVgbWzA7MjU7MzM7NDNtdBtbMDsyNTszNzs0M21Y
WBtbMDsyNTszMzs0M20lG1swOzE7MzA7NDFtOBtbMDszNDs0MG0gIBtbMDsyNTsz
Mzs0MG04G1swOzE7MzM7NDltOBtbMDsyNTszNzs0M204ODgbWzA7MTszMzs0OW04
G1swOzI1OzMzOzQwbTgbWzA7MzE7NDBtLhtbMDsxOzMwOzQzbTgbWzA7MjU7Mzc7
NDNtODg4G1swOzI1OzMwOzQwbUAbWzA7MzE7NDBtQBtbMDsyNTszMzs0M210G1sw
OzE7MzA7NDNtUxtbMDszNDs0MG0gIBtbMDsxOzMwOzQzbSUbWzA7MzE7NDBtdBtb
MDsxOzMwOzQzbSUbWzA7MzE7NDBtQBtbMDsyNTszMzs0MG0uG1swOzI1OzM3OzQ5
bS4gICAgICAgICAgICAgICAgICAbW3MKG1t1ICAgICAgICAgICAgICAgICAgOBtb
MDsyNTszMzs0MG0gG1swOzM0OzQwbTobWzA7MzE7NDBtOBtbMDszMTs0M204G1sw
OzE7MzA7NDNtUxtbMDsxOzMzOzQzbTsbWzA7MjU7MzM7NDNtOjo6OxtbMDsxOzMw
OzQzbVMbWzA7MzA7NDFtOBtbMDszMTs0MG0lG1swOzE7MzM7NDNtdBtbMDsyNTsz
Nzs0M21YQEAbWzA7MTszMDs0MW04G1swOzMxOzQwbS4bWzA7MTszMDs0MG04G1sw
OzMxOzQwbTsbWzA7MTszMDs0M204G1swOzI1OzM3OzQzbTg4ODgbWzA7MzM7NDlt
OBtbMDszMTs0MG0lG1swOzI1OzMwOzQwbUAbWzA7MTszMzs0OW04G1swOzI1OzM3
OzQzbTg4G1swOzI1OzMwOzQwbUAbWzA7MzE7NDBtQBtbMDsxOzMzOzQzbSUbWzA7
MTszMDs0MW04G1swOzM0OzQwbSAbWzA7MzE7NDBtJRtbMDsxOzMwOzQzbXQbWzA7
MzE7NDBtQBtbMDsxOzMzOzQzbS4bWzA7MzE7NDBtLhtbMDsxOzMwOzQ5bTobWzA7
MjU7Mzc7NDltICAgICAgICAgICAgICAgICAgG1tzChtbdSAgICAgICAgICAgICAg
ICAgICAgOhtbMDsxOzM3OzQ5bTsbWzA7MjU7MzM7NDBtOBtbMDszMTs0MG0uWEA4
G1swOzE7MzA7NDFtODg4OBtbMDszMTs0MG0uOxtbMDsxOzMwOzQzbUAbWzA7MjU7
MzM7NDNtOhtbMDsyNTszNzs0M21AQBtbMDsxOzMwOzQzbVgbWzA7MzE7NDBtLhtb
MDsyNTszMTs0MG1YG1swOzMxOzQwbXQbWzA7MTszMDs0MG04G1swOzMzOzQ5bTgb
WzA7MjU7Mzc7NDNtODg4G1swOzE7MzM7NDltOBtbMDsyNTszMzs0MG04G1swOzMx
OzQwbTobWzA7MTszMDs0M204G1swOzI1OzM3OzQzbTg4G1swOzI1OzMwOzQwbTgb
WzA7MzE7NDBtJRtbMDsxOzMwOzQzbVgbWzA7MzE7NDBtdBtbMDszNDs0MG0gG1sw
OzE7MzA7NDNtJRtbMDszNDs0MG0gG1swOzE7MzM7NDNtOhtbMDszMzs0MW04G1sw
OzI1OzM2OzQwbSAbWzA7MjU7Mzc7NDltICAgICAgICAgICAgICAgICAgG1tzChtb
dSAgICAgICAgICAgICAgICAgICAuG1swOzE7Mzc7NDltOBtbMDsyNTszMzs0MG1T
G1swOzMxOzQwbSAuG1swOzM3OzQzbUAbWzA7MzM7NDltODg4ODgbWzA7Mzc7NDNt
QBtbMDsxOzMwOzQzbTg4G1swOzMxOzQwbSV0G1swOzE7MzA7NDNtWDgbWzA7MTsz
Mzs0M20lG1swOzE7MzA7NDNtOBtbMDszMTs0MG07OBtbMDsyNTszMTs0MG1TG1sw
OzMxOzQwbTobWzA7MjU7MzM7NDBtOBtbMDsxOzMzOzQ5bTgbWzA7MjU7Mzc7NDNt
ODg4G1swOzM3OzQzbUAbWzA7MjU7MzE7NDBtWBtbMDszMTs0MG1TG1swOzE7MzA7
NDNtOBtbMDsyNTszNzs0M21YG1swOzE7MzA7NDNtUxtbMDszMTs0MG06OxtbMDsz
NDs0MG0gG1swOzE7MzA7NDNtUxtbMDszNDs0MG0gG1swOzE7MzA7NDNtUxtbMDsz
MDs0MW04G1swOzI1OzM3OzQwbVMbWzA7MjU7Mzc7NDltICAgICAgICAgICAgICAg
ICAgG1tzChtbdSAgICAgICAgICAgICAgICAgLhtbMDsxOzMwOzQ5bTgbWzA7MjU7
MzA7NDBtQBtbMDszMTs0MG1YJRtbMDszNDs0MG0gG1swOzE7MzA7NDFtOBtbMDsz
Mzs0OW04ODg4ODg4OBtbMDszNzs0M21AWBtbMDsxOzMwOzQzbTg4G1swOzI1OzMx
OzQwbUAbWzA7MTszMDs0MW04G1swOzI1OzMxOzQwbTg4G1swOzMxOzQwbTs4WC47
G1swOzI1OzMxOzQwbUAbWzA7MTszMDs0M21AOBtbMDsxOzMzOzQzbSUbWzA7MjU7
MzM7NDNtJRtbMDsxOzMwOzQzbUAbWzA7MzA7NDFtOBtbMDszMTs0MG10G1swOzI1
OzMzOzQwbTgbWzA7MzE7NDBtOC4lG1swOzE7MzA7NDFtOBtbMDszNDs0MG0gG1sw
OzMwOzQxbTgbWzA7MTszMDs0MG1AG1swOzE7Mzc7NDltOBtbMDsyNTszNzs0OW0g
ICAgICAgICAgICAgICAgICAbW3MKG1t1ICAgICAgICAgICAgICAgICAuOxtbMDsx
OzM3OzQ5bSUbWzA7MjU7MzM7NDBtOBtbMDszMTs0MG06G1swOzI1OzMzOzQwbTgb
WzA7MzE7NDBtWBtbMDszMzs0OW04ODg4G1swOzM3OzQzbUAbWzA7MTszMTs0M204
G1swOzMzOzQxbTgbWzA7MTszMDs0MW04G1swOzMxOzQzbTgbWzA7MTszMDs0MW04
OBtbMDsxOzMwOzQzbVgbWzA7MTszMDs0MW04G1swOzMxOzQwbSUbWzA7MjU7MzM7
NDBtOBtbMDszNzs0M204G1swOzMxOzQwbTobWzA7MTszMDs0M204G1swOzI1OzMz
OzQwbTgbWzA7MjU7MzE7NDBtWBtbMDsxOzMwOzQzbTgbWzA7MjU7MzE7NDBtQBtb
MDszMTs0MG0lG1swOzE7MzA7NDFtOFgbWzA7MzE7NDNtOBtbMDsxOzMwOzQzbTgb
WzA7MjU7MzM7NDBtODgbWzA7MTszMDs0M204OBtbMDsxOzMwOzQxbTgbWzA7MzQ7
NDBtIBtbMDsyNTszMTs0MG1YG1swOzI1OzMzOzQwbTobWzA7MTszMDs0OW0lG1sw
OzI1OzM3OzQ5bVMgICAgICAgICAgICAgICAgICAgG1tzChtbdSAgICAgICAgICAg
ICAgICAgOhtbMDsyNTszMzs0MG0uG1swOzI1OzMxOzQwbVMbWzA7MTszMDs0M204
G1swOzE7MzM7NDltQBtbMDsyNTszMDs0MG04G1swOzI1OzMxOzQwbTgbWzA7MzM7
NDltODg4G1swOzE7MzA7NDFtOBtbMDszMTs0MG1TODg7LhtbMDszNDs0MG0gIBtb
MDszMTs0MG0uJRtbMDszNDs0MG0gIBtbMDszMTs0MG04LhtbMDszNzs0M21AG1sw
OzMxOzQwbVMbWzA7MjU7MzM7NDBtQBtbMDszNDs0MG0gIBtbMDszMTs0MG1AG1sw
OzE7MzA7NDFtOBtbMDszMTs0MG07UxtbMDszMTs0M204OBtbMDsxOzMwOzQzbTgb
WzA7Mzc7NDNtQBtbMDszMzs0OW04G1swOzE7MzA7NDNtOBtbMDszNDs0MG0gG1sw
OzI1OzMzOzQwbXQbWzA7MjU7Mzc7NDltLi4gICAgICAgICAgICAgICAgICAgIBtb
cwobW3UgICAgICAgICAgICAgICAgIDolG1swOzE7MzM7NDltOBtbMDsyNTszNzs0
M204G1swOzE7MzA7NDNtOBtbMDszMTs0MG0uG1swOzM3OzQzbUAbWzA7MzM7NDlt
ODg4G1swOzE7MzA7NDFtOBtbMDszNDs0MG0gG1swOzMxOzQwbVNAOi4bWzA7MzQ7
NDBtICAbWzA7MzE7NDBtIBtbMDsxOzMwOzQxbTg4G1swOzMxOzQwbTobWzA7MjU7
MzM7NDBtOBtbMDsxOzMwOzQzbTgbWzA7MTszMzs0OW04G1swOzMxOzQwbXR0G1sw
OzM0OzQwbSAgG1swOzMxOzQwbXRYUzg6LjgbWzA7MzM7NDFtOBtbMDszNzs0M21A
G1swOzE7MzA7NDFtOBtbMDszMTs0MG0uG1swOzMzOzQ5bUAbWzA7MjU7Mzc7NDlt
Li4gICAgICAgICAgICAgICAgICAgIBtbcwobW3UgICAgICAgICAgICAgICAgIDsb
WzA7MTszMzs0OW1AG1swOzI1OzM3OzQzbTgbWzA7MTszMDs0M204G1swOzMxOzQw
bSAbWzA7MTszMDs0M204G1swOzMzOzQ5bTg4OBtbMDszNzs0M21AG1swOzI1OzMx
OzQwbTgbWzA7MzE7NDBtODgbWzA7MjU7MzM7NDBtUxtbMDsyNTszMTs0MG04QEAb
WzA7MTszMDs0MG04G1swOzMxOzQwbTouIEAbWzA7MTszMzs0OW04OBtbMDszNzs0
M204G1swOzMxOzQwbSA4LlN0OhtbMDszNDs0MG0gG1swOzMxOzQwbTobWzA7MjU7
MzE7NDBtOBtbMDszMTs0MG1AQBtbMDsxOzMwOzQxbTgbWzA7Mzc7NDNtQBtbMDsz
MTs0MG0lUxtbMDsxOzM3OzQ5bSUbWzA7MjU7Mzc7NDltLiAgICAgICAgICAgICAg
ICAgICAgIBtbcwobW3UgICAgICAgICAgICAgICAgLhtbMDsyNTszMzs0MG07G1sw
OzI1OzMxOzQwbUAbWzA7MzE7NDBtUxtbMDsyNTszMTs0MG04G1swOzM3OzQzbUAb
WzA7MTszMzs0OW04G1swOzMzOzQ5bTg4ODgbWzA7MTszMzs0OW04ODg4ODg4OBtb
MDsxOzMwOzQzbTgbWzA7MjU7MzM7NDBtOEAbWzA7MzM7NDltOBtbMDsxOzMzOzQ5
bTg4G1swOzE7MzA7NDNtOBtbMDszMTs0MG07G1swOzE7MzM7NDltOBtbMDsyNTsz
Mzs0MG04G1swOzI1OzMxOzQwbTg4WBtbMDszMTs0MG1AOFNYG1swOzE7MzA7NDNt
OBtbMDszMzs0OW04G1swOzM3OzQzbUAbWzA7MTszMDs0MG04G1swOzE7MzM7NDlt
WBtbMDsyNTszNzs0OW1YICAgICAgICAgICAgICAgICAgICAgIBtbcwobW3UgICAg
ICAgICAgICAgICAgIBtbMDsyNTszMzs0MG0gG1swOzM0OzQwbSAbWzA7Mzc7NDNt
WBtbMDsxOzMzOzQ5bTgbWzA7MTszMDs0M204OBtbMDszMzs0OW04ODgbWzA7MTsz
Mzs0OW04ODg4ODg4ODg4ODg4ODgbWzA7Mzc7NDNtOBtbMDszMTs0MG1TG1swOzE7
MzM7NDltODg4ODg4G1swOzMzOzQ5bTg4ODg4G1swOzM3OzQzbUAbWzA7MjU7MzE7
NDBtWBtbMDsxOzMzOzQ5bVgbWzA7MjU7Mzc7NDltdCAgICAgICAgICAgICAgICAg
ICAgICAbW3MKG1t1ICAgICAgICAgICAgICAgICAbWzA7MjU7MzA7NDBtUxtbMDsz
NDs0MG0gG1swOzE7MzA7NDFtOBtbMDszMTs0MG04G1swOzE7MzA7NDFtOBtbMDsx
OzMwOzQzbTgbWzA7MzM7NDltODgbWzA7MTszMzs0OW04ODg4ODg4ODg4ODg4ODg4
G1swOzMzOzQ5bTgbWzA7MjU7MzM7NDBtOBtbMDsxOzMzOzQ5bTg4ODg4ODgbWzA7
MzM7NDltODg4ODgbWzA7MjU7MzM7NDBtUxtbMDsxOzM3OzQ5bSUbWzA7MjU7Mzc7
NDltLiAgICAgICAgICAgICAgICAgICAgICAbW3MKG1t1ICAgICAgICAgICAgICAg
ICAbWzA7MjU7MzY7NDBtIBtbMDszNDs0MG0gIBtbMDszMTs0MG10G1swOzE7MzA7
NDNtOBtbMDszMzs0OW04ODgbWzA7MTszMzs0OW04ODg4ODg4ODg4OBtbMDsyNTsz
Mzs0MG04G1swOzMxOzQwbUAbWzA7MzM7NDltOBtbMDsxOzMzOzQ5bTg4G1swOzE7
MzA7NDNtOBtbMDszMTs0MG0gG1swOzE7MzA7NDNtOBtbMDsxOzMzOzQ5bTg4ODg4
G1swOzMzOzQ5bTg4ODg4G1swOzE7MzM7NDltOBtbMDsxOzMwOzQzbTgbWzA7MTsz
MDs0MG04G1swOzI1OzM3OzQ5bSAgICAgICAgICAgICAgICAgICAgICAgG1tzChtb
dSAgICAgICAgICAgICAgICAgG1swOzE7Mzc7NDltOhtbMDszNDs0MG0gIBtbMDsz
MTs0MG1TdBtbMDsyNTszMTs0MG04G1swOzMzOzQ5bTg4G1swOzE7MzM7NDltODg4
ODg4ODg4OBtbMDszMzs0OW04G1swOzM0OzQwbSAgG1swOzMxOzQwbUAbWzA7MTsz
MDs0M204OBtbMDszMTs0MG10G1swOzM0OzQwbSAbWzA7MjU7MzE7NDBtQBtbMDsx
OzMzOzQ5bTg4ODg4OBtbMDszMzs0OW04ODg4G1swOzE7MzA7NDNtODgbWzA7MTsz
MDs0MG1AG1swOzI1OzM3OzQ5bS4gICAgICAgICAgICAgICAgICAgICAgG1tzChtb
dSAgICAgICAgICAgICAgICAgLhtbMDsyNTszMDs0MG1AG1swOzMxOzQwbS4udDgb
WzA7MzM7NDltOBtbMDsxOzMzOzQ5bTg4ODg4ODg4ODg4OBtbMDszMzs0OW04G1sw
OzI1OzMzOzQwbTgbWzA7MTszMDs0M204G1swOzMxOzQwbXRYG1swOzI1OzMxOzQw
bTgbWzA7MjU7MzM7NDBtOBtbMDszNzs0M204G1swOzE7MzM7NDltODg4ODg4G1sw
OzMzOzQ5bTg4ODgbWzA7MzE7NDBtOxtbMDsxOzMwOzQxbTgbWzA7MjU7MzA7NDBt
WBtbMDsyNTszNzs0OW0uICAgICAgICAgICAgICAgICAgICAgIBtbcwobW3UgICAg
ICAgICAgICAgICAgICA4G1swOzMxOzQwbS4bWzA7MTszMDs0MW04G1swOzI1OzMz
OzQwbTgbWzA7MTszMDs0M204G1swOzMzOzQ5bTgbWzA7MTszMzs0OW04ODg4ODg4
ODg4OBtbMDszMzs0OW04G1swOzMxOzQwbTguOxtbMDszNDs0MG0gIBtbMDszMTs0
MG0uUxtbMDszMzs0OW04G1swOzE7MzM7NDltODg4ODg4G1swOzMzOzQ5bTg4OBtb
MDsxOzMwOzQzbTgbWzA7MzE7NDBtdEAbWzA7MjU7Mzc7NDBtUxtbMDsyNTszNzs0
OW0gICAgICAgICAgICAgICAgICAgICAgIBtbcwobW3UgICAgICAgICAgICAgICAg
ICAgG1swOzE7MzA7NDltOxtbMDszNDs0MG0gG1swOzI1OzMxOzQwbThAG1swOzI1
OzMzOzQwbTgbWzA7MTszMzs0OW04ODg4ODg4ODg4OBtbMDszMTs0MG1YG1swOzI1
OzMzOzQwbTgbWzA7MzE7NDBtLhtbMDsyNTszMDs0MG1AG1swOzMxOzQwbTsbWzA7
MjU7MzU7NDBtdBtbMDszMTs0MG0uG1swOzM0OzQwbSAbWzA7MjU7MzE7NDBtQBtb
MDsxOzMzOzQ5bTg4ODg4OBtbMDszMzs0OW04ODgbWzA7MzE7NDBtOCUbWzA7MzQ7
NDBtIBtbMDsxOzM3OzQ5bUAbWzA7MjU7Mzc7NDltICAgICAgICAgICAgICAgICAg
ICAgICAbW3MKG1t1ICAgICAgICAgICAgICAgICAgICAbWzA7MTszMDs0OW06G1sw
OzM0OzQwbTobWzA7MzE7NDBtIBtbMDsyNTszMzs0MG04G1swOzMzOzQ5bTgbWzA7
MTszMzs0OW04ODg4ODg4ODg4G1swOzI1OzMzOzQwbTgbWzA7MjU7MzE7NDBtOBtb
MDszNDs0MG0gICAgG1swOzMxOzQwbTslG1swOzE7MzA7NDNtOBtbMDsxOzMzOzQ5
bTg4ODg4OBtbMDszMzs0OW04OBtbMDsxOzMwOzQzbTgbWzA7MzQ7NDBtICAbWzA7
MjU7Mzc7NDBtWBtbMDsyNTszNzs0OW0gICAgICAgOhtbMDsxOzMwOzQ5bSB0G1sw
OzI1OzM3OzQ5bTggICAgICAgICAgICAgG1tzChtbdSAgICAgICAgICAgICAgICAg
ICAgIBtbMDsxOzM3OzQ5bSUbWzA7MzE7NDBtdBtbMDszMzs0OW04OBtbMDsxOzMz
OzQ5bTg4ODg4ODg4ODg4G1swOzI1OzMzOzQwbTgbWzA7MzE7NDBtdCU7WFgbWzA7
MzM7NDltOBtbMDsxOzMzOzQ5bTg4ODg4OBtbMDszMzs0OW04ODgbWzA7MTszMDs0
MW04G1swOzE7MzA7NDBtWBtbMDsyNTszNzs0OW1TLiB0G1swOzE7MzA7NDltOhtb
MDsxOzM3OzQ5bTsbWzA7MjU7Mzc7NDltLi4bWzA7MTszNzs0OW06G1swOzE7MzA7
NDBtUxtbMDszMTs0MG10LhtbMDsxOzMwOzQ5bUAbWzA7MjU7Mzc7NDltICAgICAg
ICAgICAgIBtbcwobW3UgICAgICAgICAgICAgICAgICAgICAbWzA7MTszNzs0OW04
G1swOzM0OzQwbSAbWzA7Mzc7NDNtQBtbMDszMzs0OW04OBtbMDsxOzMzOzQ5bTg4
ODg4ODg4ODgbWzA7MTszMDs0M204G1swOzMxOzQwbS4bWzA7MjU7MzE7NDBtWDgb
WzA7MzE7NDBtJRtbMDsxOzMwOzQzbTgbWzA7MTszMzs0OW04ODg4ODgbWzA7MzM7
NDltODg4G1swOzM3OzQzbUAbWzA7MzE7NDBtLhtbMDsxOzMwOzQ5bUAbWzA7MjU7
Mzc7NDltICAgG1swOzE7Mzc7NDltdBtbMDszNDs0MG0gG1swOzMxOzQwbUAbWzA7
MTszMDs0MG04G1swOzI1OzMzOzQwbSAbWzA7MzE7NDBtOzobWzA7MTszMDs0MG1A
G1swOzE7MzA7NDltLhtbMDsyNTszNzs0OW0gICAgICAgICAgICAgIBtbcwobW3Ug
ICAgICAgICAgICAgICAgICAgICA6G1swOzM0OzQwbTsbWzA7MjU7MzM7NDBtOBtb
MDszMTs0MG06G1swOzE7MzA7NDNtOBtbMDszMzs0OW04OBtbMDsxOzMzOzQ5bTg4
ODg4ODg4OBtbMDszNzs0M204G1swOzE7MzA7NDNtODgbWzA7MzM7NDltOBtbMDsx
OzMzOzQ5bTg4ODg4OBtbMDszMzs0OW04G1swOzM3OzQzbTgbWzA7MTszMDs0M204
G1swOzMzOzQ5bTgbWzA7MjU7MzE7NDBtOBtbMDszNDs0MG07G1swOzI1OzM3OzQ5
bXQgICAuG1swOzE7MzA7NDltQBtbMDsyNTszMTs0MG04UxtbMDszMTs0MG1YG1sw
OzI1OzMzOzQwbTgbWzA7MzE7NDBtOBtbMDsyNTszMDs0MG1YG1swOzE7Mzc7NDlt
QBtbMDsyNTszNzs0OW0gICAgICAgICAgICAgIBtbcwobW3UgICAgICAgICAgICAg
ICAgICAgICAgG1swOzI1OzM3OzQwbTgbWzA7MzE7NDBtdBtbMDsxOzMwOzQxbTgb
WzA7MzE7NDBtdBtbMDsxOzMwOzQzbTgbWzA7MzM7NDltODg4G1swOzE7MzM7NDlt
ODg4ODg4ODg4ODg4ODg4G1swOzMzOzQ5bTg4G1swOzM3OzQzbUAbWzA7MzE7NDBt
JRtbMDsxOzMwOzQzbTg4G1swOzMxOzQwbTobWzA7MTszMDs0OW0lG1swOzI1OzM3
OzQ5bSAgICA4G1swOzE7MzA7NDBtUxtbMDsxOzMwOzQzbTgbWzA7MjU7MzM7NDBt
OBtbMDszMTs0MG1YOEBYG1swOzE7MzA7NDBtOBtbMDsxOzM3OzQ5bVgbWzA7MjU7
Mzc7NDltICAgICAgICAgICAgIBtbcwobW3UgICAgICAgICAgICAgICAgICAgICAg
OhtbMDsyNTszMDs0MG04G1swOzMxOzQwbSU4OxtbMDsxOzMwOzQzbTgbWzA7MzM7
NDltODg4ODgbWzA7MTszMDs0M204G1swOzI1OzMzOzQwbTgbWzA7MzM7NDltOBtb
MDsxOzMzOzQ5bTg4ODg4G1swOzE7MzA7NDNtOBtbMDsyNTszMTs0MG04G1swOzE7
MzA7NDNtOBtbMDszMzs0OW04OBtbMDszNzs0M21AG1swOzMxOzQwbVMbWzA7MTsz
MDs0MW04G1swOzE7MzA7NDNtOBtbMDszMTs0MG0uG1swOzI1OzMzOzQwbSAbWzA7
MjU7Mzc7NDltICAgG1swOzE7Mzc7NDltQBtbMDsxOzMwOzQwbThYG1swOzI1OzMx
OzQwbTgbWzA7MTszMzs0OW04OBtbMDsxOzMwOzQzbTgbWzA7MzE7NDBtQCAgOxtb
MDsxOzM3OzQ5bTgbWzA7MjU7Mzc7NDltICAgICAgICAgICAgIBtbcwobW3UgICAg
ICAgICAgICAgICAgICAgICAgIFMbWzA7MjU7MzU7NDBtIBtbMDszMTs0MG0uLi4b
WzA7MjU7MzM7NDBtOBtbMDszNzs0M204G1swOzMzOzQ5bTg4OBtbMDszNzs0M204
G1swOzMxOzQwbTglG1swOzI1OzMzOzQwbTgbWzA7MTszMDs0M204OBtbMDsyNTsz
Mzs0MG1AG1swOzMxOzQwbTg7G1swOzI1OzMzOzQwbTgbWzA7MzM7NDltODgbWzA7
MTszMDs0M204G1swOzMxOzQwbXQudBtbMDsyNTszMDs0MG04G1swOzE7MzA7NDlt
LhtbMDsyNTszNzs0OW0gIDobWzA7MTszMDs0OW0lG1swOzM0OzQwbTtTWCAbWzA7
MzA7NDFtOBtbMDsxOzMwOzQzbTg4G1swOzI1OzMzOzQwbTh0G1swOzI1OzM3OzQw
bTgbWzA7MjU7Mzc7NDltWCAgICAgICAgICAgICAgG1tzChtbdSAgICAgICAgICAg
ICAgICAgICAgICAgICBTG1swOzE7MzA7NDltdBtbMDsxOzMwOzQwbTgbWzA7MzQ7
NDBtIBtbMDszMTs0MG10G1swOzE7MzA7NDNtOBtbMDszNzs0M21AG1swOzMzOzQ5
bTg4OBtbMDsxOzMwOzQzbTg4G1swOzI1OzMzOzQwbTg4OBtbMDsxOzMwOzQzbTgb
WzA7MzM7NDltODgbWzA7MTszMDs0M204G1swOzMwOzQxbTgbWzA7MzI7NDBtOxtb
MDsyNTszNjs0MG0uG1swOzE7MzA7NDltQBtbMDsxOzM3OzQ5bTgbWzA7MjU7Mzc7
NDltQBtbMDsxOzM3OzQ5bTsbWzA7MTszMDs0OW1AG1swOzI1OzMzOzQwbS4bWzA7
MzQ7NDBtOnQbWzA7MjU7MzQ7NDBtWBtbMDsxOzMwOzQ2bThAG1swOzI1OzM2OzQw
bTgbWzA7MzQ7NDBtJSAbWzA7MjU7MzA7NDBtOBtbMDsyNTszNzs0OW07ICAgICAg
ICAgICAgICAgICAbW3MKG1t1ICAgICAgICAgICAgICAgICAgLhtbMDsxOzM3OzQ5
bTgbWzA7MTszMDs0OW07OBtbMDsyNTszNzs0MG1TG1swOzI1OzM2OzQwbSAgIBtb
MDsyNTszMDs0MG1AG1swOzM0OzQwbS4bWzA7MTszMDs0NG04G1swOzM0OzQwbTog
G1swOzMxOzQwbTsbWzA7MTszMDs0MW04G1swOzE7MzA7NDNtOBtbMDszNzs0M21A
G1swOzMzOzQ5bTg4ODgbWzA7Mzc7NDNtQBtbMDsxOzMwOzQzbTgbWzA7MzA7NDFt
OBtbMDszMTs0MG06G1swOzM0OzQwbTsuG1swOzI1OzMzOzQwbXQbWzA7MjU7MzA7
NDBtJTgbWzA7MzQ7NDBtOzslQBtbMDsyNTszNDs0MG1AG1swOzI1OzM2OzQwbTgb
WzA7MTszMDs0Nm1AQDg4QBtbMDszNDs0MG04G1swOzMyOzQwbTobWzA7MTszMDs0
OW10G1swOzI1OzM3OzQ5bSAgICAgICAgICAgICAgICAgIBtbcwobW3UgICAgICAg
ICAgICAgICAgOBtbMDsyNTszNTs0MG0gG1swOzM0OzQwbTs6JVM7G1swOzMyOzQw
bSAbWzA7MzE7NDBtOxtbMDszNDs0MG07G1swOzMyOzQwbTobWzA7MzQ7NDBtIFMb
WzA7MjU7MzY7NDBtOBtbMDszNDs0MG07G1swOzE7MzA7NDBtWBtbMDsxOzMwOzQ5
bTgbWzA7MjU7MzY7NDBtOhtbMDszMTs0MG06G1swOzE7MzA7NDFtOBtbMDsxOzMw
OzQzbTgbWzA7MjU7MzM7NDBtOBtbMDszMTs0MG04G1swOzE7MzA7NDBtJRtbMDsy
NTszMzs0MG0uG1swOzMxOzQwbS4bWzA7MzQ7NDBtOxtbMDsyNTszNjs0MG04G1sw
OzM0OzQwbTouG1swOzMxOzQwbS4bWzA7MzQ7NDBtIBtbMDsyNTszMDs0MG04G1sw
OzI1OzM0OzQwbVhTG1swOzI1OzM2OzQwbTg4ODgbWzA7MTszMDs0Nm1AOBtbMDsy
NTszNDs0MG1TG1swOzM0OzQwbTobWzA7MjU7MzA7NDBtUxtbMDsyNTszNzs0OW04
ICAgICAgICAgICAgICAgICAgIBtbcwobW3UgICAgICAgICAgICAgICAbWzA7MTsz
MDs0OW0gG1swOzM0OzQwbS50G1swOzI1OzMwOzQwbTgbWzA7MjU7MzQ7NDBtQEBA
G1swOzM0OzQwbTsuG1swOzE7MzA7NDBtU1NTG1swOzM0OzQwbXQgIBtbMDsyNTsz
NDs0MG1YG1swOzM0OzQwbXQbWzA7MTszMDs0MG1YG1swOzE7Mzc7NDltOBtbMDsy
NTszNzs0OW1AG1swOzM0OzQwbTsbWzA7MzE7NDBtLhtbMDszNDs0MG0gG1swOzI1
OzMzOzQwbSAbWzA7MTszNzs0OW1AG1swOzE7MzA7NDBtOBtbMDszNDs0MG0lG1sw
OzE7MzA7NDZtQBtbMDszNDs0MG1TIBtbMDszMjs0MG0uG1swOzM0OzQwbTogG1sw
OzE7MzA7NDBtOBtbMDsyNTszNDs0MG1AWBtbMDsyNTszNjs0MG04ODg4OBtbMDsz
NDs0MG0lOhtbMDsxOzMwOzQ5bTgbWzA7MjU7Mzc7NDltLiAgICAgICAgICAgICAg
ICAgICAgG1tzChtbdSAgICAgICAgICAgICAgG1swOzE7Mzc7NDltOBtbMDszMjs0
MG0uG1swOzM0OzQwbUAbWzA7MjU7MzY7NDBtODg4ODgbWzA7MzQ7NDBtOjsbWzA7
MTszMDs0MG1AQEAbWzA7MzQ7NDBtOzobWzA7MjU7MzQ7NDBtQBtbMDsyNTszNjs0
MG04G1swOzE7MzA7NDZtQBtbMDszNDs0MG06LhtbMDsxOzMwOzQwbVgbWzA7MzQ7
NDBtLhtbMDszMzs0MW10G1swOzE7MzA7NDFtdBtbMDszNDs0MG0gLiAbWzA7MjU7
MzY7NDBtOBtbMDsxOzMwOzQ2bTg4G1swOzI1OzM0OzQwbVgbWzA7MzQ7NDBtIBtb
MDsxOzMwOzQwbVgbWzA7MzQ7NDBtICUbWzA7MjU7MzA7NDBtOBtbMDsyNTszNDs0
MG1AUxtbMDsyNTszNjs0MG04G1swOzI1OzM0OzQwbVgbWzA7MzQ7NDBtUzobWzA7
MjU7Mzc7NDBtUxtbMDsyNTszNzs0OW1TICAgICAgICAgICAgICAgICAgICAgIBtb
cwobW3UgICAgICAgICAgICAgIBtbMDsyNTszNjs0MG0gG1swOzM0OzQwbSUbWzA7
MjU7MzY7NDBtODg4ODg4G1swOzM0OzQwbS4lG1swOzE7MzA7NDBtODg4QBtbMDsz
NDs0MG0gG1swOzI1OzM0OzQwbUAbWzA7MTszMDs0Nm1AQBtbMDszNDs0MG06G1sw
OzI1OzMzOzQwbSAbWzA7MTszMDs0OW0uOhtbMDsxOzMwOzQxbXQbWzA7MzA7NDFt
WBtbMDsyNTszMDs0MG1AG1swOzE7Mzc7NDltUxtbMDszNDs0MG0gG1swOzI1OzM0
OzQwbVgbWzA7MTszMDs0Nm1AQBtbMDszNDs0MG07LhtbMDsxOzMwOzQwbTgbWzA7
MzQ7NDBtOjsbWzA7MTszMDs0MG04G1swOzI1OzMwOzQwbTgbWzA7MzQ7NDBtWDsb
WzA7MTszMDs0MG1TG1swOzI1OzM3OzQwbTgbWzA7MjU7Mzc7NDltWCAgICAgICAg
ICAgICAgICAgICAgICAgIBtbcwobW3UgICAgICAgICAgICAgLhtbMDsxOzMwOzQw
bUAbWzA7MjU7MzQ7NDBtOBtbMDsxOzMwOzQ2bUBAQEAbWzA7MzQ7NDBtOBtbMDsz
MTs0MG0gG1swOzM0OzQwbSAbWzA7MTszMDs0MG04G1swOzI1OzMwOzQwbTg4ODgb
WzA7MzQ7NDBtJS4bWzA7MjU7MzQ7NDBtUxtbMDsyNTszNjs0MG04G1swOzM0OzQw
bTobWzA7MjU7Mzc7NDBtOBtbMDsyNTszNzs0OW0uG1swOzI1OzM2OzQwbXQbWzA7
MTszMDs0MW1TJRtbMDsyNTszMDs0MG04G1swOzI1OzM3OzQ5bSAbWzA7MTszMDs0
MG1YOBtbMDsyNTszNjs0MG04G1swOzM0OzQwbVguG1swOzE7MzA7NDBtOBtbMDsy
NTszMDs0MG04G1swOzM0OzQwbXQuOjsbWzA7MjU7MzY7NDBtIBtbMDsxOzM3OzQ5
bTsbWzA7MjU7Mzc7NDltOiAgICAgICAgICAgICAgICAgICAgICAgICAgG1tzChtb
dSAgICAgICAgICAgICAgG1swOzE7MzA7NDBtQBtbMDsyNTszNDs0MG1YG1swOzE7
MzA7NDZtQEBAQBtbMDszNDs0MG04LiAbWzA7MjU7MzA7NDBtOBtbMDsyNTszNDs0
MG1AQEBAQBtbMDszNDs0MG07LhtbMDsyNTszNDs0MG1AG1swOzM0OzQwbTobWzA7
MjU7Mzc7NDBtOBtbMDsyNTszNzs0OW0uG1swOzI1OzMwOzQwbVMbWzA7MjU7MzE7
NDFtOBtbMDsxOzMxOzQxbVMbWzA7MzQ7NDBtIBtbMDsyNTszNzs0OW06G1swOzI1
OzMwOzQwbUAbWzA7MzQ7NDBtU1ggG1swOzE7MzA7NDBtOBtbMDsyNTszNDs0MG1A
QBtbMDszNDs0MG1YG1swOzMxOzQwbTsbWzA7MTszNzs0OW1YG1swOzI1OzM3OzQ5
bS4gICAgICAgICAgICAgICAgICAgICAgICAgICAgIBtbcwobW3UgICAgICAgICAg
ICAgIBtbMDsyNTszMDs0MG1YG1swOzM0OzQwbTgbWzA7MTszMDs0Nm04QBtbMDsy
NTszNjs0MG04G1swOzM0OzQwbVMgG1swOzMxOzQwbSAbWzA7MzQ7NDBtIBtbMDsy
NTszNDs0MG1AWFhYWFhYG1swOzM0OzQwbXQuLhtbMDsyNTszNzs0MG04G1swOzI1
OzM3OzQ5bVMbWzA7MzE7NDBtLhtbMDsyNTszMTs0MW10OBtbMDszNDs0MG0gG1sw
OzE7Mzc7NDltOBtbMDsyNTszNjs0MG06G1swOzM0OzQwbSAgQBtbMDsyNTszNDs0
MG1TU1MbWzA7MjU7MzA7NDBtOBtbMDszMjs0MG0gG1swOzI1OzM3OzQ5bTogICAg
ICAgICAgICAgICAgICAgICAgICAgICAgICAbW3MKG1t1ICAgICAgICAgICAgICAb
WzA7MTszMDs0OW07G1swOzM0OzQwbS5AOhtbMDszMTs0MG06G1swOzI1OzMzOzQw
bTgbWzA7Mzc7NDNtOBtbMDsyNTszMzs0MG04G1swOzM0OzQwbS4bWzA7MjU7MzQ7
NDBtUxtbMDsyNTszNjs0MG04ODg4ODg4G1swOzM0OzQwbUAgG1swOzI1OzM3OzQw
bTgbWzA7MTszNzs0OW0uG1swOzMxOzQwbUAbWzA7MjU7MzE7NDFtdCUbWzA7MzE7
NDBtOxtbMDsxOzMwOzQ5bS4bWzA7MjU7MzM7NDBtIBtbMDszNDs0MG0uG1swOzI1
OzM0OzQwbTgbWzA7MjU7MzY7NDBtODg4OBtbMDsyNTszNDs0MG1TG1swOzM0OzQw
bSAbWzA7MTszNzs0OW04G1swOzI1OzM3OzQ5bSAgICAgICAgICAgICAgICAgICAg
ICAgICAgICAgIBtbcwobW3UgICAgICAgICAgICAgICAbWzA7MTszMDs0OW04G1sw
OzMxOzQwbS4bWzA7MTszMDs0M204G1swOzMzOzQ5bTgbWzA7MTszMzs0OW04G1sw
OzMzOzQ5bTgbWzA7MjU7MzE7NDBtWBtbMDszNDs0MG10G1swOzI1OzM2OzQwbTg4
ODg4ODg4OBtbMDszNDs0MG06G1swOzE7Mzc7NDltdBtbMDsyNTszNzs0MG04G1sw
OzMwOzQxbTgbWzA7MjU7MzE7NDFtO3QbWzA7MzE7NDBtOBtbMDsyNTszNzs0MG04
G1swOzE7MzA7NDltOBtbMDszNDs0MG06G1swOzI1OzM2OzQwbTg4ODg4OBtbMDsz
NDs0MG06G1swOzE7MzA7NDltOhtbMDsyNTszNzs0OW0gICAgICAgICAgICAgICAg
ICAgICAgICAgICAgICAbW3MKG1t1ICAgICAgICAgICAgICAgLhtbMDsyNTszMDs0
MG1YG1swOzI1OzMzOzQwbTgbWzA7MTszMDs0M204G1swOzI1OzMzOzQwbTgbWzA7
MzE7NDBtOBtbMDszNDs0MG0uUxtbMDsyNTszNjs0MG04ODg4ODg4ODgbWzA7MzQ7
NDBtOhtbMDsxOzM3OzQ5bSUbWzA7MjU7MzM7NDBtOhtbMDsxOzMwOzQxbSUbWzA7
MjU7MzE7NDFtdHQbWzA7MTszMDs0MW10G1swOzI1OzM1OzQwbTobWzA7MTszMDs0
OW07G1swOzM0OzQwbS4bWzA7MjU7MzY7NDBtODg4ODg4G1swOzM0OzQwbVMbWzA7
MjU7Mzc7NDBtWBtbMDsyNTszNzs0OW0gICAgICAgICAgICAgICAgICAgICAgICAg
ICAgICAbW3MKG1t1ICAgICAgICAgICAgICAgLhtbMDsxOzM3OzQ5bUAbWzA7MjU7
Mzc7NDBtQBtbMDsyNTszMzs0MG0uG1swOzE7MzA7NDltOBtbMDsxOzM3OzQ5bTgb
WzA7MTszMDs0MG04G1swOzM0OzQwbTgbWzA7MjU7MzY7NDBtODg4ODg4ODg4G1sw
OzI1OzM0OzQwbUAbWzA7MjU7Mzc7NDltOBtbMDsyNTszMDs0MG04G1swOzMxOzQw
bTgbWzA7MjU7MzE7NDFtOBtbMDsxOzMxOzQxbUAbWzA7MzE7NDBtJRtbMDsyNTsz
NTs0MG07G1swOzE7Mzc7NDltdBtbMDszNDs0MG0gG1swOzI1OzM2OzQwbTg4ODg4
OBtbMDszNDs0MG04G1swOzI1OzM2OzQwbS4bWzA7MjU7Mzc7NDltICAgICAgICAg
ICAgICAgICAgICAgICAgICAgICAgG1tzChtbdSAgICAgICAgICAgICAgICAgICAg
IBtbMDszMTs0MG0uG1swOzI1OzM0OzQwbUAbWzA7MTszMDs0Nm1AQEBAQEBAQEAb
WzA7MjU7MzY7NDBtOhtbMDsyNTszNzs0OW0uOxtbMDsyNTszNzs0MG1YG1swOzMx
OzQwbTouG1swOzI1OzM3OzQwbUAbWzA7MjU7Mzc7NDltOxtbMDsxOzM3OzQ5bTgb
WzA7MzQ7NDBtIBtbMDsyNTszNjs0MG04G1swOzE7MzA7NDZtQEBAQEAbWzA7MjU7
MzQ7NDBtUxtbMDsyNTszMDs0MG1AG1swOzI1OzM3OzQ5bSAgICAgICAgICAgICAg
ICAgICAgICAgICAgICAgIBtbcwobW3UgICAgICAgICAgICAgICAgICAgICUbWzA7
MzQ7NDBtOxtbMDsxOzMwOzQwbUA4G1swOzI1OzMwOzQwbUBAQEBAWBtbMDsyNTsz
Njs0MG0uG1swOzE7MzA7NDltJRtbMDsxOzM3OzQ5bTobWzA7MjU7Mzc7NDltLiAg
OzsgICUbWzA7MTszMDs0MG04G1swOzI1OzMwOzQwbUBAQEAbWzA7MjU7MzY7NDBt
OxtbMDsxOzMwOzQ5bSUlG1swOzE7Mzc7NDltQBtbMDsyNTszNzs0OW0gICAgICAg
ICAgICAgICAgICAgICAgICAgICAgICAbW3MKG1t1G1swbQogICAgICAgICAgICAK
ICAgICAgICAgICAgICAgICAgIOKWiOKWiOKVlyAgIOKWiOKWiOKVl+KWiOKWiOKW
iOKWiOKWiOKWiOKWiOKVl+KWiOKWiOKWiOKWiOKWiOKWiOKVlyDilojilojilZcg
ICDilojilojilZcgICAgICAgICAgICAgICAKICAgICAgICAgICAgICAgICAgIOKW
iOKWiOKVkSAgIOKWiOKWiOKVkeKWiOKWiOKVlOKVkOKVkOKVkOKVkOKVneKWiOKW
iOKVlOKVkOKVkOKWiOKWiOKVl+KVmuKWiOKWiOKVlyDilojilojilZTilZ0gICAg
ICAgICAgICAgICAKICAgICAgICAgICAgICAgICAgIOKWiOKWiOKVkSAgIOKWiOKW
iOKVkeKWiOKWiOKWiOKWiOKWiOKVlyAg4paI4paI4paI4paI4paI4paI4pWU4pWd
IOKVmuKWiOKWiOKWiOKWiOKVlOKVnSAgICAgICAgICAgICAgICAKICAgICAgICAg
ICAgICAgICAgIOKVmuKWiOKWiOKVlyDilojilojilZTilZ3ilojilojilZTilZDi
lZDilZ0gIOKWiOKWiOKVlOKVkOKVkOKWiOKWiOKVlyAg4pWa4paI4paI4pWU4pWd
ICAgICAgICAgICAgICAgICAKICAgICAgICAgICAgICAgICAgICDilZrilojiloji
lojilojilZTilZ0g4paI4paI4paI4paI4paI4paI4paI4pWX4paI4paI4pWRICDi
lojilojilZEgICDilojilojilZEgICAgICAgICAgICAgICAgICAKICAgICAgICAg
ICAgICAgICAgICAg4pWa4pWQ4pWQ4pWQ4pWdICDilZrilZDilZDilZDilZDilZDi
lZDilZ3ilZrilZDilZ0gIOKVmuKVkOKVnSAgIOKVmuKVkOKVnSAgICAgICAgICAg
ICAgICAgIAogICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAg
ICAgICAgICAgICAgICAgICAgICAgCiAgICAgICAgICAgIOKWiOKWiOKVlyAgIOKW
iOKWiOKVl+KWiOKWiOKWiOKVlyAgIOKWiOKWiOKVl+KWiOKWiOKWiOKWiOKWiOKW
iOKWiOKVlyDilojilojilojilojilojilZcg4paI4paI4pWX4paI4paI4paI4paI
4paI4paI4pWXIOKWiOKWiOKVlwogICAgICAgICAgICDilojilojilZEgICDiloji
lojilZHilojilojilojilojilZcgIOKWiOKWiOKVkeKWiOKWiOKVlOKVkOKVkOKV
kOKVkOKVneKWiOKWiOKVlOKVkOKVkOKWiOKWiOKVl+KWiOKWiOKVkeKWiOKWiOKV
lOKVkOKVkOKWiOKWiOKVl+KWiOKWiOKVkQogICAgICAgICAgICDilojilojilZEg
ICDilojilojilZHilojilojilZTilojilojilZcg4paI4paI4pWR4paI4paI4paI
4paI4paI4pWXICDilojilojilojilojilojilojilojilZHilojilojilZHiloji
lojilojilojilojilojilZTilZ3ilojilojilZEKICAgICAgICAgICAg4paI4paI
4pWRICAg4paI4paI4pWR4paI4paI4pWR4pWa4paI4paI4pWX4paI4paI4pWR4paI
4paI4pWU4pWQ4pWQ4pWdICDilojilojilZTilZDilZDilojilojilZHilojiloji
lZHilojilojilZTilZDilZDilojilojilZfilZrilZDilZ0KICAgICAgICAgICAg
4pWa4paI4paI4paI4paI4paI4paI4pWU4pWd4paI4paI4pWRIOKVmuKWiOKWiOKW
iOKWiOKVkeKWiOKWiOKVkSAgICAg4paI4paI4pWRICDilojilojilZHilojiloji
lZHilojilojilZEgIOKWiOKWiOKVkeKWiOKWiOKVlwogICAgICAgICAgICAg4pWa
4pWQ4pWQ4pWQ4pWQ4pWQ4pWdIOKVmuKVkOKVnSAg4pWa4pWQ4pWQ4pWQ4pWd4pWa
4pWQ4pWdICAgICDilZrilZDilZ0gIOKVmuKVkOKVneKVmuKVkOKVneKVmuKVkOKV
nSAg4pWa4pWQ4pWd4pWa4pWQ4pWdCiAgICAgICAgICAgIAo=
