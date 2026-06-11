# Learner Portal Design Specification

## Overview

This document defines the design of the **learner portal** — the GitHub Pages
entry point that learners use to navigate the 2-day Azure IaaS Workshop. It
serves as the specification that any agent or contributor must follow when
modifying the portal so that its look, behaviour, and (critically) its
GitHub Pages rendering remain consistent.

The portal is a single Markdown file, `materials/docs/index.md`, that embeds a
self-contained two-pane application (a navigation Table of Contents plus an
`iframe` content viewer) using inline CSS and JavaScript. It is published to
GitHub Pages and is live at:

- **Production URL**: <https://hironariy.github.io/Azure-IaaS-Workshop/>

## Scope

- **In scope**: Portal layout, design system, navigation TOC, progress
  tracking, active-page synchronization, styling injected into the embedded
  content `iframe` (including code blocks and syntax highlighting), local
  preview/verification, and the deployment path.
- **Out of scope**: The content of the learner/operations/reference pages
  themselves (those are authored as Markdown under `materials/docs/**`), and
  the application source under `frontend/`, `backend/`, `bicep/`.

## Goals and Non-Goals

### Goals
- Give learners a single, always-available view of the workshop flow with a
  persistent TOC and a content pane.
- Let learners track their own progress with checkboxes that **survive page
  reloads**.
- Make the current page obvious (active highlight synced with the content).
- Keep the right-pane content readable and visually consistent with the portal,
  including high-contrast, clearly-delineated code blocks.
- Remain **self-contained** so it works on stock GitHub Pages with no custom
  Jekyll theme, gem, or build step beyond the standard Pages build.

### Non-Goals
- No client-side framework (React/Vue), bundler, or external CSS/JS assets.
- No server-side state; progress is per-browser only (intentionally
  ephemeral, learner-private).
- No dark mode for the portal chrome (minima's page background is light; the
  portal is a polished light theme). Only **code blocks** are dark by design.

## Architecture and Constraints

| Aspect | Decision | Rationale |
|---|---|---|
| Host | GitHub Pages (project site) | Already used by the repo; zero infra. |
| Generator | Jekyll via the `github-pages` gem | This is what Pages runs. **Pins Jekyll 3.10.x and minima 2.5.1.** |
| Theme | `minima` (stock) | No custom theme to maintain; portal styles itself. |
| Implementation | Single file `materials/docs/index.md` with inline `<style>`, HTML, and `<script>` | Self-contained; survives Markdown→HTML conversion; nothing else to wire up. |
| Content rendering | Right pane is an `<iframe>` pointing at sibling pages | Lets each learner page stay a normal standalone Markdown page while the portal frames it. |
| Markdown engine | kramdown | Passes raw HTML (the portal markup) through untouched. |

**Key constraint — raw HTML passthrough**: Because the portal is raw HTML inside
a Markdown file, kramdown must not escape it. This is verified (see
*Verification*). Keep the block-level HTML flush-left and avoid indenting it
under list/code contexts.

## Layout

The portal page hides minima's own site chrome so learners land directly on the
portal: `.site-header` and `.site-footer` are set to `display: none` on this page,
and the page `<h1>` (the "受講者ポータル" title) is omitted. `.page-content` keeps a
small top padding so the lead paragraph is not flush against the viewport edge.
(This is distinct from hiding the *framed* page's header/footer, which is done via
the injected `EMBEDDED_STYLE`.)

A CSS Grid two-pane layout (`.workshop-portal`):

- **Left pane** (`.workshop-toc`): sticky, scrollable navigation. Width
  `minmax(23rem, 34%)`.
- **Right pane** (`.workshop-content`): an `<iframe name="workshop-content-frame">`
  that renders the selected page. Width `minmax(0, 1fr)`.
- TOC links use `target="workshop-content-frame"` so clicks load into the
  iframe without leaving the portal.
- Below 900px the grid collapses to a single column (TOC stacks above content).

## Design System

All visual tokens are CSS custom properties on `:root` (prefix `--wp-`). When
changing colours, change the token, not the call sites.

