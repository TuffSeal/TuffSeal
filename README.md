# 🦭 TuffSeal

**TuffSeal** is a small, interpreted, dynamically-typed programming language with a C-style syntax.
It is implemented entirely in **Luau**, including a custom **lexer, parser, AST, and interpreter**.

TuffSeal is designed to be simple, explicit, and easy to extend, making it ideal for learning language internals or embedding into larger projects.

---

## ✨ Features

* `let` and `const` variable declarations
* Dynamic typing
* Arrays (0-based indexing)
* Dictionaries (object-style and bracket access)
* Arithmetic, comparison, and logical operators
* Control flow (`if`)
* Function calls
* Strict runtime and parser error reporting

---

## 📦 Variables & Constants

```ts
let x = 5;
const y = 10;
```

* `let` variables can be reassigned
* `const` variables cannot be reassigned
* Constant arrays and dictionaries are immutable

---

## 📊 Data Types

### Numbers

```ts
let n = 42;
```

### Strings

```ts
let s = "Hello!";
```

### Arrays (0-based indexing)

```ts
let arr = [1, 2, 3, "hello"];
print(arr[0]);
```

### Dictionaries

```ts
let dict = {
    text: "Hello!",
    count: 5
};

print(dict.text);
print(dict["count"]);
```

---

## 🔁 Control Flow

### `if` Statement

```ts
if (x == 5) {
    print("yes");
}
```

Supported operators:

* Comparison: `== != < > <= >=`
* Logical: `&& ||`
* Arithmetic: `+ - * /`

---

## 🧮 Expressions

* Numbers and strings support arithmetic and concatenation
* Arrays and dictionaries are first-class values
* Expressions are evaluated via an AST-based interpreter

Example:

```ts
let a = 5 + 2 * 3;
let b = "Hello " + "World";
```

---

## 🔒 Immutability Rules

* `const` variables cannot be reassigned
* Constant arrays cannot be modified
* Constant dictionaries cannot be mutated
* Any attempt to mutate a constant throws a runtime error

---

## 🧠 Built-in Environment Functions

TuffSeal exposes utility functions in the global environment, including:

* Array insertion
* Array removal
* Value lookup
* Table length utilities

(Exact API may change as the language evolves.)

---

## 🏗 Architecture

TuffSeal is split into three clear stages:

1. **Lexer**

   * Converts source code into tokens

2. **Parser**

   * Builds an Abstract Syntax Tree (AST)

3. **Interpreter**

   * Walks the AST and evaluates nodes

Each stage is isolated and easy to modify or extend.

---

## 📜 Example Program

```ts
let a = 5;

if (a == 5) {
    print("It works!");
}

let arr = [1, 2, 3];
let obj = { name: "TuffSeal" };

print(arr[1]);
print(obj.name);
```

---

## 🚧 Project Status

TuffSeal is a **work in progress**.

Planned features:

* `while` and `for` loops
* User-defined functions
* Better error diagnostics
* Module / import system

Breaking changes may occur.

---

## ⚙️ Running TuffSeal

Example integration:

```lua
local lexer = Lexer.new(source);
local parser = Parser.new(lexer:scanTokens());
local ast = parser:parse();
Interpreter.new():interpret(ast);
```

---

## 📄 License

MIT License.
