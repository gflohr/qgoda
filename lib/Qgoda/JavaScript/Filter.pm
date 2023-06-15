#! /bin/false

# Copyright (C) 2016-2023 Guido Flohr <guido.flohr@cantanea.com>,
# all rights reserved.

# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 3 of the License, or
# (at your option) any later version.

# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

package Qgoda::JavaScript::Filter;

use strict;

use Filter::Util::Call;
use Locale::TextDomain qw(qgoda);

sub import {
	my ($class, $package) = @_;

	my $preamble = <<EOF;
package $package;

use strict;

my \$code;

sub code {
	if (!defined \$code) {
		\$code = join '', <DATA>;
	}
	return \$code
}

1;

__DATA__
EOF

	my $filter = sub {
		my $status = filter_read;
		return $status if $status <= 0;

		if (defined $preamble) {
			if ($_ !~ m{^(?:[ \011-\015]*|//.*)$}) {
				my (undef, $filename, $lineno) = caller;
				die __x("The first line of the JavaScript code must be empty "
						. "or begin with \"//\" at {filename} {lineno}.\n",
						filename => $filename, lineno => $lineno);
			}
			$_ = $preamble;
			undef $preamble;
		}

		return length $_;
	};

	filter_add($filter);
}

1;

=head1 NAME

Qgoda::JavaScript::Filter - Require JavaScript source files

=head1 SYNOPSIS

Use the first line in the following snippet as the first line of your
JavaScript files:

	//; use Qgoda::JavaScript::Filter('Qgoda::JavaScript::console');

	/* Example Javascript code.  */
	console.log('Hello, world');

The one and only argument should be the package name you want the code
to be available as, here B<Qgoda::JavaScript::console>.

Getting the content of the JavaScript file goes like this:

	require 'Qgoda/JavaScript/console.js';

	my $code = Qgoda::JavaScript::console->code;

	# Feed the code into an ECMAScript engine:
	JavaScript::Duktape::XS->new->eval($code);

=head1 DESCRIPTION

Qgoda comes with several JavaScript files.  Those in B<Qgoda::node_modules>
are loaded by JavaScript itself.  Those under B<Qgoda::JavaScript> are
loaded by Perl.

=head2 METHODS

=over 4

=item B<import YOUR_PACKAGE>

You have to "use()" the JavaScript module with the desired package name.
Otherwise your code will be lost in lala land.

=back

=head2 METHODS IN THE GENERATED PACKAGE

Apart from those defined by L<UNIVERSAL>:

=over 4

=item B<code>

A class method that returns the JavaScript code contained in the file.

=back

=head2 LIMITATIONS

Perl source filters do not parse B<__DATA__> sections but this source
filter starts a data section at the very beginning.  Due to that fact
the first line of your JavaScript code will be lost!

The filter therefore generates a syntax error, when your first line of
JavaScript code does not begin with "//" or contains only whitespace.

For the same reason you always have to add 2 to the line number if the
JavaScript engine reports an error. The first line is for the "use"
directive, the second one for the lost line.

=head2 Why the hack (pun intended)?

You could of course just write your code in the data section of a regular
Perl module.  This is indeed what the filter does unter the hood.  But
since you mix JavaScript with Perl syntax, syntax highlighter can only
highlight one portion of the code and that portion would unfortunately
be the insignificant Perl code.

But more important is actually that you can syntax-check the JavaScript
code the file is valid Perl and valid JavaScript at the same time.

=head1 SEE ALSO

L<perlfilter>, L<perl>