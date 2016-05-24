#! /bin/false

package Qgoda::Util;

use strict;

use IO::File;
use File::Path qw(make_path);
use File::Basename qw(fileparse);
use Locale::TextDomain qw(com.cantanea.qgoda);
use Scalar::Util qw(reftype looks_like_number);

use base 'Exporter';
use vars qw(@EXPORT_OK);
@EXPORT_OK = qw(empty read_file write_file yaml_error front_matter lowercase
                expand_perl_format read_body merge_data interpolate);

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

sub expand_perl_format {
	my ($string, $hash) = @_;
	
	my $keys = join '|', keys %$hash, '{', '}';
	$string =~ s/
	            \{($keys)\}
	            /
	            if (defined $hash->{$1}) {
	            	$hash->{$1}
	            } elsif ('{' eq $1 || '}' eq $1) {
	            	$1
	            } else {
	            	''
	            }
	            /gxe;
	
	
	return $string;
}

sub merge_data {
	my ($data, $overlay) = @_;
	
	# Return $overlay if it is of a different type than $data.
	sub equal_ref {
		my ($x, $y) = @_;
		
		return 1 if ref $x && ref $y && ref $x eq ref $y;
	}

	return $overlay if !equal_ref $overlay, $data;
    return $overlay if UNIVERSAL::isa($overlay, 'ARRAY');
    
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

sub extract_number($) {
	my ($string) = @_;
	
	if ($string =~ s/^([-+]?
                     (?:0x[0-9a-f]+)           # Binary.
                     |
	                 (?:0[0-7]+)               # Octal.
	                 |
	                 (?:0b[01]+)               # Binary.
	                 )//xi) {
	    my $number = eval { oct $1 };
	    if ($@) {
	    	$number = '';
	    	$string = $1;
	    }
		return wantarray ? ($number, $string) : $number;
	}
	
	if ($string =~ s/^([-+]?
  	                # Integer part.
	                  (?:
	                    0                          # Lone 0.
	                    |
	                    [1-9][0-9]*                # Other integers.
	                  )
	                  # Fractional part.
	                  (?:
	                    \.
	                    [0-9]+
	                    (
	                      e
	                      [-+]?
  	                      (?:
	                        0
	                        |
	                        [1-9][0-9]*
	                      )
	                    )?
	                  )?
	                )//xi) {
	    my $number = eval "$1";
	    if ($@) {
            $number = '';
            $string = $1;
        }
        return wantarray ? ($number, $string) : $number;
	 }
	
}

sub __interpolate($$) {
	my ($string, $cursor) = @_;

    return '', '' if empty $string;
    my $reftype = reftype $cursor;
    if (!$reftype) {
    	$cursor = {};
    	$reftype = 'HASH';
    }
    
    if ($string =~ s/^([^\}\[\.\"\']+)//) {
    	my $match = $1;

        if ($match =~ /^[-+]?[0-9]+$/) {
        }   	
    }
    
	return $string, $string;
}

sub interpolate($$) {
    my ($string, $data) = @_;
    
    return $string if empty $string;
    
    my $result = '';
    while ($string =~ s/^([^{]*){//) {
    	$result .= $1;
    	my ($cooked, $remainder) = __interpolate $string, $data;
    	if ('}' eq substr $remainder, 0, 1) {
            $result .= $cooked;
            $string = substr $remainder, 1;
    	} else {
    		$result .= '{';
    	}
    }
    
    return $result . $string;
}

sub js_unescape() {
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
                		chr oct '0x' . substr $1, 0, 2;
                	} else {
                        chr oct '0x' . substr $1, 1;
                	}
                }
                /xegs;
    
    return $string;
}

sub tokenize() {
	my ($string) = @_;
    
    return [123400, 'n'];	
}
