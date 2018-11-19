#! /usr/bin/env perl # -*- perl -*-

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

use common::sense;

BEGIN {
    my $test_dir = __FILE__;
    $test_dir =~ s/[-a-z0-9]+\.t$//i;
    unshift @INC, $test_dir;
}

use Test::More;
use JSON qw(decode_json);
use YAML::XS qw(Load);
use Storable qw(thaw);

use Qgoda;
use Qgoda::Util qw(read_file);
use Qgoda::CLI;

use TestSite;
use MemStream;

my %assets;

$assets{'a'} = {
	name => 'a',
	content => 'this is a'
};
$assets{'b'} = {
	name => 'b',
	content => 'this is b'
};

my $site = TestSite->new(name => 'config-defaults',
	assets => \%assets,
);

my ($stdout, $expected);

$stdout = tie *STDOUT, 'MemStream';
ok (Qgoda::CLI->new(['dump'])->dispatch);
untie *STDOUT;
my $json = decode_json $stdout->buffer;
is ref $json, 'ARRAY';
is 2, @$json;
is 'HASH', ref $json->[0];
is 'HASH', ref $json->[1];
$json = [sort {$a->{name} cmp $b->{name}} @$json];
is 'a', $json->[0]->{name};
is 'b', $json->[1]->{name};

$stdout = tie *STDOUT, 'MemStream';
ok (Qgoda::CLI->new(['dump', '--output-format=json'])->dispatch);
untie *STDOUT;
my $json2 = decode_json $stdout->buffer;
$json2 = [sort {$a->{name} cmp $b->{name}} @$json2];
is_deeply $json2, $json;

$stdout = tie *STDOUT, 'MemStream';
ok (Qgoda::CLI->new(['dump', '--output-format=yaml'])->dispatch);
untie *STDOUT;
my $yaml = Load $stdout->buffer;
$yaml = [sort {$a->{name} cmp $b->{name}} @$yaml];
is_deeply $yaml, $json;

$stdout = tie *STDOUT, 'MemStream';
ok (Qgoda::CLI->new(['dump', '--output-format=storable'])->dispatch);
untie *STDOUT;
my $storable = thaw $stdout->buffer;
$storable = [sort {$a->{name} cmp $b->{name}} @$storable];
is_deeply $storable, $json;

$stdout = tie *STDOUT, 'MemStream';
ok (Qgoda::CLI->new(['dump', '--output-format', 'perl'])->dispatch);
untie *STDOUT;
my $Qgoda1;
my $perl = eval $stdout->buffer;
$perl = [sort {$a->{name} cmp $b->{name}} @$perl];
is_deeply $storable, $json;

eval { Qgoda::CLI->new(['dump', '--output-format', 'python'])->dispatch };
ok $@;

$site->tearDown;

done_testing;
