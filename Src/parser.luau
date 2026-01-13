-- // TuffSeal parser

type Token = {
    type: string;
    lexeme: string;
    literal: any?;
    line: number;
}

type ASTNode = {
    kind: string;
    value: any?;
    left: ASTNode?;
    operator: string?;
    right: ASTNode?;
    name: string?;
    callee: string?;
    arguments: { ASTNode }?;
    parameters: { string }?;
    body: { ASTNode }?;
    declareKind: string?;
    condition: boolean?;
    thenBranch: { any }?;
    elseIfBranches: { { condition: ASTNode?, block: { ASTNode } } }?;
    elseBranch: {any}?;
    elements: { ASTNode }?;
    entries: { key: string, value: any }?;
    callSelf: boolean?;
}

local Parser = {};
Parser.__index = Parser;

function Parser.new(tokens: { Token })
    assert(tokens ~= nil, "Parser received nil tokens!");
    local self = setmetatable({}, Parser);
    self.tokens = tokens;
    self.current = 1;
    return self;
end;

function Parser:peek(): Token
    return self.tokens[self.current] or {
        type = "EOF";
        lexeme = "";
        literal = nil;
        line = self.tokens[#self.tokens] and self.tokens[#self.tokens].line or 1;
    };
end;

function Parser:advance(): Token
    local token: Token = self:peek();
    self.current += 1;
    return token;
end;

function Parser:isAtEnd(): boolean
    return self:peek().type == "EOF";
end;

function Parser:parsePrimary(): ASTNode
    local expr: ASTNode;
    local token: Token = self:advance();

    if (token.type == "NUMBER") then
        expr = { kind = "Literal"; value = token.literal; };
    elseif (token.type == "STRING") then
        expr = { kind = "Literal"; value = token.literal; };
    elseif (token.type == "TRUE") then
        expr = { kind = "Literal"; value = true; };
    elseif (token.type == "FALSE") then
        expr = { kind = "Literal"; value = false; };
    elseif (token.type == "NULL") then
        expr = { kind = "Literal"; value = nil; };
    elseif (token.type == "(") then
        expr = self:parseExpression();
        local closing: Token = self:advance();
        if (closing.type ~= ")") then
            error(`TuffSeal parser error: Expected ')' after expression!`, 2);
        end;
    elseif (token.type == "[") then
        local elements = {};
        if (self:peek().type ~= "]") then
            while true do
                table.insert(elements, self:parseExpression());
                if (self:peek().type == ",") then
                    self:advance();
                else
                    break;
                end;
            end;
        end;
        local closing = self:advance();
        assert(closing.type == "]", "TuffSeal parser error: Expected ']' after array literal!");
        expr = { kind = "Array"; elements = elements; };
    elseif (token.type == "{") then
        local entries = {};
        while self:peek().type ~= "}" and not self:isAtEnd() do
            local key = self:advance();
            assert(key.type == "IDENTIFIER" or key.type == "STRING", "TuffSeal parser error: Invalid dictionary key!");
            local colon = self:advance();
            assert(colon.type == ":", "TuffSeal parser error: Expected ':' in dictionary!");
            local value = self:parseExpression();
            table.insert(entries, { key = key.literal or key.lexeme; value = value; });
            if self:peek().type == "," then
                self:advance();
            else
                break;
            end;
        end;
        local close = self:advance();
        assert(close.type == "}", "TuffSeal parser error: Expected '}' after dictionary!");
        expr = { kind = "Dictionary"; entries = entries; };
    elseif (token.type == "IDENTIFIER") then
        expr = { kind = "Variable"; name = token.lexeme; };
    elseif (token.type == "INS") then
        expr = self:parseInsStatement();
    else
        error(`TuffSeal parser error: Unexpected token: {token.type} at line {tostring(token.line)}`, 2);
    end;

    while true do
        if self:peek().type == "(" then
            self:advance();
            local args = {};
            while self:peek().type ~= ")" and not self:isAtEnd() do
                table.insert(args, self:parseExpression());
                if self:peek().type == "," then
                    self:advance();
                else
                    break;
                end;
            end;
            local closing = self:advance();

            if closing.type ~= ")" then
                error(`TuffSeal parser error: Expected ')' after function args!`, 2);
            end;

            local callSelf = false;
            if self:peek().type == "!" then
                self:advance();
                callSelf = true;
            end;

            expr = { kind = "Call"; callee = expr; arguments = args; callSelf = callSelf; };
        elseif self:peek().type == "[" then
            self:advance();
            local index = self:parseExpression();
            local close = self:advance();
            assert(close.type == "]", "TuffSeal parser error: Expected ']' after index!");
            expr = { kind = "Index"; object = expr; index = index; };
        elseif self:peek().type == "." then
            self:advance();
            local name = self:advance();
            assert(name.type == "IDENTIFIER", "TuffSeal parser error: Expected property name!");
            expr = { kind = "Property"; object = expr; name = name.lexeme; };
        else
            break;
        end;
    end;

    return expr;
end

function Parser:parseFactor(): ASTNode
    local expr: ASTNode = self:parseUnary();

    while (not self:isAtEnd()) do
        local op: Token = self:peek();
        if (op.type == "*" or op.type == "/") then
            self:advance();
            local right: ASTNode = self:parseUnary();
            expr = { kind = "Binary"; left = expr; operator = op.type; right = right; };
        else
            break;
        end;
    end;

    return expr;
end;

function Parser:parseTerm(): ASTNode
    local expr: ASTNode = self:parseFactor();

    while (not self:isAtEnd()) do
        local op: Token = self:peek();
        if (op.type == "+" or op.type == "-") then
            self:advance();
            local right: ASTNode = self:parseFactor();
            expr = { kind = "Binary"; left = expr; operator = op.type; right = right; };
        else
            break;
        end;
    end;

    return expr;
end;

function Parser:parseComparison(): ASTNode
    local expr = self:parseTerm();

    while (not self:isAtEnd()) do
        local op = self:peek();
        if (
            op.type == "<" or
            op.type == ">" or
            op.type == "<=" or
            op.type == ">="
        ) then
            self:advance();
            local right = self:parseTerm();
            expr = {
                kind = "Binary",
                left = expr,
                operator = op.type,
                right = right
            };
        else
            break;
        end;
    end;

    return expr;
end;

function Parser:parseEquality(): ASTNode
    local expr = self:parseComparison();

    while (not self:isAtEnd()) do
        local op = self:peek();
        if (op.type == "==" or op.type == "!=") then
            self:advance();
            local right = self:parseComparison();
            expr = {
                kind = "Binary",
                left = expr,
                operator = op.type,
                right = right
            };
        else
            break;
        end;
    end;

    return expr;
end;

function Parser:parseAnd(): ASTNode
    local expr = self:parseEquality();

    while (self:peek().type == "&&") do
        local op = self:advance();
        local right = self:parseEquality();
        expr = {
            kind = "Logical",
            left = expr,
            operator = op.type,
            right = right
        };
    end;

    return expr;
end;

function Parser:parseOr(): ASTNode
    local expr = self:parseAnd();

    while (self:peek().type == "||") do
        local op = self:advance();
        local right = self:parseAnd();
        expr = {
            kind = "Logical",
            left = expr,
            operator = op.type,
            right = right
        };
    end;

    return expr;
end;

function Parser:parseDeclaration(): ASTNode
    --[[
    let var_name = value;
    const VAR_NAME = value;
    ]]
    
    local kind: string = self.tokens[self.current - 1].type:lower();
    local nameToken: Token = self:advance();

    if (nameToken.type ~= "IDENTIFIER") then
        error(`TuffSeal parser error: Expected identifier after {kind}`, 2);
    end;

    local eqToken: Token = self:advance();
    if (eqToken.type ~= "=") then
        error(`TuffSeal parser error: Expected '=' after variable name!`, 2);
    end;

    local value: ASTNode = self:parseExpression();

    if (self:peek().type == ";") then
        self:advance();
    end

    return {
        kind = "Assignment",
        name = nameToken.lexeme,
        value = value,
        declareKind = kind
    }
end

function Parser:parseAssignment(): ASTNode
    local expr = self:parseOr();

    if (self:peek().type == "=") then
        local eq = self:advance();

        if (expr.kind ~= "Variable" and expr.kind ~= "Property" and expr.kind ~= "Index") then
            error(`TuffSeal parser error: Invalid assignment target!`, 2);
        end

        local value = self:parseAssignment();

        return {
            kind = "Assign",
            name = expr.name,
            value = value
        }
    end

    return expr;
end

function Parser:parseFunctionDeclaration(kind: string): ASTNode
    --[[
    const fn A(b, c) {
        // do whatever
    }

    let fn a(b, c) {
        // do whatever
    }
    ]]
    self:advance();

    local NameToken: Token = self:advance();

    if (NameToken.type ~= "IDENTIFIER") then
        error(`TuffSeal parser error: Expected function name after 'fn'!`, 2);
    end

    local opening: Token = self:advance();
    if (opening.type ~= "(") then
        error(`TuffSeal parser error: Expected '(' after function name!`, 2);
    end

    local params: { string } = {};

    while (self:peek().type ~= ")") do
        local param: Token = self:advance();

        if (param.type ~= "IDENTIFIER") then
            error(`TuffSeal parser error: Expected parameter name!`, 2);
        end
        table.insert(params, param.lexeme);

        if (self:peek().type == ",") then
            self:advance();
        else
            break;
        end
    end

    local closing: Token = self:advance();

    if (closing.type ~= ")") then
        error(`TuffSeal parser error: Expected ')' after parameters!`, 2);
    end

    local brace_open: Token = self:advance();
    if (brace_open.type ~= "{") then
        error("TuffSeal parser error: Expected '{' before function body!", 2);
    end;

    local body: { ASTNode } = {};
    while (self:peek().type ~= "}" and not self:isAtEnd()) do
        table.insert(body, self:parseStatement());
    end

    local brace_close: Token = self:advance();
    if (brace_close.type ~= "}") then
        error("TuffSeal parser error: Expected '}' after function body!", 2);
    end

    return {
        kind = "Function",
        name = NameToken.lexeme,
        parameters = params,
        body = body,
        declareKind = kind
    }
end

function Parser:parseStatement(): ASTNode
    while self:peek().type == ";" do
        self:advance();
    end

    if self:isAtEnd() or self:peek().type == "}" then
        return nil;
    end

    local token = self:peek();
    local statement;

    if token.type == "LET" or token.type == "CONST" then
        self:advance()
        if self:peek().type == "FN" then
            return self:parseFunctionDeclaration(token.type:lower());
        else
            statement = self:parseDeclaration();
        end
    elseif token.type == "FN" then
        statement = self:parseFunctionDeclaration("let");
    elseif token.type == "IF" then
        statement = self:parseIfStatement();
    elseif token.type == "WHILE" then
        statement = self:parseWhileStatement();
    elseif token.type == "FOR" then
        statement = self:parseForStatement();
    elseif token.type == "INS" then
        self:advance();
        statement = self:parseInsStatement();
    elseif token.type == "BREAK" then
        self:advance();
        statement = { kind = "Break" };
    else
        statement = self:parseExpression();
    end

    if self:peek().type == ";" then
        self:advance();
    end

    return statement
end

function Parser:parseIfStatement(): ASTNode
    self:advance();

    local OpenParen = self:advance();
    if (OpenParen.type ~= "(") then
        error(`TuffSeal parser error: Expected '(' after if!`, 2);
    end

    local condition = self:parseExpression();

    local CloseParen = self:advance();

    if (CloseParen.type ~= ")") then
        error(`TuffSeal parser error: Expected ')' after if condition!`, 2);
    end

    local BraceOpen = self:advance();
    if (BraceOpen.type ~= "{") then
        error("TuffSeal parser error: Expected '{' after if condition!", 2);
    end

    local ThenBranch = {};

    while (self:peek().type ~= "}" and not self:isAtEnd()) do
        local statement = self:parseStatement();
        if (statement) then
            table.insert(ThenBranch, statement);
        end
    end

    local BraceClose = self:advance();
    if (BraceClose.type ~= "}") then
        error(`TuffSeal parser error: Expected '}' after if block!`, 2);
    end

    local elseIfBranches = {};
    local elseBranch = nil;

    while (self:peek().type == "ELSEIF") do
        self:advance();

        local op = self:advance();
        if (op.type ~= "(") then
            error(`TuffSeal parser error: Expected '(' after elseif!`, 2);
        end

        local ElifCondition = self:parseExpression();
        local cp = self:advance();
        if (cp.type ~= ")") then
            error("TuffSeal parser error: Expected ')' after elseif!", 2);
        end

        local bo = self:advance();
        if (bo.type ~= "{") then
            error("TuffSeal parser error: Expected '{' after elseif!", 2);
        end

        local block = {};
        while (self:peek().type ~= "}" and not self:isAtEnd()) do
            local statement = self:parseStatement();
            if (statement) then
                table.insert(block, statement);
            end
        end

        local block_close = self:advance();
        assert(block_close.type == "}", `TuffSeal parser error: Expected '}' after elseif block!`);

        table.insert(
            elseIfBranches,
            {
                condition = ElifCondition,
                block = block
            }
        );
    end

    if (self:peek().type == "ELSE") then
        self:advance();

        local bo = self:advance();
        assert(bo.type == "{", "TuffSeal parser error: Expected '{' after else!");

        elseBranch = {};
        while (self:peek().type ~= "}" and not self:isAtEnd()) do
            local statement = self:parseStatement();
            if (statement) then
                table.insert(elseBranch, statement);
            end
        end

        local bc = self:advance();
        assert(bc.type == "}", "TuffSeal parser error: Expected '}' after else block!");
    end

    return {
        kind = "If",
        condition = condition,
        thenBranch = ThenBranch,
        elseIfBranches = elseIfBranches,
        elseBranch = elseBranch
    }
end

function Parser:parseWhileStatement(): ASTNode
    self:advance();

    local open_paren = self:advance();
    assert(open_paren.type == "(", "TuffSeal parser error: Expected '(' after while!");

    local condition = self:parseExpression();

    local close_paren = self:advance();
    -- // You CANNOT believe how tired i am of writing error messages
    -- // i hate this
    assert(close_paren.type == ")", "TuffSeal parser error: Expected ')' after while condition!");

    local brace_open = self:advance();
    assert(brace_open.type == "{", "TuffSeal parser error: Expected '{' after while condition!");

    local body = {};
    while (self:peek().type ~= "}" and not self:isAtEnd()) do
        local statement = self:parseStatement();
        if (statement) then
            table.insert(body, statement);
        end
    end

    local brace_close = self:advance();
    assert(brace_close.type == "}", "TuffSeal parser error: Expected '}' after while body!");

    return {
        kind = "While",
        condition = condition,
        body = body
    }
end

function Parser:parseForStatement(): ASTNode
    self:advance();

    local open_paren = self:advance();
    assert(open_paren.type == "(", "TuffSeal parser error: Expected '(' after for");

    if self:peek().type == "IDENTIFIER" and self.tokens[self.current + 1].type == "=" then
        local varToken = self:advance()
        assert(varToken.type == "IDENTIFIER", "TuffSeal parser error: Expected identifier in numeric for");

        assert(self:advance().type == "=", "TuffSeal parser error: Expected '=' after for variable");

        local startExpr = self:parseExpression();

        assert(self:advance().type == ",", "TuffSeal parser error: Expected ',' after start expression");

        local endExpr = self:parseExpression()

        local stepExpr = { kind = "Literal", value = 1 };
        if self:peek().type == "," then
            self:advance();
            stepExpr = self:parseExpression();
        end

        assert(self:advance().type == ")", "TuffSeal parser error: Expected ')' after numeric for");

        assert(self:advance().type == "{", "TuffSeal parser error: Expected '{' after for");

        local body = {};
        while self:peek().type ~= "}" and not self:isAtEnd() do
            local stmt = self:parseStatement()
            if stmt then
                table.insert(body, stmt);
            end
        end

        local brace_close = self:advance();
        assert(brace_close.type == "}", "TuffSeal parser error: Expected '}' after for body");

        return {
            kind = "ForNumeric",
            variable = varToken.lexeme,
            start = startExpr,
            ["end"] = endExpr,
            step = stepExpr,
            body = body
        }
    else
        local keyVar = self:advance();
        assert(keyVar.type == "IDENTIFIER", "TuffSeal parser error: Expected key identifier in for-in");

        assert(self:advance().type == ",", "TuffSeal parser error: Expected ',' after key");

        local valueVar = self:advance();
        assert(valueVar.type == "IDENTIFIER", "TuffSeal parser error: Expected value identifier in for-in");

        assert(self:advance().type == "IN", "TuffSeal parser error: Expected 'in' in for-in");

        local iterable = self:parseExpression();

        assert(self:advance().type == ")", "TuffSeal parser error: Expected ')' after for-in");

        assert(self:advance().type == "{", "TuffSeal parser error: Expected '{' after for-in");

        local body = {}
        while self:peek().type ~= "}" and not self:isAtEnd() do
            local stmt = self:parseStatement();
            if stmt then
                table.insert(body, stmt);
            end
        end

        local brace_close = self:advance()
        assert(brace_close.type == "}", "TuffSeal parser error: Expected '}' after for-in body");

        return {
            kind = "ForIn",
            key = keyVar.lexeme,
            value = valueVar.lexeme,
            iterable = iterable,
            body = body
        }
    end
end

function Parser:parseInsStatement(): ASTNode
    --[[
    ins (a, b) {
        // ...
    }
    ]]

    local open_paren: Token = self:advance();
    assert(open_paren.type == "(", `TuffSeal parser errror: Expected '(' after 'ins'!`);

    local params: { string } = {};

    while (self:peek().type ~= ")") do
        local param: Token = self:advance();

        if (param.type ~= "IDENTIFIER") then
            error(`TuffSeal parser error: Expected parameter name!`, 2);
        end
        table.insert(params, param.lexeme);

        if (self:peek().type == ",") then
            self:advance();
        else
            break;
        end
    end

    local close_paren: Token = self:advance();
    assert(close_paren.type == ")", `TuffSeal parser error: Expected ')' after 'ins' params!`);

    local open_body: Token = self:advance();
    assert(open_body.type == "{", `TuffSeal parser error: Expected 'ins' body after params!`);

    local body: { ASTNode } = {};
    while (self:peek().type ~= "}" and not self:isAtEnd()) do
        table.insert(body, self:parseStatement(body));
    end

    local close_body: Token = self:advance();
    assert(close_body.type == "}", `TuffSeal parser error: Expected '}' after 'ins' body!`);

    return {
        kind = "Ins",
        parameters = params,
        body = body
    }
end

function Parser:parseUnary(): ASTNode
    local token = self:peek();

    if (token.type == "!" or token.type == "-") then
        self:advance();
        local right = self:parseUnary();
        return {
            kind = "Unary",
            operator = token.type,
            right = right
        };
    end

    return self:parsePrimary();
end;

function Parser:parseExpression(): ASTNode
    return self:parseAssignment();
end;

return Parser;
