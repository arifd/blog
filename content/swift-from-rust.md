+++
title = "Swift for Rust Developers: The Surprising Parts"
weight = 1

[extra]
date = "2026-10-30"
author = "Arif Driessen"
+++

Swift shares several syntactic similarities with Rust, making it easy to
assume that familiar constructs behave the same way, even when their
semantics differ.

This article documents the differences that caught me off guard while learning
Swift and developing [a custom app launcher for macOS](https://github.com/arifd/mac-config/tree/main/programs/launcher).

Rather than providing an exhaustive comparison of the two languages, it focuses
on the differences worth knowing to make the transition from Rust to Swift smoother.

<aside>
    Throughout this blog post, where you see text inside a block such as this,
    this indicates my subjective experience of the particular phenomena
</aside>

## Computed properties and property observers

In Swift, property access can execute arbitrary logic.

```swift
var area: Double {
    get { width * height }
    set {
        // The setter's implicit `newValue` is the value assigned to `area`.
        width = newValue / height
    }
}
```

Reading `area` executes the getter, while assigning `area = 100`
executes the setter.

Even a `var` declaration can be read-only if it defines only a getter:

```swift
var id: String {
    return "hello"
}
```

Additionally, you can attach observers to monitor changes:

```swift
var count = 0 {
    // Swift provides `newValue` and `oldValue`.
    willSet { print("About to become \(newValue)") }
    didSet { print("Was \(oldValue)") }
}

// Prints one line from willSet and one from didSet.
count = 5
```

<aside>
    I found it useful for trivial accesses, such as aliasing nested fields, or
    setting constant values, etc. but wherever computation needs to occur I
    opted to move it to a function, so that callers may know where the expensive
    logic may live.
</aside>

## Opaque types (some) and Existential types (any)

The `some` keyword in Swift has nothing to do with optionals. Instead, it is
roughly equivalent to the `impl` keyword in Rust.

Similarly, `any` is roughly equivalent to `dyn`.

## Package manifest directives in comments

The Swift Package Manager requires a comment like
`// swift-tools-version: 6.0` at the very top of `Package.swift`.
Removing it breaks compilation entirely because the parser relies on it to
determine the toolchain version.

## Documentation generation (DocC)

To get something roughly equivalent to `cargo doc`, Swift uses DocC.

First, add the DocC plugin to your `Package.swift` dependencies:

```swift
.package(
    url: "https://github.com/swiftlang/swift-docc-plugin",
    from: "1.4.0"
),
```

This does not add any runtime dependencies to your library.

Then, you can preview your documentation locally by running:

```sh
swift package --disable-sandbox \
    preview-documentation --product <NAME_OF_LIBRARY>
```

<aside>
    I did not find this as useful as `rustdoc`, and in the end, preferred to
    just read the code directly.
</aside>

## Modules and visibility

In Swift, a "module" is roughly equivalent to a crate, rather than an
individual source file as it typically is in Rust. All files within the
same Swift module can access each other's internal declarations without
`mod` or `use` statements. The `public` keyword in Swift exposes declarations
to other Swift modules.

<aside>
    At first this was rather surprising, but I became a fan of it for my own
    modules. When importing third-party modules, however, it's a bit unfortunate
    that you get all `public` declarations in scope automatically. When reading
    code you did not write, it's hard to know where anything lives.
</aside>

## Top-level statements

Swift allows top-level executable statements in an entry-point file, commonly,
but not always named `main.swift`.

<aside>
    This was surprising at first, especially in a larger codebase. I felt "lost"
    when not inside a function, but for small programs it makes sense. I'm not
    sure if I'm ultimately a fan of it, though.
</aside>

## Semicolons

Semicolons are optional in Swift and are only required when writing multiple
statements on the same line.

Idiomatic Swift omits semicolons unless needed.

## Trailing Closure Syntax

Imagine a function that takes a closure:

```swift
func run(_ action: () -> Void) { /* ... */ }
```

A closure is an expression that can look like a block:

```swift
{ print("Hello") } // This is a closure.
```

Swift allows placing closure arguments **outside the parentheses** of a function
call!

Thus, the following three are equivalent:

```swift
run({ print("Hello") })  // Inline
run { print("Hello") }   // Trailing without parentheses
run() { print("Hello") } // Trailing with parentheses
```

Swift also supports multiple trailing closures using argument labels:

```swift
func perform(task: () -> Void, onSuccess: () -> Void) { /* ... */ }

perform {
    print("Task")
} onSuccess: {
    print("Success")
}
```

Now imagine a function that takes an ordinary argument followed by a closure:

```swift
func repeatAction(times: Int, action: () -> Void) { /* ... */ }
```

You will commonly see it expressed like this:

```swift
repeatAction(times: 3) {
    print("Hello")
}
```

<aside>
    At first this made me feel a little sick in my stomach, but you get used to
    it. It feels like the syntax-bending you see in languages that don't require
    parentheses for function paremeters, only worse, because Swift both uses it
    and doesn't.
</aside>

## `if let` and `guard let`

Swift's `if let` is conceptually similar to Rust's `if let`, and `guard let`
corresponds to Rust's `let else` statements.

Unlike Rust—which uses pattern matching on enums like `Some(T)`, Swift has
built-in optionals.

Here is `if let` for conditional unwrapping within a block:

```swift
func greet(_ name: String?) {
    if let name {
        print(name) // `name` is unwrapped here
    }

    // `name` is again an optional here
}
```

And here is `guard let`, which exits early and leaves the unwrapped variable
in scope for the rest of the function:

```swift
func greet(_ name: String?) {
    guard let name else {
        return
    }

    // `name` is unwrapped for the rest of the function scope
}
```

For more complex enum unpacking with associated values closer to Rust's full
pattern matching, Swift provides `if case let` and `guard case let`:

```swift
enum Result {
    case success(String)
    case failure(Int)
}

func handle(_ result: Result) {
    if case let .success(message) = result {
        print(message)
    }
}
```

## Mutability with `let`

In Rust, `let` bindings are immutable by default, requiring `let mut` for
mutation. In Swift, `let` also declares an immutable binding, while `var`
declares a mutable one.

For structs (value types), `let` behaves as expected:

```swift
struct Configuration {
    var activates = false
}

let configuration = Configuration()
configuration.activates = true // Error!
```

However, classes in Swift are reference types, and `let` only prevents
reassigning the reference, **not mutating the object it refers to**:

```swift
class Configuration {
    var activates = false
}

let configuration = Configuration()
configuration.activates = true  // OK!
configuration = Configuration() // Error!
```

Swift's `let` does not guarantee that an object is immutable; it only
guarantees that the binding cannot be reassigned.

<aside>
    This caught me completely off guard, as I began to worry what it could mean
    to my sanity in a world where the `let`/`var` sanctity has been broken. But
    I guess it's the same process one goes through, when discovering interior mutability in Rust.
</aside>
