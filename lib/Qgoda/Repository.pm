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

package Qgoda::Repository;

use strict;

use File::Spec;
use File::HomeDir;

use Qgoda::Util qw(read_file write_file);

use URI;

sub new {
	my ($class, $uri) = @_;

    $uri = URI->new($uri);

    if ($uri =~ m{^\.\.?\\/}) {
        $uri = 'file://' . File::Spec->rel2abs($uri);
        $uri =~ s{\\}{/}g;
        $uri = URI->new($uri);
    } elsif ($uri =~ s{^~([^/\\]*)}{}) {
        my $user = $1;
        my $home;
        if (length $user) {
            $home = File::HomeDir->user_home($user);
        } else {
            $home = File::HomeDir->my_home;
        }
        $uri = 'file://' . $home . '/' . $uri;
        $uri =~ s{\\}{/}g;
        $uri = URI->new($uri);
    }
    
    if (undef eq $uri->scheme) {
        my $file = "$uri";

        if (File::Spec->file_name_is_absolute($file)) {
            $uri = URI->new($file, 'file');
        } else {
            if (!-e $file && $file =~ m{/}) {
                $uri = URI->new('git://github.com/' . $file);
            } else {
                $uri = URI::file->new_abs($file);
            }
        }
    }

    my $self = {
        __uri => $uri
    };

    my $protocol = $uri->scheme;
    my %known = (
        'git' => 'Git',
        'git+ssh' => 'Git',
        'git+http' => 'Git',
        'git+https' => 'Git',
        'git+file' => 'Git',
        'file' => 'File'
    );

    $self->{__type} = $known{$protocol} || 'LWP';

    # If there is a git directory at the location, use git.
    if ('File' eq $self->{__type}) {
        my $path = $self->{__uri}->file;
        my $gitdir = File::Spec->catfile($path, '.git');
        if (-e $gitdir) {
            $self->{__uri} = URI->new($path, 'file');
            $self->{__type} = 'Git';
        }
    } elsif ('Git' eq $self->{__type}) {
        my $scheme = $self->{__uri}->scheme;
        if ($scheme =~ /\+(.*)/) {
            $self->{__uri}->scheme($1);
        }
    }

    if ($self->{__type}) {
        if ('Git' eq $self->{__type}) {
            if ('github.com' eq $self->{__uri}->host) {
                $self->{__source} = 'Github';
            }
        }
    }

    bless $self, $class;
}

sub type { shift->{__type} }
sub source { shift->{__source} }
sub uri { shift->{__uri} }

package URI::git;

use strict;

use base qw(URI::http);

package URI::git_Phttp;

use strict;

use base qw(URI::git);

package URI::git_Phttps;

use strict;

use base qw(URI::git);

package URI::git_Pssh;

use strict;

use base qw(URI::git);

package URI::git_Pfile;

use strict;

use base qw(URI::file);

1;