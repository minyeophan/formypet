# Pet Diary Design System

This app should feel like a warm daily notebook for pet care: soft, small, affectionate, and practical. Use Lovable's restraint as inspiration, but keep the existing pet diary identity first: cream background, orange primary color, Noto Sans KR, rounded cards, and pet-specific accent colors.

## Core Principles

- Keep repeated-use screens calm. Home, records, and routines are tools people open many times a day.
- Prefer warmth over decoration. A small paw/emoji, soft tint, or friendly empty state is enough.
- Use borders and subtle shadows for depth. Avoid heavy floating cards and SaaS-style dashboards.
- Do not create landing-page hero sections. The first screen is the actual app.
- Keep Korean UI text readable UTF-8. Never romanize Korean to avoid encoding issues.

## Color Tokens

- `background`: `#F7F4ED` warm cream page background.
- `surface`: `#FFFCF7` card and bottom sheet surface.
- `surfaceSoft`: `#FFF8F0` soft inner panels and empty states.
- `primary`: `#F4A460` warm orange CTA.
- `primaryPressed`: `#E5904B` pressed/strong orange.
- `text`: `#1C1C1C` near-black main text.
- `textSecondary`: `#5F5F5D` secondary body text.
- `muted`: `#A79F94` metadata and inactive controls.
- `border`: `#ECE7DE` warm divider/border.
- `white`: `#FFFFFF` only for text on strong color and small highlights, not page backgrounds.

Pet accent colors remain valid and should be used for pet-specific hero gradients, selected calendar dates, and small status indicators.

## Typography

- Font: Noto Sans KR only.
- Use `NotoSansKR_700Bold` for headings, section titles, and CTA labels.
- Use `NotoSansKR_400Regular` for body, metadata, and labels.
- Do not use negative letter spacing or oversized editorial type. This is a compact mobile utility app.
- Typical sizes:
  - Screen title: 17-20
  - Section title: 14-16
  - Body: 13-15
  - Caption: 11-12
  - Emoji/icon tile: 20-32

## Cards And Surfaces

- Page background is always cream.
- Primary cards use `surface`, `borderWidth: 1`, `borderColor: border`, and radius `18-22`.
- Inner panels use `surfaceSoft` or pet/activity tint with radius `14-16`.
- Use light shadow only for important overlay surfaces such as toast:
  - shadow color `#3A2A18`
  - opacity `0.08-0.12`
  - radius `10-14`
  - offset height `4`
- Do not nest decorative cards inside decorative cards. Inner rows can be flat/tinted panels.

## Buttons

- Primary CTA: orange background, white bold label, radius `14-18`, vertical padding `12-16`.
- Secondary CTA: `surfaceSoft` background, warm border, charcoal or muted text.
- Icon buttons should use familiar icons from Ionicons/lucide-equivalent libraries when available.
- Keep touch targets at least 44px high where possible.

## Home Screen

- Home should show app identity, pet selector, a pet hero card, quick records, recent records, and today's routines without feeling like a marketing page.
- Pet hero card may use a soft gradient from `surfaceSoft` to the active pet accent tint.
- Quick record tiles should feel like small stickers: rounded, lightly bordered, activity tint background, emoji first.
- Empty states should be friendly and small, for example a paw/clipboard emoji plus one concise Korean sentence.

## Records

- Record cards should be scan-friendly: emoji tile, type label, short summary, optional time.
- Use activity-specific pastel tile backgrounds from `QUICK_TYPES`.
- Empty record states should invite the next action without guilt.
- Editing/detail bottom sheets should keep the same surface, border, radius, and input treatment as the rest of the app.

## Routines

- Routine completion state should be tactile: unchecked circle with warm border, checked circle with orange fill.
- Completed rows may use soft cream tint and muted text, but still remain legible.
- Routine empty states should be cute but brief, then offer a clear CTA.
- Calendar dots should stay subtle and use pet accent colors.

## Toasts

- Toasts are warm floating notes, not system alerts.
- Surface: `surface`, border `border`, radius `18`.
- Success uses orange/check styling; error uses soft red; info uses soft blue only when needed.
- Text should be concise and friendly.

## Do

- Read this file before adding or changing UI.
- Reuse `frontend/src/lib/colors.ts` tokens.
- Preserve existing Korean wording unless the UI change requires text adjustment.
- Keep changes small and verifiable on mobile.
- Update this file first when a new design pattern is introduced.

## Don't

- Do not introduce strong purple/blue gradients or a cold SaaS palette.
- Do not use pure white as a full-screen background.
- Do not add decorative blobs, orbs, or generic landing-page compositions.
- Do not make cards visually heavy with large shadows.
- Do not change backend/API/data model for visual work.
