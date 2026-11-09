# Building Space Invaders in Bend: a learning log

This log records a native Space Invaders game built in Bend 2 (`bend version`
prints 2.0.39), one small step at a time. Each step is a program named `stepNN_*.bend` in
the repo root that you can build and run on its own. For each step the log covers
the Bend ideas it needs, the code, what broke, and how it got fixed.

To play the finished game:

```sh
bend step10_speed.bend -o invaders && ./invaders
# ← → move, Space fires, R restarts, Escape quits
bend PROOF.bend   # checks every law in LAWS.bend
```

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

## Step 1: hello window (`step01_hello.bend`)

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
bend step01_hello.bend -o hello && ./hello
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

## Step 2: drawing rectangles (`step02_rects.bend`)

Goal: draw a list of colored rectangles, with one sliding across the
screen, by building the `Image` quadtree from step 1. Every shape in the
game (ship, invaders, bullets, shields) will be a rectangle, so this is
the renderer for the rest of the project.

```sh
bend step02_rects.bend -o rects && ./rects
```

A screenshot confirmed it: four rectangles, earlier ones in the list drawn
on top, and the blue square moving right between two frames.

### The idea: split until each square is one color

Step 1 painted the whole window with one `Pix`. To draw shapes, start
with the full 256 x 256 square and ask what it looks like:

- If no rectangle touches it, it's all background: `Pix{background}`.
- If the topmost rectangle touching it covers all of it, it's that
  rectangle's color: `Pix{color}`.
- Otherwise it's a mix. Split it into four 128 x 128 quarters, ask the
  same question for each, and combine the four answers with `Qua`.

The splitting stops at 1 x 1 pixels at the latest. Large empty or filled
areas stop early, so a frame with a few rectangles builds a few thousand
nodes instead of 65,536 pixels.

One speed-up: each quarter only needs the rectangles that touch it. So
before recursing, the program filters the list down for each quarter, and
deeper levels check fewer rectangles.

### New Bend ideas in this step

#### Your own types

```python
type Rect is Data:
  Rect{x: U32, y: U32, w: U32, h: U32, color: U32}

type Look is Data:
  Solid{color: U32}
  Mixed{}
```

`Rect` is a struct: one constructor, five fields. `Rect{40, 40, 80, 60,
16733525}` builds one, with fields in the order they're declared. `Look`
is the answer to "what does this square look like": `Solid{color}` or
`Mixed{}`. Both are `is Data`, so their values may be copied with `+`.

To read a field, `match` on the value and name the fields in the pattern.
`Rect.color` does just that:

```python
def Rect.color(r: Rect) -> U32:
  match r:
    case Rect{x, y, w, h, c}:
      c
```

The unused `x`, `y`, `w` and `h` are fine, since the use-once rule allows
zero uses.

#### A constant is a function with no parameters

```python
def background() -> U32:
  1052688
```

You use it as `background()`. (1052688 is `0x101010`, a near-black.)

#### Lists: `[a, b]` and `<>`

`[a, b, c]` is a list literal. `r <> rest` puts `r` in front of the list
`rest`, the same as `Con{r, rest}`.

#### `Bool` logic

`&&` (and) and `||` (or) work on `Bool` values without a `: T`
annotation. Comparisons need one: `(x < (rx + w : U32) : U32)` reads "x is
less than rx + w, comparing as `U32`".

#### Definition order matters

A `def` can only call `def`s written above it. I first had `Rect.color`
below `classify`, which calls it, and got a confusing error:

```
- expected : a filled definition (an unfilled law is a dead claim: live code cannot use it)
- observed : Rect.color
```

Moving `Rect.color` above `classify` fixed it. This is why the file reads
bottom-up: small helpers first, `main` last.

#### `match` only works on parameters and fields

This is the rule that shapes the code the most. Both of these are
rejected (checked):

```python
match pos(x):      # a computed value
```

```
- message  : a parameter or field scrutinee (a match cannot scrutinize a computed value: give it its own def)
```

```python
b = pos(x)
match b:           # a local variable
```

```
- message  : a parameter or field scrutinee (a match cannot scrutinize a local binder: give it its own def)
```

The fix the message suggests: write a small helper whose parameter is the
value, and match on that parameter. That's what `keep` and `solid_if` are.
They're Bend's `if`:

```python
def keep(hit: Bool, r: Rect, rest: +List<Rect>) -> +List<Rect>:
  match hit:
    case True{}:
      r <> rest
    case False{}:
      rest
```

`keep(touches(r, x, y, s), r, ...)` reads "if `r` touches the square, put
it in front of the rest, otherwise leave it out".

#### Copyable lists: `+List<Rect>` versus `+rs`

`paint` hands the same rectangle list to four quarters, so the list must be
copyable. That takes `+` in two places, with two meanings:

- In a type, `+List<Rect>` means "a list whose values may be copied". A
  plain `List<Rect>` is a use-once list, even though `Rect` is `Data`.
- On a variable, `+rs` means "I will use `rs` more than once". This only
  works when the type allows copies.

So the signature is `def paint(..., +rs: +List<Rect>, ...)`.

Having a copyable type isn't enough on its own. A field pulled out by
`match` needs its own `+` when used twice. In `touching`, `r` goes both to
`touches` and into the result, and `case Con{r, rest}:` failed with
`r (consumed more than once)`. The fix is `case Con{+r, rest}:`.

The same goes for numbers from a `Nat` match. `paint` recurses four times
with `p`, so it needs `case 1n+(+p):`. With plain `1n+p` the error is
`p (consumed more than once)`.

#### Local variables

Inside a body, `name = value` binds a local variable, and `+name = value`
binds one you can use several times:

```python
+h = (s / 2 : U32)
+xr = (x + h : U32)
```

The body's last line is still the result.

#### Nested `match`

A `case` body can contain another `match`. `paint` first matches on the
depth `d`, then on `look`.

#### Parallel calls

```python
a b c e = paint(p, x, y, h, tl, classify(tl, x, y, h))
  paint(p, xr, y, h, tr, classify(tr, xr, y, h))
  paint(p, x, yb, h, bl, classify(bl, x, yb, h))
  paint(p, xr, yb, h, br, classify(br, xr, yb, h))
Qua{a, b, c, e}
```

`a b c e = f(...) g(...) h(...) k(...)` runs the four calls in parallel
and names their results `a`, `b`, `c` and `e`. It can continue on
indented lines. Bend's pure, use-once values mean the four calls can't
interfere with each other, so this is always safe. According to the guide,
the native build spreads them over CPU cores, and they run best when they
do similar amounts of work, which four quarters of a screen usually do. I
haven't measured the speed-up.

#### No mutual recursion, so one recursive function

The natural design is two functions: `paint` decides what a square looks
like, and `split` paints four quarters by calling `paint`. Bend doesn't
allow two functions that call each other, because it couldn't prove they
finish. So all recursion lives in one function, `paint`.

That ran into the `match` rule. `paint` needs to branch on "what does this
square look like", which is a computed value. The way out is to make the
caller compute it and pass it in as the parameter `look`:

```python
def paint(d: Nat, +x: U32, +y: U32, +s: U32, +rs: +List<Rect>, look: Look) ->
  Image:
```

Each recursive call works out `classify(...)` for its quarter and passes
it along. `paint` then matches on `look`, which is a parameter.

#### Termination with several parameters

`paint` recurses on `p`, which is smaller than `d`. Bend reads the
arguments of a recursive call left to right. Each one must be unchanged
until it reaches one that got smaller, and after that the rest may be
anything. Here `d` is first and gets smaller (`p`), so `x`, `y`, `s`, `rs`
and `look` are free to change. That's why the shrinking parameter goes
first.

