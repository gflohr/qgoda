//; use Qgoda::JavaScript::Filter('Qgoda::JavaScript::console');

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

/* Polyfill for a minimal console.  Less minimal than the original
 * Duktape console, and it allows tieing the standard streams.
 *
 * Apart from that, the code is a mess and should be replaced with something
 * reasonable.
 */

(function () {
	// Pre-fill escapes.
	const escapes = [];
	for (var i = 0; i < 32; ++i) {
		var hex = i.toString(16);
		if (i < 0x10)
			escapes[i] = '\\u000' + hex;
		else
			escapes[i] = '\\u00' + hex;
		escapes[0x8] = '\\b';
		escapes[0x9] = '\\t';
		escapes[0xa] = '\\n';
		escapes[0xc] = '\\f';
		escapes[0xd] = '\\r';
	}

	Object.defineProperty(this.console, 'log', {
		value: function () {
			__perl__.modules.console.log(format(arguments));
		}, writable: true, enumerable: false, configurable: true
	});
	Object.defineProperty(this.console, 'warn', {
		value: function () {
			__perl__.modules.console.warn(format(arguments));
		}, writable: true, enumerable: false, configurable: true
	});
	Object.defineProperty(this.console, 'error', {
		value: function () {
			__perl__.modules.console.error(format(arguments));
		}, writable: true, enumerable: false, configurable: true
	});

	function format(args) {
		const output = [];

		var i = 0;
		if (args.length > 1 && 'string' === typeof args[0]
			&& args[0].match(/%[sjdif%]/)) {
			// Format string.
			++i;
			var fmt = args[0];
			var interpolated = fmt.replace(/%(.)/g, function(match, p1) {
				if (i >= args.length) return '%' + p1;
				switch(p1) {
					case 'd':
						return Number(args[i++]);
					case 's':
						return String(args[i++]);
					case 'f':
						return parseFloat(args[i++]);
					case 'i':
						return ;
					case 'j':
						var retval;
						try {
							retval = JSON.stringify(args[i++]);
						} catch(e) {
							retval = args[--i];
						}
						return retval;
					case 'o':
					case 'O':
						// Marginal support for Node.JS's %o and %O.
						return inspect(args[i++]);
					case '%':
						return '%';
					default:
						return '%' + p1;
				}
			});

			output.push(interpolated);
		}

		for (; i < args.length; ++i) {
			output.push(inspect(args[i]));
		}

		return output.join(' ');
	}

	function stringify(obj) {
		return obj.replace(/[\u0000-\u001f\\']/g, function(match) {
			if (match === "'")
				return "\\'";
			else if (match === '\\')
				return '\\\\';
			else
				return escapes[match.charCodeAt(0)];
		});
	}

	function objectType(obj) {
		if (obj === null) {
			return 'null';
		} else if ('[object Array]' === toString.call(obj)) {
			return 'array';
		} else {
			return 'object';
		}
	}

	/*
	 * Similar to util.inspect from NodeJS but all options are ignored.
	 * Circular references should be handled correctly but the function
	 * recurses infinitely (FIXME! This should probably be changed) and
	 * it always prints all array elements.
	 */
	function inspect(root) {
		var seen = [];
		var depth = 0;

		const inspectRecursive = function(tokens, obj) {
			// FIXME! How does Node.JS actually count the depth?
			++depth;
			var type = typeof obj;
			if ('object' === type) type = objectType(obj);

			if ('array' === type) {
				if (seen.indexOf(obj) !== -1) {
					tokens.push('[Circular]');
					return;
				}
				seen.push(obj);

				tokens.push('[');
				for (var i = 0; i < obj.length; ++i) {
					if (i !== 0) tokens.push(', ');
					const item = obj[i];
					Array.prototype.push.apply(tokens,
                                               inspectRecursive(tokens, item));
				}
				tokens.push(']');
			} else if ('object' === type) {
				if (seen.indexOf(obj) !== -1) {
					tokens.push('[Circular]');
					return;
				}
				seen.push(obj);

				tokens.push('{');
				var count = 0;
				for (var prop in obj) {
					if (!obj.hasOwnProperty(prop)) continue;

					if (count++) tokens.push(', ');

					if (prop.match(/^[_a-zA-Z][_a-zA-Z0-9]*$/)) {
						tokens.push(prop + ': ');
					} else {
						tokens.push("'" + stringify(prop) + "': ");
					}

					Array.prototype.push.apply(tokens,
					                           inspectRecursive(tokens,
					                           obj[prop]))
				}
				tokens.push('}');
			} else if ('string' === type) {
				if (depth !== 1) {
					tokens.push("'" + stringify(obj) + "'");
				} else {
					tokens.push(obj);
				}
			} else if ('function' === type) {
				tokens.push('[Function]');
			} else if ('null' === type) {
				tokens.push('null');
			} else if ('undefined' === type) {
				tokens.push('undefined');
			} else if ('number' === type) {
				tokens.push(obj);
			} else {
				tokens.push(obj);
			}
		}

		const output = [];

		inspectRecursive(output, root);

		return output.join('');
	}
})();

