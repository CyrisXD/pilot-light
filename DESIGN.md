---
name: Pilot Light
description: A night desk where one MacBook closes its lid and a single pilot flame stays lit.
colors:
  ink: "#05070C"
  night: "#0A1020"
  well: "#0B111C"
  track: "#111827"
  rule: "#1A2232"
  text: "#F2F4F8"
  muted: "#A3ACBB"
  dim: "#7A8392"
  flame: "#FF8A3D"
  flame-hover: "#FFA25E"
  flame-soft: "#FFB070"
  flame-ember: "#1A0B02"
  menu-highlight: "#C2551B"
  slate: "#5C6F92"
  alu-1: "#D9DDE3"
  alu-2: "#AEB4BD"
  alu-3: "#7D848F"
typography:
  display:
    fontFamily: "-apple-system, BlinkMacSystemFont, \"SF Pro Display\", \"SF Pro Text\", \"Helvetica Neue\", Helvetica, sans-serif"
    fontSize: "clamp(44px, 7.2vw, 88px)"
    fontWeight: 700
    lineHeight: 1.02
    letterSpacing: "-0.03em"
  headline:
    fontFamily: "-apple-system, BlinkMacSystemFont, \"SF Pro Display\", \"SF Pro Text\", \"Helvetica Neue\", Helvetica, sans-serif"
    fontSize: "clamp(36px, 4.6vw, 56px)"
    fontWeight: 700
    lineHeight: 1.05
    letterSpacing: "-0.03em"
  title:
    fontFamily: "-apple-system, BlinkMacSystemFont, \"SF Pro Display\", \"SF Pro Text\", \"Helvetica Neue\", Helvetica, sans-serif"
    fontSize: "clamp(28px, 3vw, 40px)"
    fontWeight: 700
    lineHeight: 1.1
    letterSpacing: "-0.02em"
  reading:
    fontFamily: "-apple-system, BlinkMacSystemFont, \"SF Pro Display\", \"SF Pro Text\", \"Helvetica Neue\", Helvetica, sans-serif"
    fontSize: "19px"
    fontWeight: 400
    lineHeight: 1.5
  lede:
    fontFamily: "-apple-system, BlinkMacSystemFont, \"SF Pro Display\", \"SF Pro Text\", \"Helvetica Neue\", Helvetica, sans-serif"
    fontSize: "clamp(18px, 1.6vw, 22px)"
    fontWeight: 400
    lineHeight: 1.45
  reading-figure:
    fontFamily: "-apple-system, BlinkMacSystemFont, \"SF Pro Display\", \"SF Pro Text\", \"Helvetica Neue\", Helvetica, sans-serif"
    fontSize: "clamp(44px, 5vw, 72px)"
    fontWeight: 700
    lineHeight: 1
    letterSpacing: "-0.03em"
    fontFeature: "\"tnum\""
  label:
    fontFamily: "-apple-system, BlinkMacSystemFont, \"SF Pro Display\", \"SF Pro Text\", \"Helvetica Neue\", Helvetica, sans-serif"
    fontSize: "13px"
    fontWeight: 400
    lineHeight: 1.5
  mono:
    fontFamily: "ui-monospace, \"SF Mono\", SFMono-Regular, Menlo, Consolas, monospace"
    fontSize: "14px"
    fontWeight: 400
    lineHeight: 1.8
rounded:
  pill: "999px"
  well: "14px"
  meter: "7px"
  row: "7px"
  focus: "6px"
spacing:
  gutter: "24px"
  container: "1080px"
  nav-height: "52px"
  section: "clamp(80px, 12vh, 140px)"
  section-open: "clamp(96px, 16vh, 180px)"
  column-gap: "56px"
