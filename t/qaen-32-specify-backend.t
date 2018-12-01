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

create_test_files(qw(one/1));
create_test_files(qw(two/1));
create_test_files(qw(one/sub/1));
## ls: one/1 one/sub/1 two/1

my $n = Qgoda::AnyEvent::Notify->new(
	dirs	 => [ map { File::Spec->catfile($dir, $_) } qw(one two) ],
	interval => 0.5,
	filter  => sub { shift !~ qr/ignoreme/ },
	cb	  => sub { receive_event(@_) },
	backend => 'Fallback',
	## parse_events => 0,
);
isa_ok($n, 'Qgoda::AnyEvent::Notify');
ok($n->isa('Qgoda::AnyEvent::Notify::Backend::Fallback'),
	'... with the fallback role');

# ls: one/1 one/sub/1 +one/sub/2 two/1
received_events(sub { create_test_files(qw(one/sub/2)) },
	'create a file', qw(created));

# ls: one/1 +one/2 one/sub/1 one/sub/2 two/1 +two/sub/2
received_events(
	sub { create_test_files(qw(one/2 two/sub/2)) },
	'create file in new subdir',
	qw(created created created)
);

# ls: one/1 ~one/2 one/sub/1 one/sub/2 two/1 two/sub/2
received_events(sub { create_test_files(qw(one/2)) },
	'modify existing file', qw(modified));

# ls: one/1 one/2 one/sub/1 one/sub/2 two/1 two/sub -two/sub/2
received_events(sub { delete_test_files(qw(two/sub/2)) },
	'deletes a file', qw(deleted));

# ls: one/1 one/2 +one/ignoreme +one/3 one/sub/1 one/sub/2 two/1 two/sub
received_events(sub { create_test_files(qw(one/ignoreme one/3)) },
	'creates two files one should be ignored', qw(created));

# ls: one/1 one/2 one/ignoreme -one/3 +one/5 one/sub/1 one/sub/2 two/1 two/sub
received_events(sub { move_test_files('one/3' => 'one/5') },
	'move files', qw(deleted created));

SKIP: {
	skip "skip attr mods on Win32", 1 if $^O eq 'MSWin32';

	# ls: one/1 one/2 one/ignoreme one/5 one/sub/1 one/sub/2 ~two/1 ~two/sub
	received_events(
		sub { modify_attrs_on_test_files(qw(two/1 two/sub)) },
		'modify attributes',
		qw(modified modified)
	);
}

# ls: one/1 one/2 one/ignoreme +one/onlyme +one/4 one/5 one/sub/1 one/sub/2 two/1 two/sub
$n->filter(qr/onlyme/);
received_events(sub { create_test_files(qw(one/onlyme one/4)) },
	'filter test', qw(created));

ok(1, '... arrived');
