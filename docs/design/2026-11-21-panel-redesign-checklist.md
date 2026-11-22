# Manual checklist: panel redesign (0.2)

Things the automated tests cannot check. Run through them on a real build before releasing 0.2.
Use a build made with `scripts/build-app.sh` and sample clips only.

## Setup
- [ ] If you are upgrading from a build with a different bundle identifier (before 0.1.0), grant the Accessibility
      permission again.
- [ ] Copy a few texts, a link, a code snippet and several screenshots so every row type exists.

## Look
- [ ] macOS 26, light mode: Liquid Glass shell looks right; the shadow follows the rounded corners (no square halo).
- [ ] macOS 26, dark mode: same checks.
- [ ] Text and previews never sit directly on glass; over a busy wallpaper everything stays readable.
- [ ] Hover on glass: row hover and chip hover are visible and calm.
- [ ] macOS 15 (if a machine is available): fallback look is clean; the segmented filter control works.
- [ ] Reduce Transparency: panel is opaque and readable.
- [ ] Reduce Motion: no sliding or fading animations.
- [ ] Increase Contrast: borders, selection and secondary text are clearly visible.

## Mouse and focus
- [ ] In TextEdit, Safari and Terminal: start typing, then click a row, a filter chip and the clear button, and open
      the context menu. Typing still goes to the search field, the target app never loses focus.
- [ ] After each of those, press Return or double click a row: the paste lands in that app.
- [ ] Control-click opens the context menu without also selecting or pasting the row.
- [ ] Context menu dismissed by clicking into another app: the panel closes and typing stays in that app.
- [ ] Context menu dismissed by clicking on the panel or choosing an item: the panel stays open and focus is in the
      search field.
- [ ] Esc with the mouse pointer outside the panel closes it.
- [ ] Esc clears the search first, then closes.
- [ ] Right click: Paste, Copy, Pin, Delete and Ignore app each work.

## VoiceOver
- [ ] Each row reads its label plus the clip text.
- [ ] Selection changes are announced.
- [ ] Notices (for example "Ignoring Terminal") are announced.
- [ ] VoiceOver can press the segmented filter control (macOS 15 fallback and macOS 26).

## Menu bar menu
- [ ] Items read: Show Pastu, Pause Recording, Clear History…, Ignored Apps, About Pastu, Quit Pastu.
- [ ] Show Pastu displays ⌘⇧V; Pause Recording gets a checkmark while paused and the icon description says paused.
- [ ] Clear History… alert opens in front; About Pastu shows the standard panel with the right version.

## Performance
- [ ] Panel open latency with several screenshot clips in the history feels as fast as 0.1.
- [ ] Scrolling a long history loads more clips without a stutter.
