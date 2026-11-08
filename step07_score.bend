import Base
import ./render.bend as R
import ./font.bend as T
import ./step06_hits.bend as G

# Step 6's game plus the score under the ground line, and R to start over.
# The score turns green on a win and red on a loss.

def white() -> U32:
  16777215

# R starts a new game, whatever state the old one was in.
def restart(g: G.Game) -> G.Game:
  G.Game.new()

def phase_color(ph: G.Phase) -> U32:
  match ph:
    case G.Playing{}:
      white()
    case G.Won{}:
      G.green()
    case G.Lost{}:
      G.red()

def Game.phase(g: G.Game) -> G.Phase:
  match g:
    case G.Game{phase, p, f, iv, score}:
      phase

def scene(+g: G.Game) -> +List<R.Rect>:
  T.text(Nat.show(G.Game.score(g)), 4, 242, phase_color(Game.phase(g)),
    G.scene(g))

def view(+g: G.Game) -> Pair(G.Game, Image):
  (g, R.draw(scene(g)))

def tick(events: List<Event>, g: G.Game) -> IO(Maybe<G.Game>):
  match events:
    case Nil{}:
      IO.pure(Maybe<G.Game>, Some{G.step(g)})
    case Con{Close{}, rest}:
      IO.pure(Maybe<G.Game>, None{})
    case Con{Key{27, True{}}, rest}:
      IO.pure(Maybe<G.Game>, None{})
    case Con{Key{114, True{}}, rest}:
      tick(rest, restart(g))
    case Con{Key{32, True{}}, rest}:
      tick(rest, G.fire(g))
    case Con{Key{63234, down}, rest}:
      tick(rest, G.set_left(g, down))
    case Con{Key{63235, down}, rest}:
      tick(rest, G.set_right(g, down))
    case Con{_, rest}:
      tick(rest, g)

def main() -> IO(Unit):
  App.run(~G.Game, ~App{+g => view(g), tick}, "Space Invaders in Bend", 256,
    256, G.Game.new())