#### Passing a `def` with `+` parameters to `App`

`view` uses its state `t` twice, so it's `def view(+t: U32)`. Passing it
directly as `~App{view, tick}` failed:

```
- expected : @_:U32 -> Sigma<&1, &1, U32, _ => Image>
- observed : @+t:U32 -> Sigma<&1, &1, U32, _ => Image>
```

The `+` is part of the function's type. `App` expects a function that takes
a use-once `U32`, and `view` asks for a copyable one, so the types differ.
(`Sigma<...>` is how the checker spells a pair type.) Wrapping it in a
lambda, `~App{+t => view(t), tick}`, works. That's the same `+s => ...`
form step 1 used.

### Reading the program

- `touches(r, x, y, s)`: does rectangle `r` overlap the `s` x `s` square
  at `(x, y)`? Two ranges overlap when each starts before the other ends.
- `covers(r, x, y, s)`: does `r` contain the whole square?
- `touching(rs, x, y, s)`: the rectangles in `rs` that touch the square,
  in order. It's a hand-written filter. `Base` has `List.filter`, but its
  test function is a `~` template, so the test can't use the local `x`,
  `y` and `s`.
- `classify(rs, x, y, s)`: given only touching rectangles, is the square
  `Solid` or `Mixed`? With none, it's background. If the first (topmost)
  one covers the square, it's that color. Otherwise it's mixed.
- `paint(d, x, y, s, rs, look)`: the image of the square of side `s = 2^d`.
  A `Solid` square becomes a `Pix`, and a `Mixed` square splits into four.
  At `d = 0` (one pixel), a `Mixed` square can't happen, since a
  rectangle touching a single pixel covers it, but `match` must handle
  every case, so it paints background.
- `scene(t)`: the rectangles for frame `t`. The blue one sits at
  `x = t % 256`, so it slides right and wraps around.
- `view(t)`: builds the scene and paints the full 256 x 256 square, depth
  `8n` because 2^8 = 256.
- `tick`: the same as step 1, except the state is now a frame counter that
  goes up by one each frame.

### What broke

In order, as the checker reported them:

1. `r (consumed more than once)` in `touching` and `classify`. Fixed with
   `case Con{+r, rest}:`.
2. `expected : a filled definition ...` for `Rect.color`. It was below its
   caller. Moved it up.
3. `p (consumed more than once)` in `paint`. Fixed with `case 1n+(+p):`.
4. `view` didn't fit `App`'s `view` field because of `+t`. Wrapped it in
   `+t => view(t)`.
5. While cleaning up unneeded `+` markers I removed the one on `s` in
   `touches` and got `s (consumed more than once)`. It's used twice, in
   `x + s` and `y + s`. Put it back.

## Step 3: the player's ship and the first law (`step03_ship.bend`)

Goal: a ship at the bottom of the screen that moves while ← or → is held
and never leaves the screen. This step also adds the project's first law,
a claim about the code that Bend proves.

```sh
bend step03_ship.bend -o ship && ./ship
bend PROOF.bend          # must print ALL PROOFS CHECK
```

Status: the code checks, the law is proven, and a screenshot shows the
ship and the ground line. I haven't seen the ship move yet. My attempt to
send arrow keys from a script went to the wrong window (see "What broke"),
so moving the ship by hand is still untested.

### Files changed

`LAWS.bend` can only import files sitting next to it, so the step files
moved from `steps/` to the repo root and were renamed:

- `steps/01_hello.bend` became `step01_hello.bend`
- `steps/02_rects.bend` became `step02_rects.bend`
- new: `render.bend`, `step03_ship.bend`, `LAWS.bend`, `PROOF.bend`

### Modules

The renderer from step 2 now lives in its own file, `render.bend`, with
no `main`. Step 3 imports it:

```python
import ./render.bend as R
```

`R` is a local nickname. Everything defined in `render.bend` is reachable
through it: functions (`R.draw(...)`), types (`List<R.Rect>`) and
constructors (`R.Rect{0, 236, 256, 2, green()}`). Without the prefix,
`Rect{...}` fails with `expected : a declared constructor (lib.Box
declares lib.Box)` (checked, in a test where the module was called
`lib`).

Two rules about import paths, both found the hard way:

- No directories. `import ./steps/step03_ship.bend` fails with
  `expected : an import path of plain names (letters, digits, _ and -)`.
- The name must start with a letter. `import ./03_ship.bend` fails with
  the same message, and `import ./s03_ship.bend` works (checked).

### The game state

```python
type Game is Data:
  Game{x: U32, left: Bool, right: Bool}
```

`x` is the ship's left edge. `left` and `right` record whether those
arrow keys are held down right now.

Why remember held keys instead of moving on each key event? A `Key` event
arrives once when a key goes down (`down` is `True{}`) and once when it
comes up (`False{}`). Moving only on events would give one 2-pixel jump
per press. Remembering "held" and moving every frame gives smooth
movement. `tick` updates the flags from the events:

```python
case Con{Key{63234, down}, rest}:     # Left arrow, pressed or released
  tick(rest, set_left(g, down))
```

and when the event list runs out, it moves the ship one frame:
`Some{step(g)}`.

#### Changing one field means building a new value

Values in Bend never change. To "set" a field, `set_left` takes the game
apart with `match` and builds a new `Game` with one field replaced:

```python
def set_left(g: Game, held: Bool) -> Game:
  match g:
    case Game{x, left, right}:
      Game{x, held, right}
```

The old `left` is dropped, which the use-once rule allows.

### Moving without wrapping around

`U32` arithmetic wraps: `0 - 2` is `4294967294`, a huge number. A ship at
x = 0 moving left would jump off the right side. So moving left first asks
whether there's room:

```python
def go_left(held: Bool, +x: U32) -> U32:
  match held:
    case True{}:
      left_by((speed() <= x : U32), x)   # room to move?
    case False{}:
      x
```

`left_by` subtracts if there's room and returns `0` if not. Moving right
can go past the edge, so after moving, `clamp` pulls `x` back to at most
`max_x() = 240`, which is 256 minus the 16-pixel ship width:

```python
def pick_x(fits: Bool, x: U32) -> U32:
  match fits:
    case True{}:
      x
    case False{}:
      max_x()

def clamp(+x: U32) -> U32:
  pick_x((x <= max_x() : U32), x)

def step(g: Game) -> Game:
  match g:
    case Game{x, +left, +right}:
      Game{clamp(go_right(right, go_left(left, x))), left, right}
```

`left` and `right` are used twice in `step`, once to move and once kept in
the new state, hence `+left` and `+right`.

### Laws and proofs

A law is a claim that must hold for every possible input. You write the
claim, and Bend refuses the project until someone supplies a proof. By
convention the claims live in `LAWS.bend`, written by the human, and the
proofs in `PROOF.bend`. You approved this law's wording before I wrote it.

`LAWS.bend`:

```python
import Base
import ./step03_ship.bend as Ship

law ship_on_screen:
  for g: Ship.Game
  {U32.is_le(Ship.Game.x(Ship.step(g)), Ship.max_x()) == True{} : Bool}
```

Reading it piece by piece:

- `law ship_on_screen:` names the claim.
- `for g: Ship.Game` means "for every possible game state `g`", including
  states the game never reaches, such as `x = 4000000000`.
- `{a == b : T}` is an equality claim: `a` and `b` are the same value of
  type `T`. Here `a` is "after one frame, is the ship's x at most 240?"
  and `b` is `True{}`.

The left edge needs no law, because a `U32` can't be negative.

A proof is a `def` whose return type is the claim. Bend has no special
proof language. If the def type-checks, the claim holds. The simplest
proof is `{==}`, which means "both sides compute to the same value". It
works when Bend can just evaluate the claim, for example
`{U32.is_le(240, 240) == True{} : Bool}`.

