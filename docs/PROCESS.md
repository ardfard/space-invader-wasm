# Building Space Invaders in Bend: a learning log

This log records a native Space Invaders game built in Bend 2 (`bend version`
prints 2.0.39), one small step at a time. Each step is a program under
`steps/` that you can build and run on its own. For each step the log covers
the Bend ideas it needs, the code, what broke, and how it got fixed.

It assumes you know some programming language but nothing about Bend. Every
Bend idea gets explained the first time it shows up. Small examples marked
"checked" were run through `bend` 2.0.39, and the error messages quoted are
the real output.

## Step 0: choosing a target

The first plan was Bend compiled to WebAssembly (wasm) and run in a browser.
That turned out to be a bad fit:

- `bend` can build a native binary, or emit C (`-o f.c`), JavaScript
  (`-o f.js`) or a JavaScript module (`-o f.mjs`). It has no wasm output.
- The C it emits is the whole Bend runtime. It starts threads, reserves a
  2 GiB stack and an 8 GiB heap, and installs signal handlers. A wasm32
  program has 4 GiB of memory in total, so getting this into a browser means
  emscripten plus hand patches to the generated C on every build.
- The JavaScript output runs on one thread, so in a browser Bend's
  parallelism does nothing.

So the game is native. I also looked at raylib for graphics and dropped it.
Calling raylib from Bend needs hand-written C glue against Bend's runtime
internals, which `bend guide effects` says can change in any release. Most of
the work would be C, and the goal is to learn Bend. Bend ships its own window
and drawing support (`App.run`, explained in step 1), which is enough for a
2D game.

Commands I keep using:

```sh
bend guide               # the language guide
bend guide effects       # how C and JS code plugs into Bend
bend base App            # print a definition from the standard library
bend base --types        # list every type in the standard library
bend f.bend --check-only # type-check f.bend without running it
bend f.bend              # check, then run main
bend f.bend -o f && ./f  # build a native binary and run it
```

## Bend basics needed for step 1

Read this section before the step 1 code. Each part builds on the one
before it.

### Files, imports and comments

A Bend program is a `.bend` file. Almost every file starts with
`import Base`. `Base` is the standard library: numbers, lists, text,
windows, everything. Lines starting with `#` are comments.

### Functions (`def`)

A function is written with `def`:

```python
def add(a: U32, b: U32) -> U32:
  (a + b : U32)
```

- `add` is the name.
- `a: U32` is a parameter called `a` of type `U32`. Every parameter needs a
  type, because Bend guesses almost nothing for you.
- `-> U32` is the type of the result.
- The indented body is an expression. Its value is the result, so there is
  no `return` keyword in ordinary functions.

You call it as `add(2, 3)`. A program runs the function named `main`.

Names may contain dots: `App.run`, `IO.pure` and `U32.show` are plain
function names. The dot is a naming convention (`Type.verb`), not a method
call on an object.

### Numbers and other basic types

| Type     | What it is                                 | Example literal |
|----------|--------------------------------------------|-----------------|
| `U32`    | unsigned 32-bit integer                    | `42`            |
| `Nat`    | natural number (0, 1, 2, ...), any size    | `42n`           |
| `F32`    | 32-bit float                               | `1.5`           |
| `Bool`   | true or false                              | `True{}`        |
| `String` | text                                       | `"hello"`       |
| `Unit`   | "nothing", like `void`                     | `Unit{}`        |

`U32` arithmetic wraps around: `(4294967295 + 1 : U32)` is `0` (checked).

### Operators need a type

`a + b` alone is an error (checked):

```
- message  : a type for this operator (write (a + b : Nat))
```

Write `(a + b : U32)`. The `: U32` tells Bend which addition to use, and
`(a + b : U32)` turns into a call to the function `U32.add(a, b)`. The same
goes for `- * / %`, the comparisons `< <= > >=`, and the bit operators
`.&.` (and), `.|.` (or) and `.^.` (xor).

For a bare literal whose type Bend can't work out, annotate it with
braces: `{5 : U32}`.

### Datatypes and constructors (Bend's structs and enums)

You define your own data shapes with `type`. One type can have several
shapes, called constructors, and each constructor has named fields:

```python
type Shape is Data:
  Circle{r: U32}
  Square{s: U32}
```

