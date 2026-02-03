# Pinforge Prototype (Godot 4.5.1)

Code-first Plinko/Peggle-style roguelite starter that runs on desktop and mobile with no art assets.

## Current prototype features

- One procedural board layout with 3 peg types:
  - Damage peg
  - Gold peg
  - Multiplier peg
- 3 pocket effects:
  - Refund (+1 ammo)
  - Crit (double multiplier)
  - Cashout (convert multiplier to gold)
- Simple fight loop:
  - Drop ball
  - Build damage/gold/multiplier from peg hits
  - Resolve turn when ball settles
  - Enemy attacks when ammo is empty
  - Board rebuilds on enemy defeat
- Cross-platform controls:
  - Desktop: A/D or Left/Right + Space/Enter
  - Mobile: drag to aim + large touch buttons

## Run

1. Open this folder in Godot 4.5.1
2. Run `scenes/Main.tscn`

## Next suggested steps

1. Add ball mods (Split, Greed, Vamp) via upgrade picks.
2. Add enemy mechanics (Shield Snail, Tax Collector).
3. Add run map (fight/event/shop/boss nodes).