`PROOF.bend` imports the laws and fills in the law with a def named
`Laws.ship_on_screen`:

```python
def clamp_ok(-y: U32, b: Bool, e: {U32.is_le(y, Ship.max_x()) == b : Bool}) ->
  {U32.is_le(Ship.pick_x(b, y), Ship.max_x()) == True{} : Bool}:
  match b:
    case True{}:
      e
    case False{}:
      {==}

def Laws.ship_on_screen(g):
  match g:
    case Ship.Game{x, left, right}:
      clamp_ok(Ship.go_right(right, Ship.go_left(left, x)),
        U32.is_le(Ship.go_right(right, Ship.go_left(left, x)), Ship.max_x()),
        {==})
```

How the proof works:

1. `Laws.ship_on_screen(g)` matches on `g`. Inside the case, Bend knows
   `g` is `Game{x, left, right}`, so `step(g)` unfolds into
   `Game{clamp(new_x), left, right}` and the claim becomes "is
   `clamp(new_x)` at most 240?". (`new_x` is short here for
   `go_right(right, go_left(left, x))`.)
2. `clamp(new_x)` unfolds into `pick_x(is_le(new_x, 240), new_x)`. Bend
   can't evaluate `is_le(new_x, 240)`, because `new_x` is unknown. That's
   where `clamp_ok` comes in.
3. `clamp_ok` takes the comparison result as a parameter `b`, plus `e`, a
   proof that `b` really is that result. It then matches on `b`, which is
   allowed because `b` is a parameter:
   - If `b` is `True{}`, `pick_x` returns `y` unchanged, and the goal is
     "`is_le(y, 240)` is `True{}`". That's exactly what `e` says now that
     `b` is `True{}`, so `e` is the proof.
   - If `b` is `False{}`, `pick_x` returns `240`, and the goal is
     "`is_le(240, 240)` is `True{}`". Bend evaluates that, so `{==}` proves
     it.
4. The caller passes `b = is_le(new_x, 240)` and `e = {==}`, which proves
   "this value equals itself".

The `-y` is erased: the proof only mentions `y` in types, so the compiled
program drops it.

This trick of passing a computed `Bool` to a helper along with a proof of
what it equals is how you reason about an `if` in Bend. It's the same move
as `keep` and `solid_if` in step 2, plus a proof of what was decided.

#### Checking that the proof means something

A proof that passes on the first try deserves suspicion. I copied the
files to `/tmp`, took `clamp` out of `step`, and ran `bend PROOF.bend`
there. It failed, and the error shows the unclamped position the law
caught:

```
- expected : {Cmp.is_le(U32.cmp(Ship.go_right(right, Ship.go_left(left, x)), 240)) == True{} : Bool}
```

So the law depends on `clamp`, as it should.

`bend PROOF.bend --verdict` re-checks proofs with a second, smaller checker
written in Lean. It needs a Lean 4 toolchain (`elan`), which isn't
installed here, so I skipped it.

### What broke

1. `import ./steps/03_ship.bend` failed: no directories in import paths.
   Moved the files to the repo root.
2. `import ./03_ship.bend` failed: a module name must start with a letter.
   Renamed the steps to `stepNN_*.bend`.
3. Testing input with a script went wrong. I used `wtype` to send arrow
   keys to the game window, after asking Hyprland to focus it. The focus
   command used syntax this Hyprland config no longer accepts. It failed
   silently, and the keys, plus one typed `a`, went to the window that had
   focus, an editor. I stopped sending keys from scripts. Movement still
   needs a manual test.

The step 3 code and the proof both passed on the first check, so there are
no checker errors to report this time.

## Step 4: shooting (`step04_shoot.bend`, `bullets.bend`)

Goal: Space fires a bullet from the ship's nose. Bullets fly up and are
removed when they leave the screen. Like the arcade game, only one bullet
can be in flight at a time.

```sh
bend step04_shoot.bend -o shoot && ./shoot   # ← → move, Space fires
bend PROOF.bend
```

Status: everything checks, both laws are proven, and the game opens and
draws. I didn't press keys from a script this time (see step 3), so I
tested the bullet logic by evaluating it directly instead. The next
section shows how.

### Building on earlier steps: a struct inside a struct

Step 4 doesn't copy the ship code. It imports step 3 and puts step 3's
whole state inside its own:

```python
import ./step03_ship.bend as Ship
import ./bullets.bend as B

type Game is Data:
  Game{ship: Ship.Game, bullets: +List<B.Bullet>}
```

A field can hold any type, including another struct. To change the ship,
step 4 takes `Game` apart and hands the ship to step 3's functions:

```python
def set_left(g: Game, held: Bool) -> Game:
  match g:
    case Game{s, bs}:
      Game{Ship.set_left(s, held), bs}
```

So the ship law from step 3 still covers the ship in step 4, because step
4 moves it with the same `Ship.step`.

Why `+List<B.Bullet>` in the field? `Game` is declared `is Data`
(copyable), so every field must be copyable too. A plain `List<B.Bullet>`
is a use-once list (see step 2), and `+List<...>` makes it copyable.

### The bullets module

```python
type Bullet is Data:
  Bullet{x: U32, y: U32}

def up(b: Bullet) -> Bullet:
  match b:
    case Bullet{x, y}:
      Bullet{x, (y - speed() : U32)}

def on_screen(b: Bullet) -> Bool:
  match b:
    case Bullet{x, y}:
      (y < 256 : U32)
```

This uses `U32` wrap-around on purpose. A bullet at `y = 2` moving up by 4
gets `y = 4294967294`, which fails `y < 256`. So "flew off the top" and
"is off screen" are the same test, and there's no special case for the
top edge.

`move` moves every bullet and drops the ones that left. It's a map and a
filter in one pass:

```python
def place(+b: Bullet, rest: +List<Bullet>) -> +List<Bullet>:
  keep(on_screen(b), b, rest)

def move(bs: +List<Bullet>) -> +List<Bullet>:
  match bs:
    case Nil{}:
      Nil{}
    case Con{b, rest}:
      place(up(b), move(rest))
```

`place` exists so the moved bullet `up(b)` gets a name. It's needed twice,
once for the test and once to keep it, and a parameter can be marked `+`
where a computed value can't.

### Patterns inside patterns

```python
case Con{B.Bullet{x, y}, more}:
  R.Rect{x, y, 2, 6, white()} <> bullet_rects(more, rest)
```

One pattern opens the list cell and the bullet inside it at the same time.
Constructors from another module keep their prefix in patterns too:
`B.Bullet{x, y}`.

### Testing without a window: a `main` that returns a value

From the guide: when `main` returns a plain value instead of `IO`, `bend
file.bend` computes it and prints it. That makes a quick test bench. In a
scratch copy I ran:

```python
def main() -> Pair(+List<B.Bullet>, +List<B.Bullet>):
  (S.Game.bullets(S.step(S.fire(S.fire(S.Game{Ship.Game{120, False{}, False{}}, []})))),
   B.move([B.Bullet{10, 2}, B.Bullet{20, 100}]))
```

and got

```
([bullets.Bullet{127, 204}], [bullets.Bullet{20, 96}])
```

- Firing twice gave one bullet, so the one-at-a-time rule works. It starts
  at the ship's nose, x = 120 + 7, y = 208, and one frame later it's at
  y = 204.
- The bullet at y = 2 was removed, and the one at y = 100 moved to 96.

(`S.Game.bullets` is a field reader I added only in the scratch copy.)

### The second law

`LAWS.bend` gets a new claim:

```python
law bullets_on_screen:
  for bs: +List<B.Bullet>
  {B.all_on_screen(B.move(bs)) == True{} : Bool}
```

