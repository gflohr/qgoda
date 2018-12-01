use Test::More tests => 6;

use strict;
use warnings;
use File::Spec;
use lib 't';
$|++;

use TestSupport qw(create_test_files delete_test_files move_test_files
  modify_attrs_on_test_files $dir received_events receive_event);

use Qgoda::AnyEvent::Notify;

sub run_test {
	my %extra_config = @_;

	my $n = Qgoda::AnyEvent::Notify->new(
		dirs => [$dir],
		cb   => sub {
			receive_event(@_);

			# This call back deletes any created files
			my $e = $_[0];
			unlink $e->path if $e->type eq 'created';
		},
		%extra_config,
	);
	isa_ok($n, 'Qgoda::AnyEvent::Notify');

	# Create a file, which will be delete in the callback
	received_events(sub { create_test_files('foo') },
		'create a file', qw(created));

	# Did we get notified of the delete?
	received_events(sub { }, 'deleted the file', qw(deleted));
}

run_test();

SKIP: {
	skip 'Requires Mac with IO::KQueue', 3
	  unless $^O eq 'darwin' and eval { require IO::KQueue; 1; };
	run_test(backend => 'KQueue');
}
