use Test::More;

use strict;
use warnings;
use lib 't';
use Data::Dump;

use TestSupport qw(create_test_files delete_test_files move_test_files
  modify_attrs_on_test_files $dir);
use Qgoda::AnyEvent::Notify;

# Setup for tests
create_test_files(qw(1 one/1 two/1));

my $old_fs = Qgoda::AnyEvent::Notify->_scan_fs($dir, "$dir/one");
is(keys %$old_fs, 6, '_scan_fs: got all of them');

create_test_files(qw(2 one/2 two/2));
my $new_fs = Qgoda::AnyEvent::Notify->_scan_fs([$dir]);
is(keys %$new_fs, 9, '_scan_fs: got all of them');

my @events = Qgoda::AnyEvent::Notify->_diff_fs($old_fs, $new_fs);
is(@events, 3, '_diff_fs: got create events') or diag ddx @events;
is($_->type, 'created', '... correct type') for @events;

$old_fs = $new_fs;
create_test_files(qw(2 one/2 two/2));
$new_fs = Qgoda::AnyEvent::Notify->_scan_fs($dir);
@events = Qgoda::AnyEvent::Notify->_diff_fs($old_fs, $new_fs);
is(@events, 3, '_diff_fs: got modification events') or diag ddx @events;
is($_->type, 'modified', '... correct type') for @events;

$old_fs = $new_fs;
delete_test_files(qw(2 one/2 two/2));
$new_fs = Qgoda::AnyEvent::Notify->_scan_fs($dir);
@events = Qgoda::AnyEvent::Notify->_diff_fs($old_fs, $new_fs);
is(@events, 3, '_diff_fs: got modification events') or diag ddx @events;
is($_->type, 'deleted', '... correct type') for @events;

$old_fs = $new_fs;
create_test_files(qw(three/1 two/one/1));
$new_fs = Qgoda::AnyEvent::Notify->_scan_fs($dir);
@events = Qgoda::AnyEvent::Notify->_diff_fs($old_fs, $new_fs);
is(@events, 4, '_diff_fs: got create dir events') or diag ddx @events;
is($_->type, 'created', '... correct type') for @events;

$old_fs = $new_fs;
delete_test_files(qw(three/1 three two/one/1));
$new_fs = Qgoda::AnyEvent::Notify->_scan_fs($dir);
@events = Qgoda::AnyEvent::Notify->_diff_fs($old_fs, $new_fs);
is(@events, 3, '_diff_fs: got create dir events') or diag ddx @events;
is($_->type, 'deleted', '... correct type') for @events;

SKIP: {
	skip "attribute changes not available on Windows", 3
	  if $^O eq 'MSWin32';

	$old_fs = $new_fs;
	modify_attrs_on_test_files(qw(1 one));
	$new_fs = Qgoda::AnyEvent::Notify->_scan_fs($dir);
	@events = Qgoda::AnyEvent::Notify->_diff_fs($old_fs, $new_fs);
	is(@events, 2, '_diff_fs: got attrib modify events') or diag ddx @events;
	is($_->type, 'modified', '... correct type') for @events;
}

done_testing();
