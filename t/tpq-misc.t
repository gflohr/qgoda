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

BEGIN {
    my $test_dir = __FILE__;
    $test_dir =~ s/[-a-z0-9]+\.t$//i;
    unshift @INC, $test_dir;
}

use TestSite;
use Test::More;

use JSON;
use Storable qw(dclone);

use Qgoda::CLI;
use Qgoda::Util qw(read_file);

my $bust_cache = <<EOF;
[%- USE q = Qgoda -%]

[% q.bustCache('/styles.css') %]

[% q.bust_cache('/styles2.css') %]

relative: [% q.bustCache('styles.css') %]

not-there: [% q.bustCache('/not-there.css') %]

[% q.bustCache('/styles.css?foo=1') %]
EOF

my $load_json = <<EOF;
[%- USE q = Qgoda -%]
[%- data = q.loadJSON('data/number.json') -%]
[%- data.number -%]
EOF

my $load_json_absolute = <<EOF;
[%- USE q = Qgoda -%]
[%- data = q.loadJSON('/data/number.json') -%]
[%- data.number -%]
EOF

my $load_json_updir = <<EOF;
[%- USE q = Qgoda -%]
[%- data = q.loadJSON('../_site/data/number.json') -%]
[%- data.number -%]
EOF

my $load_json_invalid = <<EOF;
[%- USE q = Qgoda -%]
[%- data = q.loadJSON('data/invalid.json') -%]
[%- data.number -%]
EOF

my $load_json_not_existing = <<EOF;
[%- USE q = Qgoda -%]
[%- data = q.loadJSON('data/not-there.json') -%]
[%- data.number -%]
EOF

# Also pass invalid and valid flags and options for test coverage.
my $paginate = <<EOF;
[%- USE q = Qgoda -%]
[%- p = q.paginate(total => 48) -%]
[%- q.encodeJSON(p, 'invalid flag', invalid => 'option', max_depth => 99) %]
EOF

# Pass a non-hash reference for test coverage.
my $paginate20 = <<EOF;
[%- USE q = Qgoda -%]
[%- p = q.paginate(total => 48, start => 20) -%]
[%- q.encodeJSON(p, [2304]) %]
EOF

my $paginate_last = <<EOF;
[%- USE q = Qgoda -%]
[%- p = q.paginate(total => 48, start => 40) -%]
[%- q.encodeJSON(p) %]
EOF

my $paginate_missing_total = <<EOF;
[%- USE q = Qgoda -%]
[%- p = q.paginate(start => 40) -%]
[%- q.encodeJSON(p) %]
EOF

my $paginate_negative_total = <<EOF;
[%- USE q = Qgoda -%]
[%- p = q.paginate(total => -2304, start => 40) -%]
[%- q.encodeJSON(p) %]
EOF

my $paginate_per_page_9 = <<EOF;
[%- USE q = Qgoda -%]
[%- p = q.paginate(total => 43, start => 18, per_page => 9) -%]
[%- q.encodeJSON(p) %]
EOF

my $paginate_filename = <<EOF;
[%- USE q = Qgoda -%]
[%- p = q.paginate(total => 48, stem => 'page', extender => '.xml') -%]
[%- q.encodeJSON(p) %]
EOF

my $paginate_invalid_noref = <<EOF;
[%- USE q = Qgoda -%]
[%- q.paginate(2304) -%]
EOF

my $paginate_invalid_no_data = <<EOF;
[%- USE q = Qgoda -%]
[%- q.paginate -%]
EOF

my $paginate_invalid_array = <<EOF;
[%- USE q = Qgoda -%]
[%- q.paginate(['foo', 'bar']) -%]
EOF

my $paginate_invalid_scalar_ref = <<EOF;
[%- USE q = Qgoda -%]
[%- q.paginate(asset.date) -%]
EOF

my $time = <<EOF;
[%- USE q = Qgoda -%]
[%- date = q.time -%]
[%- date -%]:[%- date.w3c -%]
EOF

my $sprintf = <<EOF;
[%- USE q = Qgoda -%]
[%- q.sprintf('%x', 8964) -%]
EOF

my $strftime = <<EOF;
[%- USE q = Qgoda -%]
year from epoch: [% q.strftime('%Y', 609322304) %]
year from date: [% q.strftime('%Y', '1989-04-23', 'C', 'div') %]
invalid date: [% q.strftime('%Y', '1989-02-30', 'C') %]
default format: [% q.strftime('', 609322304, 'C') %]
EOF

