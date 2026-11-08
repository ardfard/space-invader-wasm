import Base
import ./step03_ship.bend as Ship
import ./bullets.bend as B

# Laws are the human's spec; PROOF.bend proves each one.

# After any frame, the player's x keeps the whole ship on screen.
# x is a U32, so 0 <= x always holds; the law states the right edge:
# x <= 256 - ship width.
law ship_on_screen:
  for g: Ship.Game
  {U32.is_le(Ship.Game.x(Ship.step(g)), Ship.max_x()) == True{} : Bool}

# After any frame, every bullet left is on screen: a bullet that flies
# off the top is removed, never kept with a wrapped-around y.
law bullets_on_screen:
  for bs: +List<B.Bullet>
  {B.all_on_screen(B.move(bs)) == True{} : Bool}
