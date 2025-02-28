#! /usr/bin/env perl # -*- perl -*-

# Copyright (C) 2016-2025 Guido Flohr <guido.flohr@cantanea.com>,
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
use YAML::XS;
use JSON::PP;

use Qgoda::Config;
use Qgoda::Schema;
use Qgoda::Util::FileSpec qw(absolute_path);

use constant true => $JSON::PP::true;
use constant false => $JSON::PP::false;

my $site = TestSite->new(name => 'config-default');
my $config = Qgoda->dumpConfig;
ok $config;
$config = YAML::XS::Load($config);
$site->tearDown;

my $schema = Qgoda::Schema->config;
my $url = $schema->{properties}->{url}->{default};

my $srcdir = absolute_path . '/t/config-default';

my $expected = <<EOF;
---
analyzers: []
case-sensitive: false
compare-output: true
defaults: []
exclude: []
exclude-watch: []
front-matter-placeholder:
    '*': "[% '' %]\\n"
generator: Qgoda v$Qgoda::VERSION (https://www.qgoda.net/)
helpers: {}
build-task-timeout: 300
index: index
latency: 0.5
link-score: 5
location: /{directory}/{basename}/{index}{suffix}
no-scm: []
paths:
  plugins: _plugins
  po: _po
  site: $srcdir/_site
  timestamp: _timestamp
  views: _views
permalink: '{significant-path}'
po:
  copyright-holder: Set config.po.copyright-holder in '_config.yaml'.
  mdextra: []
  msgfmt: [msgfmt]
  msgid-bugs-address: Set config.po.msgid-bugs-address in '_config.yaml'.
  msgmerge: [msgmerge]
  qgoda: [qgoda]
  reload: false
  textdomain: messages
  tt2:
  - _views
  xgettext: [xgettext]
  xgettext-tt2: [xgettext-tt2]
post-processors:
  modules: []
  options: {}
precious: []
processors:
  chains:
    html:
      modules:
      - TT2
      - Strip
      - HTMLFilter
    markdown:
      modules:
      - TT2
      - Strip
      - Markdown
      suffix: html
      wrapper: html
    raw:
      modules:
      - TT2
      - Strip
    xml:
      modules:
      - TT2
      - Strip
  options:
    HTMLFilter:
      AnchorTarget: {}
      Generator: {}
      CleanUp: {}
      TOC:
        content-tag: qgoda-content
        end: 6
        start: 2
        template: components/toc.html
        toc-tag: qgoda-toc
  triggers:
    htm: html
    html: html
    json: raw
    md: markdown
    mdown: markdown
    mdwn: markdown
    mkd: markdown
    mkdn: markdown
    xml: raw
srcdir: $srcdir
taxonomies:
  categories: 3
  links: 1
  tags: 2
title: A new Qgoda Powered Site
track-dependencies: false
url: $url
view: default.html
EOF
$expected = Load($expected);

is_deeply $config, $expected, 'default config should not change';

done_testing;
