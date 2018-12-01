use Test::More tests => 2;

use strict;
use warnings;

use Qgoda::AnyEvent::Notify::Event;

my $e = Qgoda::AnyEvent::Notify::Event->new(
	path   => 'some/path',
	type   => 'modified',
	is_dir => undef,
);

isa_ok($e, "Qgoda::AnyEvent::Notify::Event");
ok(!$e->is_dir, 'is_dir');
