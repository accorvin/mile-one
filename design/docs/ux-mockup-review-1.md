# Mile One — UX Mockup Adversarial Review #1
*In-Run Experience: Timer, Walking, Post-Run Summary*

---

## Screen 1: Running Interval (01-in-run-timer.html)

### Readability While Running
- 🔴 **Countdown at 96px font-weight:200 (ultralight) will disappear in sunlight.** Thin white strokes on dark background wash out completely outdoors. Bump to font-weight 300-400 minimum, or use a slight text-shadow/glow.
- 🟠 **"REMAINING THIS INTERVAL" at 13px, rgba(255,255,255,.4)** — 40% opacity white on near-black is ~2.5:1 contrast ratio. Fails WCAG AA (4.5:1 required). Won't be readable while bouncing. Raise to at least .6 opacity.
- 🟠 **"Interval 5 of 8" and "62%" at 11px, rgba(255,255,255,.4)** — Same contrast issue, plus 11px is tiny. Not readable at a glance while running.
- ✅ The RUNNING badge at 15px with green color is good — distinctive, readable.
- ✅ Stats (Time/Miles/Pace) at 22px font-weight 600 are solid.

### Touch Targets
- 🔴 **Pause and End Run are only 16px apart (gap:16px between 72px circles).** During a run with sweaty fingers, accidentally hitting End Run when reaching for Pause is a real risk. These need **at least 40px separation**, or End Run should be moved to a completely different location (e.g., long-press, or behind a "..." menu).
- ✅ 72px button diameter is good — exceeds Apple's 44pt minimum.
- 🟡 The swipe dots (6px) are too small to be a tap target, but they're indicators not buttons, so that's fine.

### Glanceability
- ✅ **Excellent.** The RUNNING badge + big countdown is immediately clear. You know what you're doing and for how long in under 1 second.
- 🟡 The "Walk break in 1:43" chip duplicates the countdown information. Consider showing the NEXT interval's duration instead: "Walk 1:30 up next" — that's actually useful new info.

### Information Hierarchy
- ✅ Good hierarchy: badge → countdown → next interval → stats → controls
- 🟡 Progress bar competes slightly with the countdown for "what do I look at first." Consider making the progress section more subtle or moving it below stats.

