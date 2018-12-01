use strict;
use warnings;
use Test::More;
use File::Find;

use_ok "Qgoda::AnyEvent::Notify::Backend::Fallback";
if ('linux' eq $^O) {
    use_ok "Qgoda::AnyEvent::Notify::Backend::Inotify2";
} elsif('darwin' eq $^O) {
    use_ok "Qgoda::AnyEvent::Notify::Backend::FSEvents";
} elsif($^O =~ /bsd/) {
    use_ok "Qgoda::AnyEvent::Notify::Backend::KQueue";
}

done_testing;