| Token | Value | Use |
|---|---|---|
| `--wp-brand` | `#0078d4` | Primary Azure blue (links, accents, bar fill). |
| `--wp-brand-dark` | `#005a9e` | Link text, emphasis. |
| `--wp-brand-darker` | `#004578` | Number-badge gradient end. |
| `--wp-accent` | `#3ba0e6` | Hover/focus accents, progress gradient end. |
| `--wp-page` | `#f4f7fb` | TOC panel background. |
| `--wp-surface` | `#ffffff` | Card surfaces. |
| `--wp-border` / `--wp-border-strong` | `#e3e8ef` / `#cdd5e0` | Card borders. |
| `--wp-text` / `--wp-muted` | `#1b2430` / `#5b6675` | Text. |
| `--wp-done` / `--wp-done-soft` | `#107c10` / `#e8f4e8` | Completed step (check, background). |
| `--wp-pre` | `#64748b` | "事前確認" (pre-check) badge. |
| `--wp-d0` / `--wp-d1` / `--wp-d2` | `#8661c5` / `#0078d4` / `#0e8f8a` | Day 0 / Day 1 / Day 2 badges. |
| `--wp-radius` / `--wp-radius-sm` | `14px` / `9px` | Corner radii. |
| `--wp-shadow` / `--wp-shadow-sm` | soft shadows | Card elevation. |

Surfaces are cards with soft shadows (not flat 1px boxes); type uses larger,
weighted headings and comfortable line-height.

## Navigation TOC

Two lists, visually distinct:

1. **Progress TOC** (`ol.wp-steps`): the 7 ordered steps of the workshop. Each
   `li.wp-step` has:
   - a circular gradient **number badge** (`.wp-step__num`),
   - a colour-coded **timing pill** (`.wp-badge--pre|--d0|--d1|--d2`),
   - the page link (`.wp-step__link`, loads into the iframe),
   - a **custom checkbox** (styled `input[type="checkbox"]`).
2. **Reference TOC** (`ul.wp-refs`): 5 on-demand reference pages, styled with a
   left accent border to signal "look up as needed", not sequential.

Each navigable `li` carries `data-page="<relative-path>"` used for active-state
matching. Steps and refs also carry a checkbox with a stable
`data-progress-id` (e.g. `quickstart`, `day0`, `ref-quickref`).

## Progress Tracking

- **Storage**: `localStorage` under key `aiw-portal-progress-v1` (bump the
  version suffix if the shape changes). Value is a JSON object of
  `{ <data-progress-id>: true }`.
- **Restore on load**: checked state is reapplied from storage on
  `DOMContentLoaded`.
- **Progress bar / counter**: only the **7 `.wp-step` items** count toward
  completion (reference pages are excluded). The bar fill width and the
  "N / 7 完了" counter update on every change; `role="progressbar"` ARIA values
  are kept in sync.
- **Done state**: a completed step gets `.is-done` (green check, soft green
  background).
- **Reset**: the "進捗をリセット" button clears storage and unchecks all boxes.
- **Resilience**: storage reads/writes are wrapped in try/catch so private mode
  degrades to session-only progress instead of throwing.

## Active-Page Highlighting

- `setActive(path)` toggles `.is-active` on the `[data-page]` item whose
  `data-page` is a substring of `path`.
- Triggered (a) on TOC link click (using the link `href`), and (b) on iframe
  `load`, attempting `frame.contentWindow.location.pathname` (same-origin) and
  falling back to the click-based state on any cross-origin error.
- The initial iframe `src` (learner quickstart) is highlighted on first paint.

## Embedded Content Styling (injected into the iframe)

On every iframe `load`, the portal injects a `<style id="embedded-workshop-style">`
into the framed document (guarded so it is injected once). This keeps each
learner page a normal standalone page while making it look consistent inside the
portal. The injected rules:

- Hide the framed page's own `.site-header` / `.site-footer`.
- Constrain content width and improve heading/table/list/blockquote spacing.
- Style tables (header background, zebra rows) and blockquotes (left accent).
- Style **code** (see below).

### Code Blocks and Syntax Theme

Code blocks are intentionally a **solid dark surface with light base text** so
they stand out clearly from the white prose, while syntax tokens
(placeholders, options, strings, variables) stay colourful and high-contrast.

- **Block**: `pre` → background `#0d1117`, text `#e6edf3`, 1px `#30363d` border,
  8px radius. The Rouge wrapper elements (`div.highlight`,
  `.highlighter-rouge .highlight`) are made **transparent** so the `pre` is a
  single clean block.
- **Inline code**: a **light** chip (`#eff1f3` background, `#0b3a66` text, 1px
  border) — deliberately light so it reads inside Japanese prose.
- **Bare command text** (untokenized) inherits the light base (`#e6edf3`), so
  commands like `az account show` are high-contrast on the dark block.

