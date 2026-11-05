import Base
import ./render.bend as R

# The player's ship moves with the arrow keys and stays on screen.
# Escape or closing the window quits.

def ship_w() -> U32:
  16

# The largest x that keeps the whole ship on screen: 256 - ship_w.
def max_x() -> U32:
  240

def speed() -> U32:
  2

def green() -> U32:
  4259648

# x is the ship's left edge; left and right say whether those keys are held.
type Game is Data:
  Game{x: U32, left: Bool, right: Bool}

def Game.x(g: Game) -> U32:
  match g:
    case Game{x, left, right}:
      x

# Moving left stops at 0 instead of wrapping around to a huge U32.
def left_by(room: Bool, +x: U32) -> U32:
  match room:
    case True{}:
      (x - speed() : U32)
    case False{}:
      0

def go_left(held: Bool, +x: U32) -> U32:
  match held:
    case True{}:
      left_by((speed() <= x : U32), x)
    case False{}:
      x

def go_right(held: Bool, x: U32) -> U32:
  match held:
    case True{}:
      (x + speed() : U32)
    case False{}:
      x

def pick_x(fits: Bool, x: U32) -> U32:
  match fits:
    case True{}:
      x
    case False{}:
      max_x()

# x, or max_x() if x is past it.
def clamp(+x: U32) -> U32:
  pick_x((x <= max_x() : U32), x)

# One frame of movement.
def step(g: Game) -> Game:
  match g:
    case Game{x, +left, +right}:
      Game{clamp(go_right(right, go_left(left, x))), left, right}

def set_left(g: Game, held: Bool) -> Game:
  match g:
    case Game{x, left, right}:
      Game{x, held, right}

def set_right(g: Game, held: Bool) -> Game:
  match g:
    case Game{x, left, right}:
      Game{x, left, held}

def scene(g: Game) -> +List<R.Rect>:
  match g:
    case Game{+x, left, right}:
      [ R.Rect{(x + 7 : U32), 214, 2, 3, green()}
      , R.Rect{(x + 6 : U32), 217, 4, 3, green()}
      , R.Rect{(x + 1 : U32), 220, 14, 2, green()}
      , R.Rect{x, 222, 16, 6, green()}
      , R.Rect{0, 236, 256, 2, green()}
      ]

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
    case Con{Key{63234, down}, rest}:
      tick(rest, set_left(g, down))
    case Con{Key{63235, down}, rest}:
      tick(rest, set_right(g, down))
    case Con{_, rest}:
      tick(rest, g)

def main() -> IO(Unit):
  App.run(~Game, ~App{+g => view(g), tick}, "Step 3: ship", 256, 256,
    Game{120, False{}, False{}})
