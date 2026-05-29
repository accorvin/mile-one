# Mile One — Feature Requirements (v2)
*Revised after adversarial review — 2026-05-28*

---

## Overview
**Mile One** is a native iOS app that coaches beginners through a 9-week couch-to-5K running program. It combines structured interval training, GPS route tracking, and pre-run route planning in a clean, distraction-free package.

---

## 1. Onboarding Flow

First-launch experience, required before accessing the app:

### 1a. Welcome Screen
- Brief explanation of the C25K program ("9 weeks, 3 runs a week, you'll run a 5K")
- Health disclaimer: "Consult a physician before starting a new exercise program" (required by Apple guidelines)
- CTA: "Let's get started"

### 1b. Biometric Collection
Needed for accurate calorie calculation:
- **Height** (ft/in or cm, based on units preference)
- **Weight** (lbs or kg)
- **Age** (year of birth or age)
- **Biological sex** (Male / Female — HealthKit standard)

### 1c. Activity Level
Used to suggest a starting week:
- "How active are you right now?" — 3 options:
  - **Couch potato** → Start at Week 1
  - **Somewhat active** (walking regularly, occasional light exercise) → Suggest starting at Week 2 or 3
  - **Fairly active** (regular exercise, just not running) → Suggest starting at Week 4 or 5
- App presents the suggestion: "Based on your activity level, we suggest starting at Week 3. You can always adjust this."
- User can accept the suggestion or manually pick any starting week

### 1d. Schedule Setup
- "Which days do you plan to run?" — pick 3 days of the week (any combination)
- "What time should we remind you?" — time picker, default 7:00 AM

### 1e. Location Permission
- In-app explanation screen before triggering the system prompt:
  - "Mile One uses GPS to track your route and map your runs. For this to work while your phone is in your pocket, we need 'Always On' location access."
  - "After tapping Continue, iOS will ask for location permission. Grant 'While Using App,' then we'll walk you through enabling background access in Settings."
- Trigger "While Using" system prompt
- If user hasn't upgraded to "Always": show a persistent in-app card explaining how to go to Settings → Mile One → Location → Always

### 1f. HealthKit Permission
- Request read/write access: Workouts, Active Energy, Distance, Heart Rate, Height, Weight, Date of Birth, Biological Sex
- Brief plain-language explanation of what's written and why

---

## 2. Training Program

### 2a. Program Structure
- **9 weeks**, **3 sessions per week**, **27 total sessions**
- Each session: 5-min warm-up walk → interval block → 5-min cool-down walk
- **Week** is defined as Mon–Sun (calendar week). Weekly ring resets every Monday.
- User picks their 3 run days; app tracks 3 completions per calendar week regardless of which days

### 2b. Full 27-Session Interval Table (NHS C25K Standard)

| Week | Session | Interval Block |
|------|---------|----------------|
| 1 | All 3 | 60s run / 90s walk × 8 (20 min) |
| 2 | All 3 | 90s run / 2 min walk × 6 (21 min) |
| 3 | All 3 | 90s run / 90s walk / 3 min run / 3 min walk × 2 (18 min) |
| 4 | All 3 | 3 min run / 90s walk / 5 min run / 2.5 min walk / 3 min run / 90s walk / 5 min run (23 min) |
| 5 | Day 1 | 5 min run / 3 min walk × 3 (24 min) |
| 5 | Day 2 | 8 min run / 5 min walk / 8 min run (21 min) |
| 5 | Day 3 | 20 min continuous run |
| 6 | Day 1 | 5 min run / 3 min walk / 8 min run / 3 min walk / 5 min run (24 min) |
| 6 | Day 2 | 10 min run / 3 min walk / 10 min run (23 min) |
| 6 | Day 3 | 22 min continuous run |
| 7 | All 3 | 25 min continuous run |
| 8 | All 3 | 28 min continuous run |
| 9 | All 3 | 30 min continuous run |

Each session total time = warm-up (5) + interval block + cool-down (5).

### 2c. Warm-Up & Cool-Down
- Always present as bookends to every session
- Shown in the interval timer as labeled "Warm-Up Walk" / "Cool-Down Walk" phases
- Audio cue at start and end of each: "Start your warm-up walk" / "Great job — begin your cool-down"

### 2d. Program Flexibility
- **Repeat week**: user can mark the current week to repeat; app doesn't advance automatically — it always waits for user to explicitly unlock the next week after completing 3 sessions
- **Starting week**: set at onboarding; can be adjusted in Settings
- **Manual week advancement**: after completing 3 sessions, CTA appears — "Ready for Week N+1?" User taps to advance

### 2e. Post-Run Effort Check-In
- Shown after every run summary, before returning to dashboard
- **3 labeled buttons** (not a slider): **Too Easy** · **Just Right** · **Too Hard**
- Response is stored per-run and shown in run history detail
- No auto-adjustment or nudges — purely informational and retrospective

### 2f. Lapsed User Recovery
Triggered when the user returns after missing 7+ days with no completed runs:
- "Welcome back! It's been a while. How are you feeling?"
- **Two options presented**:
  - "I'm ready to pick up where I left off" → resume at next uncompleted session
  - "Let me repeat last week first" → reset current week's completion ring, replay that week's 3 sessions
- No judgment, no streak-breaking penalty language

### 2g. Graduation
After completing Week 9 Day 3:
- Full-screen celebration moment ("You ran 5K. You did it.")
- Lifetime stats summary: total runs, total miles, total time, first run date vs. today
- CTA: "Keep Running" — app transitions to a free-run mode (unlocked after graduation) where user can start a GPS-tracked run without an interval program
- Program dashboard replaced with run history + lifetime stats view

