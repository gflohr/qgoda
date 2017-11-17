/*
 * Copyright (C) 2016 Guido Flohr <guido.flohr@cantanea.com>,
 * all rights reserved.

 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 3 of the License, or
 * (at your option) any later version.

 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.

 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

%{

use Locale::TextDomain qw(com.cantanea.qgoda);

use Qgoda;
use Qgoda::Util qw(read_file empty);

%}

%token CDATA
%token SO
%token ST

%%
liquid: chunks
      ;

chunks: chunks CDATA { $_[0]->addOutput($_[2]) }
      | chunks tag
      | /* empty */
      ;

tag: ST DIRECTIVE
   ;
%%
