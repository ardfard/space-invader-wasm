import Base

# Bullets fired by the player. They fly up and are removed once off screen.

# x, y is the bullet's top-left corner.
type Bullet is Data:
  Bullet{x: U32, y: U32}

def speed() -> U32:
  4

# One frame up. Near the top, y - speed wraps around to a huge U32,
# which on_screen then rejects.
def up(b: Bullet) -> Bullet:
  match b:
    case Bullet{x, y}:
      Bullet{x, (y - speed() : U32)}

def on_screen(b: Bullet) -> Bool:
  match b:
    case Bullet{x, y}:
      (y < 256 : U32)

def keep(hit: Bool, b: Bullet, rest: +List<Bullet>) -> +List<Bullet>:
  match hit:
    case True{}:
      b <> rest
    case False{}:
      rest

def place(+b: Bullet, rest: +List<Bullet>) -> +List<Bullet>:
  keep(on_screen(b), b, rest)

# One frame for every bullet: move up, drop the ones that left.
def move(bs: +List<Bullet>) -> +List<Bullet>:
  match bs:
    case Nil{}:
      Nil{}
    case Con{b, rest}:
      place(up(b), move(rest))

# Is every bullet in the list on screen?
def all_on_screen(bs: +List<Bullet>) -> Bool:
  match bs:
    case Nil{}:
      True{}
    case Con{b, rest}:
      on_screen(b) && all_on_screen(rest)
