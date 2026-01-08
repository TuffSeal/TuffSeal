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
    elseif (token.type == "(") then
        expr = self:parseExpression();
        local closing: Token = self:advance();
        if (closing.type ~= ")") then
            error(`TuffSeal parser error: Expected ')' after expression!`, 2);
        end;
    elseif (token.type == "[") then
        local elements = {};

        if (self:peek().type ~= "]") then
            while (true) do
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

        expr = {
            kind = "Array";
            elements = elements;
        };
    elseif (token.type == "{") then
        local entries = {};

        while (self:peek().type ~= "}" and not self:isAtEnd()) do
            local key = self:advance();
            assert(key.type == "IDENTIFIER" or key.type == "STRING", "TuffSeal parser error: Invalid dictionary key!");

            local colon = self:advance();
            assert(colon.type == ":", "TuffSeal parser error: Expected ':' in dictionary!");

            local value = self:parseExpression();

            table.insert(entries, {
                key = key.literal or key.lexeme;
                value = value;
            });

            if (self:peek().type == ",") then
                self:advance();
            else
                break;
            end;
        end;

        local close = self:advance();
        assert(close.type == "}", "TuffSeal parser error: Expected '}' after dictionary!");

        expr = {
            kind = "Dictionary";
            entries = entries;
        };
    elseif (token.type == "IDENTIFIER") then
        if (self:peek().type == "(") then
            self:advance();
            local args = {};

            while (self:peek().type ~= ")" and not self:isAtEnd()) do
                table.insert(args, self:parseExpression());
                if (self:peek().type == ",") then
                    self:advance();
                else
                    break;
                end;
            end;

            local closing: Token = self:advance();
            if (closing.type ~= ")") then
                error(`TuffSeal parser error: Expected ')' after function args!`, 2);
            end;

            expr = {
                kind = "Call";
                callee = token.lexeme;
                arguments = args;
            };
        else
            expr = {
                kind = "Variable";
                name = token.lexeme;
            };
        end;
    else
        error(`TuffSeal parser error: Unexpected token: {token.type}`, 2);
    end;

    while (true) do
        if (self:peek().type == "[") then
            self:advance();
            local index = self:parseExpression();
            local close = self:advance();
            assert(close.type == "]", "TuffSeal parser error: Expected ']' after index!");

            expr = {
                kind = "Index";
                object = expr;
                index = index;
            };
        elseif (self:peek().type == ".") then
            self:advance();
            local name = self:advance();
            assert(name.type == "IDENTIFIER", "TuffSeal parser error: Expected property name!");

            expr = {
                kind = "Property";
                object = expr;
                name = name.lexeme;
            };
        else
            break;
        end;
    end;

    return expr;
end;

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
    while (self:peek().type == ";") do
        self:advance();
    end

    if (self:isAtEnd() or self:peek().type == "}") then
        return nil;
    end
    
    local token: Token = self:peek();
    local statement: ASTNode;

    if (token.type == "LET" or token.type == "CONST") then
        self:advance() 
        if self:peek().type == "FN" then
            return self:parseFunctionDeclaration(token.type:lower()) 
        else
            statement = self:parseDeclaration() -- // normal variable
        end
    elseif (token.type == "FN") then
        statement = self:parseFunctionDeclaration("let") -- // plain fn defaults to let
    elseif (token.type == "IF") then
        return self:parseIfStatement();
    elseif (token.type == "WHILE") then
        return self:parseWhileStatement();
    elseif (token.type == "FOR") then
        return self:parseForStatement();
    else
        statement = self:parseExpression()
    end

    local nextToken: Token = self:peek()
    if nextToken.type == ";" then
        self:advance();
    elseif nextToken.type == "}" or nextToken.type == "EOF" then
        -- // semicolons are optional
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

    local first = self:advance();
    assert(first.type == "IDENTIFIER", "TuffSeal parser error: Expected identifier in for loop!");

    -- // numeric for
    if (self:peek().type == "=") then
        self:advance();

        local startExpr = self:parseExpression();

        local comma1 = self:advance();
        assert(comma1.type == ",", "TuffSeal parser error: Expected ',' after for loop start!");

        local endExpr = self:parseExpression();
        local stepExpr = { kind = "Literal", value = 1 };

        if (self:peek().type == ",") then
            self:advance();
            stepExpr = self:parseExpression();
        end

        local close_paren = self:advance();
        assert(close_paren.type == ")", "TuffSeal parser error: Expected ')' after for numeric loop!");

        local BraceOpen = self:advance();
        assert(BraceOpen.type == "{", "TuffSeal parser error: Expected '{' after for!");

        local body = {};

        while (self:peek().type ~= "}" and not self:isAtEnd()) do
            local statement = self:parseExpression();
            if (statement) then table.insert(body, statement) end;
        end

        self:advance();

        return {
            kind = "ForNumeric",
            variable = first.lexeme,
            start = startExpr,
            ["end"] = endExpr,
            step = stepExpr,
            body = body
        }
    end

    local keyVar = self:advance();
    assert(keyVar.type == "IDENTIFIER", "TuffSeal parser error: Expected key identifier in for-in loop!");

    local comma = self:advance();
    assert(comma.type == ",", "TuffSeal parser error: Expected ',' in for-in loop");

    local valueVar = self:advance();
    assert(valueVar.type == "IDENTIFIER", "TuffSeal parser error: Expected value identifier in for-in loop!");

    local inTok = self:advance();
    assert(inTok.type == "IN", "TuffSeal parser error: Expected 'in' in for-in loop!");

    local iterable = self:parseExpression();

    local close_paren = self:advance();
    assert(close_paren.type == ")", "TuffSeal parser error: Expected ')' after for-in!");

    local brace_open = self:advance();
    assert(brace_open.type == "{", "TuffSeal parser error: Expected '{' after for-in!");

    local body = {};
    while (self:peek().type ~= "}" and not self:isAtEnd()) do
        local statement = self:parseStatement();
        if (statement) then
            table.insert(body, statement);
        end
    end

    local brace_close = self:advance();
    assert(brace_close.type == "}", "TuffSeal parser error: Expected '}' after for-in body!");

    return {
        kind = "ForIn",
        key = keyVar.lexeme,
        value = valueVar.lexeme,
        iterable = iterable,
        body = body
    };
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
    return self:parseOr();
end;

return Parser;