"For every list of bullets, after one frame, every bullet left is on
screen." `all_on_screen` is a plain function that checks each bullet with
`on_screen` and combines the answers with `&&`.

The proposal was "bullets only move upward, and a bullet that leaves the
top is removed". This law states the second half. The first half would
mean proving facts about `U32` subtraction, and a `U32` in Bend is 32
individual bits (`bend base U32` shows `U32{data: Word(32n)}`), so that
proof would be long. "Moves upward" is also just what `up` says, so a law
restating it would prove little.

### The proof: induction and rewriting

```python
def keep_ok(
  -m: B.Bullet, -rest: +List<B.Bullet>,
  h: {B.all_on_screen(rest) == True{} : Bool},
  b: Bool, e: {B.on_screen(m) == b : Bool}
) -> {B.all_on_screen(B.keep(b, m, rest)) == True{} : Bool}:
  match b:
    case True{}:
      %Equal.sym(Bool, B.on_screen(m), True{}, e) :
        {Bool.and(_, B.all_on_screen(rest)) == True{} : Bool}
      h
    case False{}:
      h

def Laws.bullets_on_screen(bs):
  match bs:
    case Nil{}:
      {==}
    case Con{b, rest}:
      keep_ok(B.up(b), B.move(rest), Laws.bullets_on_screen(rest),
        B.on_screen(B.up(b)), {==})
```

New ideas:

**Proof by induction is recursion.** `Laws.bullets_on_screen` calls itself
on `rest`. That call is a proof that the law holds for the shorter list,
which is the "induction hypothesis" from math class. The empty list is the
base case: `all_on_screen(move(Nil{}))` computes to `True{}`, so `{==}`.

**A proof can take proofs as parameters.** `h` is a proof that the rest of
the list is fine. `e` is a proof of what the `Bool` `b` equals, the same
trick as `clamp_ok` in step 3.

**Erased parameters (`-m`, `-rest`).** These only appear inside types, so
`-` tells Bend to drop them from the compiled program.

**Case `False{}`: the bullet was dropped.** `keep(False{}, m, rest)`
computes to `rest`, so the goal is "`rest` is all on screen". That's `h`.

**Case `True{}`: the bullet was kept.** `keep(True{}, m, rest)` computes to
`m <> rest`, and `all_on_screen` of that computes to
`Bool.and(on_screen(m), all_on_screen(rest))`. Bend can't compute
`on_screen(m)` because `m` is unknown. But `e` says
`on_screen(m) == True{}`, so the proof swaps that in. That's a rewrite:

```python
%proof : P
next
```

- `proof` must prove an equality, `{a == b : T}`.
- `P` is the current goal written out, with `_` where `b` appears.
- After the line, the goal is `P` with `a` in place of `_`. `next`
  proves that.

We have `e : {on_screen(m) == True{}}`, but we want to replace
`on_screen(m)` with `True{}`, the other direction. `Equal.sym` from `Base`
flips an equality: `Equal.sym(Bool, on_screen(m), True{}, e)` proves
`{True{} == on_screen(m)}`. Then `P` marks `on_screen(m)` with `_`, and the
goal becomes `Bool.and(True{}, all_on_screen(rest)) == True{}`.
`Bool.and(True{}, x)` computes to `x` (`bend base Bool.and`), so what's
left is `all_on_screen(rest) == True{}`, which is `h`.

**Checking the proof can fail.** As in step 3, I broke the code in a
scratch copy, making `place` keep every bullet, and `bend PROOF.bend`
failed in `Laws.bullets_on_screen`. The proof does depend on bullets being
removed.

### What broke

Nothing this time. The code, the law and the proof all checked on the
first run. The rules from steps 2 and 3 (`+` on reused fields, helpers to
`match` on computed values, defs above their callers) were enough.

## Step 5: the invader fleet (`step05_fleet.bend`, `fleet.bend`)

Goal: a block of 5 rows x 8 invaders that marches sideways, one pixel per
frame. When it reaches an edge, it drops 8 pixels and turns around.
Bullets pass through invaders for now; step 6 adds hits.

```sh
bend step05_fleet.bend -o fleet && ./fleet
bend PROOF.bend
```

Status: everything checks, all three laws are proven, and a screenshot
shows the fleet over the ship. I checked the turning by evaluating the
fleet directly (below).

### The fleet is only a position

The fleet doesn't store 40 invaders. It stores the block's top-left
corner and its direction:

```python
type Fleet is Data:
  Fleet{x: U32, y: U32, right: Bool}
```

Drawing works out each invader's position from the corner: column `c` is
at `x + 20 * c`, row `r` at `y + 16 * r`. Step 6 will add which invaders
are still alive.

### Moving and turning

```python
def next_x(right: Bool, x: U32) -> U32:
  match right:
    case True{}:
      (x + 1 : U32)
    case False{}:
      (x - 1 : U32)

def go_or_turn(fits: Bool, nx: U32, y: U32, +right: Bool) -> Fleet:
  match fits:
    case True{}:
      Fleet{nx, y, right}
    case False{}:
      Fleet{edge(right), (y + drop() : U32), Bool.not(right)}

def advance(+nx: U32, y: U32, right: Bool) -> Fleet:
  go_or_turn((nx <= max_x() : U32), nx, y, right)
```

This uses the wrap-around trick from step 4. Moving left from `x = 0`
gives `4294967295`, which fails `nx <= 104` just like moving right past
104 does. One test covers both edges. When the next position doesn't fit,
the fleet goes to the edge it was heading for (`edge(right)` is 104 or
0), drops, and turns around. `Bool.not` from `Base` flips a `Bool`.

`max_x()` is 104 because the block is `7 * 20 + 12 = 152` pixels wide,
and `256 - 152 = 104`.

Checked by evaluating a value `main` in a scratch copy, with `run(n, f)`
stepping the fleet `n` times:

| Start                    | Frames | Result              |
|--------------------------|--------|---------------------|
| `Fleet{0, 24, True{}}`   | 104    | `Fleet{104, 24, True{}}`, at the right edge |
| `Fleet{0, 24, True{}}`   | 105    | `Fleet{104, 32, False{}}`, dropped and turned |
| `Fleet{0, 40, False{}}`  | 1      | `Fleet{0, 48, True{}}`, the left edge turns too |

### Drawing a grid with two counting loops

```python
def row_rects(n: Nat, +x: U32, +y: U32, rest: +List<R.Rect>) -> +List<R.Rect>:
  match n:
    case 0n:
      rest
    case 1n+p:
      R.Rect{x, y, F.inv_w(), F.inv_h(), purple()}
        <> row_rects(p, (x + F.gap_x() : U32), y, rest)
```

This is a counting loop. `n` is a `Nat`, and `case 1n+p:` matches any
number at least 1, naming the number one less `p`. So `row_rects(8n, ...)`
runs 8 times, moving right by `gap_x()` each time. `grid_rects` does the
same for rows, calling `row_rects` once per row.

Both functions take `rest`, a list to put their rectangles in front of.
That way the pieces chain together, fleet then bullets then ship, with no
list appending.

### Reusing step 4

```python
type Game is Data:
  Game{play: S.Game, fleet: F.Fleet}
```

Same pattern as step 4: step 5's state wraps step 4's state and adds the
fleet. Each handler opens `Game`, passes `play` to step 4's function, and
leaves the fleet alone, or the other way round.

### The third law

```python
law fleet_on_screen:
  for f: F.Fleet
  {U32.is_le(F.Fleet.x(F.step(f)), F.max_x()) == True{} : Bool}
```

"For every fleet, after one frame, the block's left edge is at most 104",
so the whole block is on screen. The left side needs nothing, because a
`U32` is never negative.

