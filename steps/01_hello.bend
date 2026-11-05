import Base

# A key press changes the color; Escape or closing the window quits.
def next_color(+c: U32) -> U32:
  ((c * 2654435761 : U32) .^. 16744512 : U32)

def tick(events: List<Event>, color: U32) -> IO(Maybe<U32>):
  match events:
    case Nil{}:
      IO.pure(Maybe<U32>, Some{color})
    case Con{Close{}, rest}:
      IO.pure(Maybe<U32>, None{})
    case Con{Key{27, True{}}, rest}:
      IO.pure(Maybe<U32>, None{})
    case Con{Key{_, True{}}, rest}:
      tick(rest, next_color(color))
    case Con{_, rest}:
      tick(rest, color)

def main() -> IO(Unit):
  App.run(~U32, ~App{+s => (s, Pix{s}), tick}, "Step 1: hello", 256, 256, 2113664)