Because minima ships Rouge with a **light-theme** token palette (dark navy
tags, teal variables, crimson strings) that is unreadable on a dark
background, the portal overrides the token colours with a GitHub Dark-inspired
palette. Mapping of the most relevant Rouge token classes:

| Meaning | Rouge classes | Colour |
|---|---|---|
| Comment | `.c .cm .c1 .cs .cd .cp` | `#8b949e` italic |
| Keyword / operator | `.k* .o .ow` | `#ff7b72` |
| String | `.s .s1 .s2 .sb .sc .sd .sh .sx .sr .ss .dl` | `#a5d6ff` |
| String escape | `.se` | `#79c0ff` |
| String interpolation `${...}` | `.si` | `#ffa657` |
| Number | `.m .mi .mf .mh .mo .il` | `#79c0ff` |
| **Option / flag** (`--name`) | `.nt` | `#7ee787` (green) |
| **Variable** (`$VAR`) | `.nv .vc .vg .vi` | `#ffa657` (orange) |
| Builtin command | `.nb .bp` | `#79c0ff` |
| Function | `.nf .fm` | `#d2a8ff` |
| Attribute/name | `.na .nl .nx` | `#79c0ff` |
| Class/namespace/constant | `.nc .nn .no` | `#ffa657` |
| Generic prompt | `.gp` | `#8b949e` |
| Diff added/removed | `.gi` / `.gd` | `#7ee787` / `#ffa198` |
| Error | `.err` | `#f85149`, background neutralized |

### Code Block Copy Buttons

On every iframe `load`, after the style is injected, the portal also injects a
small `<script>` into the framed document that adds a **copy button** to each
code block.

- **Targeting**: it selects `div.highlight, .highlighter-rouge .highlight,
  pre.highlight`, dedupes by the inner `<pre>`, and anchors the button on the
  outer `.highlighter-rouge` wrapper (made `position: relative` via the
  `.wp-code-wrap` class).
- **Button**: a `<button class="wp-copy-btn">` (GitHub-style clipboard SVG +
  "コピー" label) pinned to the top-right of the block. It is `opacity: 0` by
  default and fades in on block hover or keyboard focus, so it does not clutter
  the code.
- **Copy**: clicking copies the `<pre>`'s text (trailing newline trimmed) via
  `navigator.clipboard.writeText`, falling back to a hidden-`textarea` +
  `document.execCommand('copy')` when the async Clipboard API is unavailable
  (e.g. non-secure contexts). On success the button shows an `.is-copied` state
  ("コピーしました", green) for ~1.8s, then reverts.
- **Idempotency**: injection is guarded per `<pre>` and per wrapper so repeated
  iframe loads never add duplicate buttons.
- The injector function is serialised with `Function.prototype.toString()` and
  run inside the framed document, because it must operate on the iframe's own
  DOM and clipboard context.

## CSS Specificity Considerations (Critical)

The injected styles share the framed document with **minima's own CSS**, so
specificity wars are real and were the source of a production-only bug.

- minima defines `.highlighter-rouge .highlight { background:#eef }`
  (specificity `0,2,0`).
- The portal also sets `.highlighter-rouge .highlight { background:transparent }`
  (`0,2,0`, injected later → wins on the wrapper).
- That same wrapper rule also matched the inner `<pre class="highlight">`. An
  earlier dark rule targeted only `pre, pre.highlight` (`0,1,1`), which **lost**
  to the `0,2,0` transparent wrapper rule — so the `<pre>` became transparent
  and the white page showed through. Token colours (`.highlight .nt`, `0,2,0`)
  still won, producing *coloured tokens on a white background*.
- **Fix / rule**: the dark `<pre>` rule must be at least as specific as the
  wrapper rule. It is now
  `.highlighter-rouge .highlight pre, .highlight pre, pre.highlight, pre`
  (`0,2,1`), which beats the transparent wrapper.

**Guidance for future edits**: when overriding any minima `.highlight*` rule,
match or exceed minima's selector depth. Do not rely on source order alone.

## Accessibility

- Custom checkboxes and links have visible `:focus-visible` outlines.
- The progress bar uses `role="progressbar"` with
  `aria-valuemin/valuemax/valuenow` kept in sync.
- Checkboxes carry descriptive `aria-label`s; the TOC `nav` is labelled.
- `@media (prefers-reduced-motion: reduce)` disables transitions/animations.
- Colour choices target legible contrast on their backgrounds (dark code
  tokens were specifically chosen/verified for the `#0d1117` surface).