A `Shape` is either a `Circle` with a field `r`, or a `Square` with a
field `s`. A struct is a type with one constructor. An enum is a type whose
constructors have no fields.

You build a value by writing the constructor with its fields in braces:
`Square{5}`. Constructors with no fields still need the braces: `True{}`,
`None{}`, `Unit{}`.

`is Data` means values of this type may be copied. `is Type` means they
can't. More on copying under "Use each variable once" below.

Some types from `Base` that step 1 uses:

```python
type Bool:        True{}  False{}
type Maybe<A>:    None{}  Some{value: A}          # an optional value
type List<A>:     Nil{}   Con{head: A, tail: List<A>}
```

(Simplified. `bend base Maybe` prints the real definitions.)

`List<A>` and `Maybe<A>` are generic. The `A` in angle brackets is the
element type, so `List<U32>` is a list of numbers. A list is a chain of
`Con` cells ending in `Nil`, so the list `[1, 2]` is
`Con{1, Con{2, Nil{}}}`.

A pair of two values is written `(a, b)`, and its type is `Pair(A, B)`.

### `match`: looking inside a value

Bend has no `if`. To make a decision, you `match` on a value and give one
`case` per constructor:

```python
def width(x: Shape) -> U32:
  match x:
    case Circle{r}:
      (2 * r : U32)
    case Square{s}:
      s
```

`case Square{s}:` means "if `x` is a `Square`, call its field `s` and run
this branch". The cases are tried top to bottom.

