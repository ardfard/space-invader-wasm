import Base
import ./LAWS.bend as Laws
import ./step03_ship.bend as Ship
import ./bullets.bend as B

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
