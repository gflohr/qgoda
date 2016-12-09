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

package Qgoda::Migrator::Jekyll::LiquidConverter;

use strict;

use Locale::TextDomain qw(com.cantanea.qgoda);

use Qgoda;
use Qgoda::Util qw(trim);

sub new {
    my ($class, $filename, $code, $logger, %options) = @_;

    $options{tt2_start} ||= '[%';
    $options{tt2_end} ||= '%]';
    $options{offset} ||= 1;

    bless {
        __filename => $filename,
        __code => $code,
        __logger => $logger,
        __options => { %options },
        __plugins => {},
    }, $class;
}

sub convert {
    my ($self) = @_;

    my $code = $self->{__code};
    $self->{__lineno} = 1 + $self->{__options}->{offset};

    my $output = '';
    while ($code =~ s/^(.*?)(\{\{|\{%|\n)//) {
        $output .= $1;
        if ('{{' eq $2) {
            $output .= $self->startTag;
            $output .= $self->convertObject(\$code);
        } elsif ('{%' eq $2) {
            $output .= $self->startTag;
            $output .= $self->convertTag(\$code);
        } else {
            $output .= $2;
            ++$self->{__lineno};
        }
    }
    
    $output .= $code if length $code;

    my $plugins = '';
    foreach my $plugin (keys %{$self->{__plugins}}) {
    	$plugins .= "[%- USE $plugin -%]\n";
    }

    return $plugins . $output;
}

sub errorCount {
	my ($self) = @_;
	
	return $self->{__err_count} || 0;
}

sub convertObject {
    my ($self, $coderef) = @_;
    
    my $output = '';
    $output .= $self->consumeWhitespace($coderef);
    
    # FIXME! We need something like translateExpression that interprets
    # balanced round parentheses.
    $output .= $self->translateToken($self->consumeNonWhitespace($coderef));
    
    # FIXME! Consume the filters!
    
    $output .= $self->proceedToObjectEnd($coderef);
    
    return $output;
}

sub convertTag {
	my ($self, $coderef) = @_;
	
	my $output = '';
    $output .= $self->consumeWhitespace($coderef);
    
    if ($$coderef =~ s{^([a-z]+)}{}) {
    	if ('if' eq $1) {
    		$output .= $self->onTagIf($coderef);
    	} elsif ('for' eq $1) {
    		$output .= $self->onTagFor($coderef);
    	} elsif ('include' eq $1) {
    		$output .= $self->onTagInclude($coderef);
        } elsif ('endif' eq $1) {
            $output .= $self->onTagEnd($coderef);
        } elsif ('endfor' eq $1) {
            $output .= $self->onTagEnd($coderef);
    	} else {
    		$output .= __x("# Unknown liquid tag '{tag}'!\n", tag => $1);
    		$output .= $1;
    		$self->logError(__x("Unknown liquid tag '{tag}'!",
    		                   tag => $1));
            $output .= $self->proceedToTagEnd($coderef);
    	}
    }
    
	return $output;
}

sub consumeWhitespace {
	my ($self, $coderef) = @_;
	
	my $output .= '';

	while ($$coderef =~ s/^([\x09-\x0d ])//g) {
		$output .= $1;
		++$self->{__lineno} if $1 eq "\n";
	}
	
	return $output;
}

sub consumeNonWhitespace {
    my ($self, $coderef) = @_;
    
    my $output .= '';

    while ($$coderef =~ s/^([^\x09-\x0d ])//g) {
        $output .= $1;
        ++$self->{__lineno} if $1 eq "\n";
    }
    
    return $output;
}

sub proceedToTagEnd {
    my ($self, $coderef) = @_;
    
    my $output = '';
    
    while ($$coderef =~ s/^([^\n%]+)//g) {
        $output .= $1;
        if ($$coderef =~ s/^\n//) {
            ++$self->{__lineno};
            $output .= "\n";
        } elsif ($$coderef =~ s/^\%\}//) {
            $output .= $self->endTag;
            last;
        } else {
            $output .= $1;
        }
    }
    
    return $output;
}

sub proceedToObjectEnd {
    my ($self, $coderef) = @_;
    
    my $output = '';
    
    while ($$coderef =~ s/^([^\n}]+)//g) {
        $output .= $1;
        if ($$coderef =~ s/^\n//) {
            ++$self->{__lineno};
            $output .= "\n";
        } elsif ($$coderef =~ s/^\}\}//) {
            $output .= $self->endTag;
            last;
        } else {
            $output .= $1;
        }
    }
    
    return $output;
}