Patterns can nest, and can contain literal numbers and `_` ("anything,
ignore it"). For example, `case Con{Key{27, True{}}, rest}:` reads "a list
whose first element is a `Key` event with code 27 that is pressed, and call
the rest of the list `rest`".

To branch on a `Bool`, match on `True{}` and `False{}`.

### Recursion instead of loops, and termination

Bend has no `for` or `while`. A function repeats work by calling itself.
Bend also refuses any function it can't prove will finish, so a recursive
call must be on a smaller piece of an input, one you got out of a `match`.

```python
def sum(xs: List<U32>, acc: U32) -> U32:
  match xs:
    case Nil{}:
      acc
    case Con{h, t}:
      sum(t, (acc + h : U32))   # t is smaller than xs, so this ends
```

A loop that should run "until the user quits" counts down a `Nat` called
fuel instead, and stops when the fuel hits `0n`.

### Use each variable once (affine variables)

This is the rule that will feel most foreign. **By default, each variable
may be used at most once.** Using it zero times is fine. Using it twice is
an error, even for a plain number (checked):

```python
def dup(c: U32) -> Pair(U32, U32):
  (c, c)
```

```
- expected : c
- observed : c (consumed more than once)
```

To use a variable more than once, put `+` in front of it where it's
introduced. This only works for `Data` types, the copyable ones. This
version runs and prints `(7, 7)` (checked):

```python
def dup(+c: U32) -> Pair(U32, U32):
  (c, c)
```

The `+` also works on fields pulled out by `match`. Computing an area uses
each field twice, so both patterns need it. Without `+s`, the `Square` case
fails with `s (consumed more than once)` (checked):

```python
def area(x: Shape) -> U32:
  match x:
    case Circle{+r}:
      (3 * r * r : U32)
    case Square{+s}:
      (s * s : U32)
```

Why this rule? It lets Bend update memory in place and free it the moment a
value is used up, without a garbage collector. Some types, like windows,
files and arrays, are `Type` rather than `Data`. They can never be copied,
so every function that uses one has to hand it back for the next user.

### Functions as values (lambdas)

`x => (x + 1 : U32)` is a function with no name, called a lambda. Its type
is written `U32 -> U32`. A type like `A -> B -> C` is a function that takes
an `A` and then a `B` and returns a `C`. A two-parameter `def` such as
`def f(a: A, b: B) -> C` fits that type.

`+s => ...` is a lambda whose parameter `s` may be used more than once.

A lambda value follows the use-once rule too. Calling the same function
value twice fails (checked):

```python
def twice(f: U32 -> U32, x: U32) -> U32:
  f(f(x))
```

```
- observed : f (consumed more than once)
```

Top-level `def`s don't have this limit. You can call `tick` or `add` as
often as you like.

### Templates (`~` parameters)

A parameter marked with `~` is a template. Bend pastes the argument's code
into the function body at compile time, the way a C macro or a C++ template
would. That gets around the limit above, because each paste is a separate
copy. This version of `twice` checks fine:

```python
def twice(~f: U32 -> U32, x: U32) -> U32:
  f(f(x))

twice(~(x => (x + 1 : U32)), 40)   # 42
```

Rules (both checked):

- `~` parameters come first. Putting one after a normal parameter gives
  `only leading binders take ~`.
- You write `~` at the call too, and the argument may only mention
  top-level names, not the caller's local variables:
  `color is a variable here, not comptime: pass it at run time`.

### Type parameters

Types are values in Bend, so a function can take a type as a parameter.
`S: Type` means "`S` is some type". Erasing it with `-S: Type` means the
type checker uses it but the compiled program drops it. You'll see `~S`,
`-S` and `S` in `Base` signatures, and you pass a type like any other
argument: `IO.pure(Maybe<U32>, Some{5})`.

### IO: doing things in the outside world

Bend functions are pure. A function can't print, read a key or draw a
window as a side effect. Instead, a function returns a description of the
work to do, a value of type `IO(T)`, where `T` is the type of the answer.
The runtime performs it.

- `main() -> IO(Unit)` means "main describes some work whose answer is
  nothing in particular".
- `IO.pure(T, value)` is IO that does nothing and answers `value`. You
  pass the type `T` because Bend doesn't infer it.
- A `do IO<T>:` block runs several IO steps in order (see `bend guide`).
  Step 1 doesn't need one.

## Step 1: hello window (`steps/01_hello.bend`)

Goal: open a 256 x 256 window filled with one color. Any key press changes
the color. Escape or closing the window quits.

The whole program:

```python
import Base

# A key press changes the color; Escape or closing the window quits.
def next_color(c: U32) -> U32:
  ((c * 2654435761 : U32) .^. 16744512 : U32)

def tick(events: List<Event>, color: U32) -> IO(Maybe<U32>):
  match events:
    case Nil{}:
      IO.pure(Maybe<U32>, Some{color})
    case Con{Close{}, rest}:
      IO.pure(Maybe<U32>, None{})
    case Con{Key{27, True{}}, rest}:
      IO.pure(Maybe<U32>, None{})
    case Con{Key{_, True{}}, rest}:
      tick(rest, next_color(color))
    case Con{_, rest}:
      tick(rest, color)

def main() -> IO(Unit):
  App.run(~U32, ~App{+s => (s, Pix{s}), tick}, "Step 1: hello", 256, 256, 2113664)
```

Build and run:

```sh
cd steps && bend 01_hello.bend -o hello && ./hello
```

### How a Bend app works

`Base` has a small game framework built around two functions you write:

- `view` takes the current game state and returns a picture of it.
- `tick` takes the key and mouse events from one frame and the current
  state, and returns the next state, or "quit".

The framework opens a window and loops: call `view`, show the picture,
collect events, call `tick`, repeat. All the game logic is in those two
pure functions. The game state can be any type you choose. In step 1 it's a
single `U32`, the current color.

### The pieces from `Base`

`bend base App` prints this definition (reformatted):

```python
type App<-S: Type> is Type:
  App{view: S -> Pair(S, Image),
      tick: List<Event> -> S -> IO(Maybe<S>)}
```

An `App<S>` is a struct with two fields, both functions. `S` is the state
type.

- `view: S -> Pair(S, Image)` takes the state and returns a pair: the state
  again, plus the picture. Why give the state back? Because of the
  use-once rule. The framework hands the state to `view`, and once `view`
  has used it, nobody else can. Returning it passes ownership back so the
  framework can give it to `tick` next.
- `tick: List<Event> -> S -> IO(Maybe<S>)` takes this frame's events and
  the state. It answers `Some{new_state}` to keep going or `None{}` to
  quit. The answer is wrapped in `IO` so `tick` may do real IO, such as
  playing a sound.

And the function that starts it all:

```python
def App.run(~S: Type, ~app: App<S>, title: String,
            width: U32, height: U32, state: S) -> IO(Unit)
```

| Parameter | In step 1                     | Meaning                         |
|-----------|-------------------------------|---------------------------------|
| `~S`      | `~U32`                        | the state type, as a template   |
| `~app`    | `~App{+s => (s, Pix{s}), tick}` | your `view` and `tick`, as a template |
| `title`   | `"Step 1: hello"`             | window title                    |
| `width`   | `256`                         | window width in pixels          |
| `height`  | `256`                         | window height in pixels         |
| `state`   | `2113664`                     | the starting state (a blue)     |

A picture is an `Image`:

```python
type Image is Data:
  Pix{color: U32}
  Qua{tl: Image, tr: Image, bl: Image, br: Image}
```

`Pix{color}` paints the whole square one color. `Qua{tl, tr, bl, br}`
splits the square into four quarters (top-left, top-right, bottom-left,
bottom-right), and each quarter is another `Image`. A picture of this kind
is a quadtree. To draw a small shape, you keep splitting until the pieces
are small enough. Step 2 does exactly that. The root square is the next
power of two at or above the larger window side, so 256 for a 256 x 256
window.

Events, from `bend base Event`:

```python
type Event is Data:
  Key{code: U32, down: Bool}      # down is True{} on press, False{} on release
  Text{text: String}
  Mouse{x: U32, y: U32, button: U32, down: Bool}
  Move{x: U32, y: U32}
  Look{dx: F32, dy: F32}
  Scroll{x: U32, y: U32, dx: F32, dy: F32}
  Close{}                          # the window's close button
```

Key codes, read from `~/.bend/bend2/effs/window.c`: a printable key is its
lowercase character code, so `a` is 97 and Space is 32. Escape is 27. The
arrows are Up 63232, Down 63233, Left 63234, Right 63235.

Colors are `U32` values in `0xRRGGBB` form. A screenshot confirmed it:
`2113664` is `0x204080`, a dark blue.

### Reading the program

`next_color(c)` scrambles a color into a different one. It multiplies by a
large odd number (wrapping at 2^32) and xors with a fixed value. Any
function that changes the number would do.

`tick(events, color)` walks the event list with `match`, one case per
situation, top to bottom:

1. `Nil{}`: no events left. Keep running with the current color:
   `IO.pure(Maybe<U32>, Some{color})`.
2. `Con{Close{}, rest}`: the first event is the close button. Quit with
   `None{}`. `rest` goes unused, which the use-once rule allows.
3. `Con{Key{27, True{}}, rest}`: Escape pressed. Quit.
4. `Con{Key{_, True{}}, rest}`: any other key pressed. Change the color
   and keep reading the rest of the list. This must come after case 3,
   because the first matching case wins.
5. `Con{_, rest}`: anything else, like a key release or mouse movement.
   Skip it.

Cases 4 and 5 call `tick` again on `rest`, which is smaller than `events`,
so Bend accepts that `tick` finishes.

`main` hands everything to `App.run`. The view is the lambda
`+s => (s, Pix{s})`. It uses `s` twice, once as the state handed back and
once as the color to paint, so it needs the `+`.

### Why `App.run` takes `~` templates

You can treat this as background, but it ties the earlier rules together.

`App.run` loops by calling `App.loop`, which counts down fuel starting at
`4294967295n` (2^32 - 1). Each round of the loop calls `view` and `tick`
once. If `app` were an ordinary parameter, it would be a function value,
and the second round would be "using `app` twice", which the use-once rule
forbids. As a template, the `App{...}` code is pasted into the loop, so
every round gets its own copy. `S` is a template for a similar reason: the
loop passes `~S` and `~app` to itself again as code.

This also explains the restriction from the templates section: the `~app`
argument may only mention top-level names. That's why `tick` is a
top-level `def`, and the starting color is passed as the plain runtime
argument `state`.

With 2^32 - 1 frames of fuel, at 60 frames per second the window would
close by itself after about 2.3 years. In practice `tick` answering
`None{}` ends it first.

### What broke

- `0x00FF8040` failed with `expected : a numeric literal`. Bend has no hex
  literals, so colors are written in decimal (`16744512`).
- `next_color` first had `+c`, which wasn't needed because `c` is used
  once. It checked fine, but I removed it so every `+` in the code means
  something.
