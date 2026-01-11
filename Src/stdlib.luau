-- // @std for tuffseal

local std = {};

std.task = require("@lune/task");
std.stdio = require("@lune/stdio");
std.fs = require("@lune/fs");
std.process = require("@lune/process");
std.net = require("@lune/net");
std.serde = require("@lune/serde");
std.datetime = require("@lune/datetime")

std.math = {
    huge = math.huge,
    pi = math.pi,
    cos = math.cos,
    cosh = math.cosh,
    ceil = math.ceil,
    random = math.random,
    round = math.round,
    rad = math.rad,
    fmod = math.fmod,
    floor = math.floor,
    frexp = math.frexp,
    abs = math.abs,
    acos = math.acos,
    asin = math.asin,
    atan = math.atan,
    atan2 = math.atan,
    clamp = math.clamp,
    exp = math.exp,
    tan = math.tan,
    tanh = math.tanh,
    noise = math.noise,
    max = math.max,
    min = math.min,
    modf = math.modf,
    map = math.map,
    log = math.log,
    log10 = math.log10,
    lerp = math.lerp, --// LARP.....
    ldexp = math.ldexp,
    isinf = math.isinf,
    isnan = math.isnan,
    isfinite = math.isfinite,
    pow = math.pow,
    
};

function std:getmodule(module_name: string)
    return self[module_name];
end

return std;