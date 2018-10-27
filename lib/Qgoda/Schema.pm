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

package Qgoda::Schema;

use strict;

use Locale::TextDomain qw(qgoda);
use Cwd;
use JSON::PP;
use File::Spec;

use Qgoda;

use constant true => $JSON::PP::true;
use constant false => $JSON::PP::false;

sub config {
	# FIXME! Fill in the variable parts.
	return {
		'$schema' => 'http://json-schema.org/draft-07/schema#',
		'$id' => 'http://www.qgoda.net/schema/Qgoda/v'
		         . $Qgoda::VERSION
				 . '/config.schema.json',
		title => __"Configuration",
		description => __"A Qgoda Configuration",
		type => 'object',
		properties => {
			'case-sensitive' => {
				description => __"Set to true if a case-sensitive file system "
				               . "shoud be assumed.",
				type => 'boolean',
				default => false
			},
			'compare-output' => {
				description => __"Should existing output files be read and "
				               . "compared to the new version to avoid "
				               . "updating timestamps (default => true)",
				type => 'boolean',
				default => true
			},
			defaults => {
				description => __"Default values, see "
				               . "http://www.qgoda.net/en/docs/defaults",
				type => 'array',
				default => [],
				items => {
					description => __"A list of objects with properties "
					               . "'files' and 'values', default => empty",
					type => 'object',
					required => [qw(files values)],
					additionalProperties => false,
					properties => {
						files => {
							description => __"Either one single file name "
							               . "pattern or a list of file name "
							               . "patterns.  Files that match will "
							               . "receive the values specified.",
							type => [qw(array string)],
							items => {
								type => 'string'
							}
						},
						values => {
							description => __"Values that should be set for "
							               . "matching files.",
							type => 'object',
						}
					}
				}
			},
			exclude => {
				description => __"List of additional file name patterns that "
				               . "should be ignored for building the site.",
				type => 'array',
				items => {
					type => 'string'
				},
				default => []
			},
			'exclude-watch' => {
				description => __"List of additional file name patterns that "
				               . "should be ignored when changed in watch "
				               . "mode.",
				type => 'array',
				items => {
					type => 'string'
				},
				default => []
			},
			'front-matter-placeholder' => {
				description => __"An object of valid chain names or '*' that "
				               . "give the frontmatter placeholder string "
				               . "for each configured processor chain.",
				type => 'object',
				default => {
					'*' => "[% '' %]\n"
				}
			},
			generator => {
				description => __"Value for the generator meta tag in "
				               . "generated pages.",
				type => 'string',
				default => __x("Qgoda v{version} (http://www.qgoda.net)",
				               version => $Qgoda::VERSION),
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
				},
				default => {}
			},
			index => {
				description => __"Basename of a file that is considered to be "
				               . "the index document of a directory.",
				type => 'string',
				default => 'index'
			},
			latency => {
				descriptions => "Number of seconds to wait until a rebuild "
				                . "is triggered after a file system change in "
				                . "watch mode.",
				type => 'number',
				minimum => 0,
				default => 0.5
			},
			linguas => {
				description => __"List of language identifiers complying to "
				               . "RFC4647 section 2.1 but without any asterisk "
				               . "(*) characters.",
				type => 'array',
				items => {
					type => 'string',
					pattern => "[a-zA-Z]{1,8}(-[a-zA-z0-9]{8})?"
				}
			},
			location => {
				description => __"Template string for the output location.",
				type => 'string',
				default => '/{directory}/{basename}/{index}{suffix}'
			},
			'no-scm' => {
				description => __"List of additional file name patterns that "
				               . "should be processed in scm mode, even when "
				               . "not under version control",
				type => 'array',
				items => {
					type => 'string'
				},
				default => []
			},
			paths => {
				description => __"Configurable paths.",
				type => 'object',
				required => [qw(plugins po site timestamp views)],
				default => {},
				properties => {
					plugins => {
						description => __"Directory for plug-ins.",
						type => 'string',
						default => '_plugins'
					},
					po => {
						description => __"Directory for po files and other i18n "
						               . "related files.",
						type => 'string',
						default => '_po'
					},
					site => {
						description => __"Directory where to store rendered "
						               . "files, defaults to the absolute path "
									   . "to '_site' in the current directory.",
						type => 'string',
						default => File::Spec->catdir(Cwd::abs_path(''), '_site')
					},
					timestamp => {
						description => __"Name of the timestamp file containing "
						               . "the seconds since the epoch since "
						               . "the last write of the site.",
						type => 'string',
						default => '_timestamp'
					},
					views => {
						description => __"Directory where view templates are "
						               . "searched.",
						type => 'string',
						default => '_views',
					}
				}
			},
			permalink => {
				description => __"Template string for permalinks.",
				type => 'string',
				default => '{significant-path}'
			},
			po => {
				description => __"Variables for internationalization (i18n) and "
				               . "the translation workflow.",
				type => 'object',
				additionalProperties => false,
				default => {},
				properties => {
					'copyright-holder' => {
						description => __"Copyright information for the original "
						               . "content.",
						type => 'string',
						default => __x("Set {variable} in '_config.yaml'.",
						               variable => 'config.po.copyright-holder')
					},
					mdextra => {
						description => __"List of file name patterns for "
						               . "additional markdown files to "
						               . "translate.",
						type => 'array',
						items => {
							type => 'string'
						},
						default => []
					},
					msgfmt => {
						description => __"The msgfmt command (or an array of "
						               . "the program name plus arguments), "
						               . "defaults to 'msgfmt'.",
						type => ['array', 'string'],
						items => {
							type => 'string'
						},
						default => 'msgfmt'
					},
					'msgid-bugs-address' => {
						description => __"Where to report translation problems "
						               . "with the original strings.",
						type => 'string',
						default => __x("Set {variable} in '_config.yaml'.",
						               variable => 'config.po.msgid-bugs-address')
					},
					msgmerge => {
						description => __"The msgmerge command (or an array of "
						               . "the program name plus arguments), "
						               . "defaults to 'msgmerge'.",
						type => [qw(array string)],
						items => {
							type => 'string'
						},
						default => 'msgmerge'
					},
					qgoda => {
						description => __"The qgoda command (or an array of the "
						               . "program name plus arguments), "
						               . "defaults to 'qgoda'.",
						type => [qw(array string)],
						items => {
							type => 'string'
						},
						default => 'qgoda',
					},
					reload => {
						description => __"Whether to throw away the "
						               . "translation before every rebuild, "
						               . "defaults to false.",
						type => 'boolean',
						default => false
					},
					textdomain => {
						description => __"An identifier for the translation "
						                . "catalog (textdomain), defaults to "
						                . "'messages'.",
						type => 'string',
						default => 'messages'
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
						# Default value will be set after parsing, if still
						# empty. See https://github.com/epoberezkin/ajv/issues/681
					},
					xgettext => {
						description => __"The xgettext command (or an array of "
						               . "the program name plus arguments), "
						               . "defaults to 'xgettext'.",
						type => [qw(array string)],
						items => {
							type => 'string'
						},
						default => 'xgettext'
					},
					'xgettext-tt2' => {
						description => __"The xgettext-tt2 command (or an "
						               . "array of the program name plus "
						               . "arguments), defaults to "
						               . "'xgettext-tt2'.",
						type => [qw(array string)],
						items => {
							type => 'string'
						},
						default => 'xgettext-tt2'
					}
				}
			},
			processors => {
				description => __"The processors to use for generating "
				                 . "content.",
				additionalProperties => false,
				default => {},
				required => ['chains', 'options', 'triggers'],
				properties => {
					chains => {
						description => __"The processor chains.",
						default => {
							html => {
								modules => ['TT2', 'Strip', 'HTMLFilter']
							},
							markdown => {
								modules => ['TT2', 'Strip', 'Markdown'],
								suffix => 'html',
								wrapper => 'html'
							},
							xml => {
								modules => ['TT2', 'Strip']
							}
						},
						patternProperties => {
							'[_a-zA-z][a-zA-Z0-9]*' => {
								description => __"Properties of one processor "
								                 . "chain.",
								type => 'object',
								addititionalProperties => false,
								required => ['modules'],
								properties => {
									modules => {
										description => __"The module names.",
										type => 'array',
										items => {
											type => 'string'
										},
										#minLength => 1
										# The possible values are filled at
										# run-time.
									},
									suffix => {
										description => __"An optional suffix "
										                 . "if different from "
														 . "original filename.",
										type => 'string',
										#minLength => 1,
									},
									wrapper => {
										description => __"An optional wrapper "
										               . "for a second run.",
										type => 'string',
										#minLength => 1
										# The possible values are filled at
										# run-time.
									}
								}
							}
						}
					},
					options => {
						description => __"Additional options for the"
						               . " processor plug-ins",
						type => 'object',
						default => {
							HTMLFilter => [
								'AnchorTarget',
								'Generator',
								'CleanUp',
								{
									'TOC' => {
										'content-tag' => 'qgoda-content',
										'toc-tag' => 'qgoda-toc',
										start => 2,
										end => 6,
										template => 'components/toc.html'
									}
								}
							]
						},
					},
					triggers => {
						description => __"Filename extenders that trigger a "
						               . " particular chain if not specified"
						               . " in front matter or defaults.",
						default => {
							    htm => 'html',
								html => 'html',
								md => 'markdown',
								mdown => 'markdown',
								mdwn => 'markdown',
								mkd => 'markdown',
								mkdn => 'markdown',
								xml => 'xml'
						},
						patternProperties => {
							'.+' => {
								description => __"The filename extender.",
								type => 'string'
							}
						}
					}
				},
			},
			scm => {
				description => __"Source code management (SCM) that is in "
				               . "use. If present, only files that are under "
							   . "version control and those matching 'no-scm' "
							   . "are processed. Currently only git is "
							   . "supported.",
				type => 'string',
				const => 'git'
			},
			srcdir => {
				description => __"The source directory for all assets. Do "
				               . "not set that variable yourself! It will be "
							   . "overwritten at runtime with the absolute "
							   . "path to the current directory.",
				type => 'string',
				const => Cwd::abs_path()
			},
			taxonomies => {
				description => __"Key/value pairs of taxonomy names and their "
				               . "respective weights for the computation "
							   . "of relatedness.",
				type => 'object',
				default => {
					categories => 3,
					links => 1,
					tags => 2
				}
			},
			title => {
				description => __"The title of the site. It has no "
				               . "particular semantics.",
				default => __"A new Qgoda Powered Site",
			},
			view => {
				description => __"The default view template to use.",
				default => 'default.html',
				minLength => 1,
			}
		}
	}
};

1;