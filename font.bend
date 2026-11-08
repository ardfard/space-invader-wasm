import Base
import ./render.bend as R

# A tiny digit font: each digit is 3 x 5 cells, each cell a 2 x 2 square.
# A glyph is 15 bits, row by row from the top-left, the top-left cell in
# bit 14. For example 0 is 111 101 101 101 111 = 31599.

def glyphs() -> +List<U32>:
  [31599, 11415, 29671, 29647, 23497, 31183, 31215, 29257, 31727, 31695]

def or_blank(m: Maybe<&2, U32>) -> U32:
  match m:
    case None{}:
      0
    case Some{v}:
      v

# The glyph of a character; anything that isn't a digit is blank.
def glyph(code: U32) -> U32:
  or_blank(List.get(&2, U32, glyphs(), U32.to_nat((code - 48 : U32))))

def cell() -> U32:
  2

def put(on: Bool, r: R.Rect, rest: +List<R.Rect>) -> +List<R.Rect>:
  match on:
    case True{}:
      r <> rest
    case False{}:
      rest

# Cells p - 1 down to 0 of glyph g at (x, y). Cell p is bit p, which sits
# at index 14 - p counting row by row from the top-left.
def cells(n: Nat, +g: U32, +x: U32, +y: U32, +color: U32,
          rest: +List<R.Rect>) -> +List<R.Rect>:
  match n:
    case 0n:
      rest
    case 1n+(+p):
      +i = (14 - U32.from_nat(p) : U32)
      put(U32.is_eq(((g >> p : U32) .&. 1 : U32), 1),
        R.Rect{(x + ((i % 3 : U32) * cell() : U32) : U32),
               (y + ((i / 3 : U32) * cell() : U32) : U32),
               cell(), cell(), color},
        cells(p, g, x, y, color, rest))

# The text s at (x, y), one glyph every 8 pixels, in front of rest.
def text(s: String, +x: U32, +y: U32, +color: U32, rest: +List<R.Rect>) ->
  +List<R.Rect>:
  match s:
    case SNil{}:
      rest
    case SCon{Chr{code}, tail}:
      cells(15n, glyph(code), x, y, color,
        text(tail, (x + 8 : U32), y, color, rest))
