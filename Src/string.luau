-- // string.luau - tuffseal

local String = {};

function String.isWhitespace(Str: string): boolean
    return (Str:match("^%s$") ~= nil);
end

function String:isInteger(Str: string): boolean
    return Str >= "0" and Str <= "9";
end

function String:isAlphaNumeric(Str: string): boolean
    return (Str:match("[%w_]") ~= nil);
end

function String.startsWith(Str: string, Start: string): boolean
    return (Str:sub(1, #Start) == Start);
end

return String;
