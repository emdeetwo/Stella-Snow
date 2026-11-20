# Stella's Snow 3.0

A menu bar app for macOS that turns the desktop into a snow day. Built in
Swift with SpriteKit. No network, no analytics, no ads, no permissions to
grant.

## What she can do

- **Watch it snow, for real.** Three depths of snow: tiny far flakes behind
  everything, the main snowfall, and big soft out-of-focus flakes drifting
  past "the lens." A few are real six-armed crystals. Wind gusts come and
  go. Swish the pointer fast and the snow scatters.
- **Snow piles up everywhere.** In drifts along the bottom of the screen
  (they sparkle), on top of every open window, and on the Dock. Close or
  minimize a window and its snow falls off in clumps that land in the drift
  below, or on a lower window. Yank a window down and half slides off.
- **Build snowmen.** Press on the snow at the bottom and drag to roll a
  snowball. It only grows where there's snow, so roll through the deep
  parts. Drop one ball on another to stack (biggest always ends up on the
  bottom). Three makes a snowman with his own random scarf color and hat
  (top hat, beanie, or earmuffs). He thanks her by name. Her snowmen are
  saved and are still there next time. Drag one off the edge of the screen
  to say goodbye.
- **The snowman.** Breathes, blinks, waves. His eyes and carrot follow the
  pointer. Click him to say hi; three quick clicks and he sneezes.
- **The yeti.** Every few minutes he walks in leaving footprints, tiptoes up
  to the snowman, looks right at her, winds up and shoves him apart (the
  balls roll away, then hop back together one at a time, hat last). Then he
  scoops three snowballs and throws them at the screen. They splat on the
  glass and slowly slide down. Click a splat to wipe it off. Click the yeti
  to bonk him with a snowball and he runs away.
- **Click the desktop** to throw a snowball into the scene.
- **Snowplough.** A little red truck scrapes the ground clean, pushing a
  growing wave of snow, and shakes the snow off the windows as it passes.
- **Let it snow!** A 20-second blizzard.

- **December presents.** Every day from Dec 1 to 25 a wrapped present
  waits on the snow (missed days wait too). Unwrapping gives something new:
  hats, glasses, bow ties, or decorations like a little tree, an igloo, a
  snow puppy, and a golden star on Christmas.
- **The closet.** Click the wooden trunk on the snow. Drag hats, glasses
  and bow ties onto any snowman; drag decorations onto the snow. With the
  closet open, drag something off a snowman to take it back.
- **Snowball fight.** Hit the yeti and he fights back, throwing at the
  pointer (dodge!). He ducks behind snowmen. 40 seconds, first to 7 wins.
- **Frost.** Leave the Mac alone for a minute and frost creeps in from
  the edges of the screen. Draw in it with the pointer.
- **Snow globe.** Shake the pointer back and forth fast.
- **Friends.** A penguin pops up on a window and belly-slides off it; a
  cardinal lands on the snow and flies off if the pointer gets close.
- **Badges.** 18 to earn, shown in the menu, celebrated when earned.
- **Special days.** Christmas Eve night: Santa's sleigh crosses the sky.
  Christmas morning: a Merry Christmas greeting. Dec 26: birthday confetti,
  balloons to pop, a party hat, and the yeti brings a cake. New Year's Eve:
  fireworks, with a finale at midnight.
- **Sneak peeks.** Hold Option while clicking the snowflake to preview any
  of the above.
- **The animated house.** The holiday house loop plays behind the desktop
  icons (the tree glows red, then green). Its first frame is also set as the
  real wallpaper, so the Mac still looks right when the app is quit.

Menu bar snowflake: snowfall, wind, and flake size sliders, the buttons
above, snowman and yeti switches, animated house, house wallpaper, open at
login, the name the snowman says hi to, Pause, Quit.

## Updates (from GitHub)

One-time setup on her Mac, in Terminal:

    git clone https://github.com/emdeetwo/Stella-Snow.git ~/StellaSnow
    bash ~/StellaSnow/install.sh

(It asks for a username and password: the username is `emdeetwo`, the
password is a read-only access token for this repo. macOS remembers it.)

After that, every update is one command:

    bash ~/StellaSnow/update.sh

## Get it running (Terminal, no App Store)

First, check what her Mac has. In Terminal:

    xcode-select -p; sw_vers -productVersion

- **It prints a folder path** (like `/Library/Developer/CommandLineTools`):
  the Swift compiler is there. `cd` into this folder and run
  `bash install.sh`. It builds the app (about a minute), installs it in her
  own Applications folder (no admin password), and opens it.
- **It says "unable to get active developer directory"** (or a window pops
  up offering to install tools): no compiler. Run `bash build.sh` on any Mac
  that has Xcode, AirDrop the `StellaSnow.app` it makes into this folder on
  her Mac, then run `bash install.sh` there. The app is built for both Apple
  silicon and Intel, so any Mac works for building.
- The second number is her macOS version. It needs 14 (Sonoma) or newer.

**Nothing works:** double-click `StellaSnow.html` (keep `Wallpaper.jpg` and
`HouseLoop.mp4` next to it). It opens in Safari with the animated house,
snow, snowman, yeti and snowball play, with pretend windows instead of her
real ones. Control-Command-F for full screen.

With Xcode, `StellaSnow.xcodeproj` also opens and runs with Cmd+R.

## How it behaves on the Mac

- Clicks go straight through to the desktop everywhere except on things she
  can grab (snowman, yeti, snowballs, the ground snow, splats). Desktop icons
  still work.
- Playing with the snow never steals focus from the app in front.
- It stops drawing completely when nothing is visible (a full-screen app, a
  window covering the screen, the display asleep), and halves the snow in
  Low Power Mode. Easy on the battery.
- The house becomes the real wallpaper on first launch. Switching "House
  wallpaper" off puts back the previous wallpaper.
- The video pauses whenever the snow pauses (hidden, asleep, or Pause), and
  it never keeps the screen from sleeping.
- Main display only.

## Honest note

This was written on Linux. Every file except the two SwiftUI views
(`ControlsView.swift`, `StellaSnowApp.swift`) was compiled through the Swift
6 compiler's type checker and definite-initialization pass against
hand-written AppKit/SpriteKit stand-ins, and the web version was run and
screenshotted in Chrome. It has not been compiled with Apple's SDK yet. The
first real build happens on the MacBook Air. If Xcode or `build.sh` shows an
error, send back the exact error text and it gets fixed.

## Files

- `StellaSnowApp.swift`: app entry, menu bar, overlay window, battery and sleep handling
- `SnowScene.swift`: snowfall, drifts, window piles, snowball play, plough
- `SnowmanNode.swift`: the snowman (and the ones she builds)
- `YetiNode.swift`: the yeti
- `PloughNode.swift`: the snowplough truck
- `WindowTracker.swift`: reads window frames (frames only, never pixels)
- `OverlayWindow.swift`: the click-through desktop panel and the house video window
- `Textures.swift`: every texture, painted in code
- `Art.swift`: colors, drawing helpers, speech bubbles
- `Settings.swift`: saved settings, cabin wallpaper, open at login
- `ControlsView.swift`: the menu bar popover
- `StellaSnow.html`: the no-install web version
- `HouseLoop.mp4`, `Wallpaper.jpg` (its first frame), `AppIcon.icns`, `Info.plist`, `build.sh`
