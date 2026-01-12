-- // TuffSeal interpreter

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

local interpreter = {};
interpreter.__index = interpreter;

local fs = require("@lune/fs");
local String = require("./string");

local BREAKSIGNAL = { kind = "Break" };

local TUFFSEAL_DEFAULT_ENVIRONMENT = {
    ['getenv'] = function (self)
        return self or {};
    end
};

-- // all array checks somehow return false on both arrays and dicts
-- // or all say that all arrays are dictionaries
-- // this is the easiest way to do this im sorry
local __ARRAYS = {};
local __DICTS = {};

-- // built-in functions and stuff are in the const environment to prevent hooking
local TUFFSEAL_DEFAULT_CONST_ENVIRONMENT = {
    ['print'] = print,
    ['warn'] = warn,
    ['error'] = error,
    ['len'] = function (obj)
        return #obj;
    end,
    ['ipairs'] = ipairs,
    ['push'] = function (array: { any }, value: any)
        local max = -1;
        for k in pairs(array) do
            if typeof(k) == "number" and k > max then
                max = k;
            end
        end
        array[max + 1] = value;
    end,
    ['pop'] = function (array: { any })
        return table.remove(array);
    end,
    ['get'] = function (array: { any }, index: number)
        return array[index + 1];
    end,
    ['remove'] = function (array: { any }, index: number)
        array[index - 1] = nil;
    end,
    ['find'] = function (array: { any }, value: any)
        for i,v in ipairs(array) do
            if (v == value) then
                return i - 1;
            end
        end
        return nil;
    end,
    ['format'] = string.format,
    ['printf'] = function (mainString: string, ...)
        print(string.format(mainString, ...));
    end,
    ['str'] = tostring,
    ['int'] = tonumber,
    ['hasattr'] = function (dict: { [string]: any }, key: string)
        if (dict[key] ~= nil) then return true else return false end;
    end,
    ['getattr'] = function (dict: { [string]: any }, key: string)
        return dict[key];
    end,
    ['setattr'] = function (dict: { [string]: any }, key: string, value: any)
        dict[key] = value;
    end,
    ['loadmodule'] = function (self: { [string]: any? }, modulePath: string, ...)
        local Lexer = require("./lexer");
        local Parser = require("./parser");

        local loadArgs = {...};

        local function t_load_module(path: string, loadargs: { any })
            local src = fs.readFile(path);

            local lexer = Lexer.new(src);
            local tokens = lexer:scanTokens();
            local parser = Parser.new(tokens);

            local mInterpreter = setmetatable({}, interpreter);
            mInterpreter.env = TUFFSEAL_DEFAULT_ENVIRONMENT;
            mInterpreter.const_env = self;

            function mInterpreter.getloadargs()
                return loadargs;
            end

            local RETURN;

            while (not parser:isAtEnd()) do
                local statement = parser:parseStatement();
                if (statement) then
                    RETURN = mInterpreter:evaluate(statement);
                end
            end

            return RETURN;
        end

        if (String.startsWith(modulePath, "@std")) then
            local remainingPath = string.sub(modulePath, 6, #modulePath);
            return require("./stdlib"):getmodule(remainingPath);
        end

        --[[
        ModuleFolder >
            TestModule >
                module.tfs
                // ...

        main.tfs <- script that the module is being loaded from.
        ]]
        if (fs.isDir(modulePath)) then
            assert(fs.isFile(`{modulePath}/module.tfs`), `loadmodule error: module '{modulePath}' is missing 'libmain.tfs'!`);
            
            return t_load_module(`{modulePath}/module.tfs`, loadArgs);
        end
        
        assert(type(self) == 'table', `loadmodule error: expected 'self' to be dictionary, but recieved: {type(self)}. Did you run loadmodule with an exclamation mark? (CORRECT: loadmodule('path.tfs', 'args')!)`);
        assert(modulePath, `loadmodule error: expected arg 'modulePath', but recieved: null`);
        assert(type(modulePath) == 'string', `loadmodule error: expected 'string' for arg 'modulePath', recieved: {type(modulePath)}`);
        assert(fs.isFile(modulePath), `loadmodule error: failed to find module for: {modulePath}`);
        
        return t_load_module(modulePath, loadArgs);
    end,
    ['cloneobject'] = function (obj: any)
        return obj;
    end,
    ['type'] = function (obj: any): string
        if (typeof(obj) == "function") then return "fn" end;
        if (typeof(obj) == "number") then return "int" end;
        if (typeof(obj) == "string") then return "string" end;
        if (typeof(obj) == "boolean") then return "bool" end;
        if (typeof(obj) == "table") then
            if (table.find(__ARRAYS, obj)) then return "array" end;
            if (table.find(__DICTS, obj)) then return "dictionary" end;
        end
        return "luau_external";
    end
};

function interpreter.new()
    local self = setmetatable({}, interpreter);

    self.env = TUFFSEAL_DEFAULT_ENVIRONMENT;
    self.const_env = TUFFSEAL_DEFAULT_CONST_ENVIRONMENT;

    function self.env.getenv()
        return self.env;
    end

    return self;
end

function interpreter:evaluate(node: ASTNode): any
    if (node == nil) then return nil end;
    
    local kind_operations = {
        Literal = function ()
            return node.value;
        end,
        Binary = function ()
            local left = self:evaluate(node.left);
            local right = self:evaluate(node.right);

            if node.operator == "+" then return left + right end;
            if node.operator == "-" then return left - right end;
            if node.operator == "*" then return left * right end;
            if node.operator == "/" then return left / right end;
            if node.operator == "==" then return left == right end;
            if node.operator == "!=" then return left ~= right end;
            if node.operator == "<" then return left < right end;
            if node.operator == ">" then return left > right end;
            if node.operator == "<=" then return left <= right end;
            if node.operator == ">=" then return left >= right end;
        end,
        Unary = function ()
            local right = self:evaluate(node.right);
            if (node.operator == "-") then return -right end;
            if (node.operator == "!") then return not right end;
        end,
        Variable = function ()
            local value = self.const_env[node.name] or self.env[node.name];

            if (value == nil) then
                error(`TuffSeal interpreter error: Undefined variable {node.name}`, 2);
            end;

            return value;
        end,
        Assignment = function ()
            --[[
            let a = 5;
            const A = 5;

            a = 6; // reassign
            A = 6; // ERROR: cannot reasign const!
            ]]

            local value = self:evaluate(node.value);

            if (node.declareKind == "const") then
                if (self.const_env[node.name]) then
                    error(`TuffSeal interpreter error: Cannot reasign constant variable {node.name}`, 2);
                end

                if (typeof(value) == "table") then
                    setmetatable(
                        value,
                        {
                            __newindex = function (self, index, value)
                                error(`TuffSeal interpreter error: Cannot modify constant array {node.name}`, 2);
                            end,
                            __metatable = "This metatable is locked by the TuffSeal interpreter."
                        }
                    );
                end

                self.const_env[node.name] = value;
            else
                self.env[node.name] = value;
            end
        end,
        Assign = function ()
            if (self.const_env[node.name] ~= nil) then
                error(`TuffSeal interpreter error: Cannot reassign constant {node.name}`, 2);
            end

            if (self.env[node.name] == nil) then
                error(`TuffSeal interpreter error: Variable {node.name} is not defined`, 2);
            end

            local value = self:evaluate(node.value);
            self.env[node.name] = value;
            return value;
        end,
        Call = function ()
            local callee_expr = self:evaluate(node.callee);

            local callee_function;
            local selfObj = nil;

            if (node.callSelf and node.callee.kind == "Property") then
                selfObj = self:evaluate(node.callee.object);
                callee_function = selfObj[node.callee.name];
            elseif (node.callee.kind == "Variable") then
                callee_function = self:evaluate(node.callee);
            else
                callee_function = callee_expr;
            end

            if (typeof(callee_function) ~= "function") then
                error(`TuffSeal interpreter error: Undefined function: {tostring(callee_function)}`, 2);
            end

            if (node.callSelf and typeof(callee_function) == "function") then
                for k, v in pairs(TUFFSEAL_DEFAULT_CONST_ENVIRONMENT) do
                    if (v == callee_function) then
                        selfObj = self.const_env;
                        break;
                    end
                end
            end

            local args = {};
            for _, argnode in ipairs(node.arguments) do
                table.insert(args, self:evaluate(argnode));
            end

            if (selfObj) then
                return callee_function(selfObj, table.unpack(args)); 
            else
                return callee_function(table.unpack(args));
            end
        end,
        Function = function ()
            --[[
            let fn a(b, c) { whatever() };
            const fn a(b, c) { whatever() };
            fn a(b, c) { whatever() };          // auto to let
            ]]
            local newFn = function (...)
                local args = { ... };
                local localEnv = {};
                
                for k, v in pairs(self.env) do localEnv[k] = v end;
                for i, param in ipairs(node.parameters) do
                    localEnv[param] = args[i];
                end

                local function_interpreter = setmetatable(
                    {
                        env = localEnv,
                        const_env = self.const_env
                    },
                    getmetatable(self)
                );

                local f_run_result;

                for _, statement in ipairs(node.body) do
                    f_run_result = function_interpreter:evaluate(statement);
                end
                return f_run_result;
            end

            if (node.declareKind == "const") then
                self.const_env[node.name] = newFn;
            else
                self.env[node.name] = newFn;
            end
            return newFn;
        end,
        Ins = function ()
            --[[
            ins (a, b) {};
            ]]
            local insFn = function (...)
                local args = { ... };
                local localEnv = {};
                
                for k, v in pairs(self.env) do localEnv[k] = v end;
                for i, param in ipairs(node.parameters) do
                    localEnv[param] = args[i];
                end

                local function_interpreter = setmetatable(
                    {
                        env = localEnv,
                        const_env = self.const_env
                    },
                    getmetatable(self)
                );

                local f_run_result;

                for _, statement in ipairs(node.body) do
                    f_run_result = function_interpreter:evaluate(statement);
                end
                return f_run_result;
            end

            return insFn;
        end,
        Logical = function ()
            local left = self:evaluate(node.left);
            
            if (node.operator == "||") then
                if (not left) then return false end;
                return self:evaluate(node.right);
            elseif (node.operator == "||") then
                if (left) then return true end;
                return self:evaluate(node.right);
            end
        end,
        If = function ()
            --[[
            if (__wtv__) {
                do sum();
            } else if (__smth__else) {
                do_stuff();
            } else {
                do_other_stuff();
            }
            ]]

            if (self:evaluate(node.condition)) then
                return self:executeBlock(node.thenBranch);
            else
                for branch_idx, branch in ipairs(node.elseIfBranches or {}) do
                    if (self:evaluate(branch.condition)) then
                        return self:executeBlock(branch.block);
                    end
                end
                if (node.elseBranch) then
                    return self:executeBlock(node.elseBranch);
                end
            end
        end,
        While = function ()
            --[[
            while (true) {
                // whatever
            }
            ]]
            while (self:evaluate(node.condition)) do
                for _, statement in ipairs(node.body) do
                    local result = self:evaluate(statement);
                    if (result == BREAKSIGNAL) then
                        return nil;
                    end
                end
            end
        end,
        Break = function ()
            return BREAKSIGNAL;
        end,
        ForNumeric = function ()
            --[[
            for (step = 1, 10, 1) {
                print(step);
            }
            ]]
            local start = self:evaluate(node.start);
            local finish = self:evaluate(node['end']);
            local step = node.step and self:evaluate(node.step) or 1;

            for i = start, finish, step do
                self.env[node.variable] = i;
                for _, statement in ipairs(node.body) do
                    local res = self:evaluate(statement);
                    if (res == BREAKSIGNAL) then return nil end;
                end
            end
        end,
        ForIn = function ()
            local iterable = self:evaluate(node.iterable)
            local iterator_func, state, var;

            if typeof(iterable) == "function" then
                iterator_func = iterable;
                state = {};
                var = nil;
            elseif typeof(iterable) == "table" then
                if node.iteratorType == "pairs" or node.iteratorType == nil then
                    iterator_func, state, var = pairs(iterable);
                elseif node.iteratorType == "ipairs" then
                    iterator_func, state, var = ipairs(iterable);
                else
                    error("TuffSeal interpreter error: Unknown for-in iterator type", 2);
                end
            else
                error("TuffSeal interpreter error: for-in expects function or table", 2);
            end

            while true do
                local k, v = iterator_func(state, var);
                if k == nil then break end;

                local LoopEnv = {};
                for k, v in pairs(self.env) do LoopEnv[k] = v end;

                if node.key then LoopEnv[node.key] = k end;
                if node.value then LoopEnv[node.value] = v end;

                local LoopInterpreter = setmetatable({env = LoopEnv, const_env = self.const_env}, interpreter);

                for _, stmt in ipairs(node.body) do
                    local res = LoopInterpreter:evaluate(stmt);
                    if (res == BREAKSIGNAL) then return nil end;
                end

                var = k;
            end
        end,
        Array = function ()
            local array = {};

            for i, elem in ipairs(node.elements) do
                array[i - 1] = self:evaluate(elem);
            end

            table.insert(__ARRAYS, array);

            return array;
        end,
        Dictionary = function ()
            if (not node or not node.entries) then
                return {};
            end

            local dict = {};

            for idx, entry in ipairs(node.entries) do
                if (entry and entry.key) then
                    dict[entry.key] = self:evaluate(entry.value);
                end
            end

            table.insert(__DICTS, dict);
            
            return dict;
        end,
        Property = function ()
            local obj = self:evaluate(node.object);
            local value = obj[node.name];

            return value;
        end,
        Index = function ()
            local obj = self:evaluate(node.object);
            local idx = self:evaluate(node.index);

            if (typeof(idx) == "number") then
                return obj[idx];
            else
                return obj[idx];
            end
        end
    };

    if (kind_operations[node.kind]) then
        return kind_operations[node.kind]();
    else
        error(`TuffSeal interpreter error: Unknown AST Node kind: {node.kind}`, 2);
    end
end

function interpreter:executeBlock(block: { ASTNode }): any?
    -- // will run using the current interpreter.

    local f_result_r: any?;

    for i, statement in ipairs(block) do
        f_result_r = self:evaluate(statement);
    end

    return f_result_r;
end

function interpreter:loadCmdlineArgs(args: { string })
    -- // check
    for i,v in ipairs(args) do
        assert(typeof(v) == "string", "TuffSeal interpreter:loadCmdlineArgs error: The table should only contain strings!");
    end

    function self.env.getargs()
        return args;
    end
end

return interpreter;
