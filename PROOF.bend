import Base
import ./LAWS.bend as Laws
import ./step03_ship.bend as Ship
import ./step04_shoot.bend as S
import ./bullets.bend as B
import ./fleet.bend as F
import ./hits.bend as H
import ./step06_hits.bend as G
import ./step07_score.bend as Top

# clamp(y) is pick_x(is_le(y, max_x), y). b stands for that is_le result,
# and e remembers what it was. If it was True, pick_x gives y back and e is
# exactly the goal. If it was False, pick_x gives max_x, and
# is_le(max_x, max_x) computes to True.
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

# keep(b, m, rest) is all on screen when rest is (h) and, if m is kept,
# m is on screen (e says b is on_screen(m)).
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

# Induction on the list: the empty list is trivially fine, and each
# bullet is either kept on screen or dropped.
def Laws.bullets_on_screen(bs):
  match bs:
    case Nil{}:
      {==}
    case Con{b, rest}:
      keep_ok(B.up(b), B.move(rest), Laws.bullets_on_screen(rest),
        B.on_screen(B.up(b)), {==})

# go_or_turn either moves to nx, when e says nx fits, or stops at an
# edge, and both edges (0 and max_x) fit by computation.
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

def Laws.fleet_on_screen(f):
  match f:
    case F.Fleet{x, y, +right}:
      turn_ok(F.next_x(right, x), y,
        U32.is_le(F.next_x(right, x), F.max_x()), {==}, right)

# settle adds the frame's points to the score, so d is those points.
def settle_ok(
  h: H.Hits, -s: Ship.Game, -fx: U32, -fy: U32, -right: Bool, -score: Nat
) -> &d: Nat -> {G.Game.score(G.settle(h, s, fx, fy, right, score)) == Nat.add(d, score) : Nat}:
  match h:
    case H.Hits{points, bs, iv}:
      (points, {==})

def advance_ok(p: S.Game, f: F.Fleet, iv: +List<H.Inv>, -score: Nat) ->
  &d: Nat -> {G.Game.score(G.advance(p, f, iv, score)) == Nat.add(d, score) : Nat}:
  match p:
    case S.Game{s, bs}:
      match f:
        case F.Fleet{+fx, +fy, right}:
          settle_ok(H.hits(bs, iv, fx, fy), s, fx, fy, right, score)

# While playing, d is the points scored this frame. Once won or lost the
# game is frozen, so d is 0n, and Nat.add(0n, score) computes to score.
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

# restart ignores the old game, so both sides compute to the same game.
def Laws.restart_starts_over(g):
  {==}
