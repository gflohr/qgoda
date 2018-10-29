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

use strict;

use Test::More;

use Qgoda;
use Qgoda::JavaScript::Environment;
use YAML::XS 0.67;

my $q = Qgoda->new({quiet => 1, log_stderr => 1});
my $node_modules = $q->nodeModules;
my $env = Qgoda::JavaScript::Environment->new(global => $node_modules);
my $input = <<'EOF';
foo: '1'
bar: 'false'
baz: ['true']
EOF

my $schema = {
	type => 'object',
	properties => {
		foo => { type => 'number' },
		bar => { type => 'boolean' },
		baz => { type => 'boolean' }
	},
	required => [qw(foo bar)]
};

# Inject the YAML source into the VM.
$env->vm->set('input', $input);
$env->vm->set('schema', $schema);

my $data = $env->run(<<'EOF');
const yaml = require('js-yaml');
const Ajv = require('ajv');

var unserialized = yaml.safeLoad(input),
	config = yaml.safeLoad(input),
    ajv = new Ajv({useDefaults: true, coerceTypes: 'array'}),
	validate = ajv.compile(schema),
	valid = validate(config);
EOF

my $expected = {
	foo => '1',
	bar => 'false',
	baz => ['true']
};
my $got = $env->vm->get('unserialized');
is_deeply $got, $expected;

$got = $env->vm->get('valid');
is $got, 1;

$expected = {
	foo => 1,
	bar => 0,
	baz => 1
};
my $config = $env->vm->get('config');
# There are problems with Perl 5.18 and the distinction between strings
# and numbers. But since we don't rely on that, we just ignore these
# problems.
foreach my $key (keys %$config) {
    $config->{$key} = "$config->{$key}" if $config->{$key} =~ /^[0-9]+$/;
}
foreach my $key (keys %$expected) {
    $expected->{$key} = "$expected->{$key}"
        if $expected->{$key} =~ /^[0-9]+$/;
}
is_deeply $config, $expected;

$YAML::XS::Boolean = 'JSON::PP';

my $got = Dump($config);

done_testing;