components:
  button-primary:
    backgroundColor: "{colors.flame}"
    textColor: "{colors.flame-ember}"
    rounded: "{rounded.pill}"
    padding: "0 24px"
    height: "48px"
  button-primary-hover:
    backgroundColor: "{colors.flame-hover}"
    textColor: "{colors.flame-ember}"
  nav-pill:
    backgroundColor: "{colors.flame}"
    textColor: "{colors.flame-ember}"
    rounded: "{rounded.pill}"
    padding: "0 14px"
    height: "30px"
  text-link:
    textColor: "{colors.flame-soft}"
    height: "44px"
  menu-row-lit:
    backgroundColor: "{colors.menu-highlight}"
    textColor: "{colors.text}"
    rounded: "{rounded.row}"
    padding: "0.48em 0.7em"
  code-well:
    backgroundColor: "{colors.well}"
    textColor: "{colors.text}"
    rounded: "{rounded.well}"
    padding: "22px 24px"
    typography: "{typography.mono}"
  meter:
    backgroundColor: "{colors.track}"
    rounded: "{rounded.meter}"
    height: "14px"
---

# Design System: Pilot Light

## Overview

**Creative North Star: "The Night Desk"**

A dark room, one aluminium MacBook on the desk, and a single pilot flame that stays lit after the lid closes. The page is one long, scroll-scrubbed product story in the Apple product-page manner: a pinned stage where the visitor closes the lid by scrolling and watches the whole-Mac power reading fall, followed by quieter full-width chapters (the hours, the positioning paragraph, the real menu, specs, install). Density is low; type is very large and very tight; every section is a single idea on a near-black field.

Depth comes from the machine and the macOS materials, not from page chrome. The MacBook is built in CSS 3D with brushed-aluminium gradients, the app UI is rendered as translucent menu-bar material, and atmosphere comes from two radial glows on the stage (a cool screen glow that dies as the lid shuts, a warm flame glow that rises as it lights). Everything else is flat ink divided by hairline rules.

Proof is the visual content. Numbers are set as display type with tabular figures and a superscript footnote marker; the footnotes carry the measurement method.

**Key Characteristics:**
- Near-black ink fields with a midnight floor gradient, never pure black or a grey surface.
- One warm accent, pilot-flame orange, against an otherwise cool palette.
- System SF stack at bold 700 with -0.03em tracking for every headline; SF Mono only for terminal and code.
- Sticky, scroll-linked stages and eased fade-ups; a full static fallback under Reduce Motion.
- No cards: content sits in rows, definition lists and grids separated by 1px rules.

## Colors

A cool night palette of inks and aluminium greys, warmed by exactly one orange family.

### Primary
- **Pilot Flame** (`flame`): the primary action fill (Download button and nav pill), the lit lid-closed figure (4.8 W in specs, timeline bar, final watt readout), the lid emblem glow, the accented phrase in each big headline, the install step-number rings, focus ring, text selection and caret.
- **Flame Hover** (`flame-hover`): hover fill for primary buttons and the nav pill.
- **Flame Soft** (`flame-soft`): inline links, the "Read the source" text link, the step numerals, terminal prompt glyph.
- **Ember** (`flame-ember`): text on any flame fill; never white on orange.
- **Menu Highlight** (`menu-highlight`): the macOS menu-row selection on the feature menu; a deeper burnt orange so white text holds contrast.

