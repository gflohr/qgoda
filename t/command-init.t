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

use lib 't';
use Test::More;
use File::Spec;
use File::Path;
use Cwd;

use Qgoda;
use Qgoda::CLI;
use Qgoda::Util qw(read_file);

my $here = Cwd::abs_path();

my $updir = File::Spec->updir;
my $theme_path = File::Spec->catdir($updir, 'minimal-theme');

my $project_dir = File::Spec->catdir('t', 'command-init');
mkdir $project_dir;
ok -d $project_dir;
ok chdir $project_dir;

ok (Qgoda::CLI->new(['--quiet', 'init', $theme_path])->dispatch);
ok (Qgoda::CLI->new(['build'])->dispatch);

ok -e '_config.yaml', '_config.yaml exists';
my $config_yaml = <<EOF;
---
title: Qgoda Test Theme
EOF
is ((read_file '_config.yaml'), $config_yaml, '_config.yaml is correct');

ok -e '_views/default.html', '_views/default.html exists';
my $default_html = <<EOF;
default view
EOF
is ((read_file '_views/default.html'), $default_html, '_default.html is correct');

ok -e 'index.md', 'index.md exists';
my $index_md = <<EOF;
---
title: Test Theme
name: home
location: /index.html
---
EOF
is ((read_file 'index.md'), $index_md, 'index.md is correct');

if (chdir $here) {
	ok rmtree $project_dir;
} else {
	ok 0, "cannot chdir to '$here' :(";
}

done_testing;
