//; use Qgoda::JavaScript::Filter('Qgoda::JavaScript::config');

/*
 *  Copyright (C) 2016-2020 Guido Flohr <guido.flohr@cantanea.com>,
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

// FIXME! Once https://github.com/gonzus/JavaScript-Duktape-XS/issues/13
// has been fixed, rather throw errors in case of failure.
delete __perl__.output.errors;

const ajv = new Ajv({useDefaults: true, coerceTypes: 'array'});

var validate;
try {
    validate = ajv.compile(schema);
} catch(e) {
    console.log("Internal error compiling schema: " + e);
    throw("Internal error compiling schema: " + e);
}

var config = {}, yaml_filename = '';

try {
    // First load and validate the main configuration.
    if (input !== '') {
        yaml_filename = filename;
	    const test = yaml.safeLoad(input);
	    const valid = validate(test);
	    if (!valid) throw validate.errors;
	    // Valid. Now parse the YAML again - so that the default values are
	    // removed.
        config = yaml.safeLoad(input);
    }

    // Load and validate local configuration.
    if (local_input !== '') {
        yaml_filename = local_filename;
	    const test = yaml.safeLoad(local_input);
	    const valid = validate(test);
	    if (!valid) throw validate.errors;
	    // Valid. Now parse the YAML again - so that the default values are
	    // removed - and merge it into the existing configuration.
	    _.merge(config, yaml.safeLoad(local_input));
    }

    // Finally validate the resulting configuration and fill in defaults.
    const valid = validate(config);
    if (!valid) {
        if (input !== '') {
            yaml_filename = filename;
        } else if (local_input === '') {
            yaml_filename = "internal error: default configuration";
        }
        throw validate.errors;
    }
} catch(e) {
	if (!Array.isArray(e)) {
		e = e.toString();
	}
	__perl__.output.errors = [yaml_filename, e];
}

