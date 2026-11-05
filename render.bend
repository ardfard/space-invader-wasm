import Base

# The rectangle renderer from step 2, as a module.
# Rectangles earlier in the list are drawn on top.

type Rect is Data:
  Rect{x: U32, y: U32, w: U32, h: U32, color: U32}

# What a square of the screen looks like: one color, or a mix.
type Look is Data:
  Solid{color: U32}
  Mixed{}

def Rect.color(r: Rect) -> U32:
  match r:
    case Rect{x, y, w, h, c}:
      c

def background() -> U32:
  1052688

# Does rectangle r touch the s x s square at (x, y)?
def touches(+r: Rect, +x: U32, +y: U32, +s: U32) -> Bool:
  match r:
    case Rect{rx, ry, w, h, c}:
      (x < (rx + w : U32) : U32) && (rx < (x + s : U32) : U32)
        && (y < (ry + h : U32) : U32) && (ry < (y + s : U32) : U32)

# Does rectangle r cover the whole s x s square at (x, y)?
def covers(+r: Rect, +x: U32, +y: U32, +s: U32) -> Bool:
  match r:
    case Rect{rx, ry, w, h, c}:
      (rx <= x : U32) && ((x + s : U32) <= (rx + w : U32) : U32)
        && (ry <= y : U32) && ((y + s : U32) <= (ry + h : U32) : U32)

def keep(hit: Bool, r: Rect, rest: +List<Rect>) -> +List<Rect>:
  match hit:
    case True{}:
      r <> rest
    case False{}:
      rest

# The rectangles that touch the square, in the same order.
def touching(rs: +List<Rect>, +x: U32, +y: U32, +s: U32) -> +List<Rect>:
  match rs:
    case Nil{}:
      Nil{}
    case Con{+r, rest}:
      keep(touches(r, x, y, s), r, touching(rest, x, y, s))

def solid_if(hit: Bool, color: U32) -> Look:
  match hit:
    case True{}:
      Solid{color}
    case False{}:
      Mixed{}

# rs holds only rectangles touching the square; the first one is on top.
def classify(rs: +List<Rect>, x: U32, y: U32, s: U32) -> Look:
  match rs:
    case Nil{}:
      Solid{background()}
    case Con{+r, rest}:
      solid_if(covers(r, x, y, s), Rect.color(r))

# The image of the s x s square at (x, y), where s = 2^d.
# The four quarters are built in parallel.
def paint(d: Nat, +x: U32, +y: U32, +s: U32, +rs: +List<Rect>, look: Look) ->
  Image:
  match d:
    case 0n:
      match look:
        case Solid{c}:
          Pix{c}
        case Mixed{}:
          Pix{background()}
    case 1n+(+p):
      match look:
        case Solid{c}:
          Pix{c}
        case Mixed{}:
          +h = (s / 2 : U32)
          +xr = (x + h : U32)
          +yb = (y + h : U32)
          +tl = touching(rs, x, y, h)
          +tr = touching(rs, xr, y, h)
          +bl = touching(rs, x, yb, h)
          +br = touching(rs, xr, yb, h)
          a b c e = paint(p, x, y, h, tl, classify(tl, x, y, h))
            paint(p, xr, y, h, tr, classify(tr, xr, y, h))
            paint(p, x, yb, h, bl, classify(bl, x, yb, h))
            paint(p, xr, yb, h, br, classify(br, xr, yb, h))
          Qua{a, b, c, e}

# The 256 x 256 image of a list of rectangles.
def draw(+rs: +List<Rect>) -> Image:
  paint(8n, 0, 0, 256, rs, classify(rs, 0, 0, 256))
