<div align="center">

<img src="https://files.catbox.moe/7jz9v1.png" alt="TuffSeal Logo" width="180"/>

# TuffSeal

**A small, explicit, embeddable scripting language**
with C-style syntax, implemented entirely in **Luau**

[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)
[![Luau](https://img.shields.io/badge/built%20with-Luau-2C3E50.svg)](https://luau-lang.org/)
[![Release](https://img.shields.io/github/v/release/U-235Consumer/TuffSeal?include_prereleases)](https://github.com/U-235Consumer/TuffSeal/releases)

</div>

**TuffSeal** is a small, interpreted, dynamically-typed programming language with a C-style syntax.
It is implemented entirely in **Luau**, featuring a custom **lexer, parser, AST, and interpreter**.

TuffSeal is designed to be **simple**, **explicit**, and **easy to extend**, making it ideal for:

* Learning how programming languages work internally
* Experimenting with interpreters and ASTs
* Embedding into larger Luau-based projects

TuffSeal uses the **`.tfs`** file format for scripts and modules.

---

## Features

* Interpreted, AST-based execution
* Dynamically typed
* C-style syntax
* `let` and `const` variables
* First-class arrays and dictionaries
* Expression-based functions (no `return` keyword)
* Hook-safe `const fn` functions
* Folder-based module system
* Built-in package manager (**PMS / PackMySeal**)
* Rich standard library (task, fs, net, process, serde, datetime, stdio)

---

## Package Manager (PMS – PackMySeal)

TuffSeal ships with an official package manager called **PMS (PackMySeal)**.

### Module Structure

Modules are now **folders**.

```
module_name/
└── module.tfs
```

`module.tfs` is automatically detected and loaded.
Modules can still be `.tfs` files.

---

### PMS Commands

```sh
pms init [project-name]
```

Initialize a new TuffSeal project.

```sh
pms install [module-name] [project-name]
```

Install a module into a project (defaults to current directory).

```sh
pms remove [module-name] [project-name]
```

Remove a module from a project.

```sh
pms upload <module-name> <version> <zip-file>
```

Upload a module to PMS (requires an account).

```sh
pms list <module-name>
```

List all available versions for a module.

```sh
pms register <username> <password>
pms login <username> <password>
pms logout
pms whoami
```

Account management commands for PMS.

### PMS Platform Support

Precompiled PMS binaries are currently provided **only for Windows (x86_64)**.

If you are on **Linux**, **macOS**, or a **non-x86_64 architecture**, you must compile `pms.py` yourself using the provided build scripts:

* `build_pms.sh` (Linux / macOS)
* `build_pms.bat` (Windows)

These scripts will generate a native PMS executable for your platform using **PyInstaller**.

> PMS is fully cross-platform, but binaries must be built locally on unsupported platforms.

---

## Comments

```tfs
// This is a comment
```

---

## Variables

```tfs
let x = 5;
const y = 10;
```

* `let` variables can be reassigned
* `const` variables cannot be reassigned
* Constant arrays and dictionaries are **immutable**

---

## Data Types

```tfs
let n = 42;
let s = "hi!";

let arr = [ 1, 2, 3, "four" ];
print(arr[0]); // 1

let dict = {
	a: "Hello!",
	b: 5
};

print(dict.a);
print(dict["b"]);
```

---

## `type()` Builtin

TuffSeal provides a built-in `type()` function to determine the runtime type of a value.

```tfs
let object = {
	a: 5,
	c: 10
};

print(type(object)); // "dictionary"
```

### Possible Return Values

* `"fn"` – functions
* `"int"` – numbers
* `"str"` – strings
* `"array"`
* `"dictionary"`
* `"luau_external"` – values originating outside TuffSeal

---

## Functions

TuffSeal does **not** use `return`.
The **last expression** is automatically returned.

```tfs
fn add(a, b) {
	a + b;
}

const fn sub(a, b) {
	a - b;
}

fn mult(a, b) {
	a * b;
}
```

---

## Control Flow

### Conditionals

```tfs
if (x == 5) {
	print("x is 5!");
} elseif (x == 10) {
	print("x is 10!");
} else {
	print("x is something else!");
}
```

### Numeric For Loop

```tfs
for (i = 1, 5, 1) {
	print(i);
}
```

### Dictionary Iteration

```tfs
for (key, value in ExampleDict) {
	print(key, value);
}
```

### While Loop

```tfs
while (true) {
}
```

---

## Attribute Helpers

```tfs
if (hasattr(obj, "a")) {
	let v = getattr(obj, "a");
}
```

---

## Arrays

```tfs
let arr = [1, 2, 3, 4, 5];

pop(arr);
remove(arr, 3);

print(find(arr, 1));
print(len(arr));
```

---

## Operators

* Comparison: `== != < > <= >=`
* Logical: `&& ||`
* Arithmetic: `+ - * /`

---

## Methods & Self (`!` Call Syntax)

```tfs
fn setA(self) {
	setattr(self, "a", 5);
}

let obj = {
	a: 1,
	setA: setA
};

obj.setA()!;
```

---

## Modules & Imports

Modules are loaded from folders containing `module.tfs` or by tuffseal script files directly.

```tfs
let mathmod = loadmodule("math_module")!;
print(mathmod.add(1, 2));
```

---

## Standard Library

```
task, stdio, fs, process, net, serde, datetime
```

---

## Philosophy

TuffSeal prioritizes:

* Explicit behavior
* Predictable execution
* Minimal magic
* Hackability

If you want a language that lets you **see and control everything**, TuffSeal is for you.
