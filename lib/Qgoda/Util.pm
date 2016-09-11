#! /bin/false

# Copyright (C) 2016 Guido Flohr <guido.flohr@cantanea.com>, 
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

package Qgoda::Util;

use strict;

use IO::File;
use File::Path qw(make_path);
use File::Basename qw(fileparse);
use Locale::TextDomain qw(com.cantanea.qgoda);
use Scalar::Util qw(reftype looks_like_number);
use Encode qw(_utf8_on);

use base 'Exporter';
use vars qw(@EXPORT_OK);
@EXPORT_OK = qw(empty read_file write_file yaml_error front_matter lowercase
                expand_perl_format read_body merge_data interpolate
                normalize_path strip_suffix perl_identifier perl_class
                slugify);

sub js_unescape($);
sub tokenize($$);
sub evaluate($$);
sub lookup($$);

sub empty($) {
    my ($what) = @_;

    return if defined $what && length $what;

    return 1;
}

sub read_file($) {
    my ($filename) = @_;

    my $fh = IO::File->new;
    $fh->open("< $filename") or return;
    
    local $/;
    my $data = <$fh>;
    $fh->close;

    return $data;
}

sub front_matter($) {
	my ($filename) = @_;
	
    my $fh = IO::File->new;
    $fh->open("< $filename") or return;
    
    my $first_line = <$fh>;
    return if empty $first_line;
    return if $first_line !~ /---[ \t]*\n$/o;
    
    my $front_matter = '';
    while (1) {
        my $line = <$fh>;
    	return if !defined $line;
    	return $front_matter if $line =~ /---[ \t]*\n$/o;
    	$front_matter .= $line;
    }
    
    return;
}

sub read_body($) {
    my ($filename) = @_;
    
    my $fh = IO::File->new;
    $fh->open("< $filename") or return;
    
    my $first_line = <$fh>;
    return if empty $first_line;
    return if $first_line !~ /---[ \t]*\n$/o;
    
    while (1) {
        my $line = <$fh>;
        return if !defined $line;
        last if $line =~ /---[ \t]*\n$/o;
    }

    local $/;
    
    return <$fh>;
}

sub write_file($$) {
    my ($path, $data) = @_;

    my (undef, $directory) = fileparse $path;
    make_path $directory unless -e $directory;

    my $fh = IO::File->new;
    $fh->open("> $path") or return;
    
    $fh->print($data) or return;
    $fh->close or return;
    
    return 1;
}

sub yaml_error {
    my ($filename, $error) = @_;

    my @lines = split /\n/, $error;
    pop @lines;
    return "$filename: " . join "\n", @lines;
}

sub lowercase($) {
	my ($str) = @_;
	
	return lc $str;
}

sub merge_data {
	my ($data, $overlay) = @_;
	
	# Return $overlay if it is of a different type than $data.
	sub equal_ref {
		my ($x, $y) = @_;
		
		return if !ref $x;
		return if !ref $y;
		
		my $ref_x = reftype $x;
		my $ref_y = reftype $y;
		
		return $ref_x = $ref_y;
	}

	return $overlay if !equal_ref $overlay, $data;
    return $overlay if 'ARRAY' eq reftype $overlay;
    
    my $merger;
    $merger = sub {
    	my ($d, $o) = @_;
    	
    	foreach my $key (keys %$d) {
    		if (exists $o->{$key}) {
    			if (!equal_ref $d->{$key}, $o->{$key}) {
    				$d->{$key} = $o->{$key};
    			} elsif (UNIVERSAL::isa($d->{$key}, 'HASH')) {
    				$merger->($d->{$key}, $o->{$key});
    			} else {
    				$d->{$key} = $o->{$key};
    			}
    		}
    	}
    	foreach my $key (keys %$o) {
    		if (!exists $d->{$key}) {
    			$d->{$key} = $o->{$key};
    		}
    	}
    };
	
	$merger->($data, $overlay);
		
	return $data;
}