### Color & Contrast
- 🟠 **Green (#4ade80) and blue (#60a5fa) are indistinguishable for deuteranopia (red-green colorblind ~8% of men).** Need a secondary differentiator — the text label helps, but add shape: e.g., up arrow ↑ for run, down arrow ↓ for walk, or a runner/walker icon in the badge.
- 🟡 The dark theme (#0a0a1a background) will be very hard to see in direct sunlight. Consider an auto-brightness boost during active runs, or offer a high-contrast/light mode for outdoor use.

### Missing States
- 🔴 **No warm-up or cool-down state shown.** Warm-up is the FIRST thing users see every run. It needs its own badge color/style — maybe yellow/amber with "WARM UP" label. Currently only RUNNING and WALKING exist.
- 🔴 **No paused state mockup.** What does the screen look like when paused? The pause button should toggle to a play/resume button. The countdown should freeze and possibly dim. The stats should show "PAUSED" somewhere prominent.
- 🟠 **No End Run confirmation dialog.** Requirements specify this. Need a modal: "End this run? Your progress will be saved." with Cancel / End Run buttons.
- 🟠 **No GPS-acquiring state.** Before the run starts, there should be a "Acquiring GPS..." indicator before the countdown begins.

---

## Screen 2: Walking Interval (02-in-run-walking.html)

### Same Issues as Screen 1 Plus:
- 🟡 **Encouragement text "You're doing great — almost there"** at rgba(255,255,255,.3) and font-style italic — 30% opacity italic is nearly invisible. If you're going to include encouragement, make it readable: at least .5 opacity, no italic (harder to read while moving).
- 🟡 The pulse animation is slower (2s vs 1.5s) for walking — nice subtle detail. But the size (10px) means most runners won't notice the distinction.
- ✅ Blue badge clearly differentiates from green running state.
- ✅ "Run starts in 0:47" with green color and up arrow — good anticipation cue.

### Emotional Design
- 🟠 **The encouragement text is generic and static.** "You're doing great — almost there" should be contextual: different messages for different points in the session. Early walk break: "Catch your breath." Final walk: "One more run — you've got this." This is a beginner app — motivation matters.

---

## Screen 3: Post-Run Summary (03-post-run-summary.html)

### Celebration
- 🟠 **"Nice work! 🎉" with a small green checkmark feels underwhelming for someone who just survived their first run.** Competitors (Nike Run Club) use full-screen animations, confetti, bold typography. This feels like completing a form, not finishing a run. Consider:
  - Larger celebration moment — full-width banner or animation
  - Personal touch: "You just ran 0.82 miles — that's further than last time!"
  - Progressive messaging: Week 1 = "You did it! First run done!" vs Week 9 = "5K RUNNER. 🏆"

### Layout
- ✅ Stats grid is clean and scannable. 28px values are readable.
- ✅ The distance card highlight (green border) draws the eye to the key stat.
- 🟡 **Map placeholder at 180px is quite small.** The GPS trace is the "proof I ran" — it's emotionally important. Make it taller (240-280px) or tappable to expand full-screen.
- 🟡 **Interval completion bar** (green/blue pips) is a nice touch but the colors are very small (6px high) and the green/blue distinction at that size won't register. Consider making them taller (10-12px) or adding run/walk icons.

### Effort Check-In
- ✅ **Three emoji buttons are great.** Clear, fast, low friction. "Just Right" selected state is clear.
- 🟡 "This helps you decide when to advance" — vague. Better: "We'll show this in your run history so you can track how sessions feel over time."
- 🟠 **No way to skip the effort check-in.** Some users will want to just tap "Done" without rating. The CTA button should work regardless of whether they've selected an effort level.

### Scrolling
- 🟠 **This screen likely requires scrolling on shorter iPhones (iPhone SE, iPhone 13 mini).** The content is ~750px tall in a ~798px viewport. With the notch/safe areas, it might clip. Test on smaller screens. The effort section could collapse or the map could be smaller on small phones.

---

## Cross-Screen Issues

### Swipe-to-Map
- 🔴 **Two tiny dots (6px) with no label is not enough to indicate swipeable content.** Most beginners won't discover the map view. Add a subtle "Swipe for map →" label on first run, or a small map thumbnail in the corner that expands on tap (better than swipe for running).

### Warm-Up / Cool-Down Identity
- 🔴 **Neither mockup shows warm-up or cool-down states.** Every session starts with 5 min warm-up and ends with 5 min cool-down. These are distinct phases that need their own visual treatment — runners need to know "this is warm-up, the real intervals haven't started yet."

### Haptic Feedback
- 🟡 No indication of haptic patterns. For a running app where audio might not be heard, haptic feedback on interval transitions is critical. Document the haptic pattern per transition type.

### Landscape / Rotation
- 🟡 No landscape consideration. Most running apps lock to portrait. Should explicitly state rotation is locked.

---

## Competitor Comparison

| Feature | Mile One | Nike Run Club | C25K ZenLabs | Runkeeper |
|---------|----------|---------------|--------------|-----------|
| Countdown prominence | ✅ Excellent | Timer smaller, pace focus | ✅ Similar large timer | Timer secondary to map |
| Run/Walk distinction | ✅ Color-coded badge | N/A (not interval) | Color + full-screen flash | N/A |
| Motivation | 🟠 Static text | Dynamic coaching audio | Static text | Audio cues |
| Post-run celebration | 🟠 Small checkmark | 🏆 Full-screen + social | Simple summary | Full-screen stats |
| Touch target safety | 🔴 End Run too close | Lock screen during run | End behind menu | Similar layout |
| Outdoor readability | 🟠 Dark only | Dark + auto-brightness | Dark mode option | Light + dark |

---

## Top 10 Fixes (Priority Order)

1. **Separate Pause and End Run** — move End Run behind a long-press or "..." menu, or add 60px+ gap
2. **Add warm-up/cool-down visual state** — amber/yellow badge, distinct from run/walk
3. **Increase countdown font weight** to 300+ for outdoor readability
4. **Fix contrast ratios** — all secondary text needs .5-.6 opacity minimum
5. **Add colorblind-safe differentiators** — icons or shapes, not just green/blue
6. **Make swipe-to-map discoverable** — label or tap-to-expand map thumbnail
7. **Bigger post-run celebration** — contextual messages, larger visual moment
8. **Add paused state mockup** — resume button, dimmed countdown, "PAUSED" indicator
9. **Add End Run confirmation dialog** — required by spec
10. **Make encouragement text contextual and readable** — higher opacity, session-aware messages

---

*This review focuses on the three in-run screens only. Dashboard, onboarding, route planner, and settings screens need separate mockups and review.*
