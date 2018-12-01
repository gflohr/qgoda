use Test::More tests => 11;

use strict;
use warnings;
use File::Spec;
use lib 't';
$|++;

use TestSupport qw(create_test_files delete_test_files move_test_files
  modify_attrs_on_test_files $dir received_events receive_event);

use Qgoda::AnyEvent::Notify;
use AnyEvent::Impl::Perl;

create_test_files(qw(one/1 two/1 one/sub/1));

my $n = Qgoda::AnyEvent::Notify->new(
	dirs   => [ map { File::Spec->catfile($dir, $_) } qw(one two) ],
	cb	 => sub   { receive_event(@_) },
	skip_subdirs => 1,
);
isa_ok($n, 'Qgoda::AnyEvent::Notify');

SKIP: {
	skip "not sure which os we are on", 1
	  unless $^O =~ /linux|darwin|bsd/;
	ok($n->isa('Qgoda::AnyEvent::Notify::Backend::Inotify2'),
		'... with the linux role')
	  if $^O eq 'linux';
	ok($n->isa('Qgoda::AnyEvent::Notify::Backend::FSEvents'),
		'... with the mac role')
	  if $^O eq 'darwin';
	ok($n->isa('Qgoda::AnyEvent::Notify::Backend::KQueue'),
		'... with the bsd role')
	  if $^O =~ /bsd/;
}

# ls: one/1 +one/2 one/sub/1 two/1
received_events(sub { create_test_files(qw(one/2)) },
	'create a file', qw(created));

# ls: one/1 ~one/2 one/sub/1 two/1
received_events(sub { create_test_files(qw(one/2)) },
	'modify a file', qw(modified));

# ls: one/1 -one/2 one/sub/1 two/1
received_events(sub { delete_test_files(qw(one/2)) },
	'delete a file', qw(deleted));

# ls: one/1 one/sub/1 +one/sub/2 two/1
received_events(sub { create_test_files(qw(one/sub/2)) },
	'create a file in subdir', qw());

# ls: one/1 one/sub/1 ~one/sub/2 two/1
received_events(sub { create_test_files(qw(one/sub/2)) },
	'modify a file in subdir', qw());

# ls: one/1 one/sub/1 -one/sub/2 two/1
received_events(sub { delete_test_files(qw(one/sub/2)) },
	'delete a file in subdir', qw());

SKIP: {
	skip "skip attr mods on Win32", 1 if $^O eq 'MSWin32';

	# ls: one/1 one/sub/1 ~two/1
	received_events(sub { modify_attrs_on_test_files(qw(two/1)) },
		'modify attributes', qw(modified));

	# ls: one/1 ~one/sub/1 two/1
	received_events(sub { modify_attrs_on_test_files(qw(one/sub/1)) },
		'modify attributes in a subdir', qw());
}

ok(1, '... arrived');

