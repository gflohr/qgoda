use Test::More;
use Test::Exception;
use strict;
use warnings;

use Qgoda::AnyEvent::Notify;

# Used to shorten the tests
my $QAEN = 'Qgoda::AnyEvent::Notify';

subtest 'Try to load the correct backend for this O/S' => sub {
	if ($^O eq 'linux' and eval { require Linux::Inotify2; 1}) {
		my $w = Qgoda::AnyEvent::Notify->new(dirs => ['t'], cb => sub {});
		isa_ok($w, $QAEN);
		ok(!$w->isa("${QAEN}::Backend::Fallback"), '... Fallback');
		ok($w->isa("${QAEN}::Backend::Inotify2"),  '... Inotify2');
		ok(!$w->isa("${QAEN}::Backend::FSEvents"), '... FSEvents');
		ok(!$w->isa("${QAEN}::Backend::KQueue"),   '... KQueue');
	} elsif ($^O eq 'darwin' and eval {require Mac::FSEvents; 1}) {
		my $w = Qgoda::AnyEvent::Notify->new(dirs => ['t'], cb => sub {});
		isa_ok($w, $QAEN);
		ok(!$w->isa("${QAEN}::Backend::Fallback"), '... Fallback');
		ok(!$w->isa("${QAEN}::Backend::Inotify2"), '... Inotify2');
		ok($w->isa("${QAEN}::Backend::FSEvents"),  '... FSEvents');
		ok(!$w->isa("${QAEN}::Backend::KQueue"),   '... KQueue');

	} elsif ($^O =~ /bsd/ and eval {require IO::KQueue; 1;}) {
		my $w = Qgoda::AnyEvent::Notify->new(dirs => ['t'], cb => sub {});
		isa_ok($w, $QAEN);
		ok(!$w->isa("${QAEN}::Backend::Fallback"), '... Fallback');
		ok(!$w->isa("${QAEN}::Backend::Inotify2"), '... Inotify2');
		ok(!$w->isa("${QAEN}::Backend::FSEvents"), '... FSEvents');
		ok($w->isa("${QAEN}::Backend::KQueue"),	'... KQueue');
	} else {
		my $w = Qgoda::AnyEvent::Notify->new(dirs => ['t'], cb => sub {});
		isa_ok($w, $QAEN);
		ok($w->isa("${QAEN}::Backend::Fallback"),  '... Fallback');
		ok(!$w->isa("${QAEN}::Backend::Inotify2"), '... Inotify2');
		ok(!$w->isa("${QAEN}::Backend::FSEvents"), '... FSEvents');
		ok(!$w->isa("${QAEN}::Backend::KQueue"),   '... KQueue');
	}
};

subtest 'Try to load the fallback backend via no_external' => sub {
	my $w = Qgoda::AnyEvent::Notify->new(
		dirs => ['t'],
		cb => sub {},
		no_external => 1,
  );
	isa_ok($w, $QAEN);
	ok($w->isa("${QAEN}::Backend::Fallback"),  '... Fallback');
	ok(!$w->isa("${QAEN}::Backend::Inotify2"), '... Inotify2');
	ok(!$w->isa("${QAEN}::Backend::FSEvents"), '... FSEvents');
	ok(!$w->isa("${QAEN}::Backend::KQueue"),   '... KQueue');
};

subtest 'Try to specify Fallback via the backend argument' => sub {
	my $w = Qgoda::AnyEvent::Notify->new(
		dirs => ['t'],
		cb => sub {},
		backend => 'Fallback',
	);
	isa_ok($w, $QAEN);
	ok($w->isa("${QAEN}::Backend::Fallback"),  '... Fallback');
	ok(!$w->isa("${QAEN}::Backend::Inotify2"), '... Inotify2');
	ok(!$w->isa("${QAEN}::Backend::FSEvents"), '... FSEvents');
	ok(!$w->isa("${QAEN}::Backend::KQueue"),   '... KQueue');
};

subtest 'Try to specify +QAENR::Fallback via the backend arguement' => sub {
	my $w = Qgoda::AnyEvent::Notify->new(
		dirs	=> ['t'],
		cb	  => sub {},
		backend => "+${QAEN}::Backend::Fallback",
  );
	isa_ok($w, $QAEN);
	ok($w->isa("${QAEN}::Backend::Fallback"),  '... Fallback');
	ok(!$w->isa("${QAEN}::Backend::Inotify2"), '... Inotify2');
	ok(!$w->isa("${QAEN}::Backend::FSEvents"), '... FSEvents');
	ok(!$w->isa("${QAEN}::Backend::KQueue"),   '... KQueue');
};

if ($^O eq 'darwin' and eval { require IO::KQueue; 1; }) {
	subtest 'Try to force KQueue on Mac with IO::KQueue installed' => sub {
		my $w = eval {
			Qgoda::AnyEvent::Notify->new(
				dirs	=> ['t'],
				cb	  => sub {},
				backend => 'KQueue'
		  );
		};
		isa_ok($w, $QAEN);
		ok(!$w->isa("${QAEN}::Backend::Fallback"), '... Fallback');
		ok(!$w->isa("${QAEN}::Backend::Inotify2"), '... Inotify2');
		ok(!$w->isa("${QAEN}::Backend::FSEvents"), '... FSEvents');
		ok($w->isa("${QAEN}::Backend::KQueue"),	'... KQueue');
	  }
}

done_testing;
