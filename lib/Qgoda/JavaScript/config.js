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
const _ = require('lodash');

const ajv = new Ajv({useDefaults: true, coerceTypes: 'array'});
const validate = ajv.compile(schema);
var config = {};

// FIXME! Once https://github.com/gonzus/JavaScript-Duktape-XS/issues/13
// has been fixed, rather throw errors in case of failure.
delete __perl__.output.errors;

// Get the default configuration.
if (!validate(config)) {
	__perl__.output.errors = [
		filename + ' [schema is buggy]',
		validate.errors
	];
}

// First load and validate the main configuration.
if (__perl__.output.errors === undefined && input !== '') {
	try {
		const test = yaml.safeLoad(input);
		const valid = validate(test);
		if (!valid) throw validate.errors;
		// Valid. Now parse the YAML again - so that the default values are
		// removed - and merge it into the existing configuration.
		_.merge(config, yaml.safeLoad(input));
	} catch(e) {
		__perl__.output.errors = [
			filename, e
		];
	}
}

// Merge local configuration inside but only after validating it.
if (__perl__.output.errors === undefined && local_input !== '') {
	try {
		const test = yaml.safeLoad(local_input);
		const valid = validate(test);
		if (!valid) throw validate.errors;
		// Valid. Now parse the YAML again - so that the default values are
		// removed - and merge it into the existing configuration.
		_.merge(config, yaml.safeLoad(local_input));
	} catch(e) {
		__perl__.output.errors = [local_filename, e];
	}
}
