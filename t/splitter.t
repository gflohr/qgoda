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
use File::Basename qw(dirname);
use File::Spec;

use Qgoda::CLI;
use Qgoda::Splitter;
use Qgoda::Util qw(read_file);

my $testdir = dirname __FILE__;

my $master_md = File::Spec->catfile($testdir, 'master.md');

my $splitter = Qgoda::Splitter->new($master_md);
ok $splitter, 'parse master';
my $meta = $splitter->meta;
is $meta->{title}, 'Master Document';
is $splitter->metaLineNumber('title'), 2, 'title line number';
is $meta->{name}, 'master-document';
is $splitter->metaLineNumber('name'), 3, 'name line number';
is $meta->{description}, 'Test for po mechanism';
is $splitter->metaLineNumber('description'), 4, 'description line number';

my @entries = $splitter->entries;
is scalar @entries, 4, 'number of entries';

my $expected = <<EOF;
Multiple lines
in one
paragraph.
EOF
chomp $expected;
is $entries[0]->{text}, $expected, 'multiple lines';

$expected = <<EOF;

Block

with

embedded

new lines.
EOF
is $entries[1]->{text}, $expected, 'block';

$expected = "Empty lines above should be ignored.";
is $entries[2]->{text}, $expected, 'last line';

$expected = 'This entry has the context "my" and a translator comment.';
is $entries[3]->{text}, $expected, 'text with comment';

$expected = 'TRANSLATORS: A translator comment.';
is $entries[3]->{comment}, $expected, 'translator comment';

$expected = 'my';
is $entries[3]->{msgctxt}, $expected, 'message context';

# Test that the generated files do not contain any traces of the xgettext
# markers.
my $site = TestSite->new(name => 'splitter',
                         assets => {
                             'master.md' => {
                                 title => 'Splitter Test',
                                 content => read_file $master_md,
                             }
                         });
ok (Qgoda::CLI->new(['build'])->dispatch);
ok -e '_site/master/index.html';
my $generated = read_file '_site/master/index.html';
ok $generated !~ /qgoda-xgettext/;
ok $generated !~ /qgoda-no-xgettext/;

done_testing;
