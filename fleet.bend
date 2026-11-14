import Base

# The invader fleet: a block of 5 rows x 8 invaders that marches sideways,
# then drops a row and turns around when it reaches an edge.

def cols() -> Nat:
  8n

def rows() -> Nat:
  5n

def inv_w() -> U32:
  12

def inv_h() -> U32:
  8

# Distance from one invader to the next, across and down.
def gap_x() -> U32:
  20

def gap_y() -> U32:
  16

# The block is 7 * 20 + 12 = 152 wide, so its left edge goes up to
# 256 - 152 = 104.
def max_x() -> U32:
  104

def drop() -> U32:
  8

# x, y is the block's top-left corner; right says which way it marches.
type Fleet is Data:
  Fleet{x: U32, y: U32, right: Bool}

def Fleet.x(f: Fleet) -> U32:
  match f:
    case Fleet{x, y, right}:
      x

# One pixel in the marching direction. Moving left from 0 wraps around
# to a huge U32, so the fit test below catches both edges.
def next_x(right: Bool, x: U32) -> U32:
  match right:
    case True{}:
      (x + 1 : U32)
    case False{}:
      (x - 1 : U32)

# The edge the block is marching toward.
def edge(right: Bool) -> U32:
  match right:
    case True{}:
      max_x()
    case False{}:
      0

# Go to nx if it fits; otherwise stop at the edge, drop and turn around.
def go_or_turn(fits: Bool, nx: U32, y: U32, +right: Bool) -> Fleet:
  match fits:
    case True{}:
      Fleet{nx, y, right}
    case False{}:
      Fleet{edge(right), (y + drop() : U32), Bool.not(right)}

def advance(+nx: U32, y: U32, right: Bool) -> Fleet:
  go_or_turn((nx <= max_x() : U32), nx, y, right)

def step(f: Fleet) -> Fleet:
  match f:
    case Fleet{x, y, +right}:
      advance(next_x(right, x), y, right)

# n steps in a row. A faster fleet takes more than one step per frame.
def march(n: Nat, f: Fleet) -> Fleet:
  match n:
    case 0n:
      f
    case 1n+p:
      step(march(p, f))

# Once outer columns are shot away, the block that is left is narrower.
# lo and hi are the leftmost and rightmost columns still alive.

# The screen x of the alive block's left edge.
def left_edge(x: U32, lo: U32) -> U32:
  (x + (lo * gap_x() : U32) : U32)

# How far right that edge may go: 256 minus the alive block's width,
# which is (hi - lo) * 20 + 12.
def room(lo: U32, hi: U32) -> U32:
  (244 - ((hi - lo : U32) * gap_x() : U32) : U32)

# Is the alive block on screen? As before, a left edge past 0 wraps to a
# huge U32, so one test covers both sides.
def fits(x: U32, +lo: U32, +hi: U32) -> Bool:
  U32.is_le(left_edge(x, lo), room(lo, hi))

# Go to nx if it fits; otherwise stay at x, drop and turn around.
def turn_in(ok: Bool, nx: U32, x: U32, y: U32, +right: Bool) -> Fleet:
  match ok:
    case True{}:
      Fleet{nx, y, right}
    case False{}:
      Fleet{x, (y + drop() : U32), Bool.not(right)}

# One step, turning at the edges of the alive block.
def step_alive(+lo: U32, +hi: U32, f: Fleet) -> Fleet:
  match f:
    case Fleet{+x, y, +right}:
      turn_in(fits(next_x(right, x), lo, hi), next_x(right, x), x, y, right)

# n such steps in a row.
def march_alive(n: Nat, +lo: U32, +hi: U32, f: Fleet) -> Fleet:
  match n:
    case 0n:
      f
    case 1n+p:
      step_alive(lo, hi, march_alive(p, lo, hi, f))
