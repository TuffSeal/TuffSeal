-- // TuffSeal main.lua

local VERSION = "v0.2.0";

local Lexer = require("./Src/lexer");
local Parser = require("./Src/parser");
local Interpreter = require("./Src/interpreter");

local fs = require("@lune/fs");
local stdio = require("@lune/stdio");
local process = require("@lune/process");

local args = process.args;

local function printHelp()
    local help_text = [[
Usage: tuffseal [options] [file]

Options:
    -h, --help      Show this help message
    -r, --run       Run a TuffSeal script (default behavior if file provided)
    --repl          Launch interactive REPL 
    --version       Output TuffSeal version

Examples:
    tuffseal script.tfs          -- runs the file
    tuffseal -r script.tfs.      -- same as above
    tuffseal -h                  -- show help
    tuffseal -v                  -- output version
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

local function repl()
    local interpreter = Interpreter.new();

    while (true) do
        local code = stdio.prompt("text", "> ");

        xpcall(
            function () 
                local lexer = Lexer.new(code);
                local tokens = lexer:scanTokens();
                local parser = Parser.new(tokens);
                
                while not parser:isAtEnd() do
                    local statement = parser:parseStatement();
                    interpreter:evaluate(statement);
                end
            end,
            function (e)
                warn(`Failed to run! Error: {e}`);
            end
        );
    end
end

if (#args == 0) then
    print("TuffSeal: No file provided.");
    local path = stdio.prompt("text", "Enter file path(type 'REPL' for REPL): ");
    if (path == "REPL") then
        repl();
    end
    if (path == "" or not fs.isFile(path)) then
        error("No valid file provided.");
    end
    runFile(path);
    return;
end

local first = args[1]

if (first == "-h" or first == "--help") then
    printHelp();
elseif (first == "--repl") then
    repl();
elseif (first == "-r" or first == "--run") then
    if #args < 2 then
        error("No file provided after -r / --run");
    end
    runFile(args[2]);
elseif (first == "-h" or first == "--version") then
    print(`TuffSeal version: {VERSION}`);
elseif (fs.isFile(first)) then
    runFile(first);
else
    print("Starting TuffSeal repl..")
    repl();
end