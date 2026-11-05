# Building Space Invaders in Bend — learning log

A step-by-step record of building a native Space Invaders in Bend 2
(`bend version`: 2.0.39). Each step is a runnable program under `steps/`,
with what it teaches, what broke, and how it was fixed.

## Step 0 — Choosing a target

The original plan was Bend → WebAssembly in a browser. Investigation showed:

- `bend` emits a native binary, C (`-o f.c`), JS (`-o f.js`) or an ES module
  (`-o f.mjs`). There is no wasm target.
- The emitted C is the whole Bend runtime: pthreads, atomics, `mmap` of a
  2 GiB stack and an 8 GiB heap, signal handlers, a blocking event loop.
  Getting it into wasm32 (4 GiB address space) needs emscripten plus patches
  to the generated C on every build.
- The JS target runs sequentially, so Bend's parallelism is lost in a browser.

Decision: go native and focus on learning Bend. Raylib was considered and
rejected: it would need hand-written C effects against runtime internals that
have no ABI promise (`bend guide effects`), and most of the work would be C
glue, not Bend. Bend's own `App.run` + `Image` cover everything a 2D game
needs.

Useful commands while learning:

```sh
bend guide            # the language guide
bend guide effects    # how C/JS effects plug in
bend base App         # print a Base definition and everything under it
bend base --types     # every type in Base
bend f.bend --check-only
bend f.bend -o f && ./f
```

## Step 1 — Hello window (`steps/01_hello.bend`)

A window whose color changes on every key press; Escape or closing quits.

```python
def main() -> IO(Unit):
  App.run(~U32, ~App{+s => (s, Pix{s}), tick}, "Step 1: hello", 256, 256, 2113664)
```

What it teaches:

- **`App.run(~S, ~app, title, w, h, state)`**: `S` is the state type, `app`
  is `App{view, tick}`. The `~` means they are *templates*: substituted at
  compile time, not passed at runtime.
- **`view : S -> Pair(S, Image)`**: the state is affine (usable once), so
  `view` must hand it back beside the image. `+s => (s, Pix{s})` marks `s`
  reusable (`U32` is `Data`, so copying is allowed) to use it twice.
- **`tick : List<Event> -> S -> IO(Maybe<S>)`**: folds a frame's events into
  the next state. `None{}` quits.
- **Pattern matching on nested constructors and literals**:
  `case Con{Key{27, True{}}, rest}:` matches "Escape pressed" directly.
- **Tail recursion**: `tick(rest, ...)` is called on `rest`, a strict
  sub-part of `events`, so the termination checker accepts it.
- **`Image`** is a quadtree: `Pix{color}` paints a whole square. The
  window's root square is the next power of two ≥ max(width, height).
- **Colors** are `0xRRGGBB` as a `U32` (verified: 2113664 = `0x204080`
  renders blue).
- **Key codes** (from `~/.bend/bend2/effs/window.c`): lowercase character
  for printable keys, Escape = 27, Space = 32, arrows Up/Down/Left/Right =
  63232/63233/63234/63235.

What broke:

- `0x00FF8040` → `expected: a numeric literal`. **Bend has no hex
  literals**; write decimal (`16744512`).
- Operators need a type: `(a * b : U32)`. `.^.` is XOR.

Run: `cd steps && bend 01_hello.bend -o hello && ./hello`
