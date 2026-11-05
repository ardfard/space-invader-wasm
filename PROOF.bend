import Base
import ./LAWS.bend as Laws
import ./step03_ship.bend as Ship

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
