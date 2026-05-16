%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

extern int yylex();
extern int yylineno;
extern int num_colonne;
extern char *yytext;

/* Compteur global d'erreurs — partagé avec le lexer */
int error_count = 0;

/* ── Prototypes ── */
void yyerror(const char *s);
static void report_error(const char *type, const char *detail);
%}

/* ── Union des valeurs sémantiques ── */
%union {
    int  num;
    char *id;
}

/* ── Déclaration des tokens ── */
%token BEGIN_TK END_TK INT_TK
%token WRITE READ
%token WHILE DO OD
%token FOR TO
%token IF THEN ELSE FI
%token ASSIGN
%token EQQ GEQ LEQ NEQ EQ GT LT
%token AND OR NOT

%token <num> NUM
%token <id>  ID

/* ── Priorités et associativités ──
   Règle du dangling-else : THEN < ELSE                               */
%right     NOT
%left      OR
%left      AND
%nonassoc  THEN
%nonassoc  ELSE

/* ── Priorités des opérateurs arithmétiques ── */
%left  '+' '-'
%left  '*' '/' '%'
%right '^'          /* exponentiation, associative à droite */

%%

/* ════════════════════════════════════════════════════════════════
   Programme principal
   ════════════════════════════════════════════════════════════════ */
programme:
      BEGIN_TK listinstr END_TK
        {
            if (error_count == 0)
                printf("\n[OK] Analyse syntaxique terminee sans erreur.\n");
            else
                printf("\n[ECHEC] Analyse terminee avec %d erreur(s).\n", error_count);
        }
    /* Récupération : structure begin...end cassée */
    | error END_TK
        {
            report_error("Programme",
                "Structure 'begin ... end' incorrecte ou mots-cles manquants");
            yyerrok;
        }
    | BEGIN_TK error
        {
            report_error("Programme",
                "'end' manquant — fin de programme non fermee");
            yyerrok;
        }
    ;

/* ════════════════════════════════════════════════════════════════
   Liste d'instructions
   ════════════════════════════════════════════════════════════════ */
listinstr:
      instr
    | instr listinstr
    /* CORRECTION : yyclearin ajouté pour vider le lookahead et éviter
       une boucle infinie lors de la récupération sur ';'             */
    | error ';'
        {
            fprintf(stderr,
                "[Erreur - Instruction] Ligne %d : "
                "instruction invalide ou inconnue, reprise apres ';'\n",
                yylineno);
            error_count++;
            yyerrok;
            yyclearin;
        }
    ;

/* ════════════════════════════════════════════════════════════════
   Instructions
   ════════════════════════════════════════════════════════════════ */