The proof has the same shape as the ship's in step 3:

```python
def turn_ok(
  -nx: U32, -y: U32,
  b: Bool, e: {U32.is_le(nx, F.max_x()) == b : Bool}, right: Bool
) -> {U32.is_le(F.Fleet.x(F.go_or_turn(b, nx, y, right)), F.max_x()) == True{} : Bool}:
  match b:
    case True{}:
      e
    case False{}:
      match right:
        case True{}:
          {==}
        case False{}:
          {==}
```

- If `nx` fits, the fleet moves there, and `e` says it fits.
- If it doesn't, the fleet goes to `edge(right)`. Bend can't compute that
  while `right` is unknown, so the proof matches on `right` as well. Then
  it's `is_le(104, 104)` or `is_le(0, 104)`, and both compute to `True{}`.

Breaking the code in a scratch copy, by turning around at `nx` instead of
at the edge, made the proof fail as expected.

### What broke

1. `expected : a declared constructor (step03_ship.Game declares
   step03_ship.Game)` for `Ship.Game{...}`. Step 5 used the `Ship` alias
   without importing step 3. An alias only exists in the file that
   declares it, so importing step 4, which imports step 3, isn't enough.
   Added `import ./step03_ship.bend as Ship`.
2. In the proof, `match right:` inside the `False{}` case failed:

   ```
   'right' can't be matched in this position (it is matched after a local
   statement or after a match on a later binder, ...)
   ```

   **Matches must follow parameter order.** `right` was declared before
   `b`, so after matching `b`, Bend won't match `right`. Moving `right` to
   the end of `turn_ok`'s parameters fixed it.
3. Not a checker error, but worth knowing: my first evaluation of the
   fleet ran in the scratch copy that I'd broken on purpose, and printed
   `Fleet{105, ...}` and a wrapped `x`. Testing against the real files gave
   the correct table above.

## Step 6: hits, score, win and lose (`step06_hits.bend`, `hits.bend`)

Goal: a bullet that hits an invader destroys both and scores 10 points.
Shooting every invader wins. An invader reaching the ship's row loses.
Either way the game freezes, and a bar across the top turns green (won)
or red (lost). The score can't be seen yet; step 7 adds text.

```sh
bend step06_hits.bend -o hits && ./hits
bend PROOF.bend
```

Status: everything checks, all four laws are proven, the game draws, and
evaluating the logic directly gave the expected results (below).

### Which invaders are alive

Step 5's fleet was only a corner position. Step 6 adds a list of the
invaders still alive, each one by column and row:

```python
type Inv is Data:
  Inv{c: U32, r: U32}
```

An invader's screen position is the fleet corner plus its column and row
times the gaps. Killing an invader removes it from the list.
`H.all_invaders()` builds the starting 40 with two counting loops, like
the drawing in step 5. `U32.from_nat` turns the `Nat` counter into a
`U32`.

### Finding hits

`strike(invs, b, fx, fy)` checks one bullet against every invader and
returns a `Strike`: how many it hit, and the invaders left. It removes
every invader the bullet overlaps. The gaps between invaders (8 pixels)
are wider than a bullet (2 x 6), so that's at most one.

`resolve` does that for every bullet and collects a `Hits`: points scored,
bullets still flying, invaders still alive. A bullet that hit something
scores 10 and disappears. One that didn't keeps flying.

### A destructuring let is a `match` too

The natural way to write `resolve` is:

```python
Strike{n, left} = strike(invs, b, fx, fy)
settle(n, b, resolve(rest, left, fx, fy))
```

That fails:

```
- message  : a parameter or field scrutinee (a match cannot scrutinize a computed value: give it its own def)
```

`Strike{n, left} = ...` takes the value apart, which is a `match`, so the
step 2 rule applies. A helper function won't work here either, because
the helper would have to call `resolve` back, and Bend doesn't allow two
functions that call each other.

The fix is the one `paint` used in step 2: the caller computes the value
and passes it in as a parameter. `resolve` takes the first bullet's strike
as `s`, and each recursive call computes the strike for the next bullet:

```python
def resolve(bs: +List<B.Bullet>, s: Strike, +fx: U32, +fy: U32) -> Hits:
  match bs:
    case Nil{}:
      match s:
        case Strike{n, left}:
          Hits{0n, Nil{}, left}
    case Con{+b, +rest}:
      match s:
        case Strike{n, left}:
          settle(n, b, resolve(rest, first_strike(rest, left, fx, fy), fx, fy))
```

This is a general pattern: **when a recursive function needs a computed
value taken apart, make it a parameter and have each call compute the
next one.**

### Game phases

```python
type Phase is Data:
  Playing{}
  Won{}
  Lost{}
```

A type whose constructors have no fields works as an enum. `step` matches
on the phase and only moves things while `Playing{}`. After the hits are
worked out, `pick_phase` decides the next phase: `Lost{}` if any invader
is low enough, otherwise `Won{}` if none are left, otherwise `Playing{}`.

`||` is "or" on `Bool`, like `&&` for "and".

### Checking the logic

A value `main` in a scratch copy printed:

```
((10n, 0n, 39n), (0n, 1n, 40n), 10n, step06_hits.Playing{}, 39n)
```

1. A bullet on invader (0,0) of a fleet at (0,24): 10 points, no bullets
   left, 39 invaders left.
2. A bullet at x = 15, in the gap between the first two columns: no
   points, the bullet keeps flying, 40 invaders.
3. Fire once from the start position and play 60 frames: score 10, still
   playing, 39 invaders. The shot hit something.

`List.length(&2, H.Inv, iv)` counts a list. The `&2` says the list holds
copyable values, the same thing `+` means in `+List<...>`.

### The fourth law: the score never goes down

The score is a `Nat` rather than a `U32`. A `U32` score wraps around, so
"never goes down" would be false: 4294967290 + 10 is 4.

```python
law score_never_drops:
  for g: G.Game
  exs d: Nat
  {G.Game.score(G.step(g)) == Nat.add(d, G.Game.score(g)) : Nat}
```

New piece: **`exs d: Nat`** means "there exists a `d`". The law says: for
every game, there's some natural number `d` such that the new score is the
old score plus `d`. A `Nat` is never negative, so the score never drops.
The proof has to supply `d`, which is called a witness, and returns it in
a pair with the proof: `(d, proof)`.

A helper proof that returns a witness writes its return type as
`&d: Nat -> {...}`. That's a dependent pair: a `Nat` called `d`, and a
proof whose claim mentions `d`.

```python
def settle_ok(
  h: H.Hits, -s: Ship.Game, -fx: U32, -fy: U32, -right: Bool, -score: Nat
) -> &d: Nat -> {G.Game.score(G.settle(h, s, fx, fy, right, score)) == Nat.add(d, score) : Nat}:
  match h:
    case H.Hits{points, bs, iv}:
      (points, {==})

def Laws.score_never_drops(g):
  match g:
    case G.Game{phase, p, f, iv, score}:
      match phase:
        case G.Playing{}:
          advance_ok(S.step(p), F.step(f), iv, score)
        case G.Won{}:
          (0n, {==})
        case G.Lost{}:
          (0n, {==})
```

- **Won or lost:** the score is unchanged, so `d = 0n`. The claim is
  `score == Nat.add(0n, score)`, and `Nat.add` computes `Nat.add(0n, b)`
  to `b` (`bend base Nat.add`), so `{==}` works. That's why the game code
  writes `Nat.add(points, score)` with the points first. Written the other
  way round, `Nat.add(score, 0n)` doesn't compute when `score` is unknown,
  and the proof would need an extra lemma like `add_zero` in the guide.
