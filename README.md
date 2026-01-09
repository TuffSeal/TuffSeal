<div align="center">

# TuffSeal

**A small, explicit, embeddable scripting language**  
with C-style syntax, implemented entirely in **Luau**

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Luau](https://img.shields.io/badge/built%20with-Luau-2C3E50.svg)](https://luau-lang.org/)
[![Release](https://img.shields.io/github/v/release/U-235Consumer/TuffSeal)](https://github.com/U-235Consumer/TuffSeal/releases)

</div>

**TuffSeal** is a small, interpreted, dynamically-typed programming language with a C-style syntax.
It is implemented entirely in **Luau**, featuring a custom **lexer, parser, AST, and interpreter**.

TuffSeal is designed to be **simple**, **explicit**, and **easy to extend**, making it ideal for:

* Learning how programming languages work internally
* Experimenting with interpreters and ASTs
* Embedding into larger Luau-based projects

TuffSeal uses the **`.tfs`** file format for both scripts and modules.

---

## Features

* Interpreted, AST-based execution
* Dynamically typed
* C-style syntax
* `let` and `const` variables
* First-class arrays and dictionaries
* Expression-based functions (no `return` keyword)
* Hook-safe `const fn` functions
* Module system
* Rich standard library (task, fs, net, process, serde, datetime, stdio)

---

## Comments

```tfs
// This is a comment
```

---

## Variables

```tfs
let x = 5;       // mutable variable
const y = 10;   // immutable variable
```

* `let` variables can be reassigned
* `const` variables cannot be reassigned
* Constant arrays and dictionaries are **immutable**

---

## Data Types

```tfs
let n = 42;          // number
let s = "hi!";      // string (semicolons are optional)

let arr = [ 1, 2, 3, "four", "apple" ];
print(arr[0]);      // 1 (arrays are 0-indexed)

let dict = {
	a: "Hello!",
	b: 5
};

print(dict.a, dict.b);     // Hello! 5
print(dict["a"]);          // Hello!
```

---

## Functions

TuffSeal does **not** use `return`.
The **last expression** in a function is automatically returned.

```tfs
let fn add(a, b)
{
	a + b;
}

const fn sub(a, b) {
	a - b;
	// const functions cannot be hooked or overwritten
}

fn mult(a, b) {
	a * b; // defaults to let
}
```

---

## Control Flow

### Conditionals

```tfs
let x = 5;

if (x == 5) {
	print("x is 5!");
} elseif (x == 10) {
	print("x is 10!");
} else {
	print("x is not 5 and not 10!");
}
```

### Numeric For Loop

```tfs
// step variable, end value, step size
for (step = 1, 5, 1) {
	print(step); // 1 2 3 4 5
}
```

### Dictionary Iteration

```tfs
let ExampleDict = {
	a: 5,
	b: 10,
	c: 15
};

for (key, value in ExampleDict) {
	print(value); // 5 10 15
}
```

### While Loop

```tfs
while (true) {
	// loop forever
}
```

---

## Attribute Helpers

```tfs
if (hasattr(ExampleDict, "a")) {
	let value_a = getattr(ExampleDict, "a");
}
```

---

## Arrays

```tfs
let arr = [ 1, 2, 3, 4, 5 ]; // index starts at 0

pop(arr);            // [1, 2, 3, 4]
remove(arr, 3);      // [1, 2, 3]

print(find(arr, 1)); // 0
print(len(arr));     // 3
```

---

## Operators

* Comparison: `== != < > <= >=`
* Logical: `&& ||`
* Arithmetic: `+ - * /`

```tfs
let a = 5 + 2 * 3;
let b = "Hello " + "World";
```

---

## Constants & Safety

* `const` variables cannot be reassigned
* Constant arrays cannot be modified
* Constant dictionaries cannot be mutated
* Any mutation attempt throws a **runtime error**

---

## Methods & Self (`!` Call Syntax)

Functions can act as methods using the `!` call syntax, which automatically passes `self`.

```tfs
fn func_inside_dict(self)
{
	setattr(self, "a", 5);
}

let obj = {
	a: 1,
	func: func_inside_dict
};

obj.func()!;
```

---

## Modules & Imports

### Module (`MODULE.tfs`)

```tfs
let loadargs = getloadargs();

fn add(a, b)
{
	a + b;
}

let returnDict = {
	add: add
};

returnDict;
```

### Script (`SCRIPT.tfs`)

```tfs
let module = loadmodule(
	"MODULE.tfs",
	"load", "args", "after", "filepath."
)!;

let result = module.add(1, 1);
print(result); // 2
```

---

## Standard Library

TuffSeal ships with a powerful standard library:

```
task, stdio, fs, process, net, serde, datetime
```

---

## `task`

```tfs
let task = loadmodule("@std/task");

task.wait(5);

fn delayed() {
	print("this task was delayed!");
}
task.delay(2, delayed);

fn spawned() {
	print("running asynchronously");
}
task.spawn(spawned);

fn deferred() {
	print("runs last");
}
task.defer(deferred);
```

---

## `datetime`

```tfs
let DateTime = loadmodule("@std/datetime")!;

let now = DateTime.now();

print(now.toRfc3339()!);
print(now.toRfc2822()!);
print(now.formatLocalTime("%A, %d, %B, %Y", "fr")!);

let future = DateTime.fromLocalTime({
	year: 3033,
	month: 8,
	day: 26,
	hour: 16,
	minute: 56,
	second: 28,
	millisecond: 892
})!;
```

---

## `fs`

Filesystem utilities:

* `readFile`
* `readDir`
* `writeFile`
* `writeDir`
* `removeFile`
* `removeDir`
* `metadata`
* `isFile`
* `isDir`
* `move`
* `copy`

Includes rich metadata, permissions, and write options.

---

## `net`

Networking primitives:

* HTTP requests (`net.request`)
* HTTP servers (`net.serve`)
* WebSockets
* TCP & TLS streams
* URL encoding/decoding

Supports full request/response objects and server handlers.

---

## `process`

Process control:

* OS, architecture, endianness info
* Environment variables
* Spawn and exec child processes
* Full stdio control
* Exit codes and background processes

---

## `serde`

Serialization & cryptography:

* Encode/decode: `json`, `yaml`, `toml`
* Compression: `gzip`, `zstd`, `lz4`, `brotli`
* Hashing: `md5`, `sha*`, `sha3*`, `blake3`
* HMAC support

---

## `stdio`

Terminal I/O:

* User prompts
* Colored & styled output
* Pretty formatting
* Direct stdin/stdout/stderr access

---

## Philosophy

TuffSeal prioritizes:

* Explicit behavior
* Predictable execution
* Minimal magic
* Hackability

If you want a language that lets you **see and control everything**, TuffSeal is for you.
