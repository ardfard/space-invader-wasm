import Base
import ./bullets.bend as B
import ./hits.bend as H
import ./step08_lives.bend as L

# Shields: blocks that bullets and shots chip away.

# One 4 x 4 block of a shield, by its top-left corner.
type Blk is Data:
  Blk{x: U32, y: U32}

# A projectile's box, for hit tests.
type Box is Data:
  Box{x: U32, y: U32, w: U32, h: U32}

def blk() -> U32:
  4

def shield_y() -> U32:
  184

# The arch's opening: the two middle blocks of the bottom row.
def gap(+c: U32, r: U32) -> Bool:
  U32.is_eq(r, 3) && (U32.is_eq(c, 2) || U32.is_eq(c, 3))

def put(on: Bool, b: Blk, rest: +List<Blk>) -> +List<Blk>:
  match on:
    case True{}:
      b <> rest
    case False{}:
      rest

# Columns n - 1 down to 0 of row r of the shield at x0.
def row(n: Nat, +x0: U32, +r: U32, rest: +List<Blk>) -> +List<Blk>:
  match n:
    case 0n:
      rest
    case 1n+(+p):
      +c = U32.from_nat(p)
      put(Bool.not(gap(c, r)),
        Blk{(x0 + (c * blk() : U32) : U32), (shield_y() + (r * blk() : U32) : U32)},
        row(p, x0, r, rest))

# Rows n - 1 down to 0 of the shield at x0, 6 blocks each.
def rows(n: Nat, +x0: U32, rest: +List<Blk>) -> +List<Blk>:
  match n:
    case 0n:
      rest
    case 1n+(+p):
      row(6n, x0, U32.from_nat(p), rows(p, x0, rest))

# Four shields, 64 pixels apart.
def all_blocks() -> +List<Blk>:
  rows(4n, 20, rows(4n, 84, rows(4n, 148, rows(4n, 212, []))))

def touch(+b: Blk, +p: Box) -> Bool:
  match b:
    case Blk{bx, by}:
      match p:
        case Box{x, y, w, h}:
          H.overlap(bx, by, blk(), blk(), x, y, w, h)

# Does any projectile in ps touch block b?
def hit_any(+b: Blk, ps: +List<Box>) -> Bool:
  match ps:
    case Nil{}:
      False{}
    case Con{+p, rest}:
      touch(b, p) || hit_any(b, rest)

# The blocks no projectile touches.
def chip(blocks: +List<Blk>, +ps: +List<Box>) -> +List<Blk>:
  match blocks:
    case Nil{}:
      Nil{}
    case Con{+b, rest}:
      put(Bool.not(hit_any(b, ps)), b, chip(rest, ps))

# Does box p touch any block?
def blocked(+p: Box, blocks: +List<Blk>) -> Bool:
  match blocks:
    case Nil{}:
      False{}
    case Con{+b, rest}:
      touch(b, p) || blocked(p, rest)

def bullet_box(b: B.Bullet) -> Box:
  match b:
    case B.Bullet{x, y}:
      Box{x, y, 2, 6}

def shot_box(s: L.Shot) -> Box:
  match s:
    case L.Shot{x, y}:
      Box{x, y, 2, 6}

def keep_bullet(on: Bool, b: B.Bullet, rest: +List<B.Bullet>) -> +List<B.Bullet>:
  match on:
    case True{}:
      b <> rest
    case False{}:
      rest

# The bullets that touch no block.
def free_bullets(bs: +List<B.Bullet>, +blocks: +List<Blk>) -> +List<B.Bullet>:
  match bs:
    case Nil{}:
      Nil{}
    case Con{+b, rest}:
      keep_bullet(Bool.not(blocked(bullet_box(b), blocks)), b,
        free_bullets(rest, blocks))

def keep_shot(on: Bool, s: L.Shot, rest: +List<L.Shot>) -> +List<L.Shot>:
  match on:
    case True{}:
      s <> rest
    case False{}:
      rest

# The shots that touch no block.
def free_shots(ss: +List<L.Shot>, +blocks: +List<Blk>) -> +List<L.Shot>:
  match ss:
    case Nil{}:
      Nil{}
    case Con{+s, rest}:
      keep_shot(Bool.not(blocked(shot_box(s), blocks)), s,
        free_shots(rest, blocks))

# Every bullet and shot as a box, bullets first.
def boxes(bs: +List<B.Bullet>, ss: +List<L.Shot>) -> +List<Box>:
  match bs:
    case Nil{}:
      match ss:
        case Nil{}:
          Nil{}
        case Con{s, rest}:
          shot_box(s) <> boxes(Nil{}, rest)
    case Con{b, rest}:
      bullet_box(b) <> boxes(rest, ss)