- **Playing:** `d` is this frame's points. Those come from a `Hits` value
  that Bend can't compute in general, so the same parameter trick
  applies. `advance_ok` takes the ship and fleet as parameters and opens
  them, then `settle_ok` takes the `Hits` as a parameter and opens it.
  Once it's open, `points` is the witness, and the claim computes to
  `Nat.add(points, score) == Nat.add(points, score)`.

**Checking that the proof can fail:** in a scratch copy, a won game took
1 point off (`Nat.sub(score, 1n)`), and the proof failed with
`expected : Nat.sub(score, 1n)`, `observed : score`.

### What broke

1. The destructuring let in `resolve` (above). Fixed by passing the strike
   in as a parameter.
2. `p (consumed more than once)` in `row_of`. The column counter is used
   for the column number and for the next call. Fixed with `1n+(+p)`.
3. `PROOF.bend` used `S.Game{...}` without importing step 4:
   `a declared constructor (unknown: S.Game)`. Same lesson as step 5:
   every file imports what it names.
4. `expected : -iv`, `observed : iv` in `advance_ok`. I'd marked `iv` as
   erased, but it goes into `H.hits(...)`, which `settle_ok` opens with
   `match` at run time. **An erased value can't feed anything that runs.**
   Made it a normal parameter.
5. My first broken test copy used `Nat.pred`, which doesn't exist
   (`expected : a defined name`). `Nat.sub` does.

## Step 7: score on screen and restart (`step07_score.bend`, `font.bend`)

Goal: show the score, and let R start a new game. This finishes the game
loop: play, win or lose, restart.

```sh
bend step07_score.bend -o invaders && ./invaders
bend PROOF.bend
```

Status: everything checks, all five laws are proven, and a screenshot of a
scratch copy, started with the score set to 1234567890, shows all ten
digits drawn correctly. I didn't test pressing R (no scripted keys); the
law below covers what restarting does.

### A font made of rectangles

The renderer only draws rectangles, so the font does too. Each digit is a
grid of 3 x 5 cells, and each lit cell is a 2 x 2 rectangle. A glyph is
stored as a 15-bit number, read row by row from the top-left:

```
0 = 111     1 = 010
    101         110
    101         010
    101         010
    111         111

0 = 111101101101111 in binary = 31599
```

`glyphs()` is the list of all ten. `glyph(code)` picks one by character
code: `'0'` is 48, so the digit is `code - 48`. `List.get` returns a
`Maybe`, `None{}` when the index is past the end, so `or_blank` turns that
into an empty glyph. A character that isn't a digit wraps around to a huge
index and draws as a blank.

`cells(15n, g, x, y, color, rest)` counts down through the 15 bits. For bit
`p` it computes the cell's index `i = 14 - p`, then its column `i % 3` and
row `i / 3`. If the bit is set, it adds a rectangle there:

```python
put(U32.is_eq(((g >> p : U32) .&. 1 : U32), 1), R.Rect{...}, cells(p, ...))
```

- `(g >> p : U32)` shifts `g` right by `p`. The shift amount is a `Nat`,
  which is handy, because `p` is already the `Nat` loop counter.
- `.&. 1` keeps the lowest bit.
- `U32.is_eq(a, b)` tests equality. `==` only exists inside law types,
  never as an operator in code.

`text(s, x, y, color, rest)` walks a `String`. A string is a list of
characters, `SCon{head, tail}` or `SNil{}`, and each character is
`Chr{code}`. So `case SCon{Chr{code}, tail}:` opens the first character
and its code in one pattern. Each character goes 8 pixels right of the
one before.

The score is a `Nat`, and `Nat.show` turns it into a `String`.

### Where the score goes

The plan was the top-left corner, but the screenshots show that the
desktop's top bar overlaps the top of this window. Text at y = 10 was
hidden, and so is step 6's win/lose bar at y = 0..6. So the score sits
under the ground line at y = 242. It also takes over the bar's job: it's
white while playing, green after a win and red after a loss.

### Restart

```python
def restart(g: G.Game) -> G.Game:
  G.Game.new()
```

Pressing R (key code 114, a lowercase `r`) replaces the game with a new
one. The old game `g` is never used, which the use-once rule allows. R
works in any phase, mid-game too.

Step 7 doesn't define a new `Game` type. It reuses step 6's and only adds
drawing and the R key, so its `tick` calls step 6's `G.step`, `G.fire` and
the rest.

### The fifth law

```python
law restart_starts_over:
  for g: G.Game
  {Top.restart(g) == G.Game.new() : G.Game}
```

"Whatever state the game was in, R gives exactly the starting game", so no
score, position or invader carries over.

The proof is one line:

```python
def Laws.restart_starts_over(g):
  {==}
```

Both sides compute to the same value, because `restart` ignores `g`. A
law this easy can still catch bugs, because it rules out future edits. To
check, a scratch copy made `restart` keep the old score, and the proof
failed. The error printed the whole computed game, all 40 invaders
included, next to the unequal `Top.restart(g)`.

(`Top` is the alias for `step07_score.bend`, because `S` was already
taken by step 4.)

### What broke

1. The top bar hid the score (above). Moved it to the bottom.
2. My first version of the broken test copy wasn't valid code: it matched
   on `G.Game.new()`, a computed value. The step 2 rule still applies when
   writing deliberate bugs. The second version built the game directly.

## Step 8: invaders shoot back, lives (`step08_lives.bend`)

Goal: invaders drop shots. A shot that hits the ship costs a life. You
start with 3, shown bottom-right, and the game is lost at 0. R restarts
with 3 lives.

```sh
bend step08_lives.bend -o invaders && ./invaders
bend PROOF.bend
```

Status: everything checks, all six laws are proven. A screenshot shows the
shots falling and the lives counter at 2 after a few seconds of standing
still. Evaluating the game directly gave the expected results (below).

### Randomness in a pure language

`tick` could ask the runtime for random numbers through IO, but `step`
is pure, and keeping it pure keeps it provable. So "random" comes from
the frame counter `t`, scrambled:

```python
def pick(t: U32) -> U32:
  (((t * 2654435761 : U32) >> 16n : U32) .&. 63 : U32)
```

Multiplying by a large odd number and keeping some middle bits gives a
number from 0 to 63 that jumps around from one call to the next. Every 32
frames, invader number `pick(t)` in the alive list fires. If fewer
invaders are alive than that number, `List.get` returns `None{}` and
nobody fires. So the fewer invaders are left, the less often they shoot.
I didn't plan that, but it's a reasonable rule. The same frames always
give the same shots, so a game is replayable, which also makes testing
easy.

### Wrapping step 6 again

```python
type Game is Data:
  Game{core: G.Game, shots: +List<Shot>, lives: Nat, clock: U32}
```

Step 8 wraps step 6's game, like each earlier step did. To end the game
at 0 lives, `lose(g)` rebuilds step 6's game with its phase set to
`G.Lost{}`. That freezes it and turns the score red, both of which step 6
and step 7 already handle.

### One `step` with no match on computed values

```python
def step(g: Game) -> Game:
  match g:
    case Game{+core, ss, lives, +t}:
      +next = G.step(core)
      +fallen = move_shots(spawn(t, next, ss))
      +sx = ship_x(next)
      +left = lose_if(playing(core) && any_hit(fallen, sx), lives)
      Game{end_if(is_out(left), next), drop_hits(fallen, sx), left,
        (t + 1 : U32)}
```

Every new field is a plain expression built from the old fields. Nothing
here matches on a computed value; helpers like `ship_x` and `playing` do
their matching on their own parameters. This shape was deliberate. It
makes the proof below short, because Bend can unfold `L.Game.lives(step(g))`
straight to `lose_if(<hit>, lives)` with no lemma for each stage.

