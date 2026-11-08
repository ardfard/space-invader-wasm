import Base
import ./render.bend as R
import ./font.bend as T
import ./step03_ship.bend as Ship
import ./step04_shoot.bend as S
import ./fleet.bend as F
import ./hits.bend as H
import ./step06_hits.bend as G
import ./step07_score.bend as Top

# Invaders shoot back. A shot that hits the ship costs a life; with no
# lives left the game is lost. Lives are shown bottom-right.

def yellow() -> U32:
  16772608

def white() -> U32:
  16777215

# A shot falling from an invader; x, y is its top-left corner.
type Shot is Data:
  Shot{x: U32, y: U32}

# The ground line; a shot that reaches it is gone.
def ground() -> U32:
  236

def keep(hit: Bool, s: Shot, rest: +List<Shot>) -> +List<Shot>:
  match hit:
    case True{}:
      s <> rest
    case False{}:
      rest

def place(+s: Shot, rest: +List<Shot>) -> +List<Shot>:
  match s:
    case Shot{x, +y}:
      keep((y < ground() : U32), Shot{x, y}, rest)

# Every shot falls 2 pixels; the ones that reach the ground are dropped.
def move_shots(ss: +List<Shot>) -> +List<Shot>:
  match ss:
    case Nil{}:
      Nil{}
    case Con{Shot{x, y}, rest}:
      place(Shot{x, (y + 2 : U32)}, move_shots(rest))

# Does shot s overlap the ship, whose left edge is sx?
def on_ship(s: Shot, sx: U32) -> Bool:
  match s:
    case Shot{x, y}:
      H.overlap(x, y, 2, 6, sx, 214, Ship.ship_w(), 14)

def any_hit(ss: +List<Shot>, +sx: U32) -> Bool:
  match ss:
    case Nil{}:
      False{}
    case Con{s, rest}:
      on_ship(s, sx) || any_hit(rest, sx)

def miss(+s: Shot, +sx: U32, rest: +List<Shot>) -> +List<Shot>:
  keep(Bool.not(on_ship(s, sx)), s, rest)

# The shots that did not hit the ship.
def drop_hits(ss: +List<Shot>, +sx: U32) -> +List<Shot>:
  match ss:
    case Nil{}:
      Nil{}
    case Con{s, rest}:
      miss(s, sx, drop_hits(rest, sx))

# A pseudo-random number from 0 to 63 for frame t.
def pick(t: U32) -> U32:
  (((t * 2654435761 : U32) >> 16n : U32) .&. 63 : U32)

def spawn_if(now: Bool, m: Maybe<&2, H.Inv>, +fx: U32, +fy: U32,
             ss: +List<Shot>) -> +List<Shot>:
  match now:
    case True{}:
      match m:
        case None{}:
          ss
        case Some{+i}:
          Shot{(H.inv_x(i, fx) + 5 : U32), (H.inv_y(i, fy) + F.inv_h() : U32)}
            <> ss
    case False{}:
      ss

# Every 32 frames, invader number pick(t) fires, if that many are alive.
def spawn(+t: U32, core: G.Game, ss: +List<Shot>) -> +List<Shot>:
  match core:
    case G.Game{ph, p, f, iv, score}:
      match f:
        case F.Fleet{fx, fy, right}:
          spawn_if(U32.is_eq((t % 32 : U32), 0),
            List.get(&2, H.Inv, iv, U32.to_nat(pick(t))), fx, fy, ss)

def playing(g: G.Game) -> Bool:
  match g:
    case G.Game{ph, p, f, iv, score}:
      match ph:
        case G.Playing{}:
          True{}
        case G.Won{}:
          False{}
        case G.Lost{}:
          False{}

def ship_x(g: G.Game) -> U32:
  match g:
    case G.Game{ph, p, f, iv, score}:
      match p:
        case S.Game{s, bs}:
          Ship.Game.x(s)

# Lose one life if hit (never below zero).
def lose_if(hit: Bool, lives: Nat) -> Nat:
  match hit:
    case True{}:
      match lives:
        case 0n:
          0n
        case 1n+p:
          p
    case False{}:
      lives

def is_out(n: Nat) -> Bool:
  match n:
    case 0n:
      True{}
    case 1n+p:
      False{}

# The game with its phase set to Lost.
def lose(g: G.Game) -> G.Game:
  match g:
    case G.Game{ph, p, f, iv, score}:
      G.Game{G.Lost{}, p, f, iv, score}

def end_if(out: Bool, g: G.Game) -> G.Game:
  match out:
    case True{}:
      lose(g)
    case False{}:
      g

type Game is Data:
  Game{core: G.Game, shots: +List<Shot>, lives: Nat, clock: U32}

def Game.new() -> Game:
  Game{G.Game.new(), [], 3n, 1}

def Game.lives(g: Game) -> Nat:
  match g:
    case Game{core, ss, lives, t}:
      lives

# One frame: step 6's game moves, invaders may fire, shots fall, and a
# shot on the ship costs a life (only while playing).
def step(g: Game) -> Game:
  match g:
    case Game{+core, ss, lives, +t}:
      +next = G.step(core)
      +fallen = move_shots(spawn(t, next, ss))
      +sx = ship_x(next)
      +left = lose_if(playing(core) && any_hit(fallen, sx), lives)
      Game{end_if(is_out(left), next), drop_hits(fallen, sx), left,
        (t + 1 : U32)}

def fire(g: Game) -> Game:
  match g:
    case Game{core, ss, lives, t}:
      Game{G.fire(core), ss, lives, t}

def set_left(g: Game, held: Bool) -> Game:
  match g:
    case Game{core, ss, lives, t}:
      Game{G.set_left(core, held), ss, lives, t}

def set_right(g: Game, held: Bool) -> Game:
  match g:
    case Game{core, ss, lives, t}:
      Game{G.set_right(core, held), ss, lives, t}

def shot_rects(ss: +List<Shot>, rest: +List<R.Rect>) -> +List<R.Rect>:
  match ss:
    case Nil{}:
      rest
    case Con{Shot{x, y}, more}:
      R.Rect{x, y, 2, 6, yellow()} <> shot_rects(more, rest)

def scene(g: Game) -> +List<R.Rect>:
  match g:
    case Game{core, ss, lives, t}:
      T.text(Nat.show(lives), 244, 242, white(),
        shot_rects(ss, Top.scene(core)))

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
    case Con{Key{114, True{}}, rest}:
      tick(rest, Game.new())
    case Con{Key{32, True{}}, rest}:
      tick(rest, fire(g))
    case Con{Key{63234, down}, rest}:
      tick(rest, set_left(g, down))
    case Con{Key{63235, down}, rest}:
      tick(rest, set_right(g, down))
    case Con{_, rest}:
      tick(rest, g)

def main() -> IO(Unit):
  App.run(~Game, ~App{+g => view(g), tick}, "Space Invaders in Bend", 256,
    256, Game.new())
