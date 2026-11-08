import Base
import ./render.bend as R
import ./step03_ship.bend as Ship
import ./step04_shoot.bend as S
import ./fleet.bend as F
import ./hits.bend as H

# Bullets now destroy invaders, each worth 10 points. Shoot them all to
# win; the game is lost when an invader reaches the ship's row.
# A bar across the top turns green on a win and red on a loss.

def purple() -> U32:
  12611583

def red() -> U32:
  16724787

def green() -> U32:
  4259648

type Phase is Data:
  Playing{}
  Won{}
  Lost{}

type Game is Data:
  Game{phase: Phase, play: S.Game, fleet: F.Fleet, invs: +List<H.Inv>,
       score: Nat}

def Game.new() -> Game:
  Game{Playing{}, S.Game{Ship.Game{120, False{}, False{}}, []},
    F.Fleet{0, 24, True{}}, H.all_invaders(), 0n}

def Game.score(g: Game) -> Nat:
  match g:
    case Game{phase, p, f, iv, score}:
      score

# The ship's top edge; an invader whose bottom reaches it has landed.
def ship_top() -> U32:
  214

def any_low(iv: +List<H.Inv>, +fy: U32) -> Bool:
  match iv:
    case Nil{}:
      False{}
    case Con{+i, rest}:
      (ship_top() <= (H.inv_y(i, fy) + F.inv_h() : U32) : U32)
        || any_low(rest, fy)

def pick_phase(low: Bool, iv: +List<H.Inv>) -> Phase:
  match low:
    case True{}:
      Lost{}
    case False{}:
      match iv:
        case Nil{}:
          Won{}
        case Con{i, rest}:
          Playing{}

# Puts the frame back together after the hits are worked out.
def settle(h: H.Hits, s: Ship.Game, +fx: U32, +fy: U32, right: Bool,
           score: Nat) -> Game:
  match h:
    case H.Hits{points, bs, +iv}:
      Game{pick_phase(any_low(iv, fy), iv), S.Game{s, bs},
        F.Fleet{fx, fy, right}, iv, Nat.add(points, score)}

def advance(p: S.Game, f: F.Fleet, iv: +List<H.Inv>, score: Nat) -> Game:
  match p:
    case S.Game{s, bs}:
      match f:
        case F.Fleet{+fx, +fy, right}:
          settle(H.hits(bs, iv, fx, fy), s, fx, fy, right, score)

# One frame: everything moves, then bullets hit. Frozen once won or lost.
def step(g: Game) -> Game:
  match g:
    case Game{phase, p, f, iv, score}:
      match phase:
        case Playing{}:
          advance(S.step(p), F.step(f), iv, score)
        case Won{}:
          Game{Won{}, p, f, iv, score}
        case Lost{}:
          Game{Lost{}, p, f, iv, score}

def fire(g: Game) -> Game:
  match g:
    case Game{phase, p, f, iv, score}:
      Game{phase, S.fire(p), f, iv, score}

def set_left(g: Game, held: Bool) -> Game:
  match g:
    case Game{phase, p, f, iv, score}:
      Game{phase, S.set_left(p, held), f, iv, score}

def set_right(g: Game, held: Bool) -> Game:
  match g:
    case Game{phase, p, f, iv, score}:
      Game{phase, S.set_right(p, held), f, iv, score}

def inv_rects(iv: +List<H.Inv>, +fx: U32, +fy: U32, rest: +List<R.Rect>) ->
  +List<R.Rect>:
  match iv:
    case Nil{}:
      rest
    case Con{+i, more}:
      R.Rect{H.inv_x(i, fx), H.inv_y(i, fy), F.inv_w(), F.inv_h(), purple()}
        <> inv_rects(more, fx, fy, rest)

def banner(ph: Phase, rest: +List<R.Rect>) -> +List<R.Rect>:
  match ph:
    case Playing{}:
      rest
    case Won{}:
      R.Rect{0, 0, 256, 6, green()} <> rest
    case Lost{}:
      R.Rect{0, 0, 256, 6, red()} <> rest

def scene(g: Game) -> +List<R.Rect>:
  match g:
    case Game{phase, p, f, iv, score}:
      match f:
        case F.Fleet{fx, fy, right}:
          banner(phase, inv_rects(iv, fx, fy, S.scene(p)))

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
  App.run(~Game, ~App{+g => view(g), tick}, "Step 6: hits", 256, 256,
    Game.new())
