# CodeIsland Design Spec

Fork of [Claude Island](https://github.com/farouqaldori/claude-island) into an open-source product that turns the MacBook notch into a real-time control surface for AI coding agents.

## Product Overview

**Name:** CodeIsland
**Base:** Fork of Claude Island (Swift/SwiftUI, 61 source files)
**License:** Open source
**Target:** Developers running multiple Claude Code / Codex / Gemini CLI sessions via cmux or Ghostty

### Core Value Proposition

- Monitor all AI agent sessions from the notch without switching windows
- Approve/deny permissions without leaving your current context
- Know instantly which session needs attention through pixel animations and 8-bit sound
- Jump to the exact cmux tab with one click

## Architecture

### Retained from Claude Island

- **Hook system** — Python script installed at `~/.claude/hooks/` communicates session state via Unix socket
- **HookSocketServer** — Listens on `/tmp/claude-island.sock`, receives JSON events, handles permission request/response protocol
- **Session monitoring** — `ClaudeSessionMonitor` + `SessionStore` track all active sessions
- **Notch window** — `NotchWindow` + `NotchViewController` render the Dynamic Island overlay

### New / Modified

- Pixel animation engine (Canvas-based sprite system)
- 8-bit sound system with per-event configuration
- Project grouping in session list
- cmux AppleScript integration for precise tab jumping
- Brand assets (icon, name, README)
- Remove Mixpanel analytics, evaluate Sparkle update dependency

## State Model

### SessionPhase → AnimationState Mapping

The existing `SessionPhase` enum maps to animation states as follows:

| SessionPhase | AnimationState | Notes |
|-------------|---------------|-------|
| `.idle` | `IDLE` | No active processing |
| `.processing` | `WORKING` | Claude is executing tools or generating |
| `.waitingForApproval` | `NEEDS_YOU` | Permission request pending |
| `.waitingForInput` | `DONE` | Claude finished, waiting for next prompt |
| `.compacting` | `THINKING` | Context window compaction in progress |
| `.ended` | `IDLE` | Session terminated, show as idle until archived |

Error detection: When a `PostToolUse` hook event arrives with error status, set a transient `hasError` flag on the session. Display `ERROR` animation for 5 seconds, then revert to the phase-based state. This avoids needing a new `SessionPhase` enum value.

### Priority Order (for collapsed notch character)

When multiple sessions are active, the pixel character shows the most urgent state:

`NEEDS_YOU > ERROR > WORKING > THINKING > DONE > IDLE`

### Zero Sessions

When no sessions are active, the notch hides entirely (existing behavior). The pixel character is not shown.

### Many Sessions (>8)

Collapsed notch shows max 8 dots. If more than 8 sessions, show 7 dots + a `+N` indicator. Expanded list scrolls naturally via `ScrollView`.

## Data Flow

```
HookEvent (Unix socket)
    → SessionStore (updates SessionState.phase)
    → NotchViewModel (derives AnimationState from phase)
    → Collapsed: PixelCharacterView + StatusDots + ScrollingText
    → Expanded: ProjectGroupedList
    → SoundManager (fires on state transitions, not on every event)
```

## Module 1: Collapsed Notch State

**Style:** iPhone Dynamic Island — session dots + pixel character + scrolling text

### Layout (left to right)

```
[ dots ] [ pixel character ] [ scrolling activity text ]
```

- **Session dots:** One colored dot per active session. Colors encode **state** (green=working, amber=needs attention, blue=idle, purple=thinking, red=error). Max 8 dots; overflow shows `+N`.
- **Pixel character:** Animated 10x10 sprite reflecting the most urgent state across all sessions per priority order defined in State Model section.
- **Scrolling text:** Latest activity from the highest-priority session, e.g. `claude: writing auth.ts...`. Monospace 10px, scrolls horizontally if exceeds available width. Minimum 60px available width required; if less, hide text and show only dots + character. Available width = notch area minus dots minus character (~120-160px depending on MacBook model).

### Interaction

- Hover: notch expands slightly to show more text
- Click: full expand to session list

## Module 2: Pixel Character Animations

Programmatic Canvas/SwiftUI drawing. No external sprite assets. Each character fits in a ~10x10 pixel grid.

### Shared Character Design

- Warm skin tones (`#FFCB8E` / `#E8A86A`)
- Brown hair (`#5B3A29`)
- Chibi proportions: big head (3x3), small body (3x2), short legs

### 6 States

| State | Animation | Main Color | Description |
|-------|-----------|------------|-------------|
| **IDLE** | Napping at desk | Blue `#5B7FBF` | Head on arms, feet dangling with gentle swing, blue Zzz bubbles float up |
| **WORKING** | Typing at laptop | Green `#3A9A5B` / Cyan `#67E8F9` | Green hoodie, arms alternate typing, screen emits cyan glow, cyan sparks fly from screen |
| **NEEDS YOU** | Standing, waving hand | Amber `#D97706` | Amber vest, left arm down, right arm raised with hand waving left/right above head (2-frame alternation, only upward) |
| **THINKING** | Cross-legged meditation | Purple `#A78BFA` | Semi-transparent body, purple robe, closed eyes, 3 purple-lilac particles orbit around body |
| **ERROR** | Red X symbol | Red `#EF4444` | No character. Clean X mark with two-tone red (`#EF4444` / `#FCA5A5`), pulsing dark-red glow behind |
| **DONE** | Green checkmark | Green `#4ADE80` | No character. Checkmark with three-tone green gradient, green particles rise from bottom and fade |

### Implementation Notes

- Animations use `TimelineView(.animation)` with SwiftUI `Canvas` for 60fps rendering, or `CADisplayLink` callback driving `NSView.needsDisplay = true` for AppKit path
- Each state is a pure function: `drawState(context: GraphicsContext, frame: Int)`
- Pixel size constant `P = 5` for retina crispness (each logical pixel = 5x5 points)
- Alpha transitions for color gradients (no blur filters)
- The existing `NotchView` uses SwiftUI; prefer SwiftUI `Canvas` + `TimelineView` to stay consistent

## Module 3: Sound System

### Sound Engine

- 8-bit chiptune style, bundled as small `.wav` files (< 50KB each) in the app bundle under `Resources/Sounds/`
- Audio assets to be sourced from CC0 8-bit sound packs (e.g., [Shapeforms Audio](https://shapeforms.itch.io/)) or created with [sfxr](https://sfxr.me/) / [jsfxr](https://sfxr.me/) (free chiptune generator)
- Playback via `NSSound(named:)` — simple, no audio engine overhead
- Sounds fire on session state transitions only (not continuously), triggered by `SoundManager` observing `SessionState.phase` changes

### Event → Sound Mapping

| Event | Sound Style | Default |
|-------|------------|---------|
| Session start | Boot-up `doo-dee` | ON |
| Processing begins | Light `bip` | OFF |
| Needs approval | Alert `bee-boo` (plays once, not looping) | ON |
| Approval granted | Confirm `da-ding!` | ON |
| Approval denied | Low `bwom` | ON |
| Session complete | Victory `ta-da-da!` | ON |
| Error | 8-bit fail `wah-wah` | ON |
| Context compacting | Compress `zwip` | OFF |

### Settings UI

- Global mute toggle
- Per-event on/off switches
- Volume slider
- Preview/test button per sound

## Module 4: Project Grouping

### Grouping Logic

Automatic grouping by `cwd` (working directory). Extract last path component as project name.

```
/Users/ying/Documents/AI/catgame/ → "catgame"
/Users/ying/projects/webapp/     → "webapp"
```

Multiple sessions in the same directory → same group, sorted by activity time.

### Expanded UI Structure

```
▼ catgame (2 active)
  ● fix auth bug          🟢 working     >_
  ● add leaderboard       🟠 needs you   >_

▼ AI (1 active)
  ● explore vibeisland    🔵 idle        >_

▶ devforge (archived)
```

- Project header: name + active count, click to collapse/expand
- Session rows: same as current (click row → expand chat, terminal icon → jump to cmux)
- Empty/archived groups can be collapsed or hidden

### Collapsed Notch Association

Session dots in collapsed state encode **state** via color (same color scheme as Module 1). Project identity is conveyed by dot **grouping** — dots from the same project are adjacent with a small gap between project groups.

## Module 5: cmux Integration

### Jump-to-Tab

cmux exposes a full AppleScript dictionary (confirmed in `Sources/AppleScriptSupport.swift` — `ScriptTerminal` class with `workingDirectory` property and `handleFocusCommand`). Ghostty 1.3+ also has native AppleScript support.

When user clicks the terminal icon on a session row:

```applescript
tell application "cmux"
    set allTerms to terminals
    repeat with t in allTerms
        if working directory of t contains "<session_cwd>" then
            focus t
            return
        end if
    end repeat
    activate
end tell
```

**Fallback chain:** cmux AppleScript → Ghostty AppleScript (same API shape) → `osascript 'tell application "cmux" to activate'`

cmux also exposes a socket CLI (`cmux focus --cwd <path>`) as an alternative to AppleScript. Prefer AppleScript for v1 since it's already implemented and tested.

### Terminal Registry

cmux bundle ID `com.cmuxterm.app` added to `TerminalAppRegistry.bundleIdentifiers`.

## Cleanup Tasks (Fork Hygiene)

- Remove Mixpanel SDK and all tracking calls
- Remove Sparkle auto-update framework (not needed for open source distribution via GitHub releases / Homebrew)
- Rename bundle identifier from `com.celestial.ClaudeIsland` to `com.codeisland.app`
- Update app icon, name, and window titles
- New README with feature overview, screenshots, install instructions
- Update socket path from `/tmp/claude-island.sock` to `/tmp/codeisland.sock`
- Update hook script name from `claude-island-state.py` to `codeisland-state.py`

## Security

- Socket permission: use `chmod 0o700` (owner-only) instead of the existing `0o777` in `HookSocketServer.swift`

## Accessibility

- Respect `accessibilityReduceMotion`: if enabled, replace pixel animations with static state icons
- VoiceOver: collapsed notch announces session count and most urgent state (e.g., "3 sessions, 1 needs approval")
- Sound alerts serve as redundant channel to visual indicators (not the only signal)

## Non-Goals (v1)

- No built-in terminal emulator (use cmux/Ghostty)
- No remote/cloud sync
- No multi-machine support
- No custom sprite uploads (programmatic only)
- No input box for sending messages to terminal (removed — use cmux directly)
