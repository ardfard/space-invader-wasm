import Base
import ./bullets.bend as B
import ./fleet.bend as F

# Which invaders are alive, and bullets hitting them.

# An alive invader, by its column and row in the fleet.
type Inv is Data:
  Inv{c: U32, r: U32}

# All 8 x 5 invaders, alive.
def row_of(n: Nat, +r: U32, rest: +List<Inv>) -> +List<Inv>:
  match n:
    case 0n:
      rest
    case 1n+(+p):
      Inv{U32.from_nat(p), r} <> row_of(p, r, rest)

def all_rows(n: Nat, rest: +List<Inv>) -> +List<Inv>:
  match n:
    case 0n:
      rest
    case 1n+(+p):
      row_of(F.cols(), U32.from_nat(p), all_rows(p, rest))

def all_invaders() -> +List<Inv>:
  all_rows(F.rows(), [])

# The invader's top-left corner on screen, for a fleet at (fx, fy).
def inv_x(+i: Inv, fx: U32) -> U32:
  match i:
    case Inv{c, r}:
      (fx + (c * F.gap_x() : U32) : U32)

def inv_y(+i: Inv, fy: U32) -> U32:
  match i:
    case Inv{c, r}:
      (fy + (r * F.gap_y() : U32) : U32)

# Do two boxes overlap? Box one at (ax, ay) size aw x ah, box two likewise.
def overlap(+ax: U32, +ay: U32, aw: U32, ah: U32,
            +bx: U32, +by: U32, bw: U32, bh: U32) -> Bool:
  (ax < (bx + bw : U32) : U32) && (bx < (ax + aw : U32) : U32)
    && (ay < (by + bh : U32) : U32) && (by < (ay + ah : U32) : U32)

def struck(+b: B.Bullet, +i: Inv, fx: U32, fy: U32) -> Bool:
  match b:
    case B.Bullet{x, y}:
      overlap(x, y, 2, 6, inv_x(i, fx), inv_y(i, fy), F.inv_w(), F.inv_h())

# How many invaders one bullet hit, and the invaders left.
type Strike is Data:
  Strike{hit: Nat, left: +List<Inv>}

def tally(hit: Bool, i: Inv, s: Strike) -> Strike:
  match hit:
    case True{}:
      match s:
        case Strike{n, l}:
          Strike{1n+n, l}
    case False{}:
      match s:
        case Strike{n, l}:
          Strike{n, i <> l}

# Remove every invader bullet b overlaps. The gaps between invaders are
# wider than a bullet, so that is at most one.
def strike(invs: +List<Inv>, +b: B.Bullet, +fx: U32, +fy: U32) -> Strike:
  match invs:
    case Nil{}:
      Strike{0n, Nil{}}
    case Con{+i, rest}:
      tally(struck(b, i, fx, fy), i, strike(rest, b, fx, fy))

# Points scored, bullets still flying, invaders still alive.
type Hits is Data:
  Hits{points: Nat, bullets: +List<B.Bullet>, invs: +List<Inv>}

# A bullet that hit nothing keeps flying; one that hit scores 10 and goes.
def settle(n: Nat, b: B.Bullet, h: Hits) -> Hits:
  match n:
    case 0n:
      match h:
        case Hits{p, bs, iv}:
          Hits{p, b <> bs, iv}
    case 1n+k:
      match h:
        case Hits{p, bs, iv}:
          Hits{Nat.add(10n, p), bs, iv}

# The strike of the first bullet in bs, if any.
def first_strike(bs: +List<B.Bullet>, invs: +List<Inv>, fx: U32, fy: U32) ->
  Strike:
  match bs:
    case Nil{}:
      Strike{0n, invs}
    case Con{+b, rest}:
      strike(invs, b, fx, fy)

# Each bullet against the invaders. s is the first bullet's strike,
# worked out by the caller, because a match can't open a computed value.
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

def hits(+bs: +List<B.Bullet>, invs: +List<Inv>, +fx: U32, +fy: U32) -> Hits:
  resolve(bs, first_strike(bs, invs, fx, fy), fx, fy)

def choose(first: Bool, a: U32, b: U32) -> U32:
  match first:
    case True{}:
      a
    case False{}:
      b

# The leftmost and rightmost alive columns; best is the answer so far.
def lo_col(iv: +List<Inv>, +best: U32) -> U32:
  match iv:
    case Nil{}:
      best
    case Con{Inv{+c, r}, rest}:
      lo_col(rest, choose((c < best : U32), c, best))

def hi_col(iv: +List<Inv>, +best: U32) -> U32:
  match iv:
    case Nil{}:
      best
    case Con{Inv{+c, r}, rest}:
      hi_col(rest, choose((best < c : U32), c, best))

# n fleet steps, turning at the edges of the columns still alive.
def march(n: Nat, +iv: +List<Inv>, f: F.Fleet) -> F.Fleet:
  F.march_alive(n, lo_col(iv, 7), hi_col(iv, 0), f)