instr:
    /* ── Déclaration de variable ── */
      INT_TK ID ';'
    | INT_TK error ';'
        {
            report_error("Declaration",
                "identifiant attendu apres 'int' (ex: int x;)");
            yyerrok; yyclearin;
        }

    /* ── Affectation ── */
    | ID ASSIGN expression ';'
    | ID ASSIGN error ';'
        {
            report_error("Affectation",
                "expression invalide a droite de ':=' — verifiez la syntaxe");
            yyerrok; yyclearin;
        }
    | ID error ';'
        {
            report_error("Affectation",
                "':=' attendu apres l'identifiant pour une affectation");
            yyerrok; yyclearin;
        }

    /* ── Instruction write ── */
    | WRITE expression ';'
    | WRITE error ';'
        {
            report_error("Write",
                "expression invalide apres 'write' (ex: write x+1;)");
            yyerrok; yyclearin;
        }

    /* ── Instruction read ── */
    | READ '(' ID ')' ';'
    | READ '(' error ')' ';'
        {
            report_error("Read",
                "identifiant attendu dans 'read(id)' — une variable simple est requise");
            yyerrok; yyclearin;
        }
    | READ error ';'
        {
            report_error("Read",
                "syntaxe 'read(id);' incorrecte — parentheses manquantes ou mal formees");
            yyerrok; yyclearin;
        }

    /* ── Boucle while ── */
    | WHILE '(' condition ')' DO listinstr OD ';'
    | WHILE '(' error ')' DO listinstr OD ';'
        {
            report_error("While",
                "condition invalide dans 'while(cond)' — "
                "operateur de comparaison attendu (>, <, ==, !=, ...)");
            yyerrok; yyclearin;
        }
    | WHILE error DO listinstr OD ';'
        {
            report_error("While",
                "parentheses manquantes autour de la condition 'while' "
                "(syntaxe: while (cond) do ... od;)");
            yyerrok; yyclearin;
        }
    | WHILE '(' condition ')' DO listinstr error ';'
        {
            report_error("While",
                "'od' manquant pour fermer la boucle 'while'");
            yyerrok; yyclearin;
        }

    /* ── Boucle for ──
       Syntaxe : for id := expr to expr do listinstr od ;             */
    | FOR ID ASSIGN expression TO expression DO listinstr OD ';'
    | FOR ID ASSIGN error TO expression DO listinstr OD ';'
        {
            report_error("For",
                "expression de debut invalide dans 'for id := EXPR to ...'");
            yyerrok; yyclearin;
        }
    | FOR ID ASSIGN expression TO error DO listinstr OD ';'
        {
            report_error("For",
                "expression de fin invalide dans 'for ... to EXPR do'");
            yyerrok; yyclearin;
        }
    | FOR ID error DO listinstr OD ';'
        {
            report_error("For",
                "en-tete 'for' mal forme — syntaxe attendue: "
                "for id := expr to expr do ... od;");
            yyerrok; yyclearin;
        }
    | FOR error DO listinstr OD ';'
        {
            report_error("For",
                "identifiant manquant ou en-tete 'for' invalide");
            yyerrok; yyclearin;
        }
    | FOR ID ASSIGN expression TO expression DO listinstr error ';'
        {
            report_error("For",
                "'od' manquant pour fermer la boucle 'for'");
            yyerrok; yyclearin;
        }

    /* ── Instruction if (sans else) ── */
    | IF condition THEN listinstr FI ';'
    /* ── Instruction if-else (ELSE a priorité plus haute que THEN) ── */
    | IF condition THEN listinstr ELSE listinstr FI ';'
    | IF error THEN listinstr FI ';'
        {
            report_error("If",
                "condition invalide dans 'if' — "
                "operateur de comparaison attendu (>, <, ==, !=, >=, <=, ===)");
            yyerrok; yyclearin;
        }
    | IF error THEN listinstr ELSE listinstr FI ';'
        {
            report_error("If",
                "condition invalide dans 'if-else'");
            yyerrok; yyclearin;
        }
    | IF condition THEN listinstr error ';'
        {
            report_error("If",
                "'fi' manquant pour fermer le bloc 'if'");
            yyerrok; yyclearin;
        }
    ;

/* ════════════════════════════════════════════════════════════════
   Expressions arithmétiques — priorités gérées par la hiérarchie
   ════════════════════════════════════════════════════════════════ */
expression:
      expression '+' term
    | expression '-' term
    | term
    ;

term:
      term '*' factor
    | term '/' factor
    | term '%' factor
    | factor
    ;

factor:
      base '^' factor      /* associativité droite pour ^ */
    | base
    ;

base:
      '(' expression ')'
    | '(' error ')'
        {
            report_error("Expression",
                "expression invalide entre parentheses");
            yyerrok; yyclearin;
        }
    | NUM
    | ID
    ;

/* ════════════════════════════════════════════════════════════════
   Conditions — opérateurs de comparaison + logiques (&&, ||, !)
   CORRECTION : ajout des opérateurs logiques pour instructions imbriquées
   ════════════════════════════════════════════════════════════════ */
condition:
    /* Comparaisons simples */
      expression GT  expression
    | expression LT  expression
    | expression GEQ expression
    | expression LEQ expression
    | expression NEQ expression
    | expression EQ  expression
    | expression EQQ expression    /* === */

    /* Conditions composées */
    | condition AND condition      /* cond && cond */
    | condition OR  condition      /* cond || cond */
    | NOT condition                /* ! cond       */
    | '(' condition ')'            /* parenthésage de conditions */
    ;

%%

/* ════════════════════════════════════════════════════════════════
   Fonctions auxiliaires
   ════════════════════════════════════════════════════════════════ */

/*
 * CORRECTION : yyerror N'incrémente PAS error_count ici.
 * Les règles de récupération appellent report_error qui, elle, incrémente.
 * yyerror sert uniquement à afficher le message brut de Bison pour les
 * erreurs non rattrapées par une règle explicite.
 */
void yyerror(const char *s) {
    fprintf(stderr,
        "[Erreur Syntaxique] Ligne %d, Col ~%d, token '%s' : %s\n",
        yylineno, num_colonne, yytext, s);
    /* error_count est incrémenté par la règle d'erreur appelante */
}

static void report_error(const char *type, const char *detail) {
    fprintf(stderr,
        "[Erreur - %-14s] Ligne %d : %s\n",
        type, yylineno, detail);
    error_count++;
}

int main(void) {
    printf("=== Debut de l'analyse ===\n\n");
    yyparse();
    printf("\n=== Fin de l'analyse : %d erreur(s) detectee(s) ===\n",
           error_count);
    return (error_count > 0) ? 1 : 0;
}
