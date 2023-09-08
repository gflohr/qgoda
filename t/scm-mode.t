#! /usr/bin/env perl # -*- perl -*-

# Copyright (C) 2016-2020 Guido Flohr <guido.flohr@cantanea.com>,
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

use lib 't';
use TestSite;

use Test::More;
use File::Path;
use Git::Repository 1.321;

use Qgoda::CLI;
use Qgoda::Util qw(read_file);
use Qgoda::Util::FileSpec qw(absolute_path);

if ($^O eq 'MSWin32' || $^O eq 'cygwin') {
	plan skip_all => 'Test does not work on MS-DOS';
}

my %assets;

$assets{'old.md'} = {
	title => 'Old',
	content => 'valid',
};
$assets{'new.md'} = {
	title => 'New',
	content => 'valid',
};
$assets{'template-added.md'} = {
	title => 'Template Added',
	content => 'valid',
	view => 'default.html'
};
$assets{'template-not-added.md'} = {
	title => 'Template Not Added',
	content => 'valid',
	view => 'new.html'
};

my $site = TestSite->new(
	name => 'scm-mode',
	assets => \%assets,
	files => {
		'_views/default.html' => "[% asset.content %]",
		'_views/new.html' => "[% asset.content %]"
	},
	config => {
		scm => 'git'
	}
);

my $repo_dir = absolute_path;
ok (Git::Repository->run(init => {cwd => $repo_dir}));
my $repo = Git::Repository->new(work_tree => $repo_dir);
ok $repo;
# Git::Repository->run returns the command output which is empty (aka false).
# It will throw an exception in case of errors.
ok !$repo->run(add => '_qgoda.yaml');
ok !$repo->run(add => 'old.md');
ok !$repo->run(add => 'template-added.md');
ok !$repo->run(add => 'template-not-added.md');
ok !$repo->run(add => '_views/default.html');

open my $olderr, '>&STDERR' or die "cannot dup stderr: $!";
close STDERR;
ok(Qgoda::CLI->new(['build'])->dispatch);
open STDERR, '>&', $olderr;

my $invalid = qr/^\[\% '' \%\]/;

ok -e '_site/old/index.html';
is ((read_file '_site/old/index.html'), '<p>valid</p>');

ok ! -e '_site/new/index.html';

ok -e '_site/template-added/index.html';
is ((read_file '_site/template-added/index.html'), '<p>valid</p>');

ok ! -e '_site/template-not-added/index.html';

$site->tearDown;

done_testing;
