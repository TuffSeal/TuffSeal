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
}

local interpreter = {};
interpreter.__index = interpreter;

local TUFFSEAL_DEFAULT_ENVIRONMENT = {};

-- // built-in functions and stuff are in the const environment to prevent hooking
local TUFFSEAL_DEFAULT_CONST_ENVIRONMENT = {
    ['true'] = true,
    ['false'] = false,
    ['none'] = nil,
    ['print'] = print,
    ['warn'] = warn,
    ['error'] = error,
    ['len'] = function (obj)
        return #obj;
    end,
    ['ipairs'] = ipairs,
    ['pairs'] = pairs,
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
        local idx = table.find(array, index);
        if (not idx) then return nil end;
        return array[idx];
    end,
    ['remove'] = function (array: { any }, index: number)
        array[index] = nil;
    end,
    ['find'] = function (array: { any }, value: any)
        for i,v in ipairs(array) do
            if (v == value) then
                return i;
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
        if (dict[key] ~= nil) then return true else return else end;
    end,
    ['getattr'] = function (dict: { [string]: any }, key: string)
        assert(TUFFSEAL_DEFAULT_ENVIRONMENT['hasattr'](dict, key), `This dictionary does not contain key: {key}!`, 2);
    end,
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

function interpreter:evaluate(node: ASTNode): number
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
        Call = function ()
            --[[
            callee("a", "b", 1, 2); etc
            ]]
            local callee_function = self.env[node.callee];
            
            if (not callee_function or typeof(callee_function) ~= "function") then
                if (self.const_env[node.callee] and typeof(self.const_env[node.callee]) == 'function') then
                    callee_function = self.const_env[node.callee];
                else
                    error(`TypeSeal interpreter error: Undefined function: {node.callee}`, 2);
                end;
            end

            local args: { any } = {};
            
            for idx, argnode in ipairs(node.arguments) do
                table.insert(args, self:evaluate(argnode));
            end
            return callee_function(table.unpack(args));
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
                    self:evaluate(statement);
                end
            end
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
                self.env[node.iterator] = i;
                for _, statement in ipairs(node.body) do
                    self:evaluate(statement);
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
                    LoopInterpreter:evaluate(stmt);
                end

                var = k;
            end
        end,
        Array = function ()
            local array = {};

            for i, elem in ipairs(node.elements) do
                array[i - 1] = self:evaluate(elem);
            end

            return array;
        end,
        Dictionary = function ()
            local dict = {};

            for idx, entry in ipairs(node.entries) do
                dict[entry.key] = self:evaluate(entry.value);
            end
            
            return dict;
        end,
        Member = function ()
            local obj = self:evaluate(node.object);
            local value = obj[node.property];

            if (value == nil) then
                error(`TuffSeal interpreter error: Undefiner property {node.property}`, 2);
            end

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
