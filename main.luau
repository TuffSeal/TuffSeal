-- // TuffSeal main.lua

local Lexer = require("./Src/lexer");
local Parser = require("./Src/parser");
local Interpreter = require("./Src/interpreter");

local fs = require("@lune/fs");
local stdio = require("@lune/stdio");

local args = { ... };

local function printHelp()
    local help_text = [[
Usage: lune main.lua [options] [file]

Options:
    -h, --help      Show this help message
    -r, --run       Run a TuffSeal script (default behavior if file provided)
    --repl          Launch interactive REPL (not implemented yet)

Examples:
    lune main.lua script.tuff          -- runs the file
    lune main.lua -r script.tuff       -- same as above
    lune main.lua -h                   -- show help
]]
    print(help_text);
end

local function runFile(path: string)
    assert(fs.isFile(path), `TuffSeal error: file not found: {path}`);

    local content = fs.readFile(path);

    local lexer = Lexer.new(content);
    local tokens = lexer:scanTokens();
    local parser = Parser.new(tokens);
    local interpreter = Interpreter.new();

    while not parser:isAtEnd() do
        local statement = parser:parseStatement();
        interpreter:evaluate(statement);
    end
end

if (#args == 0) then
    print("TuffSeal: No file provided.");
    local path = stdio.prompt("text", "Enter file path: ");
    if path == "" or not fs.isFile(path) then
        error("No valid file provided.");
    end
    runFile(path);
    return;
end

local first = args[1]

if (first == "-h" or first == "--help") then
    printHelp();
elseif (first == "--repl") then
    error("REPL not implemented yet");
elseif (first == "-r" or first == "--run") then
    if #args < 2 then
        error("No file provided after -r / --run");
    end
    runFile(args[2]);
elseif (fs.isFile(first)) then
    runFile(first);
else
    error(`TuffSeal: Unknown argument or file not found: '{first}'`);
end