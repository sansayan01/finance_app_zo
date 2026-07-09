# Live Agent Location Map — Implementation Plan

> **Vision:** A live, interactive agent-tracking map for MicroFlow Pro — comparable to how
> Zomato, Swiggy, Blinkit, and Zepto show delivery partners moving in real time.
> **The delivery agent's (field staff's) live location must be visible and moving on the map,
> exactly like those apps** — smooth marker motion, follow-camera, accuracy circle, and
> clear "Live / last updated / signal lost" status.

This plan builds on the existing location stack (already upgraded in the prior phases:
background tracking, offline queue, geofencing, history playback). It focuses on the
**UI/UX polish and real-time interactivity** that makes tracking feel "live" rather than a
static snapshot.

---

## 1. Goal

Give managers (and branch managers) a map where **each field agent appears as a moving,
live marker** that:

- Moves smoothly between GPS pings (no teleporting / stuttering).
- Shows a directional arrow pointing in the travel direction.
- Has a translucent accuracy circle around it.
- Is auto-followed by the camera, with a "Re-center" button when the user pans away.
- Displays live status: pulsing "Live" badge, "updated Xs ago", "signal lost".

**Note on the delivery agent's location:** The field agent is the **delivery partner** in
the Zomato/Swiggy sense — their position must be continuously visible to managers on the
ops console, exactly like a delivery partner is visible to the customer. This is the core
requirement. There is no "share a link / temporary session" model here: agents are simply
live and visible whenever they are on duty, and managers watch them from a central dashboard.

---

## 2. Current State (what already exists)

| Capability | Status | File |
|------------|--------|------|
| Real-time agent positions via Supabase Realtime | ✅ INSERT + UPDATE stream | `live_tracking_repository.dart` |
| Animated marker with ripple + heading rotation | ✅ (`_markerMoveCtrl`, `_RipplePainter`) | `manager_live_map_page.dart` |
| Speed-colored breadcrumb trail | ✅ | `manager_live_map_page.dart` |
| Geofence zone overlays | ✅ `PolygonLayer` | `manager_live_map_page.dart` |
| Agent detail sheet (battery, speed, call, history) | ✅ | `manager_live_map_page.dart` |
| Dashboard mini-map card | ✅ | `live_agents_map_card.dart` |
| Distance-based + offline-resilient uploads | ✅ | `live_location_service.dart` |

**Gaps vs. the Zomato/Swiggy experience:** interpolation is keyframe-only (not elapsed-time
based), no accuracy circle, no follow-camera with recenter, no "updated Xs ago / signal
lost" freshness UI, no smooth heading interpolation, no share/link model (managers just
open the page).

---

## 3. Implementation Plan (by priority)

### Phase A — Smooth, Accurate Movement (the "hard part")

**Goal:** Markers glide continuously instead of jumping between GPS fixes.

1. **Elapsed-time interpolation.** Keep `prev` (last rendered) and `target` (latest GPS)
   per agent. On each new fix, animate from `prev → target` over the **elapsed time
   between the two fixes** (capped at ~1.5s), using `Curves.easeInOutCubic`. Replace the
   current fixed `AnimationController` forward with a duration computed from the timestamp
   delta in the location payload.
2. **Heading interpolation.** Rotate the arrow toward travel direction
   (`atan2(dLng, dLat)`), falling back to device `heading`. Smoothly lerp the rotation
   angle (handle the 359°→0° wraparound).
