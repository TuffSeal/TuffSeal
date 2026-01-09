-- // @std for tuffseal

local std = {};

std.task = require("@lune/task");
std.stdio = require("@lune/stdio");
std.fs = require("@lune/fs");
std.process = require("@lune/process");
std.process.args = nil;
std.net = require("@lune/net");
std.serde = require("@lune/serde");
std.datetime = require("@lune/datetime")

function std:getmodule(module_name: string)
    return self[module_name];
end

return std;
