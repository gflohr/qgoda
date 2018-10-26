//; use Qgoda::JavaScript::Filter('Qgoda::JavaScript::config');

/*
 *  Copyright (C) 2016-2018 Guido Flohr <guido.flohr@cantanea.com>,
 *  all rights reserved.
 *
 *  This program is free software: you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 3 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

/*
 * Read the Qgoda configuration, validate it against the schema provided,
 * and return the configuration merged with the defaults.
 *
 * Variables to be injected:
 *
 *   schema:         The JSON schema (version 7).
 *   input:          The YAML input.
 *   filename:       The filename for the YAML input.
 *   local_input:    The local YAML input.
 *   local_filename: The filename for the local YAML input.
 *
 * Output variables:
 *
 *   config: The configuration with the default values from the schema
 *           merged in.
 */

const Ajv = require('ajv');
const yaml = require('js-yaml');

const ajv = new Ajv({useDefaults: true, coerceTypes: 'array'});
const validate = ajv.compile(schema);
var config = {};

// First load and validate the main configuration.
if (input !== '') {
	try {
		config = yaml.safeLoad(input);
		const valid = validate(config);
		if (!valid) throw validate.errors;
	} catch(e) {
		throw local_filename + ':' + e;
	}
} else {
	validate(config); 
}

// Merge local configuration inside but only after validating it.
if (local_input !== '') {
	try {
		const local_config = yaml.safeLoad(local_input);
		const valid = validate(local_config);
		if (!valid) throw validate.errors;

		// Valid. Now parse the YAML again - so that the default values are
		// removed - and merge it into the existing configuration.
		const _ = require('lodash');
		_.merge(config, yaml.safeLoad(local_input));
	} catch(e) {
		throw local_filename + ':' + e;
	}
}
