import Base
import ./step03_ship.bend as Ship
import ./bullets.bend as B
import ./fleet.bend as F
import ./hits.bend as H
import ./step06_hits.bend as G

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

# After any frame, the invader fleet stays within the screen's left and
# right edges: its left edge is at most 256 minus the block's width.
law fleet_on_screen:
  for f: F.Fleet
  {U32.is_le(F.Fleet.x(F.step(f)), F.max_x()) == True{} : Bool}

# The score never goes down: after any frame, the new score is the old
# score plus some natural number d (and a Nat is never negative).
law score_never_drops:
  for g: G.Game
  exs d: Nat
  {G.Game.score(G.step(g)) == Nat.add(d, G.Game.score(g)) : Nat}
