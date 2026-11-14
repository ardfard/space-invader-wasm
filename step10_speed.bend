import Base
import ./fleet.bend as F
import ./hits.bend as H
import ./step06_hits.bend as G
import ./step08_lives.bend as L
import ./step09_shields.bend as W

# Step 9's game, but the fleet speeds up as invaders die: one step per
# frame with a full fleet, up to four with two or fewer left.

# How many invaders are alive.
def count(iv: +List<H.Inv>) -> U32:
  match iv:
    case Nil{}:
      0
    case Con{i, rest}:
      (count(rest) + 1 : U32)

# One more step if fast is True.
def faster(fast: Bool, n: Nat) -> Nat:
  match fast:
    case True{}:
      1n+n
    case False{}:
      n

# Extra steps per frame for this many invaders left.
def extra(+left: U32) -> Nat:
  faster((left <= 20 : U32),
    faster((left <= 8 : U32), faster((left <= 2 : U32), 0n)))

# The extra steps, only while the game is being played.
def hurry(ph: G.Phase, +iv: +List<H.Inv>, f: F.Fleet) -> F.Fleet:
  match ph:
    case G.Playing{}:
      H.march(extra(count(iv)), iv, f)
    case G.Won{}:
      f
    case G.Lost{}:
      f

def speed_up(g: W.Game) -> W.Game:
  match g:
    case W.Game{p, blocks}:
      match p:
        case L.Game{core, ss, lives, t}:
          match core:
            case G.Game{+ph, s, f, +iv, score}:
              W.Game{L.Game{G.Game{ph, s, hurry(ph, iv, f), iv, score}, ss,
                  lives, t}, blocks}

def step(g: W.Game) -> W.Game:
  speed_up(W.step(g))

def tick(events: List<Event>, g: W.Game) -> IO(Maybe<W.Game>):
  match events:
    case Nil{}:
      IO.pure(Maybe<W.Game>, Some{step(g)})
    case Con{Close{}, rest}:
      IO.pure(Maybe<W.Game>, None{})
    case Con{Key{27, True{}}, rest}:
      IO.pure(Maybe<W.Game>, None{})
    case Con{Key{114, True{}}, rest}:
      tick(rest, W.Game.new())
    case Con{Key{32, True{}}, rest}:
      tick(rest, W.fire(g))
    case Con{Key{63234, down}, rest}:
      tick(rest, W.set_left(g, down))
    case Con{Key{63235, down}, rest}:
      tick(rest, W.set_right(g, down))
    case Con{_, rest}:
      tick(rest, g)

def main() -> IO(Unit):
  App.run(~W.Game, ~App{+g => W.view(g), tick}, "Space Invaders in Bend",
    256, 256, W.Game.new())
