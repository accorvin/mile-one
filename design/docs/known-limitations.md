← [Back to Index](README.md)

# Mile One — Known Limitations & Workarounds

## 8. Known Limitations & Workarounds

### 8a. AVSpeechSynthesizer + Third-Party Audio (Spotify, etc.)

**Problem**: Audio ducking (`duckOthers`) is unreliable with third-party apps. Some apps don't restore volume after ducking. Spotify sometimes pauses instead of ducking. Additionally, deactivating the audio session after every utterance causes rapid duck/unduck cycling that disrupts music playback.

**Workaround**: 
- Use `.mixWithOthers` as fallback if ducking causes issues
- Keep audio session active for the duration of the run instead of activating/deactivating per utterance
- Queue management: cancel pending utterances before speaking new ones to avoid stale cue pile-up during rapid interval skips
- Document as known V1 limitation
- Test thoroughly with Spotify, Apple Music, podcast apps
- Future: consider pre-recorded audio files for more reliable audio session behavior

### 8b. Background Location Permission

**Problem**: iOS requires "When In Use" authorization first; "Always" can be requested as an upgrade via `requestAlwaysAuthorization()`, but iOS 14+ may silently downgrade "Always" to "While In Use" if the system determines the app doesn't need continuous background access. The `location` background mode in UIBackgroundModes is required for background GPS, and `allowsBackgroundLocationUpdates` must only be set *after* authorization is granted (setting it before authorization crashes on iOS 17+).

**Workaround**:
- Request "When In Use" first (system prompt), then request "Always" upgrade
- Show persistent in-app card explaining how to go to Settings → Mile One → Location → Always
- Deep link to Settings: `UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)`
- App works with "When In Use" + background location mode enabled, but GPS may stop ~10s after screen locks without "Always"
- Check authorization status on each run start and show warning if not "Always"

### 8c. SwiftData `#Predicate` Date Queries

**Problem**: `#Predicate` macros in SwiftData have limited support for complex predicates. Simple date comparisons and equality checks work, but deeply nested expressions may fail.

**Workaround**:
- Use `#Predicate` for simple filters (e.g., `$0.weekNumber == weekNumber`)
- For complex queries that genuinely fail: fetch results and filter in-memory
- Monitor SwiftData updates in iOS 18+ for improved predicate support
- Note: many queries currently using in-memory filtering could use `#Predicate` directly — refactor opportunistically

### 8d. MKDirections Rate Limiting

**Problem**: Apple's MKDirections API has undocumented rate limits (~50 requests/day, ~1/minute sustained). Multi-waypoint routes can hit this quickly.

**Workaround**:
- Aggressive caching (cache by coordinate pair, persist to disk)
- Minimum 2-second delay between requests
- Exponential backoff on `MKError.serverFailure` or `MKError.loadingThrottled`
- Show loading indicator while waiting for rate limit
- For routes with 5+ waypoints, warn user that calculation may take a moment
- Cache polyline results in `SavedRoute.polylineData` so re-opening a saved route doesn't re-request
- Note: cache keys must not use floating-point string interpolation — use a stable coordinate hash instead

### 8e. GPS Accuracy During First 30–90 Seconds

**Problem**: When GPS starts, initial readings have high `horizontalAccuracy` (>100m). Filtering too aggressively would discard the first 30-90 seconds of a run.

**Workaround**:
- 60-second grace period: accept all GPS points regardless of accuracy for the first 60 seconds
- After grace period: filter points with `horizontalAccuracy > 50m` (not 20m — too aggressive)
- Use `desiredAccuracy = kCLLocationAccuracyBest` and `distanceFilter = 5` for optimal precision vs battery
- After grace period, only accumulate distance when accuracy < 30m (use last known good point for distance calculation)

**Implementation note**: The grace period compares `location.timestamp` against `startTime`. Since `startTime` is `Date()` (wall clock) while `location.timestamp` is GPS time, these clocks may differ slightly. The grace period may be shorter or longer than exactly 60s. This is acceptable for V1 but the implementation must be consistent with the documented approach.

### 8f. SwiftData + CloudKit Sync Latency

**Problem**: CloudKit sync is not real-time. Changes may take seconds to minutes to propagate between devices.

**Workaround**:
- Show sync status indicator (subtle, non-intrusive)
- On new device: "Restoring your data from iCloud…" screen
- Conflict resolution: last-write-wins (SwiftData default)
- If sync appears stuck, suggest toggling airplane mode

### 8g. CloudKit Array Property Ordering

**Problem**: SwiftData can persist arrays of primitives (e.g., `runDays: [Int]`, GPS point arrays), but CloudKit sync does not guarantee array ordering after a round-trip. On older iOS versions, `[2,4,6]` may come back as `[4,2,6]`, breaking reminder scheduling and route rendering.

**Workaround**:
- Sort `runDays` after fetching from the store (sort ascending before using)
- GPS points must include a `timestamp` or `index` field and be sorted after fetch — never rely on insertion order
- Test sync round-trips with array properties on minimum deployment target
- Consider storing order-sensitive data as encoded `Data` (JSON) instead of native arrays if ordering issues persist

### 8h. Battery Consumption

**Problem**: Continuous GPS + background execution drains battery.

**Workaround**:
- `distanceFilter = 5` reduces GPS callback frequency
- Display timer at 1Hz (not 10Hz)
- No unnecessary processing in GPS callbacks
- Typical 30-min run with GPS: ~5-8% battery drain (acceptable)
- Battery warning if < 20% when starting a run (requires `UIDevice.current.isBatteryMonitoringEnabled = true`)

### 8i. SwiftData Threading & Cross-Actor Isolation

**Problem**: `@Model` objects must be accessed on the same actor that owns their `ModelContext`. Passing `@Model` objects between views and background services causes crashes or Swift 6 strict concurrency compile errors.

**Workaround**:
- All SwiftData access goes through `DataStore` (`@ModelActor`)
- Views receive plain-struct snapshots, not `@Model` objects
- Use `@Observable` view models that hold snapshots
- When a view needs to update data: call `DataStore` method, then refresh the snapshot
- **Critical**: `fetchUserProfile()` and `fetchGPSPoints()` must return struct copies, not `@Model` references. Current implementation returns `@Model` objects — this is a known Swift 6 strict concurrency violation that must be fixed before shipping.

### 8j. App Termination During Run

**Problem**: iOS may terminate the app during a run (memory pressure, user force-quit). Run data is lost if not periodically saved.

**Workaround**:
- Periodically checkpoint run state (every 30s or every N GPS points) to SwiftData
- On next launch, detect incomplete run and offer to resume or discard
- Save GPS points in batches during the run, not only at completion

### 8k. Phone Call Interruption

**Problem**: Incoming phone calls pause the app. After the call ends, the app resumes but timer state may be inconsistent (especially with the display timer leak from pause/resume cycles).

**Workaround**:
- Handle `UIApplication.willResignActiveNotification` and `didBecomeActiveNotification`
- Pause run on resign, resume on become active (if user confirms)
- Ensure pause/resume cycle properly invalidates old timers before creating new ones

### 8l. Timer Retain Cycle

**Problem**: `Timer.scheduledTimer` retains its target. If RunEngine doesn't invalidate the timer in `deinit`, the engine is never deallocated. Additionally, each pause/resume cycle creates a new timer without invalidating the old one, leading to N+1 timers after N cycles.

**Workaround**:
- Invalidate timer in `deinit`
- Invalidate existing timer before creating a new one in `resume()`
- Consider using `Timer.publish` or `AsyncTimerSequence` which don't have retain cycle issues

---
