# Pet Care Sticker Icons Design

## Goal

Create a consistent, cute button and icon direction for the pet diary app. The style should feel like small hand-drawn care-item stickers, not 3D, AI-rendered, or mixed OS emoji.

## Approved Direction

Use custom 2D line icons based on pet-care objects. Icons should represent the object itself, without character faces or mascot-style expressions.

The visual mood is:

- Cute and compact
- Soft, warm, and practical
- Hand-drawn but clean
- Consistent across all quick record, record list, routine, and management icons

## Icon Style Rules

- Shape: simple object-centered 2D line drawings
- Stroke: rounded charcoal line, visually consistent across the set
- Fill: limited pastel fills, usually one or two areas per icon
- Depth: no 3D, no glossy highlights, no heavy shadow
- Faces: no faces unless a future feature explicitly needs a pet avatar
- Emoji: do not mix OS emoji with this custom icon set in the same feature area
- Detail: use the minimum detail needed to recognize the object

Suggested colors:

- Stroke: charcoal gray close to `#4A4A4A`
- Primary accent: existing orange `#F4A460`
- Supporting accents: mint, pale yellow, soft pink, light sky blue
- Background: existing cream/surface tokens from `DESIGN.md`

## Button Treatment

Quick record buttons should become sticker-like tiles that match the current app design system:

- Keep warm cream backgrounds
- Use light borders
- Keep rounded tile shapes
- Avoid heavy shadows
- Keep touch targets comfortable
- Place the icon above a short Korean label

The first implementation target is the home quick record area because it is the most visible place where icon consistency will immediately improve the app.

## Quick Record Icon Concepts

| Record type | Icon concept |
| --- | --- |
| Meal | Small food bowl with spoon |
| Water | Water bowl with one droplet |
| Medicine | Two pills with a small medical cross |
| Poop | Waste bag or litter scoop |
| Walk | Leash with paw print |
| Sleep | Cushion with small moon |
| Play | Ball or toy rope |
| Weight | Round scale |
| Vet/checkup | Medical note or clipboard with cross |

## Rollout

1. Replace home quick record emojis with the new custom icon set.
2. Reuse the same icon set in record cards and record editing surfaces.
3. Extend compatible icons to routine and My Page management tiles.
4. Adjust bottom tab icons only after the main app surfaces feel consistent.

## Constraints

- Follow `DESIGN.md` first for colors, typography, cards, buttons, and empty states.
- Keep Korean text readable UTF-8.
- Do not change backend, API, or data model for this visual work.
- Keep the first implementation small and verifiable on mobile.

## Success Criteria

- Quick record icons no longer use mixed OS emoji.
- All quick record icons share the same stroke, fill, and object-centered style.
- The app still feels like the existing warm pet diary, not a copied baby-care app.
- `DESIGN.md` compliance is checked before implementation is considered complete.
- Korean mojibake scan passes if any Korean text is edited.