sub startTag { 
    my ($self) = @_;
    
    return $self->{__options}->{tt2_start};
}

sub endTag { 
    my ($self) = @_;
    
    return $self->{__options}->{tt2_end};
}

sub onTagIf {
    my ($self, $coderef) = @_;
    
    my $output = 'IF';
    $output .= $self->consumeWhitespace($coderef);
    
    my $token = $self->consumeNonWhitespace($coderef);
    $output .= $self->translateToken($token);
    
    $output .= $self->proceedToTagEnd($coderef);
    
    return $output;
}

sub onTagEnd {
    my ($self, $coderef) = @_;
    
    my $output = 'END';
    
    $output .= $self->proceedToTagEnd($coderef);
    
    return $output;
}

sub onTagFor {
    my ($self, $coderef) = @_;
    
    my $output = 'FOREACH';
    $output .= $self->consumeWhitespace($coderef);
    $output .= $self->consumeNonWhitespace;
    $output .= $self->consumeWhitespace($coderef);
    my $in = $self->consumeNonWhitespace($coderef);
    if ('in' ne $in) {
    	$self->logError(__x("Expected 'in', got '{got}!'",
    	                    got => $in));
    	$output .= $in;
    } else {
    	$output .= 'IN';
    }
    
    $output .= $self->proceedToTagEnd($coderef);
    
    return $output;
}

sub onTagInclude {
	my ($self, $coderef) = @_;
	
	my $output = 'INCLUDE';
	
	$output .= $self->consumeWhitespace($coderef);

    my $filename = $self->consumeNonWhitespace($coderef);
    if ($filename =~ /^"'/) {
    	# Requote and insert the prefix!
    	$filename = $self->requote($filename);
    	$filename =~ s/(.)/$self->{__options}->{partials_dir}/;
    } else {
    	if (-e File::Spec->catfile($self->{__options}->{includes_dir}, $filename)) {
    		# Assume that this is really a filename.
    	    $filename = $self->{__options}->{partials_dir} . '/' . $filename;
    	    $output .= $self->requote(qq{"$filename"});
    	} else {
    		$output .= $self->translateToken($filename);
    	}
    }
    
    $output .= $self->proceedToTagEnd($coderef);
	
	return $output;
}

sub logError {
    my ($self, $msg) = @_;
    
    $msg = "$self->{__filename}:$self->{__lineno}: $msg";

    $self->{__logger}->error($msg);
    ++$self->{__err_count};
        
    # This allows the construct $self->logError or return;
    return;
}

sub translateVariable {
	my ($self, $variable) = @_;
	
	my %mapping = (
	    lang => 'lingua',
	    content => 'asset.content',
	);
	
	return $mapping{$variable} if exists $mapping{$variable};
	
	return $variable;
}

sub requote {
	my ($self, $quoted) = @_;

    if ($quoted =~ /"(.*)"/s) {
    	$quoted = $1;
    	$quoted =~ s/([\\"])/\\$1/gs;
    	$quoted = qq{"$quoted"};
    } elsif ($quoted =~ /'(.*)'/s) {
        $quoted = $1;
        $quoted =~ s/([\\'])/\\$1/gs;
        $quoted = qq{'$quoted'};
    }
    
    return $quoted;
}

sub translateToken {
	my ($self, $token) = @_;

    # Liquid seems to have no escapes.
    $token =~ s/(".*?")/$self->requote($1)/ges;
    $token =~ s/('.*?')/$self->requote($1)/ges;
    
    # Now extract everything that looks like a variable.
	$token =~ s/(\A|[\[\]])(.*?)(\A|[\[\]])/
	            $1 . $self->translateVariable($2) . $3/ges;
	
	return $token;
}

sub addPlugin {
	my ($self, $plugin) = @_;
	
	$self->{__plugins}->{$plugin} = 1;
	
	return $self;
}

1;