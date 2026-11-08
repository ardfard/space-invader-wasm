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
