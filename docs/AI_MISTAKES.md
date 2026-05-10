# AI Mistakes Log

This file must be read at the start of every coding session.

## Repeated Mistakes

### BottomSheet open state regressions
- Do not hide a BottomSheet by unmounting it and then rely on a ref effect to open it in the same render.
- For modals opened by context state, either keep the sheet mounted and control it consistently, or mount it only when open with `index={0}`.
- After changing close behavior, verify every entry point that calls `openModal()`: home quick buttons, routine shortcuts, and `records.tsx` add button.

### Korean mojibake regressions
- Files containing Korean UI text must stay UTF-8.
- Prefer `apply_patch`; avoid PowerShell rewrites without explicit UTF-8.
- When checking Korean text on Windows, use `Get-Content -Encoding utf8`; do not judge file corruption from default console output alone.
- Run `powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\check-korean-mojibake.ps1` before finishing Korean text edits.
- After editing Korean text, run a mojibake scan before finishing.

## Rule

If the same mistake happens 3 or more times, add it here with:
- what broke
- why it broke
- the verification that must be run next time
