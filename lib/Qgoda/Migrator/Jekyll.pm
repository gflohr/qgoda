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

package Qgoda::Migrator::Jekyll;

use strict;

use Locale::TextDomain qw(qgoda);
use YAML::XS;
use File::Find;

use Qgoda;
use Qgoda::Util qw(empty read_file write_file yaml_error);
use Qgoda::Migrator::Jekyll::LiquidConverter;

use base qw(Qgoda::Migrator);

sub migrate {
    my ($self) = @_;

    my $qgoda = Qgoda->new;

    my $config = $self->readConfig;

    my $src_dir = $config->{source};
    $src_dir = '.' if empty $config->{source};
    $self->{_src_dir} = $src_dir;

    my $out_dir = $qgoda->getOption('output_directory');
    $out_dir = '_migrated' if empty $out_dir;
    $self->{_out_dir} = $out_dir;

    my $layouts_dir = delete $config->{layouts_dir};
    $layouts_dir = '_layouts' if empty $layouts_dir;
    $self->{__layouts_dir} = $layouts_dir;

    my $plugins_dir = delete $config->{plugins_dir};
    $plugins_dir = '_plugins' if empty $plugins_dir;
    $self->markFileDone($plugins_dir);

    my $destination = delete $config->{destination};
    $destination = '_site' if empty $destination;
    $self->markFileDone($destination);

    my $includes_dir = delete $config->{includes_dir};
    $includes_dir = '_includes' if empty $includes_dir;
    $self->{__includes_dir} = $includes_dir;

    my $new_config = $self->{_config} = $self->migrateConfig($config);

    my $views_dir = '_views';
    my $cc = -1;
    while (-e File::Spec->catdir($layouts_dir, $views_dir)) {
        $views_dir .= --$cc;
        $self->{_config}->{directory}->{views} = $views_dir;
    }
    $self->{__views_dir} = $views_dir;

    my $partials_dir = 'partials';
    while (-e File::Spec->catdir($layouts_dir, $partials_dir)) {
        $partials_dir .= 'X';
    }
    $self->{__partials_dir} = $partials_dir;

    $self->createOutputDirectory;

    $self->migrateLayouts;
    $self->migrateIncludes;
    $self->migratePosts;

    $self->writeConfig($new_config);

    # Convert assets while they are copied.
    my $fcopy = sub {
        my ($from, $to) = @_;

        return if !-e $to;

        my $liquid = read_file $to;
        # Front matter?
        if ($liquid !~ /^---[ \t\r]*\n.*\n---[ \t\r]*\n/s) {
            return $_[-1];
        }

        my $tt2 = $self->convertLiquidTemplate($to);
        write_file $to, $tt2
            or return $self->logError(__x("Error writing '{filename}':"
                                          . " {error}!\n",
                                          filename => $to,
                                          error => $!));

        return $_[-1];
    };
    $self->copyUndone($fcopy);

    if ($self->{_err_count}) {
        $self->logger->error(__(<<EOF));
The migration had errors! See above for details!
EOF
    }

    return $self;
}

sub migratePosts {
    my ($self) = @_;

    # This does not seem to be configurable in Jekyll.
    my $in_dir = '_posts';
    $self->markFileDone($in_dir);
    my $out_dir = $self->outputDirectory;

    my $posts_dir = 'posts';
    while (-e File::Spec->catfile($out_dir, $posts_dir)) {
        $posts_dir .= 'X';
    }
    $posts_dir = File::Spec->catfile($out_dir, $posts_dir);

    my $logger = $self->logger;
    $logger->info(__x("Migrating Jekyll posts from '{from_dir}' to "
                      . "Qgoda views in '{to_dir}'.\n",
                      from_dir => $in_dir, to_dir => $out_dir));

    my @jobs;
    my $wanted = sub {
        return if -d $_;
        push @jobs, $File::Find::name;
    };
    File::Find::find($wanted, $in_dir);

    foreach my $name (@jobs) {
        my $relpath = File::Spec->abs2rel($name, $in_dir);
        my ($volume, $directory, $filename) = File::Spec->splitpath($relpath);
        $filename =~ s/^[0-9]{4}-[0-9]{2}-[0-9]{2}-//;
        $relpath = File::Spec->catpath($volume, $directory, $filename);
        my $outpath = File::Spec->catfile($posts_dir, $relpath);

        my $count = -1;
        while (-e $outpath) {
            # Conflict.
            my ($stem, $extender) = ($relpath, '');
            if ($relpath =~ /(.*)(\..+)/) {
                ($stem, $extender) = ($1, $2);
            }
            $stem .= --$count;
            $relpath = $stem . $extender;
            $outpath = File::Spec->catfile($posts_dir, $relpath);
        }

        $logger->debug("  '$name' => '$outpath'");

        my $tt2 = $self->convertLiquidTemplate($name);

        $self->createFile($outpath, $tt2);
    }

    return $self;
}

sub migrateLayouts {
    my ($self) = @_;

    return $self->migrateLiquidDirectory($self->{__layouts_dir},
                                         $self->{__views_dir});
}