### Neutral
- **Ink** (`ink`): page background, `theme-color`, nav glass tint (at 72% alpha).
- **Night** (`night`): the bottom of the pinned stage's vertical gradient, the desk floor.
- **Well** (`well`): recessed code block background.
- **Track** (`track`): empty meter track.
- **Rule** (`rule`): every section divider, spec row divider, code-block border.
- **Paper White** (`text`): headings and primary copy.
- **Muted** (`muted`): ledes, body paragraphs under headings, spec labels, nav links.
- **Dim** (`dim`): meta line, unlit reveal words, tick labels, footnotes, captions.
- **Slate** (`slate`): the lid-open comparison bar; the cool "before" state set against flame's "after".
- **Aluminium 1–3** (`alu-1`, `alu-2`, `alu-3`): reserved for the machine. The CSS MacBook uses literal aluminium gradients in this range (#B9BFC8 to #D3D8DF body, #6D747F to #9DA4AE edges).

### Named Rules
**The One Flame Rule.** Orange is the only warm hue on the page and it always means "lit": the action, the lid-closed result, or the phrase that carries the promise. Everything that is not lit is ink, grey or aluminium.

**The Dark Text On Flame Rule.** Any flame fill carries Ember text (`#1A0B02`); the only white-on-orange surface is the deeper Menu Highlight.

## Typography

**Display Font:** System SF stack (-apple-system, SF Pro Display, falling back to Helvetica Neue)
**Body Font:** Same system SF stack
**Label/Mono Font:** ui-monospace / SF Mono (Menlo, Consolas fallback)

**Character:** One family doing everything, at two extremes: enormous, bold, tightly tracked headlines and calm 19px reading text. Mono appears only where a Mac would show mono.

### Hierarchy
- **Display** (700, clamp 44–88px, 1.02, -0.03em): the hero headline, max 14ch, balanced wrap. Sibling sizes on the same voice: the "3.5× less power" statement (clamp 40–80px), the scroll captions (clamp 36–68px) and the word-reveal paragraph (clamp 32–58px, -0.025em).
- **Headline** (700, clamp 36–56px, 1.05, -0.03em): section heads such as "Small enough to read." and "Set up in a minute."
- **Title** (700, clamp 28–40px, 1.1, -0.02em): feature headings beside the menu.
- **Reading figure** (700, clamp 44–72px, tabular figures): the live watt readout and the big spec values (clamp 36–52px); units drop to 0.45em.
- **Lede** (400, clamp 18–22px, 1.45): the one line under a headline, muted, max 34–36em, pretty wrap.
- **Body** (400, 19px, 1.5): feature and section copy, max ~30em.
- **Label** (400–600, 13px): nav links, readout states, menu captions, footnotes.
- **Mono** (400, 14px, 1.8): build-from-source code well, terminal on the MacBook screen, timeline tick labels at 12px.

### Named Rules
**The Tight Bold Rule.** Every heading is weight 700 with negative tracking (-0.02em to -0.03em) and balanced wrapping. No light or thin display weights.

**The Accent Phrase Rule.** A big headline may colour one closing phrase in Pilot Flame (a `span` or `em`); never more than one phrase, never a whole headline.

## Layout

A single centred column, max 1080px with 24px gutters, under a 52px sticky glass nav. The opening is a pinned stage 520vh tall whose sticky 100svh viewport holds the hero, three scroll captions, the CSS MacBook and the watt readout; scroll progress drives every transform. At 1100px and wider the readout moves to a right-side column; below that it sits centred under the machine.

After the stage, sections are full-width chapters with generous vertical padding (clamp 80–140px for specs and install, up to clamp 96–180px for the open chapters). Two-column grids appear only for the features (menu sticky at left, feature list at right, 64px gap) and install (steps and code, 56px gap); both collapse to one column at 860px. Spec rows are a label/value grid (160–260px label column) that stacks at 640px. Nav links hide at 640px, leaving brand and Download pill.

Motion grammar: scroll-linked transforms on sticky stages, word-by-word brightening on the positioning paragraph, menu rows lighting as each feature crosses mid-viewport, and one-time eased fade-ups (28px, 1s) for supporting copy. Reduce Motion unpins the stage, shows the open Mac and readout statically, lights all words and drops transitions.

## Elevation & Depth

The page itself is flat: ink fields and 1px rules. Depth is reserved for objects that are physically deep or are macOS material. The CSS MacBook gets a blurred contact shadow that shrinks as the lid closes and a specular sweep across the lid back; app UI (screen menu, terminal window, the large feature menu, the nav) uses translucent backgrounds with backdrop blur and soft, long drop shadows. Atmosphere is light, not shadow: radial glows on the stage behind the machine.

### Shadow Vocabulary
- **Menu float** (`box-shadow: 0 30px 60px -20px rgba(0,0,0,.7)`): the large feature menu panel.
- **Window float** (`box-shadow: 0 1.6em 3em rgba(0,0,0,.45)`): windows and menus on the MacBook screen.
- **Contact shadow** (blurred ellipse, `rgba(0,0,0,.55)`, blur 3.5% of machine width): under the MacBook only.
- **Flame glow** (`drop-shadow(0 0 2% rgba(255,122,46,.9))` stacked with a wider 0.55 layer): the lid emblem once lit.

### Named Rules
**The Material Not Chrome Rule.** Blur, translucency and shadow belong to the machine and to macOS surfaces (nav glass, menus, windows). Page sections, specs and steps stay flat on ink.

## Shapes

Two shape families. Interactive controls are full pills (999px). macOS surfaces keep macOS radii: menu panels 14px with 7px row highlights, code well 14px, meter tracks 7px, terminal window 0.6em. The machine is scaled geometry: every MacBook radius is a fraction of its width so it stays proportionate at any size. Install step numerals sit in 36px outlined circles. Dividers are 1px hairlines in Rule; nothing else carries a border except glass panels (1px white at 6–12% alpha).

## Components

### Buttons
- **Shape:** full pill (999px).
- **Primary:** Pilot Flame fill, Ember text, 17px weight 600, 48px min height, 24px side padding, optional 18px download glyph at 10px gap.
- **Hover / Focus:** fill shifts to Flame Hover and lifts 1px over 0.3s on the expo-out ease; focus is the global 2px flame outline at 4px offset.
- **Nav pill:** the same recipe at 30px tall, 13px text, 14px padding.
- **Text link:** Flame Soft, 17px, no underline until hover, 44px tap height, trailing chevron.

### Navigation
Sticky 52px bar on Ink at 72% alpha with saturate(180%) blur(20px) and a 6% white bottom hairline. Brand (28px app icon plus "Pilot Light", 19px/600) at left, 13px Muted links that brighten to Paper White on hover, Download pill at right. Links hide under 640px.

### Live Readout
The watt figure counts down from 16.7 to 4.8 W as the lid closes, in Reading-figure type with tabular numerals, turning Pilot Flame when it lands. Beneath it, small Muted labels ("Screen", "Low Power", "Agents") with bold Paper White states that flip as the scroll passes each event, and a footnoted "whole-Mac power draw" caption.

### macOS Menu (signature)
A faithful translucent menu: rgba(40,45,58,.72) with blur(24px), 1px 12% white border, 14px radius, Menu float shadow, 0.5em inner padding. Rows carry a check glyph or an equal-width spacer so labels align, a chevron for submenus, Muted label rows for readings, and 1px separators. The row matching the feature in view takes the Menu Highlight fill with near-white text, transitioning over 0.45s. Rows wrap under 860px.

### Battery Meter
14px track in Track colour with 7px radius; the fill grows to its share of a 24-hour scale as it enters the viewport. Lid-open fill is Slate, lid-closed fill is Pilot Flame. Labels to the left (bold state, Muted figure), mono hour ticks below.

### Spec Rows
A definition list: Muted 17px label, 21px/600 value with a Muted 15px qualifier underneath, each row topped by a Rule hairline. Headline numbers use Reading-figure type; the lid-closed number is Pilot Flame.

### Code Well
Recessed block on Well with a 1px Rule border, 14px radius, 22px/24px padding, SF Mono 14px at 1.8 line height.

### CSS MacBook (signature)
An aluminium laptop built from transformed boxes: deck, keyboard grid, trackpad, hinge, lip and a lid that rotates from -12deg to -89.4deg with scroll. Its screen shows a dark-blue wallpaper with a warm horizon, a macOS menu bar, a terminal running an agent and the open Pilot Light menu. As the lid shuts the screen dims to black, the keyboard fades, a specular light sweeps the lid back and the flame emblem lights with a warm glow.

## Do's and Don'ts

### Do:
- **Do** keep every page field on Ink or the Ink-to-Night gradient, separated by 1px Rule hairlines.
- **Do** reserve Pilot Flame for lit things: the primary action, the lid-closed result, one accent phrase per headline, focus.
- **Do** set every measured number in tabular figures with a superscript footnote to its method.
- **Do** set headings in the system SF stack at 700 with -0.02em to -0.03em tracking and balanced wrapping.
- **Do** render app UI as real macOS material (translucent, blurred, macOS radii), not as a styled card.
- **Do** give every scroll-linked effect a static Reduce Motion state that reads completely.

### Don't:
- **Don't** introduce a second accent hue or a light theme; the palette is a night palette.
- **Don't** put content in bordered or shadowed cards; use rows, lists and grids on ink.
- **Don't** add eyebrow or kicker labels above headlines.
- **Don't** use white text on Pilot Flame; use Ember.
- **Don't** apply blur, glass or drop shadows to page sections; depth is for the machine and macOS surfaces.
- **Don't** ship Apple-owned imagery or font files; the system stack resolves to SF on a Mac.
