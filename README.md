# Real Rain v1.2.7

# Real Rain

**1.2.6 note:** added quick forced weather modes: rain only, thunder + rain, and full thunderstorm. Lightning keeps the nicer short blue-white flash, with no visible bolt sprite.

Real Rain adds AAA-style rain ambience to Nauvis with staged storm systems, layered rain sheets, gusting wind, tile-aware ground splashes, cinematic thunder layering, lightning, solar reduction, pollution washout, and fire extinguishing.

## Highlights

- Staged weather: drizzle, rain, heavy rain, storm, and rare monsoon events
- Layered foreground, midground, and mist rain FX
- Wind gust direction changes so storms feel alive
- Tile-aware splashes: harder on concrete, softer on dirt/grass, ripple-like on water
- Post-rain puddle ripples and drip ambience instead of hard stop/start weather
- Area-aware ambience around forests, factories, and water
- Bolt-free blue-white lightning flashes with linked thunder audio: distant rumbles, close cracks, rolling tails, and monsoon impacts
- Runtime presets: Subtle, Balanced, Storm, Monsoon
- Performance modes: Cinematic, Balanced, UPS Saver
- Optional solar reduction during rain
- Optional pollution cleanup while it rains
- Optional fire extinguishing with hiss FX
- Debug/admin commands:
  - `/real-rain status`
  - `/real-rain thunder`
  - `/real-rain clear 300`
  - `/real-rain drizzle 240`
  - `/real-rain rain 240` - rain only, no thunder/lightning
  - `/real-rain thunder-rain 240` - rain + thunder sounds, no lightning
  - `/real-rain thunderstorm 240` - rain + lightning flash + linked thunder
  - `/real-rain heavy 240`
  - `/real-rain storm 240`
  - `/real-rain monsoon 240`

## Notes

This build was created as a standalone Real Rain mod from the supplied Dynamic Rain reference package. The implementation is under the Real Rain namespace and expands the weather system with new staged weather logic, tile-aware effects, post-rain ambience, performance modes, and debug tooling.


## v1.2.0 thunder pass

This version adds a dedicated thunder sound pass. Close lightning now gets a punchier strike plus an optional delayed rolling tail, distant thunder is softer and lower, and monsoon weather can layer extra impacts and rumbles.

See `CREDITS.md` for sound source notes and Mixkit license references.


## v1.2.1 command pass

Admin/debug commands now include separate thunder, lightning, and full lightning-strike tests:

- `/real-rain thunder [far|close|roll|monsoon]` - play a thunder sound layer near the player.
- `/real-rain lightning [far|close]` - show lightning and play matching linked thunder.
- `/real-rain strike [far|close|monsoon]` - show lightning and trigger matching thunder.
- `/rrain` works as a shorter alias.


## Forced Weather Modes

Use these when testing the feel in-game:

```txt
/rrrain 300
/rrthunderrain 300
/rrstorm 300
/rrthunderstorm 300
```

- `/rrrain` = rain only. No thunder, no lightning.
- `/rrthunderrain` = rain with thunder sounds only. No lightning flash.
- `/rrstorm` / `/rrthunderstorm` = full thunderstorm. Rain, lightning flash, and linked thunder.

Long form commands also work:

```txt
/real-rain rain 300
/real-rain thunder-rain 300
/real-rain thunderstorm 300
```

## Debug / Test Commands

Use these in-game while testing:

```txt
/real-rain thunder close
/real-rain thunder roll
/real-rain lightning close
/real-rain strike close
/real-rain strike monsoon
/real-rain thunder-test
```

Short aliases are also available:

```txt
/rrthunder close
/rrlightning close
/rrstrike monsoon
/rrtest
```

`/real-rain thunder-test` plays far, close, rolling, and monsoon thunder in sequence so the whole thunder bank can be checked quickly.



## v1.2.3 hotfix

This version fixes the thunder/lightning command crash by safely clamping every runtime sound `volume_modifier` to Factorio's valid 0..1 range. Test with `/rrtest`, `/rrstrike close`, and `/rrlightning close`.
