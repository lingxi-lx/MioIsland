# Expanded UI Redesign — Notes

Based on Vibe Island competitor screenshots, the expanded notch UI needs these improvements:

## Session List (ClaudeInstancesView)
- Cat face icon (matching collapsed state) instead of generic dot
- Session row: cat icon + task name (bold) + tags (Claude/cmux) + duration
- Subtitle: last message e.g. "You: fix the auth bug"
- Status text with color: "Done — click to jump" (green), "working..." (cyan)
- Cleaner spacing and typography

## Permission Request (approval bar)
- Orange dot + "Permission Request" title
- Warning icon + file path: "⚠ Edit src/auth/middleware.ts"
- **Code diff preview** with line numbers, green/red highlighting
- Bottom buttons: "Deny ⌘Y" / "Allow ⌘Y" with keyboard shortcuts

## Claude Asks (interactive questions)
- Blue chat icon + "Claude asks" title
- Question text in large font
- Option cards with keyboard shortcut labels (⌘1, ⌘2, ⌘3)
- Dark rounded card backgrounds

## Header
- Replace ClaudeCrabIcon with cat face in opened header too
- Menu icon on right (hamburger / X toggle)

## General
- Consistent dark theme with subtle borders
- Rounded corners on all cards
- Proper spacing and padding
- Tags as small pill badges (grey background)
