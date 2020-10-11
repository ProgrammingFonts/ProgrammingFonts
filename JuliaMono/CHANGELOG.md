# Changelog

## [v0.018] forthcoming

### Added

### Changed

- numerous fixes for glyphs #49 (Thanks DSCorbett)
- small vertical shift for `#` #52 (Thanks waldyrious)

### Removed

- some empty glyphs removed using complicated regex pattern... :(

### Deprecated

# ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

## [v0.017] 2020-09-29

### Added

### Changed

- fixed u02a7 tesh
- fixed u240E shift out
- fixed U1D2E2 mayan numeral 2

### Removed

### Deprecated

# ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

## [v0.016] 2020-09-26

### Added

### Changed

- fixed faulty axis weight setting
- tidied up some fractions
- more tweaking of Greek characters (one day George will be happy :)

### Removed

### Deprecated

# ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

## [v0.015] 2020-09-15

### Added

- JuliaMono-BoldLatin is a JuliaMono-Bold on a diet: only 330 glyphs!
- ss09 contains an allternate design for "f"

### Changed

### Removed

### Deprecated

# ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

## [v0.014] 2020-09-08

### Added

- `ss08` "Distinct Ligatures" is a stylistic set that inserts a small gap between the arrow ligature glyphs - ONLY if `calt` is not enabled

### Changed

- tweaked some Greek characters: Φϕφ
- removed <- ligature
- misc tweaking

### Removed

### Deprecated

# ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

## [v0.013] 2020-09-03

### Added

### Changed

- minor tweaks to subscripts, scripts, math operators
- fixed css errors in website

### Removed

### Deprecated

# ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

## [v0.012] 2020-09-01

### Added

### Changed

- typoascender set to 950
- fixed weird ligature bug with ->
- tweak designs of some script glyphs (WIP)

### Removed

### Deprecated

# ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

## [v0.011] 2020-08-31

### Added

- copied subscripts and superscripts to PUA F0000 temporarily (cf steven johnson's proposal)

### Changed


- typoascender set to 1000
- adjusted height of acute accented characters, perhaps will avoid some clipping on windows terminal
- minor adjustments to subscripts...

### Removed

### Deprecated

# ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

## [v0.010] 2020-08-27

### Added

- added ss07: smaller grave
- added Rrotundas

### Changed

- minor adjustments to glyphs
- updated specimen

### Removed

### Deprecated

# ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

## [v0.009] 2020-08-20

### Added

### Changed

- adjusted designs for Ψ and ψ to make them more different
- added \U1F7C0 -> \U1F7D8
- adjusted saltire

### Removed

### Deprecated

# ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

## [v0.008] 2020-08-15 00:00:00

### Added

- JuliaMono-RegularLatin is JuliaMono-Regular on a diet: only 330 glyphs!

### Changed

- tuning a few more blocks used by UnicodePlots
- planck \u210E and planck2π \u210F now have serifs
- website css changes to `@font-face`

### Removed

### Deprecated

# ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

## [v0.007] 2020-08-10 19:17:29

### Added

- some CI stuff: git tag v0.00x then git push origin --tag

### Changed

- tuned blocks for UnicodePlots use
- hbar, planck slanted
- tweaked vertical metrics, hoping it won't all go horribly wrong

### Removed

### Deprecated

# ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

## [v0.006] 2020-08-08 16:49:55

### Added

- tweaked tildes eg for ÃÑÕãñõĨĩŨũ to be slightly narrower and higher (#15, #18)

### Changed

- fraktur capitals simplified

### Removed

### Deprecated

# ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

## [v0.005] 2020-08-05 19:29:40

### Added

- alternate form for `::`
- punctuation is no longer case-sensitive (https://github.com/cormullion/juliamono/issues/8)

### Changed

### Removed

### Deprecated

# ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

## [v0.004] Some hints added

### Added

- Added some TrueType hinting instructions as an experiment.

- Aligned /< and /: more preciselyy (thanks Jeff!)

### Changed

### Removed

### Deprecated

# ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

## [v0.003] Started changelog

### Added

### Changed

I'm trying out a switch from CFF to TTF format, trading file
size (they got bigger)  for better cross-platform behaviour (Windows).

### Removed

### Deprecated

# ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