`lose_if(hit, lives)` takes one life when hit, and never goes below 0:

```python
def lose_if(hit: Bool, lives: Nat) -> Nat:
  match hit:
    case True{}:
      match lives:
        case 0n:
          0n
        case 1n+p:
          p
    case False{}:
      lives
```

`case 1n+p:` with result `p` is how you subtract one from a `Nat`.

### Checking by evaluation

Running the game with the ship standing still (a value `main` in a
scratch copy, `run(n, g)` steps `n` frames, and each result is lives,
phase, shots in flight):

| Frames | Start lives | Result                  |
|--------|-------------|-------------------------|
| 100    | 3           | `3n, Playing{}, 2n`     |
| 400    | 3           | `2n, Playing{}, 2n`     |
| 1500   | 3           | `1n, Playing{}, 0n`     |
| 400    | 1           | `0n, Lost{}, 2n`        |

The last row shows that losing the last life ends the game. Evaluating
1500 frames this way took about 50 seconds. The checker's evaluator is
slow next to the compiled program, which runs 60 frames a second.

### The sixth law: lives never go up

```python
law lives_never_go_up:
  for g: L.Game
  exs d: Nat
  {L.Game.lives(g) == Nat.add(d, L.Game.lives(L.step(g))) : Nat}
```

The same shape as the score law, turned around: the old lives are the new
lives plus some `d`.

```python
def lose_if_ok(hit: Bool, lives: Nat) ->
  &d: Nat -> {lives == Nat.add(d, L.lose_if(hit, lives)) : Nat}:
  match hit:
    case True{}:
      match lives:
        case 0n:
          (0n, {==})
        case 1n+p:
          (1n, {==})
    case False{}:
      (0n, {==})

def Laws.lives_never_go_up(g):
  match g:
    case L.Game{+core, ss, lives, +t}:
      lose_if_ok(
        L.playing(core) && L.any_hit(L.move_shots(L.spawn(t, G.step(core), ss)),
          L.ship_x(G.step(core))),
        lives)
```

- `lose_if_ok` covers each case of `lose_if`. Hit with `1n+p` lives
  leaves `p`, and `Nat.add(1n, p)` computes to `1n+p`, so `d = 1n`.
  Otherwise nothing changes and `d = 0n`.
- The main proof hands `lose_if_ok` the exact hit expression from `step`.
  Bend infers nothing, so the expression has to be written out again.
  Since `step` uses `core` three times in it, the pattern needs `+core`.

Breaking it in a scratch copy, so that getting hit at 0 lives gave a life
back, made the proof fail (`expected : 0n`, `observed : 1n`).

### What broke

1. My first `tick` used a template helper,
   `def on_core(g: Game, ~f: G.Game -> G.Game)`, to apply a step 6
   function to the inner game. Two rules from step 1 rejected it: `~`
   parameters must come first (`only leading binders take ~`), and the
   lambda I passed, `c => G.set_left(c, down)`, mentions the local `down`,
   which template arguments can't. Plain wrappers (`fire`, `set_left`,
   `set_right`) fixed it.

## Step 9: shields (`step09_shields.bend`, `shields.bend`)

Goal: four arch-shaped shields above the ship. Any bullet or invader shot
that touches a shield block destroys the block and itself, so the shields
wear away from both sides.

```sh
bend step09_shields.bend -o invaders && ./invaders
bend PROOF.bend
```

Status: everything checks, all seven laws are proven, evaluation gave the
expected results, and a screenshot shows the shields chipped by invader
shots after 8 seconds.

### Shields are a list of blocks

```python
type Blk is Data:
  Blk{x: U32, y: U32}
```

Each shield is 6 x 4 blocks of 4 x 4 pixels, minus the two middle blocks
of the bottom row, which make the arch. So it's 22 blocks per shield, 88
in all. `all_blocks()` builds them with the counting-loop pattern from
step 5. `gap(c, r)` picks out the arch's opening, and `put` (Bend's `if`
again) leaves those blocks out.

### One frame of shield damage

After step 8's frame, `settle` does three things with the same old block
list:

- `free_bullets` keeps the bullets that touch no block.
- `free_shots` keeps the invader shots that touch no block.
- `chip(blocks, boxes(bs, ss))` keeps the blocks that no bullet or shot
  touches.

`boxes` turns bullets and shots into one list of `Box{x, y, w, h}`, so
`chip` doesn't care which kind of projectile hit. A bullet is 6 pixels
tall and blocks are 4, so one hit can take out two blocks stacked on top
of each other, which makes the shields wear down chunkily.

`settle` takes step 8's whole game apart (`L.Game`, then `G.Game`, then
`S.Game`) to get at the bullets and shots, and builds it again with the
survivors. Deep, but each layer is the same `match` and rebuild as in
every earlier step.

Checked by evaluation (values in a scratch copy):

| Test                                              | Result |
|---------------------------------------------------|--------|
| number of blocks                                  | 88     |
| blocks after a 2 x 6 box at (21, 185)             | 86, two stacked blocks gone |
| bullets at (21, 185) and (60, 185), after shields | 1, the one between shields |
| lives and blocks after 1500 frames, standing still | 1 life, 74 blocks |

### A termination detail

```python
case Nil{}:
  match ss:
    case Con{s, rest}:
      shot_box(s) <> boxes(Nil{}, rest)
```

Here `boxes` calls itself with the first argument `Nil{}`, which is the
same value it just matched, and the second argument shrinking. Bend
accepted it. Passing an argument unchanged counts as "unchanged" even when
it's written out again as `Nil{}`.

### The seventh law: shields only shrink

```python
law shields_only_shrink:
  for blocks: +List<Sh.Blk>
  for +ps: +List<Sh.Box>
  exs d: Nat
  {Nat.add(List.length(&2, Sh.Blk, Sh.chip(blocks, ps)), d)
    == List.length(&2, Sh.Blk, blocks) : Nat}
```

"For any blocks and any projectiles, the number of blocks after chipping,
plus some `d`, equals the number before." So chipping never adds blocks.
It's stated on `chip` itself, not on the whole game frame, because that's
where blocks get removed.

### The first lemma proven by induction

This proof needs a fact about addition that Bend can't just compute:

```python
def add_succ(a: Nat, -b: Nat) -> {Nat.add(a, 1n+b) == 1n+Nat.add(a, b) : Nat}:
  match a:
    case 0n:
      {==}
    case 1n+p:
      %add_succ(p, b) : {1n+Nat.add(p, 1n+b) == 1n+_ : Nat}
      {==}
```

`a + (1 + b) = 1 + (a + b)`. `Nat.add` only takes its first argument
apart, so when `a` is unknown, `Nat.add(a, 1n+b)` is stuck. The proof is by
induction on `a`:

- `a = 0n`: both sides compute to `1n+b`. `{==}`.
- `a = 1n+p`: the left side computes to `1n+Nat.add(p, 1n+b)`, and the
  right to `1n+1n+Nat.add(p, b)`. The recursive call `add_succ(p, b)` is
  the induction hypothesis: `Nat.add(p, 1n+b) == 1n+Nat.add(p, b)`. The
  rewrite replaces the right-hand `1n+Nat.add(p, b)` (marked `_`) with
  `Nat.add(p, 1n+b)`, and then both sides match.

This is the same shape as `add_zero` in `bend guide`.

### The main proof

Induction on the block list. For each block, `chip` either keeps it or
drops it, and `chip_step` handles both:

```python
match keep:
  case True{}:
    (d, e) = ih
    (d, %e : {1n+Nat.add(List.length(&2, Sh.Blk, Sh.chip(rest, ps)), d) == 1n+_ : Nat}
      {==})
  case False{}:
    (d, e) = ih
    (1n+d, drop_ok(Sh.chip(rest, ps), rest, d, e))
```

