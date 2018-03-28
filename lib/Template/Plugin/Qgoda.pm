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

package Template::Plugin::Qgoda;

use strict;

use base qw(Template::Plugin);

use Locale::TextDomain qw('qgoda');
use File::Spec;
use Cwd;
use URI;
use Scalar::Util qw(reftype);
use JSON qw(encode_json decode_json);
use Date::Parse qw(str2time);
use POSIX qw(strftime setlocale LC_ALL );
use File::Basename;
use List::Util qw(pairmap);
use Locale::Util qw(web_set_locale);
use Encode;

use Qgoda;
use Qgoda::Util qw(collect_defaults merge_data empty read_file html_escape
                   escape_link);
use Qgoda::Builder;

sub new {
    my ($class, $context) = @_;

    return $class if ref $class;

    my $get_values = sub {
        my ($assets, @fields) = @_;

        my $stash = $context->stash->clone;

        # Find a random variable name.
        my $name = 'a';
        while (1) {
            last if empty $stash->get($name);
            ++$name;
        }

        my @values;
        my $i = 0;
        foreach my $asset (@$assets) {
            my @subvalues;
            push @values, [$i++, \@subvalues];

            # The variable name 'asset' is therefore not available.
            $stash->set($name => $asset);
            foreach my $field (@fields) {
                push @subvalues, $stash->get("$name.$field");
            }
        }

        $stash->declone;

        return @values;
    };

    sub compare_array {
        my $arr1 = $a->[1];
        my $arr2 = $b->[1];

        for (my $i = 0; $i < @$arr1; ++$i) {
            my ($val1, $val2) = ($arr1->[$i], $arr2->[$i]);

            return $val1 cmp $val2 if $val1 cmp $val2;
        }

        return 0;
    }

    sub ncompare_array {
        my $arr1 = $a->[1];
        my $arr2 = $b->[1];

        for (my $i = 0; $i < @$arr1; ++$i) {
            my ($val1, $val2) = ($arr1->[$i], $arr2->[$i]);

            return $val1 <=> $val2 if $val1 <=> $val2;
        }

        return 0;
    }

    my $sort_by = sub {
        my ($assets, $field) = @_;

        my @sorted = map { $assets->[$_->[0]] }
                     sort compare_array $get_values->($assets, $field);
        return \@sorted;
    };

    my $nsort_by = sub {
        my ($assets, $field) = @_;

        my @sorted = map { $assets->[$_->[0]] }
                     sort ncompare_array $get_values->($assets, $field);
        return \@sorted;
    };

    my $kebap_snake = sub {
        return {
            pairmap {
                $a =~ s/-/_/g;
                $a, $b;
            } %{$_[0]}
        };
    };

    my $kebap_camel = sub {
        return {
            pairmap {
                $a =~ s/-(.)/uc $1/ge;
                $a =~ s/-$/_/;
                $a, $b;
            } %{$_[0]}
        };
    };

    my %escapes = ('"' => 'quot', '&' => 'amp');
    my $quote_values = sub {
        return { 
            pairmap {
                $b =~ s/(["&])/&$escapes{$1};/og;
                $a, qq{"$b"}
            } %{$_[0]}
        };
    };

    $context->define_vmethod(list => sortBy => $sort_by);
    $context->define_vmethod(list => nsortBy => $nsort_by);
    $context->define_vmethod(scalar => slugify => \&Qgoda::Util::slugify);
    $context->define_vmethod(scalar => unmarkup => \&Qgoda::Util::unmarkup);
    $context->define_vmethod(hash => kebapSnake => $kebap_snake);
    $context->define_vmethod(hash => kebapCamel => $kebap_camel);
    $context->define_vmethod(hash => quoteValues => $quote_values);

    my $self = {
        __context => $context
    };
    bless $self, $class;
}

sub __getContext {
    shift->{__context};
}

sub __getStash {
    shift->{__context}->stash;
}

sub __getAsset {
    shift->{__context}->stash->{asset};
}

sub __getConfig {
    shift->{__context}->stash->{config};
}

sub bust_cache {
    my ($self, $uri) = @_;

    return $uri if $uri !~ m{^/};

    my($scheme, $authority, $path, $query, $fragment) =
        $uri =~ m|(?:([^:/?#]+):)?(?://([^/?#]*))?([^?#]*)(?:\?([^#]*))?(?:#(.*))?|o;
    return if !defined $path;

    require Qgoda;
    my $srcdir = Qgoda->new->config->{srcdir};
    my $fullpath = File::Spec->canonpath(File::Spec->catfile($srcdir, $path));

    my @stat = stat $fullpath or return $uri;
    if (defined $query) {
        return "$uri&$stat[9]"
    } else {
        return "$uri?$stat[9]"
    }
}

sub include {
    my ($self, $path, $overlay, $extra) = @_;

    die "usage: include(PATH, OVERLAY, KEY = VALUE, ...\n"
        if empty $path || empty $overlay;
    $overlay = $self->__sanitizeHashref($overlay, 'include');
    $extra = $self->__sanitizeHashref($extra, 'include', 1);

    my $asset = $self->__include($path, $overlay, $extra);

    return $asset->{content};
}

sub __include {
    my ($self, $_path, $overlay, $extra) = @_;

    require Qgoda;
    my $q = Qgoda->new;
    my $srcdir = $q->config->{srcdir};

    my $path = Cwd::abs_path($_path);
    if (!defined $path) {
        die __x("error including '{path}': {error}.\n",
                path => $_path, error => $!);
    }

    my $relpath = File::Spec->abs2rel($path, $srcdir);
    my $asset = Qgoda::Asset->new($path, $relpath);

    if ($overlay) {
        my %overlay = %$overlay;
        delete $overlay{path};
        delete $overlay{relpath};
        delete $overlay{reldir};
        delete $overlay{view};
        delete $overlay{chain};
        delete $overlay{wrapper};
        merge_data $asset, \%overlay;
    }

    merge_data $asset, $extra;

    $q->analyzeAssets([$asset], $extra);
    $q->locateAsset($asset);

    my $builders = $q->getBuilders;
    my $site = $q->getSite;
    foreach my $builder (@{$builders}) {
        $builder->processAsset($asset, $site);
        $builder->wrapAsset($asset, $site);
    }

    return $asset;
}

sub __sanitizeFilters {
    my ($self, $filters) = @_;

    return {} if empty $filters;
    if (!ref $filters) {
        die __x("invalid filters '{filters}' (used named arguments)\n",
                filters => $filters);
    }

    my $reftype = reftype $filters;
    if ('ARRAY' eq $reftype) {
        my $json = encode_json($filters);
        $json =~ s{.(.*).}{$1};
        die __x("invalid filters '{filters}' (use named arguments)\n",
                 filters => $json);
    } elsif ('HASH' ne $reftype) {
        die __x("invalid filters '{filters}' (use named arguments)\n",
                 filters => $filters);
    }

    # The caller may want to add default filters.  Make sure that the original
    # reference is kept untouched.
    return {%$filters};
}

sub __sanitizeHashref {
    my ($self, $hashref, $method, $optional) = @_;

    if (empty $hashref) {
        if ($optional) {
            return {};
        } else {
            die __x("named arguments for '{method}()' are mandatory\n",
                    method => $method);
        }
    }

    if (!ref $hashref) {
        die __x("method '{method}' requires named arguments, not '{args}'",
                method => $method, args => $hashref);
    }

    my $reftype = reftype $hashref;
    if ('ARRAY' eq $reftype) {
        my $json = encode_json($hashref);
        $json =~ s{.(.*).}{$1};
        die __x("invalid arguments '{args}' for method '{method}()'"
                . " (use named arguments)\n",
                 args => $json, method => $method);
    } elsif ('HASH' ne $reftype) {
        die __x("invalid arguments '{args}' for method '{method}()'"
                . " (use named arguments)\n",
                 args => $hashref, method => $method);
    }

    return $hashref;
}

sub list {
    my ($self, $filters) = @_;

    $filters = $self->__sanitizeFilters($filters);

    my $site = Qgoda->new->getSite;
    return $site->searchAssets(%$filters);
}

sub llist {
    my ($self, $filters) = @_;

    $filters = $self->__sanitizeFilters($filters);
    $filters->{lingua} = $self->__getAsset->{lingua};

    return $self->list($filters);
}

sub listPosts {
    my ($self, $filters) = @_;

    $filters = $self->__sanitizeFilters($filters);
    $filters->{type} = 'post';

    return $self->list($filters);
}

sub llistPosts {
    my ($self, $filters) = @_;

    $filters = $self->__sanitizeFilters($filters);
    $filters->{lingua} = $self->__getAsset->{lingua};

    return $self->listPosts($filters);
}

sub link {
    my ($self, $filters) = @_;

    $filters = $self->__sanitizeFilters($filters);

    my $set = $self->list($filters);
    if (@$set == 0) {
        my $json = encode_json($filters);
        $json =~ s{.(.*).}{$1};
        warn "broken link($json)\n";
        return '';
    } if (@$set > 1) {
        my $json = encode_json($filters);
        $json =~ s{.(.*).}{$1};
        warn "ambiguous link($json)\n";
    }

    return $set->[0]->{permalink};
}

sub xref {
    my ($self, $variable, $filters) = @_;

    $filters = $self->__sanitizeFilters($filters);

    my $set = $self->list($filters);
    if (@$set == 0) {
        my $json = encode_json($filters);
        $json =~ s{.(.*).}{$1};
        warn "broken xref($json)\n";
    } if (@$set > 1) {
        my $json = encode_json($filters);
        $json =~ s{.(.*).}{$1};
        warn "ambiguous xref($json)\n";
    }

    return $set->[0]->{$variable};
}

sub llink {
    my ($self, $filters) = @_;

    $filters = $self->__sanitizeFilters($filters);
    $filters->{lingua} = $self->__getAsset->{lingua};

    return $self->link($filters);
}

sub lxref {
    my ($self, $variable, $filters) = @_;

    $filters = $self->__sanitizeFilters($filters);
    $filters->{lingua} = $self->__getAsset->{lingua};

    return $self->xref($variable, $filters);
}

sub anchor {
    my ($self, $filters) = @_;

    my $href = escape_link $self->link($filters);
    my $title = html_escape $self->xref(title => $filters);

    return qq{<a href="$href">$title</a>};
}

sub lanchor {
    my ($self, $filters) = @_;

    my $href = escape_link $self->llink($filters);
    my $title = html_escape $self->lxref(title => $filters);

    return qq{<a href="$href">$title</a>};
}

sub linkPost {
    my ($self, $filters) = @_;

    $filters = $self->__sanitizeFilters($filters);
    $filters->{type} = 'post';

    my $set = $self->list($filters);
    if (@$set == 0) {
        my $json = encode_json($filters);
        $json =~ s{.(.*).}{$1};
        die "broken linkPost($json)\n";
    } if (@$set > 1) {
        my $json = encode_json($filters);
        die "ambiguous linkPost($json)\n";
    }

    return $set->[0]->{permalink};
}

sub llinkPost {
    my ($self, $filters) = @_;

    $filters = $self->__sanitizeFilters($filters);
    $filters->{lingua} = $self->__getAsset->{lingua};

    return $self->linkPost($filters);
}

sub writeAsset {
    my ($self, $path, $overlay, $extra) = @_;

    die "usage: writeAsset(PATH, OVERLAY, KEY = VALUE, ...\n"
        if empty $path || empty $overlay;
    $overlay = $self->__sanitizeHashref($overlay, 'include');
    $extra = $self->__sanitizeHashref($extra, 'include', 1);

    my $asset = $self->__include($path, $overlay, $extra);

    my $q = Qgoda->new;
    my $logger = $q->logger('template');
    my $builder = Qgoda::Builder->new;
    my $site = $q->getSite;

    $builder->saveArtefact($asset, $site, $asset->{location});
    $logger->debug(__x("successfully built '{location}'",
                       location => $asset->{location}));

    return '';
}

sub clone {
    my ($self, $extra) = @_;

    $extra = $self->__sanitizeHashref($extra, 'clone', 1);
    die __"the argument 'location' is mandatory for clone()\n"
        if empty $extra->{location};

    my $asset = $self->__getAsset;
    my $parent = $asset->{parent} ? $asset->{parent} : {
        location => $asset->{location},
    };

    # Force these values.
    $extra->{relpath} = $asset->getRelpath;
    $extra->{path} = $asset->getPath;
    $extra->{parent} = $parent;
    return $self->writeAsset($asset->getRelpath, $asset, $extra);
}

sub strftime {
    my ($self, $format, $date, $lingua) = @_;

    my $time = $date =~ /^[-+]?[1-9][0-9]*$/ ? "$date" : str2time $date;
    $time = $date if !defined $time;

    $format = '%c' if empty $format;

    my $saved_locale;    
    if (!empty $lingua) {
        $saved_locale = POSIX::setlocale(LC_ALL);
        web_set_locale($lingua, 'utf-8') if $lingua;
    }

    my $formatted_date = POSIX::strftime($format, localtime $time);

    POSIX::setlocale(LC_ALL, $saved_locale) if defined $saved_locale;

    Encode::_utf8_off($formatted_date);
    return $formatted_date;
}

sub try {
    require Carp;
    Carp::croak("q.try is now invalid");
}

sub paginate {
    my ($self, $data) = @_;

    $data = $self->__sanitizeHashref($data, 'paginate', 1);
    die __"argument '{total}' is mandatory for paginate()\n"
        if empty $data->{total};
    die __"argument '{total}' cannot be zero paginate()\n"
        if !$data->{total};

    use integer;

    my $start = $data->{start} || 0;
    my $total = $data->{total} || return {};
    my $per_page = $data->{per_page} || 10;
    my $page0 = $start / $per_page;
    my $page = $page0 + 1;
    my $stem = $data->{stem};
    my $extender = $data->{extender};
    my $total_pages = 1 + ($total - 1) / $per_page;

    my $asset = $self->__getAsset;
    my $location;
    if (!empty $asset->{plocation}) {
        $location = $asset->{plocation};
    } elsif ($asset->{parent}) {
        $location = $asset->{parent}->{location};
    } else {
        $location = $asset->{location};
    }
    my $basename = basename $location;

    $basename =~ m{(.*?)(\..+)?$};
    $stem = $1 if empty $stem;
    $extender = $2 if empty $extender;

    my ($next_start, $next_location);
    if ($page < $total_pages) {
        $next_start = $start + $per_page;
        $next_location = dirname $location;
        $next_location .= "/${stem}-" . ($page + 1) . $extender;
    }

    # FIXME! Not flexible enough.  We cannot put pages into a subdirectory.
    my @links;
    for (my $i = 1; $i <= $total_pages; ++$i) {
        my $link = $stem;
        $link .= "-$i" if $i > 1;
        $link .= $extender;
        push @links, $link;
    }
    my $previous_page = $page0 ? $page0 : undef;
    my $next_page = $start + $per_page < $total ? $page0 + 2 : undef;

    $previous_page = $links[$previous_page - 1] if defined $previous_page;
    $next_page = $links[$next_page - 1] if defined $next_page;

    my @tabindexes = (0) x $#links;
    $tabindexes[$page0] = -1;
    $tabindexes[0] = -1 if !defined $previous_page;

    my $retval = {
        start => $start,
        page0 => $page0,
        page => $page,
        per_page => $per_page,
        total_pages => $total_pages,
        previous_link => $previous_page,
        next_link => $next_page,
        links => \@links,
        tabindices => \@tabindexes,
        tabindexes => \@tabindexes,
        next_start => $next_start,
        next_location => $next_location,
    };

    return $retval;
}

sub taxonomyValues {
    my ($self, $taxonomy, $filters) = @_;

    my $filters = $self->__sanitizeFilters($filters);
    my $site = Qgoda->new->getSite;

    my @values = $site->getTaxonomyValues($taxonomy, %$filters);

    return [sort @values];
}

sub ltaxonomyValues {
    my ($self, $taxonomy, $filters) = @_;

    $filters = $self->__sanitizeFilters($filters);
    $filters->{lingua} = $self->__getAsset->{lingua};

    return $self->taxonomyValues($taxonomy, $filters);
}

sub sprintf {
    my ($self, $fmt, @args) = @_;

    return sprintf $fmt, @args;
}

sub loadJSON {
    my ($self, $filename) = @_;

    die __x("loadJSON('{filenname}'): absolute paths are not allowed!\n",
            filename => $filename)
        if File::Spec->file_name_is_absolute($filename);

    my $absolute = File::Spec->rel2abs($filename, Qgoda->new->config->{srcdir});
    my ($volume, $directories, undef) = File::Spec->splitpath($absolute);
    my @directories = File::Spec->splitdir($absolute);
    map { 
        $_ eq File::Spec->updir and
            die __x("'{filenname}'): '{updir}' is not allowed!\n",
                    filename => $filename, updir => File::Spec->updir);
    } File::Spec->splitdir($absolute);

    my $json = read_file $filename or return;
    my $data = eval { decode_json $json };
    return if !defined $data;

    return $data;
}

sub related {
    my ($self, $threshold, $filters) = @_;

    my $asset = $self->__getAsset;
    my @related = map { $_->[0] } 
                  sort { $b->[1] <=> $a->[1] }
                  grep { $_->[1] >= $threshold } 
                  @{$asset->{related}};

    $filters = $self->__sanitizeFilters($filters);

    my $site = Qgoda->new->getSite;

    return $site->filter(\@related, %$filters);
}

sub lrelated {
    my ($self, $threshold, $filters) = @_;

    $filters = $self->__sanitizeFilters($filters);
    $filters->{lingua} = $self->__getAsset->{lingua};

    return $self->related($threshold, $filters);
}

1;
