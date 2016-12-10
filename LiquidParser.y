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

%%
liquid: chunks
      ;

chunks: chunks CDATA
      | /* empty */
      ;
%%

sub _Error {
    if (exists $_[0]->YYData->{ERRMSG}) {
        warn delete $_[0]->YYData->{ERRMSG};
        return;
    }
    warn "Syntax error.\n";

    return;
}

sub _Lexer {
    my ($parser) = @_;

    $parser->YYData->{INPUT} = <STDIN> if empty $parser->YYData->{INPUT};
    return '', undef if empty $parser->YYData->{INPUT};

    return $parser->YYData->{INPUT}, 'CDATA';
}

sub parse {
    my ($self, $filename) = @_;

    my $logger = $self->logger;
    my $input = read_file $filename
        or $logger->fatal(__x("Cannot read '{filename}': {error}!\n"));

    my $lineno = 1;
    my $state = 0;
    my $lexer = sub {
        return '', undef if empty $input;

        if ($state = 0) {
            $input =~ s/([^\n\{]*)//;
            return CDATA => $1 if !empty $1;
        
            if ("\n" eq $1) {
                ++$lineno;
                return CDATA => "\n";
            } elsif ($input =~ s/^\{\{//) {
                return SE => '{{';
            } elsif ($input =~ s/^\{\%//) {
                return SE => '{%';
            } else {
                die;
            }
        }
    };
    my $error = sub {
        $logger->error(__"Syntax error!\n");
    };

    $self->YYParse(yylex => $lexer, yyerror => $error);
}

sub logger {
    Qgoda->new->logger('LiquidParser');
}