## Responsive Behaviour

- `@media (max-width: 900px)`: grid collapses to one column; the TOC becomes
  static (non-sticky) and stacks above the content; iframe height reduces.

## Local Preview and Verification

> **Lesson learned**: A local build that does not match the GitHub Pages stack
> can hide real bugs. The code-block specificity bug above rendered correctly
> under a plain Jekyll 4 + newer-minima local build but broke on Pages. **Always
> preview with the same stack Pages uses.**

- **Faithful preview script**: `scripts/preview-pages.sh` builds and serves
  `materials/docs` with the **`github-pages` gem** (Jekyll 3.10 + minima 2.5.1)
  in Docker, using the real `_config.yml`:
  - `./scripts/preview-pages.sh` → serves <http://localhost:4000>
  - `./scripts/preview-pages.sh stop` → stop and remove the container
  - `./scripts/preview-pages.sh clean` → also drop the cached gem volume
  - It handles the known gotchas: adds `webrick` (not bundled in Ruby 3.1+),
    uses `--force_polling` (Docker bind mounts have no inotify), uses the
    `ruby:3.1` image (the `github-pages` dependency tree needs Ruby ≥ 3.0), and
    caches gems in a named volume for fast restarts. Build output goes to
    `/tmp/site` in the container so the working tree stays clean.
- **Authoritative build**: `.github/workflows/pages.yml` is the real
  build/deploy. Pushing to `main` under `materials/docs/**` (or `assets/**`)
  triggers it.
- **Checks to run before pushing portal changes**:
  1. Raw HTML passthrough: the portal markup appears unescaped in the built
     `index.html` (no `&lt;div ...`).
  2. Code blocks render on a **dark** surface with coloured tokens and
     near-white command text (verify on a bash-heavy page such as the Day 1
     checklist and a comment/string-heavy page such as the quick reference).
  3. Progress persists across reload; the progress bar/counter and active
     highlight update correctly.

## Deployment

- Workflow: `.github/workflows/pages.yml` (commented with the local preview
  command). It copies `materials/docs` (and `assets/`) into a Pages source,
  builds with `actions/jekyll-build-pages`, and deploys with
  `actions/deploy-pages`.
- Trigger paths: `materials/docs/**`, `assets/**`, and the workflow file.

## Maintenance Notes

- **Add a workshop step**: add an `<li class="wp-step" data-page="…">` with a
  number badge, the correct `.wp-badge--*` pill, the link
  (`target="workshop-content-frame"`), and a checkbox with a new stable
  `data-progress-id`. The progress total updates automatically from the number
  of `.wp-step` items.
- **Add a reference page**: add an `<li class="wp-ref" data-page="…">` similarly
  (use a `ref-*` progress id). References do **not** count toward progress.
- **Change a colour**: edit the `:root` token, not individual rules.
- **Change code-block syntax colours**: edit the `.highlight .*` rules in
  `EMBEDDED_STYLE`; preserve the specificity guidance above for the `pre`
  background.
- **Invalidate saved progress** (after incompatible changes): bump the
  `STORAGE_KEY` version suffix (`aiw-portal-progress-vN`).

## Related Documents

- `design/RepositoryWideDesignRules.md` — cross-cutting rules (priority #1).
- `design/AzureArchitectureDesign.md` — infrastructure the workshop deploys.
- `materials/docs/index.md` — the portal implementation this spec describes.
- `scripts/preview-pages.sh` — faithful local preview tooling.
- `.github/workflows/pages.yml` — authoritative build/deploy.

## Change History

- **Initial split-view portal**: two-pane TOC + iframe.
- **Design brush-up**: design-token system, step-card TOC with number badges
  and day pills, persistent progress (localStorage) with progress bar and
  reset, active-page highlight, and improved embedded content styling.
- **Code-block readability**: dark, solid code surface with a GitHub
  Dark-inspired Rouge token palette; inline code kept light.
- **GitHub Pages specificity fix**: raised the dark `<pre>` rule to beat
  minima's transparent wrapper rule; made the local preview faithful to the
  GitHub Pages stack (`github-pages` gem) to prevent recurrence.
- **Header/footer removal**: hid minima's `.site-header` / `.site-footer` on the
  portal page and removed the page `<h1>` so the portal opens straight into the
  lead paragraph and two-pane content.
- **Code-block copy buttons**: inject a hover-revealed copy button into every
  framed code block (Clipboard API with `execCommand` fallback, "コピーしました"
  confirmation state).