my $site = TestSite->new(
	name => 'tpq-misc',
	assets => {
		'bust-cache.md' => {content => $bust_cache},
		'load-json.md' => {content => $load_json},
		'load-json-absolute.md' => {content => $load_json_absolute},
		'load-json-updir.md' => {content => $load_json_updir},
		'load-json-invalid.md' => {content => $load_json_invalid},
		'load-json-not-existing.md' => {content => $load_json_not_existing},
		'paginate.html' => {content => $paginate, chain => 'xml'},
		'paginate20.html' => {content => $paginate20, chain => 'xml'},
		'paginate-last.html' => {content => $paginate_last, chain => 'xml'},
		'paginate-missing-total.html' =>
			{
				content => $paginate_missing_total, 
				chain => 'xml'
			},
		'paginate-negative-total.html' =>
			{
				content => $paginate_negative_total, 
				chain => 'xml'
			},
		'paginate-per-page-9.html' =>
			{
				content => $paginate_per_page_9,
				chain => 'xml'
			},
		'paginate-filename.html' =>
			{
				content => $paginate_filename,
				chain => 'xml'
			},
		'paginate-invalid-no-data.html' =>
			{
				content => $paginate_invalid_no_data,
				chain => 'xml'
			},
		'paginate-invalid-noref.html' =>
			{
				content => $paginate_invalid_noref,
				chain => 'xml'
			},
		'paginate-invalid-array.html' =>
			{
				content => $paginate_invalid_array,
				chain => 'xml'
			},
		'paginate-invalid-scalar-ref.html' =>
			{
				content => $paginate_invalid_scalar_ref,
				chain => 'xml'
			},
		'time.html' => { content => $time, chain => 'xml' },
		'sprintf.html' => { content => $sprintf, chain => 'xml' },
		'strftime.html' => { content => $strftime, chain => 'xml' },
	},
	files => {
		'_views/default.html' => "[% asset.content %]",
		'styles.css' => '// Test styles',
		'styles2.css' => '// Test styles',
		'data/number.json' => '{"number":"2304"}',
		'data/invalid.json' => '{"number":}',
	}
);

# Temporarily close stderr while building the site.
open my $olderr, '>&STDERR' or die "cannot dup stderr: $!";
close STDERR;
my $started = time;
ok(Qgoda::CLI->new(['build'])->dispatch);
my $finished = time;
open STDERR, '>&', $olderr;

ok -e '_site/bust-cache/index.html';
my $bust_cache_content = read_file '_site/bust-cache/index.html';
like ($bust_cache_content, qr{<p>/styles\.css\?[0-9]+</p>}, 'bustCache');
like ($bust_cache_content, qr{<p>/styles2\.css\?[0-9]+</p>}, 'bust_cache');
like ($bust_cache_content, qr{<p>relative: styles\.css</p>},
      'bustCache relative');
like ($bust_cache_content, qr{<p>not-there: /not-there\.css</p>},
      'bustCache non existing');
like ($bust_cache_content, qr{<p>/styles\.css\?foo=1\&amp;[0-9]+</p>},
      'bustCache with query parameter');

ok -e '_site/load-json/index.html';
is ((read_file '_site/load-json/index.html'), '<p>2304</p>', 'loadJSON');

my $invalid = qr/^\[\% '' \%\]/;

# Absolute paths are not allowed.
ok -e '_site/load-json-absolute/index.html';
like ((read_file '_site/load-json-absolute/index.html'), $invalid,
      'loadJSON absolute');

ok -e '_site/load-json-updir/index.html';
like ((read_file '_site/load-json-updir/index.html'), $invalid,
      'loadJSON updir');

ok -e '_site/load-json-invalid/index.html';
is ((read_file '_site/load-json-invalid/index.html'), '', 'loadJSON invalid');

ok -e '_site/load-json-not-existing/index.html';
is ((read_file '_site/load-json-not-existing/index.html'), '',
    'loadJSON not existing');

my $expected_default = {
	per_page => 10,
	page => 1,
	page0 => 0,
	total_pages => 5,
	next_link => 'index-2.html',
	previous_link => undef,
	tabindexes => [ -1, 0, 0, 0, 0 ],
	tabindices => [ -1, 0, 0, 0, 0 ],
	start => 0,
	next_start => 10,
	next_location => '/paginate/index-2.html',
	links => [
		'index.html',
		'index-2.html',
		'index-3.html',
		'index-4.html',
		'index-5.html'
	]
};

my ($json, $p, $expected);

ok -e '_site/paginate/index.html';
$json = read_file '_site/paginate/index.html';
$p = eval { decode_json $json };
ok $p, $@;
$expected = dclone $expected_default;
is_deeply($p, $expected);

