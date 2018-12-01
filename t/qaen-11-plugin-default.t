use Test::More tests => 6;
use Test::Exception;
use strict;
use warnings;

use Qgoda::AnyEvent::Notify;

use Test::Without::Module qw(Linux::Inotify2 Mac::FSEvents IO::KQueue);

my $w = Qgoda::AnyEvent::Notify->new(
	dirs => ['t'],
	cb => sub { },
	no_external => 1
);
isa_ok($w, 'Qgoda::AnyEvent::Notify');
ok($w->isa('Qgoda::AnyEvent::Notify::Backend::Fallback'),  '... Fallback');
ok(!$w->isa('Qgoda::AnyEvent::Notify::Backend::Inotify2'), '... Inotify2');
ok(!$w->isa('Qgoda::AnyEvent::Notify::Backend::FSEvents'), '... FSEvents');
ok(!$w->isa('Qgoda::AnyEvent::Notify::Backend::KQueue'),   '... KQueue');

SKIP: {
	skip 'Test for Mac/Linux/BSD only', 1
	  unless $^O eq 'linux'
	  or $^O eq 'darwin'
	  or $^O =~ /bsd/;

	throws_ok {
		Qgoda::AnyEvent::Notify->new(dirs => ['t'], cb => sub { });
	}
	qr/Error initializing file system backend/, 'fails ok';
}

done_testing;
