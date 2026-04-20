# Blade-Of-Order
A mobile action-platformer project in partial fulfillment of the requirements for the course Visual Graphics Design.

## Current Status
Initial Godot 4.6.1 vertical-slice scaffold is implemented for the Bubble Sort level:

- Project bootstrap and input map
- Mobile touch control HUD (move, jump, dash, attack)
- Greybox player controller with jump buffering, coyote time, dash, and attack states
- Greybox Bubble Sort boss placeholder with stun/resurrect loop
- Puzzle shell overlay with 3-mistake fail mechanic

## Tech Baseline
- Engine: Godot 4.6.1 (standard, non-.NET)
- Language: GDScript
- Platform focus: Android first

## Run Instructions
1. Open the folder in Godot 4.6.1.
2. If prompted, import and re-scan the project.
3. Run the main scene at `res://scenes/MainMenu/main_menu.tscn`.

## Test Loop (Current Prototype)
1. Use touch controls to move and jump.
2. Press Attack repeatedly to trigger temporary debug boss damage.
3. When boss HP reaches 0, the puzzle shell opens.
4. Press Simulate Wrong three times to force boss resurrection.
5. Press Simulate Correct to seal the boss.
