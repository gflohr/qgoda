#! /bin/false

# Copyright (C) 2016-2018 Guido Flohr <guido.flohr@cantanea.com>,
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

package Qgoda::Schemas;

use strict;

use boolean;
use Locale::TextDomain qw(qgoda);

use Qgoda;

sub config {
	return {
		'$schema' => 'http => //json-schema.org/draft-07/schema#',
		'$id' => 'http => //www.qgoda.net/schema/'
		         . $QGODA::VERSION . '/config.schema.json',
		title => __"Configuration",
		description => __"A Qgoda Configuration",
		type => 'object',
		properties => {
			'case-sensitive' => {
				description => __"Should a case-sensitive file system be "
				               . "assumed (default => false)",
				type => 'boolean'
			},
			'compare-output' => {
				description => __"Should existing output files be read and "
				               . "compared to the new version to avoid "
				               . "updating timestamps (default => true)",
				type => 'boolean'
			},
			defaults => {
				description => __"Default values, see "
				               . "http://www.qgoda.net/en/docs/defaults",
				type => 'array',
				items => {
					description => __"A list of objects with properties "
					               . "'files' and 'values', default => empty",
					type => 'object',
					required => [qw(files values)],
					additionalProperties => false,
					properties => {
						files => {
							description => "Either one single file name "
							               . "pattern or a list of file name "
							               . "patterns.  Files that match will "
							               . "receive the values specified.",
							type => [qw(array string)],
							items => {
								type => 'string'
							}
						},
						values => {
							description => "Values that should be set for "
							               + "matching files.",
							type => 'object',
						}
					}
				}
			},
			exclude => {
				description => __"List of additional file name patterns that "
				               . "should be ignored for building the site "
				               . "(default: empty).",
				type => 'array',
				items => {
					type => 'string'
				}
			},
			'exclude-watch' => {
				description => __"List of additional file name patterns that "
				               . "should be ignored when changed in watch mode "
				               . "(default => empty)",
				type => 'array',
				items => {
					type => 'string'
				}
			},
			'front-matter-placeholder' => {
				description => __"An object of valid chain names or '*' that "
				               . "give the frontmatter placeholder string "
				               . "for each configured processor chain.",
				type => 'object'
			},
			generator => {
				description => __x("Value for the generator meta tag in "
				               . "generated pages, defaults to 'Qgoda "
				               . "v{version} (http => //www.qgoda.net)'",
				               version => $Qgoda::VERSION),
				type => 'string'
			},
			helpers => {
				description => __"Key-value pairs of command identifiers and "
				               . "the command to run in parallel, when running "
				               . "in watch mode. Default: empty.",
				type => 'object',
				additionalProperties => false,
				patternProperties => {
					'.+' => {
						type => [qw(array string)],
						items => {
							type => 'string'
						}
					}
				}
			},
			index => {
				description => "Basename of a file that is considered to be "
				               . "the index document of a directory, defaults "
				               . "to 'index'.",
				type => 'string'
			},
			latency => {
				descriptions => "Number of seconds to wait until a rebuild "
				                . "is triggered after a file system change in "
				                . "watch mode, defaults to 0.5 s.",
				type => 'number',
				minimum => 0
			},
			linguas => {
				description => "List of language identifiers complying to "
				               . "RFC4647 section 2.1 but without any asterisk "
				               . "(*) characters.",
				type => 'array',
				items => {
					type => 'string',
					pattern => "[a-zA-Z]{1,8}(-[a-zA-z0-9]{8})?"
				}
			},
			location => {
				description => "Template string for output location, "
				               . "defaults to "
				               . "'/{directory}/{basename}/{index}{suffix}'.",
				type => 'string'
			},
			'no-scm' => {
				description => "List of additional file name patterns that "
				               . "should be processed in scm mode, even when "
				               . "not under version control (default => empty)",
				type => 'array',
				items => {
					type => 'string'
				}
			},
			paths => {
				description => "Configurable paths.",
				type => 'object',
				properties => {
					plugins => {
						description => "Directory for plug-ins, default "
						               . "'_plugins'.",
						type => 'string'
					},
					po => {
						description => "Directory for po files and other i18n "
						               . "related files, default '_po'.",
						type => 'string'
					},
					site => {
						description => "Directory where to store rendered "
						               . "files, defaults to absolute path of "
						               . "'_site'.",
						type => 'string'
					},
					timestamp => {
						description => "Name of the timestamp file containing "
						               . "the seconds since the epoch since "
						               . "the last write of the site, defults "
						               . "to '_timestamp'.",
						type => 'string'
					},
					views => {
						description => "Directory where view templates are "
						               . "searched, defaults to '_views'.",
						type => 'string'
					}
				}
			},
			permalink => {
				description => "Template string for permalinks, defaults to "
				               . "'{significant-path}'.",
				type => 'string'
			},
			po => {
				description => "Variables for internationalization (i18n) and "
				               . "the translation workflow.",
				type => 'object',
				additionalProperties => false,
				properties => {
					'copyright-holder' => {
						description => "Copyright information for the original "
						               . "content.",
						type => 'string'
					},
					mdextra => {
						description => "List of file name patterns for "
						               . "additional markdown files to "
						               . "translate.",
						type => 'array',
						items => {
							type => 'string'
						}
					},
					msgfmt => {
						description => "The msgfmt command (or an array of "
						               . "the program name plus arguments), "
						               . "defaults to 'msgfmt'.",
						type => ['array', 'string'],
						items => {
							type => 'string'
						}
					},
					'msgid-bugs-address' => {
						description => "Where to report translation problems "
						               . "with the original strings.",
						type => 'string'
					},
					msgmerge => {
						description => "The msgmerge command (or an array of "
						               . "the program name plus arguments), "
						               . "defaults to 'msgmerge'.",
						type => [qw(array string)],
						items => {
							type => 'string'
						}
					},
					qgoda => {
						description => "The qgoda command (or an array of the "
						               . "program name plus arguments), "
						               . "defaults to 'qgoda'.",
						type => [qw(array string)],
						items => {
							type => 'string'
						}
					},
					reload => {
						description => "Whether to throw away the "
						               . "translation before every rebuild, "
						               . "defaults to false.",
						type => 'boolean'
					},
					textdomain => {
						description => __"An identifier for the translation "
						                . "catalog (textdomain), defaults to "
						                . "'messages'.",
						type => 'string'
					},
					tt2 => {
						description => __"A list of file name patterns or one "
						                . "single pattern, where translatable "
						                . "templates for the Template Toolkit "
						                . "version 2 are stored, defaults to "
						                . "'_views'.",
						types => [qw(array string)],
						items => {
							type => 'string'
						}
					},
					xgettext => {
						description => __"The xgettext command (or an array of "
						               . "the program name plus arguments), "
						               . "defaults to 'xgettext'.",
						type => [qw(array string)],
						items => {
							type => 'string'
						}
					},
					'xgettext-tt2' => {
						description => __"The xgettext-tt2 command (or an "
						               . "array of the program name plus "
						               . "arguments), defaults to "
						               . "'xgettext-tt2'.",
						type => [qw(array string)],
						items => {
							type => 'string'
						}
					}
				}
			}
		}
	}
};