3. **Accuracy circle.** Draw a `CircleLayer` / marker circle of radius = `accuracy` meters
   (converted to the map's zoom-space), semi-transparent, updated per fix.
4. **Speed-aware pacing.** When `speed` is available, scale interpolation so on-screen
   velocity roughly matches real speed.

> Files: `manager_live_map_page.dart` (marker builder + animation), optionally extract a
> `LiveAgentMarker` widget. `live_agents_map_card.dart` gets a lighter version.

### Phase B — Follow Camera & Map Interaction

1. **Auto-follow selected agent.** `MapController.move()` to the interpolated position on
   each frame while follow is enabled.
2. **Pause-on-interaction.** Detect user pan/zoom (map event callback) → set
   `_isFollowing = false`, show a floating **"Re-center"** button. Tapping it resumes
   follow and re-centers.
3. **Controls:** zoom in/out buttons, recenter, and a compact legend (colors = activity
   type, circle = accuracy, ripple = live).
4. **Responsive layout:** full viewport on mobile; on desktop, a side panel listing agents
   synced with the map selection.

### Phase C — Live Status & Freshness UI

1. **Pulsing "Live" badge** on actively-updating markers (already have ripple; promote to
   a status pill).
2. **"Updated Xs ago"** computed from `recorded_at` vs. now, refreshed every 1s.
3. **"Signal lost"** state when no update for >30s (greys the marker, shows warning).
4. **Accuracy readout** in meters on the agent detail sheet and marker tooltip.

### Phase D — Agent List / Side Panel (ops-console feel)

A scrollable list of all on-duty agents with: name, live status dot, last-seen, current
activity, battery. Tapping an item selects + follows that agent on the map. This is what
makes it feel like the Swiggy "who's delivering" console.

### Phase E — Share / Deep-link (optional, WhatsApp-style)

A "Share live map" action that generates a deep link (e.g.
`app://live-map?branch=<id>` or a web fallback) so a link can be opened to jump straight to
a branch's live view. No new backend room model needed — reuse `branch_id` scoping already
present in `staff_locations`.

---

## 4. Architecture Notes

- **No new backend.** All smart movement logic stays client-side (per the existing
  pattern). Supabase Realtime already pushes INSERT + UPDATE events.
- **No SQL migrations / no DB deploys** (per project constraints). Everything is Dart +
  existing `staff_locations` table.
- **Reuse:** `GeofenceUtils`, `PolylineUtils`, `LiveTrackingRepository`, and the existing
  provider graph (`liveAgentLocationsProvider`, `managerGeofenceZonesProvider`).
- **Smoothness:** prefer animating on the existing `AnimationController` + `Curves`, not
  raw `setState` per frame.

---

## 5. Suggested Modifications / Decisions Needed

A few things I'd recommend changing from the original WhatsApp prompt to fit MicroFlow:

1. **Drop the room/WebSocket relay (§7–§9 of the prompt file).** MicroFlow already has
   Supabase Realtime + `staff_locations` + `org_id`/`branch_id` scoping. A separate Node
   `ws` relay is redundant and would require new infra. Recommend: keep the *behavior*
   (live move, last-known on join, reconnect) but implement it on Supabase Realtime.
2. **Role model is manager→agent, not peer-to-peer.** In WhatsApp both sides share; here
   only agents share and managers view. So "Stop sharing" = agent ends duty; "Leave" =
   manager navigates away. No symmetric share/leave needed.
3. **Background tracking is already handled** (Phase 1 work) — the prompt's "Out of Scope"
   note about native background GPS does not apply; we already added
   `ACCESS_BACKGROUND_LOCATION` + permissions.
4. **MapLibre/Leaflet note doesn't apply** — we're in Flutter using `flutter_map` +
   Mapbox raster; that's the right call for a native app and gives smooth 60fps motion.

---

## 6. Recommendations (beyond the prompt)

- **Clustering at low zoom:** when many agents are in one city, cluster markers (e.g.
  supercluster-style) so the map isn't a mess — like Swiggy does in dense areas.
- **ETA / distance-to-branch:** show each agent's straight-line distance to their assigned
  branch. Cheap to compute with `GeofenceUtils.haversineDistance`.
- **Trail fade:** fade older breadcrumb segments (already speed-colored) for a cleaner
  "comet tail" look.
- **Battery-aware UI:** surface low-battery agents prominently so managers can recall them.
- **Playback reuse:** the Phase-3 history playback widget can share the same marker/circle
  rendering as the live view — build one `AgentMarkerPainter` used by both.

---

## 7. Acceptance Criteria (test checklist)

- [ ] Granting permission → agent's own marker moves on their staff map.
- [ ] Manager opens live map → **sees the same agent move live** (delivery-partner style).
- [ ] Movement is **smooth/interpolated**, not teleporting between pings.
- [ ] Marker **arrow points in travel direction**; accuracy circle grows/shrinks with GPS.
- [ ] Camera follows marker; panning shows **Re-center** button; recenter works.
- [ ] **"Updated Xs ago" / "Signal lost"** states render correctly.
- [ ] Geofence zones + breadcrumb trails still render alongside live markers.
- [ ] Permission denied / signal loss / dropped connection handled gracefully, no crash.
- [ ] Works on mobile (touch) and desktop (side panel).

---

## 8. Out of Scope (this pass)

- Native iOS/Android background GPS (already delivered in Phase 1).
- Account/login for share links (use `branch_id` scoping instead).
- Chat/messaging (location only).
- A separate web relay server (reuse Supabase Realtime).