sub migrateIncludes {
    my ($self) = @_;

    my $partials_dir = File::Spec->catdir($self->{__views_dir},
                                          $self->{__partials_dir});
    return $self->migrateLiquidDirectory($self->{__includes_dir},
                                         $partials_dir);
}

sub migrateLiquidDirectory {
    my ($self, $in_dir, $out_dir) = @_;

    $self->markFileDone($in_dir);
    $out_dir = File::Spec->catfile($self->outputDirectory, $out_dir);

    my $logger = $self->logger;
    $logger->info(__x("Migrating Jekyll liquid template from '{from_dir}' to "
                      . "Qgoda views in '{to_dir}'.\n",
                      from_dir => $in_dir, to_dir => $out_dir));

    $self->createDirectory($out_dir);

    my @jobs;
    my $wanted = sub {
        return if -d $_;
        push @jobs, $File::Find::name;
    };
    File::Find::find($wanted, $in_dir);

    foreach my $name (@jobs) {
        my $relpath = File::Spec->abs2rel($name, $in_dir);
        my $outpath = File::Spec->catfile($out_dir, $relpath);

        $logger->debug("  '$name' => '$outpath'");

        my $tt2 = $self->convertLiquidTemplate($name);

        $self->createFile($outpath, $tt2);
    }

    return $out_dir;
}

sub convertLiquidTemplate {
    my ($self, $name) = @_;

    my $code = read_file $name
        or return $self->logError(__x("Error reading '{file}': {error}!",
                                      file => $name, error => $!));
    my $logger = $self->logger;
    my %options = (
        partials_dir => $self->{__partials_dir},
        includes_dir => $self->{__includes_dir},
    );
    my $converter = Qgoda::Migrator::Jekyll::LiquidConverter->new($name,
                                                                  $code,
                                                                  $logger,
                                                                  %options);
    my $tt2 = $converter->convert($code);
    $self->{_err_count} += $converter->errorCount;

    return $tt2;
}

sub migrateConfig {
    my ($self, $config) = @_;

    $self->markFileDone('_config.yml');
    $self->migrateDefaults($config);

    # Variables which currently do not exist in qgoda.  This is actually a
    # todo list for qgoda.
    # FIXME! "source" is supported but is called "srcdir".  But it is not
    # enough to just change the key.  We also have to make sure that it
    # not only exists.  We need a method like translateConfigVariable() for
    # that.
    foreach my $variable (qw(source destination safe keep_files timezone
                             encoding show_drafts future lsi
                             limit_posts incremental profile
                             port host baseurl detach webrick
                             no_fenced_code_blocks smart markdown
                             plugins_dir data_dir includes_dir
                             collections markdown_ext unpublished whitelist
                             gems highlighter excerpt_separator
                             show_dir_listing permalink paginate_path
                             quiet verbose liquid rdiscount redcarpet
                             kramdown error_mode)) {
        if (exists $config->{$variable}) {
            $self->logError(__x("The configuration variable '{varname}'"
                                . " from '_config.yaml' is not supported or"
                                . " by Qgoda or it does not make sense.",
                                varname => $variable));
        }
    }

    # JEKYLL_ENV = production

    return $config;
}

sub migrateDefaults {
    my ($self, $config) = @_;

    my $logger = $self->logger;
    $logger->debug(__"Migrating defaults.");

    my $old_defaults = $config->{defaults} or return $self;

    eval {
        my %defaults;
        foreach my $default (@$old_defaults) {
            my $scope = $default->{scope} or next;
            my $values = $default->{values} or next;
            if (!exists $scope->{path}) {
                my $dump = YAML::XS::Dump($scope);
                $dump =~ s/^/    /gm;
                $dump .= "    ---\n";
                $self->logError(__x("Cannot migrate default without path:\n"
                                    . "{dump}", dump => $dump));
                next;
            }
            my $path = $scope->{path};
            my $new = {
                values => {},
            };

            foreach my $key (keys %$values) {
                my ($name, $value) = $self->translateVariable($key,
                                                              $values->{$key});
                $new->{values}->{$name} = $value;
            }

            $defaults{$path} = $new;
        }

        $config->{defaults} = \%defaults;
    };
    if ($@) {
        $self->logError($@);
    }

    return $self;
}

sub readConfig {
    my ($self) = @_;

    my $logger = $self->logger;
    my $filename = '_config.yml';
    $logger->info(__x("reading configuration from '{filename}'",
                          filename => $filename));

    my $yaml = read_file $filename;
    if (!defined $yaml) {
        $logger->fatal(__x("error reading file '{filename}': {error}",
                           filename => $filename, error => $!));
    }
    my $config = eval { YAML::XS::Load($yaml) };
    $logger->fatal(yaml_error $filename, $@) if $@;

    return $config;
}

sub translateVariable {
    my ($self, $variable, $value) = @_;

    my %value_mapping = (
        type => {
            posts => 'post',
        },
    );
    my (%name_mapping) = (
        lang => 'lingua',
    );

    if (exists $value_mapping{$variable}
        && exists $value_mapping{$variable}->{$value}) {
        $value = $value_mapping{$variable}->{$value};
    }

    if (exists $name_mapping{$variable}) {
        $variable = $name_mapping{$variable};
    }

    return $variable, $value;
}

1;
