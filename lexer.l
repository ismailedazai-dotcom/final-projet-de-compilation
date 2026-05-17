%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "parser.tab.h"

extern int error_count;


int num_colonne = 1;
%}

%option yylineno
%option noyywrap

DIGIT   [0-9]
ALPHA   [a-zA-Z_]
ALNUM   [a-zA-Z0-9_]

%%

[ \t]+          { num_colonne += yyleng; }
\n              { num_colonne = 1; }
"//".*          { /* commentaire ligne — ignore */ }

"begin"         { num_colonne += yyleng; return BEGIN_TK; }
"end"           { num_colonne += yyleng; return END_TK;   }
"int"           { num_colonne += yyleng; return INT_TK;   }
"write"         { num_colonne += yyleng; return WRITE;    }
"read"          { num_colonne += yyleng; return READ;     }
"while"         { num_colonne += yyleng; return WHILE;    }
"do"            { num_colonne += yyleng; return DO;       }
"od"            { num_colonne += yyleng; return OD;       }
"for"           { num_colonne += yyleng; return FOR;      }
"to"            { num_colonne += yyleng; return TO;       }
"if"            { num_colonne += yyleng; return IF;       }
"then"          { num_colonne += yyleng; return THEN;     }
"else"          { num_colonne += yyleng; return ELSE;     }
"fi"            { num_colonne += yyleng; return FI;       }


":="            { num_colonne += 2; return ASSIGN; }
"==="           { num_colonne += 3; return EQQ;    }  
">="            { num_colonne += 2; return GEQ;    }
"<="            { num_colonne += 2; return LEQ;    }
"!="            { num_colonne += 2; return NEQ;    }
"=="            { num_colonne += 2; return EQ;     }
">"             { num_colonne += 1; return GT;     }
"<"             { num_colonne += 1; return LT;     }

"&&"            { num_colonne += 2; return AND;    }
"||"            { num_colonne += 2; return OR;     }
"!"             { num_colonne += 1; return NOT;    }


{DIGIT}+        {
                    yylval.num = atoi(yytext);
                    num_colonne += yyleng;
                    return NUM;
                }

{ALPHA}{ALNUM}* {
                    yylval.id = strdup(yytext);
                    num_colonne += yyleng;
                    return ID;
                }

[+\-*/%^();]    { num_colonne++; return yytext[0]; }


.               {
                    fprintf(stderr,
                        "[Erreur Lexicale] Ligne %d, Col %d : "
                        "caractere inconnu '%s' (code ASCII %d)\n",
                        yylineno, num_colonne, yytext, (unsigned char)yytext[0]);
                    error_count++;
                    num_colonne++;
                }

%%
