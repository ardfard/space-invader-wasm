import Base
import ./render.bend as R
import ./step03_ship.bend as Ship
import ./step04_shoot.bend as S
import ./fleet.bend as F

# Step 4's ship and bullets plus a marching invader fleet.
# The bullets pass through invaders for now; step 6 adds hits.

def purple() -> U32:
  12611583

def Game.new() -> Game:
  Game{S.Game{Ship.Game{120, False{}, False{}}, []}, F.Fleet{0, 24, True{}}}

# n invaders in a row, starting at (x, y), in front of rest.
def row_rects(n: Nat, +x: U32, +y: U32, rest: +List<R.Rect>) -> +List<R.Rect>:
  match n:
    case 0n:
      rest
    case 1n+p:
      R.Rect{x, y, F.inv_w(), F.inv_h(), purple()}
        <> row_rects(p, (x + F.gap_x() : U32), y, rest)

# n rows of invaders, the first at (x, y), in front of rest.
def grid_rects(n: Nat, +x: U32, +y: U32, rest: +List<R.Rect>) -> +List<R.Rect>:
  match n:
    case 0n:
      rest
    case 1n+p:
      row_rects(F.cols(), x, y, grid_rects(p, x, (y + F.gap_y() : U32), rest))

def fleet_rects(f: F.Fleet, rest: +List<R.Rect>) -> +List<R.Rect>:
  match f:
    case F.Fleet{x, y, right}:
      grid_rects(F.rows(), x, y, rest)

type Game is Data:
  Game{play: S.Game, fleet: F.Fleet}

def step(g: Game) -> Game:
  match g:
    case Game{p, f}:
      Game{S.step(p), F.step(f)}

def fire(g: Game) -> Game:
  match g:
    case Game{p, f}:
      Game{S.fire(p), f}

def set_left(g: Game, held: Bool) -> Game:
  match g:
    case Game{p, f}:
      Game{S.set_left(p, held), f}

def set_right(g: Game, held: Bool) -> Game:
  match g:
    case Game{p, f}:
      Game{S.set_right(p, held), f}

def scene(g: Game) -> +List<R.Rect>:
  match g:
    case Game{p, f}:
      fleet_rects(f, S.scene(p))

def view(+g: Game) -> Pair(Game, Image):
  (g, R.draw(scene(g)))

def tick(events: List<Event>, g: Game) -> IO(Maybe<Game>):
  match events:
    case Nil{}:
      IO.pure(Maybe<Game>, Some{step(g)})
    case Con{Close{}, rest}:
      IO.pure(Maybe<Game>, None{})
    case Con{Key{27, True{}}, rest}:
      IO.pure(Maybe<Game>, None{})
    case Con{Key{32, True{}}, rest}:
      tick(rest, fire(g))
    case Con{Key{63234, down}, rest}:
      tick(rest, set_left(g, down))
    case Con{Key{63235, down}, rest}:
      tick(rest, set_right(g, down))
    case Con{_, rest}:
      tick(rest, g)

def main() -> IO(Unit):
  App.run(~Game, ~App{+g => view(g), tick}, "Step 5: fleet", 256, 256,
    Game.new())
