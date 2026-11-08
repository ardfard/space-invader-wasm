import Base
import ./render.bend as R
import ./step03_ship.bend as Ship
import ./bullets.bend as B

# The ship from step 3 can now shoot: Space fires, one bullet at a time.
# Escape or closing the window quits.

def white() -> U32:
  16777215

# The whole game: the ship from step 3 plus the bullets in flight.
type Game is Data:
  Game{ship: Ship.Game, bullets: +List<B.Bullet>}

# A new bullet at the ship's nose, but only if none is in flight.
def fire_from(bs: +List<B.Bullet>, x: U32) -> +List<B.Bullet>:
  match bs:
    case Nil{}:
      [B.Bullet{(x + 7 : U32), 208}]
    case Con{b, rest}:
      b <> rest

def fire(g: Game) -> Game:
  match g:
    case Game{+s, bs}:
      Game{s, fire_from(bs, Ship.Game.x(s))}

def set_left(g: Game, held: Bool) -> Game:
  match g:
    case Game{s, bs}:
      Game{Ship.set_left(s, held), bs}

def set_right(g: Game, held: Bool) -> Game:
  match g:
    case Game{s, bs}:
      Game{Ship.set_right(s, held), bs}

def step(g: Game) -> Game:
  match g:
    case Game{s, bs}:
      Game{Ship.step(s), B.move(bs)}

# Each bullet becomes a 2 x 6 white rectangle, in front of rest.
def bullet_rects(bs: +List<B.Bullet>, rest: +List<R.Rect>) -> +List<R.Rect>:
  match bs:
    case Nil{}:
      rest
    case Con{B.Bullet{x, y}, more}:
      R.Rect{x, y, 2, 6, white()} <> bullet_rects(more, rest)

def scene(g: Game) -> +List<R.Rect>:
  match g:
    case Game{s, bs}:
      bullet_rects(bs, Ship.scene(s))

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
  App.run(~Game, ~App{+g => view(g), tick}, "Step 4: shoot", 256, 256,
    Game{Ship.Game{120, False{}, False{}}, []})