- `ih` is the law for the rest of the list: a witness `d` and a proof `e`
  that `kept + d == rest`. `(d, e) = ih` takes the pair apart. That's
  allowed, because `ih` is a parameter.
- **Block kept:** both counts go up by one, so `d` stays the same. The
  goal computes to `1 + (kept + d) == 1 + rest`, and rewriting with `e`
  finishes it.
- **Block dropped:** `kept` stays the same and `rest` goes up by one, so
  the witness is `1n+d`. The goal is `kept + (1 + d) == 1 + rest`. That's
  where `add_succ` comes in, inside `drop_ok`: first turn `kept + (1 + d)`
  into `1 + (kept + d)`, then rewrite with `e`. Two rewrites in a row,
  each on its own line.

**`?goal` as a tool.** I wrote the dropped case as `(1n+d, ?goal)` first.
Bend checked everything else and printed the remaining goal with every
variable in scope, which showed exactly what `drop_ok` had to prove.

**Checking that the proof can fail:** a scratch copy where `put` keeps two
copies of each surviving block failed with `expected : {2n+Nat.add(...)`.

### What broke

1. In my first draft of `gap` I wrote `(c == 2 : U32)`. `==` only exists
   in law types; code uses `U32.is_eq(c, 2)`. I caught it before
   checking.
2. **Erased values can't feed live code, and the rule spreads.** `drop_ok`
   had `-kept`, but `kept` goes into `add_succ`'s first argument, which
   `add_succ` matches on. So `kept` had to be live, then `rest` and `ps` in
   `chip_step` too, since they build `kept`. Each fix revealed the next
   error (`expected : -kept`, then `expected : -ps`).
3. `ps (consumed more than once)` in the main proof. Adding `+` there
   failed with a parse error. A def that fills a law takes its parameter
   quantities from the law. So `LAWS.bend` says `for +ps`, which means the
   same thing, since `ps` is a copyable list anyway.
4. Not a checker error. A screenshot showed score 10 and a missing
   invader, though the test never pressed a key. Evaluating the same 480
   frames gave score 0. The new game window had taken keyboard focus, and
   a real keypress meant for another window reached it. The game logic
   was fine. Windowed tests should be short, or run while not typing.

## Step 10: the fleet speeds up (`step10_speed.bend`)

Goal: the fewer invaders are left, the faster the fleet marches. With all
40 alive it moves 1 pixel per frame, as before. It gets one extra step per
frame at 20 or fewer, another at 8 or fewer, and another at 2 or fewer, so
the last invaders move 4 pixels per frame.

```sh
bend step10_speed.bend -o invaders && ./invaders
bend PROOF.bend
```

Status: everything checks, all eight laws are proven, and evaluation
gave the expected speeds. I didn't take a screenshot, because nothing
new is drawn and new game windows steal keyboard focus (see step 9).

### More steps, not bigger steps

The fleet already knows how to take one step and turn at an edge. So
instead of teaching it bigger steps, a faster fleet just takes several
steps in one frame. `march` in `fleet.bend` repeats `step` n times:

```python
def march(n: Nat, f: Fleet) -> Fleet:
  match n:
    case 0n:
      f
    case 1n+p:
      step(march(p, f))
```

This is the counting pattern from step 2: a `Nat` is either `0n` or
`1n+p`, and each call works on the smaller `p`, so Bend can see it ends.

### How many extra steps

`extra` turns the number of invaders left into a `Nat` of extra steps.
Bend has no `if`, so each threshold is a `Bool` passed to a small helper
that matches on it:

```python
def faster(fast: Bool, n: Nat) -> Nat:
  match fast:
    case True{}:
      1n+n
    case False{}:
      n

def extra(+left: U32) -> Nat:
  faster((left <= 20 : U32),
    faster((left <= 8 : U32), faster((left <= 2 : U32), 0n)))
```

`left` is used three times, so it is marked reusable with `+`.

### Wrapping without a new type

Step 7 used step 6's `Game` type directly instead of wrapping it, because
it only added drawing and a key. Step 10 does the same with step 9's
`W.Game`. Its `step` runs step 9's frame, then `speed_up` opens the nested
game, gives the fleet its extra steps, and puts everything back:

```python
def step(g: W.Game) -> W.Game:
  speed_up(W.step(g))
```

`hurry` only adds steps while the phase is `Playing{}`, so a won or lost
game stays frozen, as in step 6.

### Checking by evaluation

A value-returning `main` in a scratch copy printed:

```
([0n, 1n, 2n, 3n], [40, 10, 40])
```

The first list is `extra` for 40, 20, 8 and 2 invaders. The second is the
invader count of a new game, then the fleet's x after 10 frames: 10 with a
full fleet, and 40 with only one invader left.

### The eighth law: a fast fleet stays on screen

```python
law fast_fleet_on_screen:
  for n: Nat
  for f: F.Fleet
  {U32.is_le(F.Fleet.x(F.march(1n+n, f)), F.max_x()) == True{} : Bool}
```

In plain words: however many steps the fleet takes in one frame, as long
as it is at least one, it ends on screen.

Why "at least one"? `f` is any fleet at all, including one that starts
off screen, such as x = 200. `march(0n, f)` is `f` itself, so with zero
steps the law would be false. Every real frame takes at least one step,
so `1n+n` is the honest statement.

### A proof that uses another law

Every law proven in `PROOF.bend` is also a function, and a proof can call
it. `Laws.fleet_on_screen(g)` returns a proof that `g`'s next step is on
screen, for any fleet `g`. `march(1n+n, f)` computes to
`step(march(n, f))`, which is one step of the fleet `march(n, f)`. So the
whole proof is one call:

```python
def Laws.fast_fleet_on_screen(n, f):
  Laws.fleet_on_screen(F.march(n, f))
```

No induction is needed. Where `march(n, f)` ended up doesn't matter,
because the last step alone puts the fleet back on screen.

**Checking that the proof can fail:** in a scratch copy where the law says
`F.march(n, f)` (zero steps allowed), Bend reported:

```
- expected : {Cmp.is_le(U32.cmp(F.Fleet.x(F.march(n, f)), 104)) == True{} : Bool}
- observed : {Cmp.is_le(U32.cmp(F.Fleet.x(F.step(F.march(n, f))), 104)) == True{} : Bool}
```

The proof shows the version with a last `step`, and the law no longer asks
for one.

### What broke

1. My first test `main` returned `List<U32>` and wrapped `extra` in
   `Nat.to_u32`, which doesn't exist: `expected : a defined name`,
   `observed : Nat.to_u32`. Returning a pair of a `List<Nat>`
   and a `List<U32>` printed both without converting.

## Where the project stands

Eight laws, all proven by `bend PROOF.bend`:

| Law                    | Says                                              |
|------------------------|---------------------------------------------------|
| `ship_on_screen`       | after any frame, the whole ship is on screen      |
| `bullets_on_screen`    | after any frame, every bullet left is on screen   |
| `fleet_on_screen`      | after any frame, the invader block is on screen   |
| `score_never_drops`    | after any frame, the score is the old one plus d ≥ 0 |
| `restart_starts_over`  | R gives exactly the starting game                 |
| `lives_never_go_up`    | after any frame, the old lives are the new ones plus d ≥ 0 |
| `shields_only_shrink`  | hits only remove shield blocks, never add any     |
| `fast_fleet_on_screen` | however many steps the fleet takes in a frame, it stays on screen |

Known simplifications, possible next steps:

- The fleet keeps its full width at the edges even after outer columns
  are shot.
- `bend PROOF.bend --verdict` (the Lean-checked second opinion) needs a
  Lean toolchain: `elan default stable`.