ok -e '_site/paginate20/index.html';
$json = read_file '_site/paginate20/index.html';
$p = eval { decode_json $json };
ok $p, $@;
$expected = dclone $expected_default;
$expected->{start} = 20;
$expected->{next_start} = 30;
$expected->{tabindexes} = $expected->{tabindices} = [0, 0, -1, 0, 0];
$expected->{page} = 3;
$expected->{page0} = 2;
$expected->{previous_link} = 'index-2.html';
$expected->{next_link} = 'index-4.html';
$expected->{next_location} = '/paginate20/index-4.html';
is_deeply($p, $expected);

ok -e '_site/paginate-last/index.html';
$json = read_file '_site/paginate-last/index.html';
$p = eval { decode_json $json };
ok $p, $@;
$expected = dclone $expected_default;
$expected->{start} = 40;
$expected->{next_start} = undef;
$expected->{tabindexes} = $expected->{tabindices} = [0, 0, 0, 0, -1];
$expected->{page} = 5;
$expected->{page0} = 4;
$expected->{previous_link} = 'index-4.html';
$expected->{next_link} = undef;
$expected->{next_location} = undef;
is_deeply($p, $expected);

ok -e '_site/paginate-missing-total/index.html';
$json = read_file '_site/paginate-missing-total/index.html';
like $json, $invalid;

ok -e '_site/paginate-negative-total/index.html';
$json = read_file '_site/paginate-negative-total/index.html';
like $json, $invalid;

ok -e '_site/paginate-per-page-9/index.html';
$json = read_file '_site/paginate-per-page-9/index.html';
$p = eval { decode_json $json };
ok $p, $@;
$expected = dclone $expected_default;
$expected->{start} = 18;
$expected->{per_page} = 9;
$expected->{total_pages} = 5;
$expected->{tabindexes} = $expected->{tabindices} = [0, 0, -1, 0, 0];
$expected->{page} = 3;
$expected->{page0} = 2;
$expected->{next_link} = 'index-4.html';
$expected->{previous_link} = 'index-2.html';
$expected->{next_location} = '/paginate-per-page-9/index-4.html';
$expected->{next_start} = 27;
is_deeply($p, $expected);

ok -e '_site/paginate-filename/index.html';
$json = read_file '_site/paginate-filename/index.html';
$p = eval { decode_json $json };
ok $p, $@;
$expected = dclone $expected_default;
$expected->{next_link} = 'page-2.xml';
$expected->{next_location} = '/paginate-filename/page-2.xml';
$expected->{links} = [
	'page.xml',
	'page-2.xml',
	'page-3.xml',
	'page-4.xml',
	'page-5.xml',
];
is_deeply($p, $expected);

ok -e '_site/paginate-invalid-no-data/index.html';
like ((read_file '_site/paginate-invalid-no-data/index.html'), $invalid,
      'paginate called without data');

ok -e '_site/paginate-invalid-noref/index.html';
like ((read_file '_site/paginate-invalid-noref/index.html'), $invalid,
      'paginate called with non-reference');

ok -e '_site/paginate-invalid-array/index.html';
like ((read_file '_site/paginate-invalid-array/index.html'), $invalid,
      'paginate called with array');

ok -e '_site/paginate-invalid-scalar-ref/index.html';
like ((read_file '_site/paginate-invalid-scalar-ref/index.html'), $invalid,
      'paginate called with scalar reference');

ok -e '_site/time/index.html';
my $output = read_file '_site/time/index.html';
like $output, qr/^([0-9]+):(.+)$/;
my ($epoch, $w3c) = split /:/, $output;
ok $epoch >= $started, "epoch after start time: $epoch <=> $started";
ok $epoch <= $finished, "epoch before end time: $epoch <=> $finished";
my @time = gmtime $epoch;
is $w3c, sprintf '%04u-%02u-%02u', $time[5] + 1900, $time[4] + 1, $time[3];

ok -e '_site/sprintf/index.html';
is ((read_file '_site/sprintf/index.html'), '2304', 'sprintf');

ok -e '_site/strftime/index.html';
my $strftime_content = read_file '_site/strftime/index.html';

like ($strftime_content, qr/^year from epoch: 1989$/m,
      'year from epoch');
like ($strftime_content, qr/^year from date: 1989$/m,
      'year from date');
like ($strftime_content, qr/^invalid date: 1989-02-30$/m,
      'invalid date');
like ($strftime_content, qr/^default format: .*Apr/m,
      'default format');
like ($strftime_content, qr/^default format: .*1989/m,
      'default format');

$site->tearDown;

done_testing;