sub interpolate($$) {
    my ($string, $data) = @_;

    $data ||= {};

    my $type = reftype $data;
    if ($type ne 'ARRAY' && $type ne 'HASH') {
        $type = 'HASH';
        $data = {};
    }

    my $result = '';
    while ($string =~ s/^([^{]*){//) {
        $result .= $1;
        
        my ($remainder, @tokens) = tokenize $string, $type;
        
        # Syntax errors can be handled in different ways.
        # You can handle it gracefully and either leave
        # everything uninterpolated, or you could replace the
        # faulty string with the emtpy string or you can throw an
        # exception.  We just throw an exception.
        die "syntax error before: '$remainder'\n" if !@tokens;

        my $value = evaluate \@tokens, $data;
        $result .= $value if defined $value;
        $string = $remainder;
    }

    return $result . $string;
}

sub normalize_path($;$) {
	my ($dir, $trailing_slash) = @_;
	
	$dir =~ s{[\\/]+}{/}g;
	$dir =~ s{/$}{} unless $trailing_slash;
	
	return $dir;
}

sub strip_suffix($) {
	my ($filename) = @_;
	
	my @parts = split /\./, $filename;
	my @suffixes;
	
	while (@parts > 1) {
		last if $parts[-1] =~ /[^a-zA-Z0-9]/;
		unshift @suffixes, pop @parts
	}
	
	my $basename = join '.', @parts;
	
	return $basename, grep { /./ } @suffixes;
}

##############################################################################
# The methods below are not exported.
##############################################################################

sub tokenize($$) {
    my ($string, $type) = @_;

    my @tokens;
    
    my $depth = 0;
    while (1) {
        $string =~ s/^[ \t\r\n]+//;
        last if !length $string;
        last if $string =~ s/^\}//;

        my $last = @tokens ? $tokens[-1]->[0] : '[';

        if ($last eq '.') {
            # Only variables are allowed but they are interpreted as
            # a quoted string.  We will repair that later, however.
            return $string unless $string =~ s/^([^\[\]\}\.]+)//;
            push @tokens, ['v', $1];
        } elsif ($last eq 'v' || $last eq ']') {
            # Only brackets or a dot are allowed.  Everything else is a
            # syntax error.
            return $string unless $string =~ s/^([\[\]\.])//;

            if ('[' eq $1) {
                ++$depth;
                push @tokens, ['[' => ''];
            } elsif (']' eq $1) {
                --$depth;
                return "]$string" if $depth < 0;
                push @tokens, [']' => ''];
            } else {
                # A dot.
                push @tokens, ['.', ''];
            }
        } elsif ($last eq '[') {
            # At the beginning or after an opening bracket only quoted
            # strings are allowed.  Everything but a quoted string is
            # treated as a variable.
            if ($string =~ s/^(["'])([^\\\1]*(?:\\.[^\\\1]*)*)\1//) {
                push @tokens, ['q', $2];
            } elsif ($string =~ s/^([^\[\]\}\.]+)//) {
                push @tokens, ['v', $1];
            } elsif (!@tokens && $string =~ s/^\[//) {
                # Special case.  We want to allow starting an expression
                # with an opening bracket so that you can write something
                # like ["key with special characters"].
                push @tokens, ['[', ''];
            } else {
                return $string;
            }
        } else {
            # The last token was a quoted string (because all other 
            # possibilities are handled above.  The only legal token after
            # a quoted string is the closing bracket.
            return $string unless $string =~ s/^]//;
            push @tokens, [']', ''];
        }
    }

    # Bracket not closed.
    return '}' if $depth;

    # We may have a trailing dot in our expression.  We check that now
    # and change the type of "variables" following a dot to a quoted
    # string.
    #
    # We also must repair the type for "variables" that look like numbers
    # and are enclosed in angle brackets.  Only in this case they are 
    # treated like numbers.  And numbers are the same as quoted strings
    # for our purposes.
    # If they are exactly between two brackets they are numbers, otherwise
    # we try them as variables.
    for (my $i = 0; $i < @tokens; ++$i) {
        if ('.' eq $tokens[$i]->[0]) {
            return $string if $i >= $#tokens;
            $tokens[++$i]->[0] = 'q';
        } elsif ('[' eq $tokens[$i]->[0]
                 && 'v' eq $tokens[$i + 1]->[0]
                 && ']' eq $tokens[$i + 2]->[0]
                 && $tokens[$i + 1]->[1] =~ /^[-+]?(?:0|[1-9][0-9]*)$/) {
            # Change the type to a quoted string.
            $tokens[$i + 1]->[0] = 'q';

            # And shorten the loop again.
            $i = $i + 2;
        }
    }

    return $string, @tokens;
}

sub evaluate($$) {
    my ($tokens, $data) = @_;

    my $cursor = $data;

    while (@$tokens) {
        my $token = shift @$tokens;
        my ($toktype, $value) = @$token;

        if ('[' eq $toktype) {
            # We have to recurse.
            my $key = evaluate $tokens, $data;
            $cursor = lookup $cursor, $key;
        } elsif (']' eq $toktype) {
            return $cursor;
        } elsif ('.' eq $toktype) {
            $token = shift @$tokens;
            $cursor = lookup $cursor, $token->[1]; 
        } elsif ('v' eq $toktype) {
            $cursor = lookup $cursor, $value;
        } elsif ('q' eq $toktype) {
            $cursor = $value;
        } else {
            die "unknown token type '$toktype'";
        }
    }

    return $cursor;
}

sub lookup($$) {
    my ($data, $key) = @_;

    my $type = reftype $data;
    if ('HASH' eq $type) {
        return $data->{$key};
    } elsif ('ARRAY' eq $type) {
        return $data->[$key];
    } else {
        return;
    }
}

sub js_unescape($) {
    my ($string) = @_;

    my %escapes = (
        "\n" => '',
        0 => "\000",    # Note that octal escapes are not supported!
        b => "\x08",
        f => "\x0c",
        n => "\x0a",
        r => "\x0d",
        t => "\x09",
        v => "\x0b",
        "'" => "'",
        '"' => '"',
        '\\' => '\\',
    );
    
    $string =~ s/
                \\
                  (
                    x[0-9a-fA-F]{2}
                    |
                    u[0-9a-fA-F]{4}
                    |
                    u\{[0-9a-fA-F]+\}
                    |
                    .
                  )
                /
                if (exists $escapes{$1}) {
                    $escapes{$1}
                } elsif (1 == length $1) {
                    $1;
                } elsif ('x' eq substr $1, 0, 1) {
                    chr oct '0' . $1;
                } elsif ('u' eq substr $1, 0, 1) {
                    if ('u{' eq substr $1, 0, 2) {
                        my $code = substr $1, 0, 2;
                        $code =~ s{^0+}{};
                        $code ||= '0';
                        chr oct '0x' . $code;
                    } else {
                        chr oct '0x' . substr $1, 1;
                    }
                }
                /xegs;
    
    return $string;
}

sub perl_identifier($) {
    my ($name) = @_;
    
    return $name =~ /^[_a-zA-Z][_0-9a-zA-Z]*$/o;
}

sub perl_class($) {
    my ($name) = @_;
    
    return $name =~ /^[_a-zA-Z][_0-9a-zA-Z]*(?:::[_a-zA-Z][_0-9a-zA-Z]*)*$/o;
}

sub slugify($;$) {
	my ($string, $locale) = @_;

    return '' if empty $string;

    Encode::_utf8_on($string);

    require Text::Unidecode;
    my $slug = lc Text::Unidecode::unidecode($string);

    # We only allow alphanumerical characters, the dot, the hyphen and the underscore.
    # Everything else gets converted into hyphens, and sequences of hyphens
    # are condensed into one.
    $slug =~ s/[\x00-\x2c\x2f\x3a-\x5e\x60\x7b-\x7f]/-/g;
    $slug =~ s/--+/-/g;

    return $slug;	
}
