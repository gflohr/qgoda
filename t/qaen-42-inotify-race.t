use Test::More;

# GitHub issue #11
# Previous implementation had a race condition which could miss entities
# created inside a newly create directory.

use strict;
use warnings;
use File::Spec;
use lib 't';
$|++;

use TestSupport qw(create_test_files delete_test_files move_test_files
  modify_attrs_on_test_files $dir received_events receive_event);

use Qgoda::AnyEvent::Notify;
use AnyEvent::Impl::Perl;

create_test_files(qw(one/1 two/1));
## ls: one/1 two/1

my $n = Qgoda::AnyEvent::Notify->new(
	dirs		 => [ map { File::Spec->catfile($dir, $_) } qw(one two) ],
	filter	   => sub   { shift !~ qr/ignoreme/ },
	cb		   => sub   { receive_event(@_) },
	parse_events => 1,
);
isa_ok($n, 'Qgoda::AnyEvent::Notify');

received_events(sub { create_test_files(qw(one/sub/2)) },
	'create subdir and file', qw(created created));
## ls: one/sub/1 one/sub/2 two/1

received_events(sub { create_test_files(qw(one/sub/ignoreme/1 one/sub/3)) },
	'create subdir and file', qw(created));
## ls: one/sub/1 one/sub/2 one/sub/ignoreme/1 one/sub/3 two/1

received_events(sub { create_test_files(qw(two/sub/ignoreme/sub/1)) },
	'create subdir and file', qw(created));
## ls: one/sub/1 one/sub/2 one/sub/ignoreme/1 one/sub/3 two/1 tow/sub/ignoreme/sub/1

## ok(1, '... arrived');
done_testing;
