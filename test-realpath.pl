use strict;

use Cwd qw(realpath abs_path);

my $p;

$p = realpath '_site';
print STDERR "realpath site: $p\n";
$p = abs_path '_site';
print STDERR "abs_path site: $p\n";