---

## 3. In-Run Screen

### 3a. Primary View (Timer Screen) — shown by default
- **Large interval countdown** front and center (e.g., "1:43")
- **Interval label**: RUNNING or WALKING (color-coded — green/blue)
- **Upcoming interval chip**: "Walk in 1:43" or "Run in 1:43"
- **Session progress bar** across top or bottom
- **Elapsed time** and **distance** in smaller text below timer
- **Controls**: Pause | Skip Interval | End Run (with confirmation)

### 3b. Secondary View (Map Screen) — swipe or tab to access
- Live GPS position on map
- Planned route overlay (if one was selected pre-run)
- Live stats: pace, distance, elapsed time
- If user deviates from planned route: no error, no rerouting — route stays overlaid as reference, position dot moves freely

### 3c. Background Mode
- App continues running with screen locked
- Audio cues fire over existing music (AVAudioSession mixWithOthers)
- Lock screen / Dynamic Island shows current interval and countdown
- Notification center shows active workout state

### 3d. Audio Cues
- Transition announcements: "Time to run" / "Take a walk break"
- Halfway point announcement: "Halfway there"
- Final interval warning: "Last interval — finish strong"
- Cool-down start: "Great work — begin your cool-down walk"
- Session complete: "You're done! Amazing work today."
- All cues use AVSpeechSynthesizer (system TTS) — no recorded audio files needed for V1

---

## 4. Pre-Run Route Planner

- **Two drawing modes** (toggle button, clearly labeled):
  - **Road Snap** — tap waypoints, route snaps to roads/paths via MapKit directions API
  - **Free Draw** — drag finger freely for trails, parks, off-road paths
- **Live distance counter** updates as route is drawn
- **Estimated time range** based on current week's expected pace (shown as a range, e.g., "~28–35 min")
- **Edit route**: drag waypoints, delete last point, clear and start over
- **Save & name route** — custom name, stored locally + iCloud
- **Saved routes list** — accessible from home screen and pre-run flow
- **Use route in run** — tap "Start Run with This Route" to overlay it on the live map during the workout
- Route deviation during run: no penalties, no rerouting prompts — route is a visual guide only

---

## 5. Post-Run Flow

After user taps "End Run" (with confirmation) or the final cool-down ends:

1. **Saving screen** (1–2 seconds): "Saving your run…" — writes to SwiftData + HealthKit + iCloud
2. **Post-Run Summary screen**:
   - Route map (GPS trace)
   - Distance, time, average pace
   - Calories (calculated from biometrics + MET value)
   - Intervals completed
   - Heart rate (if available from HealthKit)
3. **Effort check-in** (see 2e above) — appears on same screen below stats, or as a modal
4. **CTA**: "Nice work → Back to Dashboard" — lands on home screen, which shows updated weekly ring and next session

---

## 6. GPS Run Tracking

- Continuous GPS recording during run (CoreLocation)
- GPS polyline stored per-run in SwiftData
- Written to HealthKit as HKWorkoutRoute
- **Post-run route map**: full GPS trace, zoomable, tappable
- **Run history**: calendar view + list view; each entry opens full summary + map

---

## 7. Apple Health Integration

- **Writes**: HKWorkoutActivityType.running, active calories, distance, start/end time, GPS route (HKWorkoutRoute)
- **Reads** (from onboarding data or HealthKit if already stored): height, weight, DOB, biological sex
- Workouts appear natively in Apple Fitness and Health apps with full detail

---

## 8. Progress Dashboard (Home Screen)

- Current week + session indicator ("Week 3 · Run 2 of 3")
- Weekly completion ring (e.g., 2/3 runs this week)
- Next scheduled run day + countdown
- Program completion percentage
- Lifetime stats: total runs, total miles, total time
- Lapsed user recovery card (if triggered)
- "Next session" CTA button — one tap to start today's workout

---

## 9. Settings

- **Units**: miles or kilometers
- **Run days**: which 3 days of the week
- **Reminder time**: time picker (default 7:00 AM)
- **Notifications**: toggle reminders on/off
- **Starting week**: adjust program position
- **Biometrics**: edit height, weight, age, biological sex
- **iCloud sync**: on/off toggle (default on)
- **About / Health disclaimer**

---

## 10. iCloud Sync (CloudKit)

- All run history, saved routes, program progress, and biometrics sync via CloudKit private database
- Transparent to user — just works
- On-off toggle in Settings for users who prefer local-only
- On new device install: "Restoring your data from iCloud…" on first launch
- Known limitation: offline-only users (toggle off or no iCloud account) have no backup

---

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Language | Swift |
| UI | SwiftUI |
| Maps | MapKit (routing + GPS) |
| Health | HealthKit |
| Storage | SwiftData (local) + CloudKit (sync) |
| Audio | AVAudioSession + AVSpeechSynthesizer |
| Location | CoreLocation (background, Always permission) |

---

## Explicit Out of Scope (V1)

| Feature | Status |
|---------|--------|
| Apple Watch app | V2 — not in V1 |
| Treadmill / indoor mode | V2 — GPS required; no accelerometer distance estimation |
| GPX import/export | V2 — routes are device/iCloud only |
| Social sharing | Out of scope entirely (per product decision) |
| Custom interval programs | Out of scope — NHS C25K schedule only |
| Post-5K training programs (10K etc.) | Future — graduation links to concept, not built |
