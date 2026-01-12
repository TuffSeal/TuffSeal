-- // TuffSeal Lexer Class

type Token = {
    type: string,
    lexeme: string,
    literal: any?,
    line: number
}

local String = require("./string");

local Lexer = {};
Lexer.__index = Lexer;

function Lexer.new(Source: string)
    local self = setmetatable({}, Lexer);

    self.source = Source;
    self.chars = Source:split("");
    self.tokens = {};
    self.current = 1;
    self.line = 1;

    return self;
end

function Lexer:advance(): string
    local c = self.chars[self.current];
    self.current += 1;

    if c == "\n" then
        self.line += 1;
    end

    return c;
end

function Lexer:peek(): string
    if self.current > #self.chars then
        return "\0";
    end
    return self.chars[self.current];
end

function Lexer:peekNext(): string
    if self.current + 1 > #self.chars then
        return "\0"
    end
    return self.chars[self.current + 1];
end

function Lexer:match(expected: string): boolean
    if self:peek() ~= expected then
        return false;
    end
    self:advance();
    return true;
end

function Lexer:readNumber()
    local start = self.current;

    while String:isInteger(self:peek()) do
        self:advance();
    end

    if self:peek() == "." and String:isInteger(self:peekNext()) then
        self:advance();
        while String:isInteger(self:peek()) do
            self:advance();
        end
    end

    local text = self.source:sub(start, self.current - 1);

    local newToken: Token = {
        type = "NUMBER",
        lexeme = text,
        literal = tonumber(text),
        line = self.line
    }

    table.insert(self.tokens, newToken);
end

function Lexer:readString()
    local start = self.current + 0
    self:advance();

    while self:peek() ~= '"' and self:peek() ~= "\0" do
        self:advance();
    end

    if self:peek() == "\0" then
        error(`TuffSeal lexer error: unfinished string literal at line: {self.line}!`, 2);
    end

    local value: string = self.source:sub(start, self.current - 1);
    self:advance();

    table.insert(self.tokens, {
        type = "STRING",
        lexeme = value,
        literal = value,
        line = self.line
    });
end

function Lexer:scanTokens(): { Token }
    while (self.current <= #self.chars) do
        local char = self:advance();

        if String.isWhitespace(char) then
            continue;
        end

        if String:isInteger(char) then
            self.current -= 1;
            self:readNumber();
            continue;
        end

        if (char == "/" and self:peek() == "/") then
            self:advance();

            while (self:peek() ~= "\n" and self:peek() ~= "\0") do
                self:advance();
            end

            continue;
        end

        --[[
        /*
        comment
        ok
        */
        ]]
        if (char == "/" and self:peek() == "*") then
            self:advance();

            while (true) do
                local pk = self:advance();

                if (self:peek() == "\0") then
                    error(`TuffSeal lexer error: unfinished /* comment at: {self.line}`, 2);
                end

                if (pk == "*") then
                    if (self:peek() == "/") then
                        self:advance();
                        break;
                    end
                end
            end

            continue;
        end

        local twoCharOps = { "==", "!=", "<=", ">=" };
        local two_char = char .. self:peek();
        if table.find(twoCharOps, two_char) then
            self:advance();
            table.insert(
                self.tokens,
                {
                    type = two_char,
                    lexeme = two_char,
                    literal = nil,
                    line = self.line
                }
            )
            continue;
        end

        if char == ":" then
            table.insert(
                self.tokens,
                {
                    type = ":",
                    lexeme = ":",
                    literal = nil,
                    line = self.line
                }
            );
            continue;
        end

        if char == "." then
            table.insert(
                self.tokens,
                {
                    type = ".",
                    lexeme = ".",
                    literal = nil,
                    line = self.line
                }
            );
            continue;
        end

        if char == '&' and self:peek() == '&' then
            self:advance();
            table.insert(self.tokens, { type = "AND", lexeme = "&&", literal = nil, line = self.line });
            continue;
        elseif char == '|' and self:peek() == '|' then
            self:advance();
            table.insert(self.tokens, { type = "OR", lexeme = "||", literal = nil, line = self.line });
            continue;
        end

        if char == '=' then
            table.insert(self.tokens, { type = "=", lexeme = "=", literal = nil, line = self.line });
            continue;
        elseif char == '!' then
            table.insert(self.tokens, { type = "!", lexeme = "!", literal = nil, line = self.line });
            continue;
        elseif char == '<' or char == '>' then
            table.insert(self.tokens, { type = char, lexeme = char, literal = nil, line = self.line });
            continue;
        end

        if char == "+" or char == "-" or char == "*" or char == "/" then
            table.insert(
                self.tokens,
                {
                    type = char,
                    lexeme = char,
                    literal = nil,
                    line = self.line
                }
            );
            continue;
        end

        if char == "(" or char == ")" then
            table.insert(
                self.tokens,
                {
                    type = char,
                    lexeme = char,
                    literal = nil,
                    line = self.line
                }
            );
            continue;
        end

        if char == "[" or char == "]" then
            table.insert(
                self.tokens,
                {
                    type = char,
                    lexeme = char,
                    literal = nil,
                    line = self.line
                }
            );
            continue;
        end

        if char == "{" or char == "}" then
            table.insert(
                self.tokens,
                {
                    type = char,
                    lexeme = char,
                    literal = nil,
                    line = self.line
                }
            );
            continue;
        end

        if char:match("%a") then
            local start = self.current - 1;

            while (String:isAlphaNumeric(self:peek())) do
                self:advance();
            end

            local text: string = self.source:sub(start, self.current - 1);
            local typeStr: string = "IDENTIFIER";

            if text == "let" then
                typeStr = "LET";
            elseif text == "const" then
                typeStr = "CONST";
            elseif text == "fn" then
                typeStr = "FN";
            elseif text == "if" then
                typeStr = "IF";
            elseif text == "else" then
                typeStr = "ELSE";
            elseif text == "while" then
                typeStr = "WHILE";
            elseif text == "elseif" then
                typeStr = "ELSEIF";
            elseif text == "for" then
                typeStr = "FOR"
            elseif text == "in" then
                typeStr = "IN"
            elseif text == "break" then
                typeStr = "BREAK";
            elseif text == "true" then
                typeStr = "TRUE";
            elseif text == "false" then
                typeStr = "FALSE";
            elseif text == "null" then
                typeStr = "NULL";
            elseif text == "ins" then
                typeStr = "INS";
            end

            table.insert(self.tokens, {
                type = typeStr,
                lexeme = text,
                literal = nil,
                line = self.line
            });

            continue;
        end

        if char == '"' then
            self:readString();
            continue;
        end

        if char == "/" and self:peek() == "/" then
            self:advance(); self:advance();

            while (self:peek() ~= "\n" and self:peek() ~= "\0") do
                self:advance();
            end
            continue;
        end

        if char == ";" then
            table.insert(
                self.tokens,
                {
                    type = ";",
                    lexeme = ";",
                    literal = nil,
                }
            );
            continue;
        end

        if char == "," then
            table.insert(
                self.tokens,
                {
                    type = ",",
                    lexeme = ",",
                    literal = nil;
                }
            );
            continue;
        end

        error(`TuffSeal: Lexer Error: Unexpected char {char} at line: {tostring(self.line)}!`, 2);
    end

    table.insert(self.tokens, {
        type = "EOF",
        lexeme = "",
        literal = nil,
        line = self.line
    });

    return self.tokens;
end

return Lexer
