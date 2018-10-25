//; use Qgoda::JavaScript::Filter('Qgoda::JavaScript::console');

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

/* Polyfill for a minimal console.  Less minimal than the original
 * Duktape console, and it allows tieing the standard streams.
 *
 * Besides, it also implements error() and warn() as this is required by
 * Ajv.
 */

(function () {
	Object.defineProperty(this.console, 'log', {
		value: function () {
			var strArgs = Array.prototype.map.call(arguments, function (v) {
				return String(v); 
			});
			__perl__.modules.console.log(Array.prototype.join.call(strArgs, ' '));
		}, writable: true, enumerable: false, configurable: true
	});
	Object.defineProperty(this.console, 'warn', {
		value: function () {
			var strArgs = Array.prototype.map.call(arguments, function (v) {
				return String(v); 
			});
			__perl__.modules.console.warn(Array.prototype.join.call(strArgs, ' '));
		}, writable: true, enumerable: false, configurable: true
	});
	Object.defineProperty(this.console, 'error', {
		value: function () {
			var strArgs = Array.prototype.map.call(arguments, function (v) {
				return String(v); 
			});
			__perl__.modules.console.error(Array.prototype.join.call(strArgs, ' '));
		}, writable: true, enumerable: false, configurable: true
	});
})();

