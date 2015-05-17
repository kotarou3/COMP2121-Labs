%lex

%%
\/\/.*                              return "SL_COMMENT";
\/\*(?:.|\n)*?\*\/                  /* Skip multi-line comments */
\\\n                                /* Skip escaped newlines */
"#".*                               return "PREPROCESSOR";
\n                                  return "NEWLINE";
[ \t]+                              /* Skip spaces */
"+"                                 return "+";
"-"                                 return "-";
([*/^|&]|[<>|&]{2})                 return "BINARY_OPERATOR";
[!~]                                return "UNARY_OPERATOR";
"("                                 return "(";
")"                                 return ")";
","                                 return ",";
\.?[a-zA-Z1-9_][a-zA-Z0-9_]*":"     return "LABEL";
(?:"0x"[0-9a-fA-F]+|[0-9]+)\b       return "CONSTANT";
"'"[^']"'"                          return "CONSTANT";
"\""(?:\\.|[^\\"])*"\""             return "STRING_LITERAL";
(?:\.|"\\")?[a-zA-Z0-9_]+           return "IDENTIFIER";
\.                                  return "PROGRAM_COUNTER";
<<EOF>>                             return "EOF";

/lex

%{
    function formatLine(line, indentation) {
        var buffer = [];

        if (line.preprocessor)
            buffer = [line.preprocessor];
        else if (line.label)
            buffer = [line.label + ":"];
        else if (line.variable)
            buffer = [line.variable + ": .byte " + line.variableSize];

        if (line.instruction)
            buffer.push(line.instruction + (line.operands ? " " + line.operands.join(", ") : ""));
        else if (line.consts)
            buffer.push((line.constSize === 1 ? ".db" : ".dw") + " " + line.consts.join(", "));

        if (line.comment)
            buffer.push(line.comment);

        if ("indentation" in line)
            indentation = line.indentation;

        if (buffer.length === 0 && !("indentation" in line))
            return null;
        return indentation + buffer.join(" ");
    }

    function processLines(lines) {
        var localPrefix = require("path").basename(process.argv[2], ".S").replace(/[^a-zA-Z0-9_]+/g, "") + "_";

        // Do a bit of preprocessing
        var isKeepingLine = [{yes: true, ignoring: true}];
        for (var l = 0; l < lines.length; ++l) {
            if (lines[l] && lines[l].preprocessor) {
                // Remove lines that get removed when ALL_ASSEMBLY or __AVRASM_VERSION__ is defined
                var match = lines[l].preprocessor.match(/^#if(n?)(?:def)?\s+(.*)$/);
                if (match) {
                    if (match[2] === "ALL_ASSEMBLY" || match[2] === "__AVRASM_VERSION__") {
                        lines[l] = {isChanged: true};
                        isKeepingLine.unshift({yes: !match[1]});
                    } else {
                        isKeepingLine.unshift({yes: isKeepingLine[0].yes, ignoring: true});
                    }
                    continue;
                } else if (lines[l].preprocessor === "#else" && !isKeepingLine[0].ignoring) {
                    lines[l] = {isChanged: true};
                    isKeepingLine[0].yes = !isKeepingLine[0].yes;
                    continue;
                } else if (lines[l].preprocessor === "#endif") {
                    if (!isKeepingLine[0].ignoring)
                        lines[l] = {isChanged: true};
                    isKeepingLine.shift();
                    continue;
                }

                // Special case for including avr/io.h: Change to m2560def.inc
                if (lines[l].preprocessor.slice(-10) === "<avr/io.h>") {
                    lines[l].isChanged = true;
                    lines[l].preprocessor = lines[l].preprocessor.slice(0, -10) + "<m2560def.inc>";
                }

                // Special case for including util.h: Change to util.inc
                if (lines[l].preprocessor.slice(-7) === "util.h\"") {
                    lines[l].isChanged = true;
                    lines[l].preprocessor = lines[l].preprocessor.slice(0, -2) + "inc\"";
                }
            }

            if (!isKeepingLine[0].yes)
                lines[l] = {isChanged: true};
        }

        var globals = {};
        var locals = {};
        var variables = {};
        var consts = {};
        var linesChanged = {};
        var insertLinesAt = {};

        // Aggregate relevent identifiers and update locals and macros
        var currentMacro = null;
        for (var l = 0; l < lines.length; ++l) {
            var line = lines[l];
            if (!line)
                continue;

            if (line.instruction === ".macro") {
                currentMacro = {params: line.operands.slice(1), paramsRegex: new RegExp("\\\\(" + line.operands.slice(1).join("|") + ")\\b", "g")};

                line.operands = [line.operands[0]];
                if (currentMacro.params.length > 0)
                    line.operands[0] += " // " + currentMacro.params.join(", "); // hack

                linesChanged[l] = true;
                continue;
            }
            if (currentMacro) {
                if (line.instruction === ".endm") {
                    currentMacro = null;
                } else {
                    if (line.operands) {
                        for (var o = 0; o < line.operands.length; ++o) {
                            line.operands[o] = line.operands[o].replace(/\b([0-9])[bf]\b/g, function (match, n) {
                                linesChanged[l] = true;
                                return String.fromCharCode(parseInt(n, 10) + "a".charCodeAt(0) - 1);
                            });

                            if (currentMacro.params.length > 0) {
                                line.operands[o] = line.operands[o].replace(currentMacro.paramsRegex, function (match, param) {
                                    linesChanged[l] = true;
                                    return "@" + currentMacro.params.indexOf(param);
                                });
                            }
                        }
                    }
                    if (line.label && line.label.match(/^[0-9]$/)) {
                        linesChanged[l] = true;
                        line.label = String.fromCharCode(parseInt(line.label, 10) + "a".charCodeAt(0) - 1);
                    }
                }

                continue;
            }

            if (line.global)
                globals[line.global] = l;

            if (line.label && !globals[line.label]) {
                locals[line.label] = l;
                linesChanged[l] = true;

                if (line.consts) {
                    consts[line.label] = l;
                } else {
                    var c;
                    for (c = l + 1; c < lines.length && !lines[c]; ++c)
                        ;
                    if (lines[c] && lines[c].consts)
                        consts[line.label] = true;
                }

                line.label = localPrefix + line.label;
            }

            if (line.variable) {
                variables[line.variable] = l;
                line.variable = localPrefix + line.variable;
            }

            if (line.isChanged)
                linesChanged[l] = true;
        }

        // Put variables in .dseg
        var variableLines = Object.keys(variables).map(function (v) { return variables[v]; }).sort(function (a, b) { return a - b; });
        for (var v = 0; v < variableLines.length; ++v) {
            var l = variableLines[v];

            var startL = l - 1;
            for (; startL >= 0 && lines[startL] && lines[startL].comment; --startL)
                ;
            ++startL;

            var endL = l + 1;
            for (; endL < lines.length && (!lines[endL] || lines[endL].comment || lines[endL].variable); ++endL)
                if (!lines[endL]) {
                    var nextEndL = endL + 1;
                    for (; nextEndL < lines.length && (!lines[nextEndL] || lines[nextEndL].comment); ++nextEndL)
                        ;
                    if (nextEndL >= lines.length || !lines[nextEndL].variable)
                        break;

                    endL = nextEndL;
                }

            insertLinesAt[startL] = [
                {indentation: ""},
                {indentation: "", instruction: ".dseg"},
                {indentation: ""}
            ];
            insertLinesAt[endL] = [
                {indentation: ""},
                {indentation: "", instruction: ".cseg"},
                {indentation: ""}
            ];

            for (; v < variableLines.length && variableLines[v] < endL; ++v)
                ;
            if (v < variableLines.length)
                --v;
        }

        // Update expressions
        var localsRegex = new RegExp("\\b(" + Object.keys(locals).concat(Object.keys(variables)).concat(Object.keys(consts)).join("|") + ")\\b", "g");
        var constsRegex = new RegExp("\\b(" + Object.keys(consts).join("|") + ")\\b", "g");
        for (var l = 0; l < lines.length; ++l) {
            var line = lines[l];
            if (!line || (!line.operands && !line.consts))
                continue;

            var expressions = line.operands || line.consts;
            for (var e = 0; e < expressions.length; ++e) {
                // consts first because they don't modify the identifier
                if (Object.keys(consts).length > 0) {
                    expressions[e] = expressions[e].replace(constsRegex, function (match, identifier, offset, string) {
                        linesChanged[l] = true;
                        // Check if it is the entire expression or already surrounded by brackets
                        if (identifier === string || (string[offset - 1] === "(" && string[offset + identifier.length] === ")"))
                            return identifier + " << 1";
                        else
                            return "(" + identifier + " << 1)";
                    });
                }

                if (Object.keys(locals).length + Object.keys(variables).length + Object.keys(consts).length > 0) {
                    expressions[e] = expressions[e].replace(localsRegex, function (match, identifier) {
                        linesChanged[l] = true;
                        return localPrefix + identifier;
                    });
                }
            }
        }

        var fs = require("fs");
        var input = fs.readFileSync(process.argv[2]).toString().split("\n");
        var output = [];
        for (var l = 0; l < input.length; ++l) {
            var indentation = input[l].match(/^([ \t]*)/)[1];

            if (insertLinesAt[l])
                for (var i = 0; i < insertLinesAt[l].length; ++i)
                    output.push(formatLine(insertLinesAt[l][i], indentation));

            if (!linesChanged[l]) {
                output.push(input[l]);
                continue;
            }

            var buffer = formatLine(lines[l], indentation);
            if (buffer !== null)
                output.push(buffer);
        }

        console.log(output.join("\n").replace(/\n{2,}/g, "\n\n").trim());
    }
%}

%left "+", "-" BINARY_OPERATOR
%left ","
%left UNARY_PLUS UNARY_MINUS UNARY_OPERATOR

%start input

%%

input
    : file
        {processLines($1);}
    ;

file
    : lines
        {$$ = []; if ($1) $$[$1.lineno] = $1;}
    | file lines
        {$$ = $1; if ($2) $$[$2.lineno] = $2;}
    ;

lines
    : line newline
        {$$ = $1; $$.lineno = yylineno - 1;}
    | line SL_COMMENT newline
        {$$ = $1; $$.comment = $2; $$.lineno = yylineno - 1;}
    | SL_COMMENT newline
        {$$ = {comment: $1, lineno: yylineno - 1};}
    | newline
        {$$ = null;}
    ;

line
    : PREPROCESSOR
        {$$ = {preprocessor: $1};}
    | instruction
        {$$ = $1;}
    | LABEL
        {$$ = {label: $1.slice(0, -1)};}
    | LABEL line
        {$$ = $2; $$.label = $1.slice(0, -1);}
    ;

instruction
    : IDENTIFIER
        {$$ = {instruction: $1};}
    | IDENTIFIER expressionList
        {
            if ($1 === ".global") {
                $$ = {isChanged: true, global: $2.expressions[0]};
            } else if ($1 === ".lcomm") {
                $$ = {isChanged: true, variable: $2.expressions[0], variableSize: $2.expressions[1]};
            } else if ($1 === ".set" || $1 === ".equ") {
                // hack
                $$ = {isChanged: true, instruction: $1 + " " + $2.expressions[0] + " =", operands: $2.expressions.slice(1)};
            } else if ($1 === ".byte" || $1 === ".word") {
                $$ = {isChanged: true, consts: $2.expressions, constSize: $1 === ".byte" ? 1 : 2};
            } else if ($1 === ".ascii") {
                $$ = {isChanged: true, consts: $2.expressions, constSize: 1};
            } else if ($1 === ".asciz") {
                $$ = {isChanged: true, consts: $2.expressions.concat("0"), constSize: 1};
            } else if ($1 === ".section" || $1 === ".balign") {
                // .section: We only ever use it to change between different code sections
                // .balign: AVR Assembler automatically re-aligns to a word boundary
                $$ = {isChanged: true};
            } else {
                lowByteReg2Word = function (reg) {
                    var match = reg.match(/^r([0-9]{1,2})$/);
                    if (match)
                        return "r" + (parseInt(match[1], 10) + 1) + ":r" + match[1];

                    match = reg.match(/^([XYZ])[HL]$/);
                    if (match)
                        return match[1] + "H:" + match[1] + "L";

                    return reg;
                }

                var isChanged = $2.isChanged;
                if ($1 in {adiw: 1, sbiw: 1, movw: 1}) {
                    isChanged = true;
                    $2.expressions[0] = lowByteReg2Word($2.expressions[0]);
                }
                if ($1 === "movw")
                    $2.expressions[1] = lowByteReg2Word($2.expressions[1]);

                $$ = {instruction: $1, operands: $2.expressions};
                if (isChanged)
                    $$.isChanged = true;
            }
        }
    ;

expressionList
    : expression
        {$$ = {isChanged: $1.isChanged, expressions: [$1.expression]};}
    | expression "+" /* for post-increment (st/ld/lpm) */
        {$$ = {isChanged: $1.isChanged, expressions: [$1.expression + $2]};}
    | PROGRAM_COUNTER /* Arithmetic on the program counter is not implemented */
        {$$ = {isChanged: true, expressions: ["PC + 1"]};}
    | expressionList "," expressionList
        {$$ = {isChanged: $1.isChanged || $3.isChanged, expressions: $1.expressions.concat($3.expressions)};}
    ;

expression
    : expression BINARY_OPERATOR expression
        {$$ = {isChanged: $1.isChanged || $3.isChanged, expression: [$1.expression, $2, $3.expression].join(" ")};}
    | expression "+" expression
        {$$ = {isChanged: $1.isChanged || $3.isChanged, expression: [$1.expression, $2, $3.expression].join(" ")};}
    | expression "-" expression
        {$$ = {isChanged: $1.isChanged || $3.isChanged, expression: [$1.expression, $2, $3.expression].join(" ")};}
    | UNARY_OPERATOR expression
        {$$ = $2; $$.expression = $1 + $$.expression;}
    | "+" expression %prec UNARY_PLUS
        {$$ = $2; $$.expression = $1 + $$.expression;}
    | "-" expression %prec UNARY_MINUS
        {$$ = $2; $$.expression = $1 + $$.expression;}
    | "(" expression ")"
        {$$ = {isChanged: $2.isChanged, expression: $1 + $2.expression + $3};}
    | CONSTANT
        {$$ = {expression: $1};}
    | STRING_LITERAL
        {$$ = {expression: $1};}
    | IDENTIFIER
        {$$ = {expression: $1};}
    | IDENTIFIER "(" ")"
        {$$ = {expression: $1 + $2 + $3};}
    | IDENTIFIER "(" expressionList ")"
        {
            if (($1 === "gs" || $1 === "_SFR_IO_ADDR" || $1 === "_SFR_MEM_ADDR") && $3.expressions.length == 1) {
                $$ = {isChanged: true, expression: $3.expressions[0]};
            } else {
                var isChanged = $3.isChanged;
                if ($1 === "lo8") {
                    isChanged = true;
                    $1 = "low";
                } else if ($1 === "hi8") {
                    isChanged = true;
                    $1 = "high";
                } else if ($1 === "hlo8") {
                    isChanged = true;
                    $1 = "byte3";
                } else if ($1 === "hhi8") {
                    isChanged = true;
                    $1 = "byte4";
                }

                $$ = {isChanged: isChanged, expression: $1 + $2 + $3.expressions.join(", ") + $4};
            }
        }
    ;

newline: NEWLINE | EOF;
