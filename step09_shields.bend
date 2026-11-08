import Base
import ./render.bend as R
import ./step04_shoot.bend as S
import ./step06_hits.bend as G
import ./step08_lives.bend as L
import ./shields.bend as Sh

# Step 8's game plus four shields. Bullets and invader shots that touch a
# shield block destroy it and are destroyed with it.

def green() -> U32:
  4259648

type Game is Data:
  Game{play: L.Game, blocks: +List<Sh.Blk>}

def Game.new() -> Game:
  Game{L.Game.new(), Sh.all_blocks()}

# After step 8's frame: projectiles and blocks that touch destroy each other.
def settle(g: L.Game, +blocks: +List<Sh.Blk>) -> Game:
  match g:
    case L.Game{core, +ss, lives, t}:
      match core:
        case G.Game{ph, p, f, iv, score}:
          match p:
            case S.Game{s, +bs}:
              Game{L.Game{G.Game{ph, S.Game{s, Sh.free_bullets(bs, blocks)}, f,
                  iv, score}, Sh.free_shots(ss, blocks), lives, t},
                Sh.chip(blocks, Sh.boxes(bs, ss))}

def step(g: Game) -> Game:
  match g:
    case Game{p, blocks}:
      settle(L.step(p), blocks)

def fire(g: Game) -> Game:
  match g:
    case Game{p, blocks}:
      Game{L.fire(p), blocks}

def set_left(g: Game, held: Bool) -> Game:
  match g:
    case Game{p, blocks}:
      Game{L.set_left(p, held), blocks}

def set_right(g: Game, held: Bool) -> Game:
  match g:
    case Game{p, blocks}:
      Game{L.set_right(p, held), blocks}

def block_rects(bs: +List<Sh.Blk>, rest: +List<R.Rect>) -> +List<R.Rect>:
  match bs:
    case Nil{}:
      rest
    case Con{Sh.Blk{x, y}, more}:
      R.Rect{x, y, Sh.blk(), Sh.blk(), green()} <> block_rects(more, rest)

def scene(g: Game) -> +List<R.Rect>:
  match g:
    case Game{p, blocks}:
      block_rects(blocks, L.scene(p))

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
