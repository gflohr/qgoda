use strict;
use Cwd;

my $here = Cwd::abs_path();
my $exists = -e $here;
warn "$here exists $exists\n";

$here .= '/';
$exists = -e $here;
warn "$here exists $exists\n";

