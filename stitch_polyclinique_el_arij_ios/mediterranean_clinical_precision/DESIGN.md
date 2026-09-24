---
name: Mediterranean Clinical Precision
colors:
  surface: '#f8f9ff'
  surface-dim: '#cbdbf5'
  surface-bright: '#f8f9ff'
  surface-container-lowest: '#ffffff'
  surface-container-low: '#eff4ff'
  surface-container: '#e5eeff'
  surface-container-high: '#dce9ff'
  surface-container-highest: '#d3e4fe'
  on-surface: '#0b1c30'
  on-surface-variant: '#44474e'
  inverse-surface: '#213145'
  inverse-on-surface: '#eaf1ff'
  outline: '#74777f'
  outline-variant: '#c4c6cf'
  surface-tint: '#495f82'
  primary: '#001026'
  on-primary: '#ffffff'
  primary-container: '#0b2545'
  on-primary-container: '#778db2'
  inverse-primary: '#b1c7f0'
  secondary: '#006688'
  on-secondary: '#ffffff'
  secondary-container: '#78d1fe'
  on-secondary-container: '#005977'
  tertiary: '#00120f'
  on-tertiary: '#ffffff'
  tertiary-container: '#002a25'
  on-tertiary-container: '#009d8c'
  error: '#ba1a1a'
  on-error: '#ffffff'
  error-container: '#ffdad6'
  on-error-container: '#93000a'
  primary-fixed: '#d5e3ff'
  primary-fixed-dim: '#b1c7f0'
  on-primary-fixed: '#001c3b'
  on-primary-fixed-variant: '#314769'
  secondary-fixed: '#c2e8ff'
  secondary-fixed-dim: '#78d1fe'
  on-secondary-fixed: '#001e2b'
  on-secondary-fixed-variant: '#004d67'
  tertiary-fixed: '#79f7e3'
  tertiary-fixed-dim: '#59dbc7'
  on-tertiary-fixed: '#00201c'
  on-tertiary-fixed-variant: '#005047'
  background: '#f8f9ff'
  on-background: '#0b1c30'
  surface-variant: '#d3e4fe'
  canvas-bg: '#F8FAFC'
  surface-glass: rgba(255, 255, 255, 0.78)
  sky-tint: '#E0F2FE'
  vital-emergency: '#E11D48'
  vital-scheduled: '#F59E0B'
  vital-discharged: '#10B981'
typography:
  display-hero:
    fontFamily: Plus Jakarta Sans
    fontSize: 36px
    fontWeight: '700'
    lineHeight: 44px
    letterSpacing: -0.02em
  display-hero-mobile:
    fontFamily: Plus Jakarta Sans
    fontSize: 30px
    fontWeight: '700'
    lineHeight: 38px
    letterSpacing: -0.015em
  headline-lg:
    fontFamily: Plus Jakarta Sans
    fontSize: 26px
    fontWeight: '600'
    lineHeight: 32px
    letterSpacing: -0.01em
  headline-md:
    fontFamily: Plus Jakarta Sans
    fontSize: 20px
    fontWeight: '600'
    lineHeight: 26px
    letterSpacing: -0.005em
  headline-sm:
    fontFamily: Plus Jakarta Sans
    fontSize: 17px
    fontWeight: '600'
    lineHeight: 22px
  body-lg:
    fontFamily: Inter
    fontSize: 17px
    fontWeight: '400'
    lineHeight: 24px
  body-md:
    fontFamily: Inter
    fontSize: 15px
    fontWeight: '400'
    lineHeight: 21px
  body-sm:
    fontFamily: Inter
    fontSize: 13px
    fontWeight: '400'
    lineHeight: 18px
  label-lg:
    fontFamily: Inter
    fontSize: 14px
    fontWeight: '600'
    lineHeight: 18px
  label-md:
    fontFamily: Inter
    fontSize: 12px
    fontWeight: '500'
    lineHeight: 16px
  label-sm:
    fontFamily: Inter
    fontSize: 11px
    fontWeight: '600'
    lineHeight: 14px
    letterSpacing: 0.04em
rounded:
  sm: 0.25rem
  DEFAULT: 0.5rem
  md: 0.75rem
  lg: 1rem
  xl: 1.5rem
  full: 9999px
spacing:
  gutter: 1rem
  gutter-sm: 0.75rem
  margin: 1rem
  margin-tablet: 1.5rem
  space-xs: 0.25rem
  space-sm: 0.5rem
  space-md: 1rem
  space-lg: 1.25rem
  space-xl: 1.75rem
---

## Brand & Style

This design system establishes an iOS-first medical interface tailored for island and regional healthcare in Djerba. The aesthetic bridges high-reliability healthcare delivery with modern Mediterranean hospitality. It pairs strict clinical clarity with calming, restorative visual depth.

The design movement centers on **Modern HIG-Informed Glassmorphism & Tonal Layering**. It leverages Apple’s Human Interface Guidelines ethos: content-first layouts, vibrant functional hierarchy, frosted navigation planes, and tactile physical feedback. The emotional tone is authoritative, hygienic, reassuring, and effortless under acute patient stress.

## Colors

The chromatic structure relies on high-trust oceanic blues and sterile medical neutrals:

- **Primary (`#0B2545` - Deep Navy):** Anchors typographic hierarchy, navigation headers, structural frames, and primary interactive buttons. Communicates clinical institutional stability.
- **Secondary (`#007EA7` - Bondi Blue):** Drives direct action, active tab highlights, progress trackers, and secondary button states.
- **Tertiary (`#00A896` - Ocean Teal):** Reserved for clinical triage accents, verified diagnostic results, successful appointments, and wellness monitoring highlights.
- **Neutral (`#64748B` - Slate Neutral):** Delivers balanced optical contrast across secondary body copy, borders, and inactive system states over the `#F8FAFC` crisp medical canvas.
- **Surface Glass (`rgba(255, 255, 255, 0.78)`): Used for frosted sheet overlays, sticky navigation bars, and floating segmented controls over background imagery and clinical feeds.

## Typography

The type scale brings Apple Human Interface Guidelines clarity to web and native cross-platform rendering by pairing **Plus Jakarta Sans** for display/headlines with **Inter** for dense clinical body text and data tables.

- Headlines utilize tight negative tracking to ensure prominent visibility for doctor titles, department names, and test results.
- Body scales preserve generous line-heights for stress-free scanning of prescriptions, operational times, and patient medical records.
- Labels utilize medium and semibold weights with slight positive tracking on uppercase tokens for badge clarity.

## Layout & Spacing

Layouts follow strict mobile screen boundaries configured around an 8pt structural rhythm, adopting fluid vertical scrolling stacks bounded by standard iOS safe areas (Top Dynamic Island / Sensor notch, Bottom Home Bar).

- **Grid Model:** Fluid single-column layouts on mobile with standard 16px (`1rem`) outer margins. For tablet viewports, layouts reflow into a 2-column or 3-column split view with 24px (`1.5rem`) margins.
- **Rhythm:** Internal card paddings use `space-lg` (20px), while grouped data points use `space-sm` (8px) and `space-xs` (4px) to retain related clinical context.

## Elevation & Depth

Visual depth is achieved through translucent background materials and diffused ambient shadows:

- **Frosted Translucency (Level 1):** `background: rgba(255, 255, 255, 0.78)`, `backdrop-filter: blur(20px) saturate(180%)`, paired with a hairline border `1px solid rgba(255, 255, 255, 0.6)`. Applied to floating search bars, bottom tab controls, and sheet headers.
- **Card Ambient Elevation (Level 2):** Pure white surface `#FFFFFF` supported by `0 4px 20px -2px rgba(11, 37, 69, 0.05), 0 1px 3px rgba(11, 37, 69, 0.03)` with a hairline boundary `1px solid rgba(224, 242, 254, 0.8)`.
- **Floating Modals & FABs (Level 3):** `0 12px 32px -4px rgba(11, 37, 69, 0.14), 0 4px 8px -2px rgba(11, 37, 69, 0.06)`. Elevates urgent triage actions, emergency appointment triggers, and active patient alerts.

## Shapes

The design system embraces iOS-native continuous curves ("squircles") that soften visual tension without looking juvenile:

- Standard Cards: 16px to 20px corner radius.
- Bottom Sheet Modals & Diagnostic Panels: 24px corner radius at top edges.
- Status Badges, Search Inputs & Segmented Controls: Full pill capsules (`9999px`).
- Interactive Icons & Action Buttons: 12px to 14px continuous smoothing.

## Components

### Buttons & Floating Actions
- **Primary Action:** Solid `#0B2545` with high-contrast `#FFFFFF` text, 48px height, 14px corner radius. On active press, scale down smoothly to `0.98`.
- **Secondary Action:** Tinted `#E0F2FE` background with `#007EA7` text and border-free container.
- **Emergency / Teleconsult FAB:** Floating circular (56px) or extended pill (48px) button bathed in `#00A896` or `#0B2545` with white iconography, cast above the tab bar.

### Segmented Controls (iOS Style)
- Encapsulated in a light `#F1F5F9` track with 10px radius.
- Active item snaps with an animated sliding white pill card accompanied by a subtle ambient drop shadow (`0 2px 6px rgba(0,0,0,0.08)`).

### Clinical Status Pills
- Compact capsules (height: 24px) utilizing semi-transparent background tints with rich dark foregrounds:
  - Emergency / Urgent: Background `rgba(225, 29, 72, 0.12)`, text `#BE123C`.
  - Scheduled / In Treatment: Background `rgba(245, 158, 11, 0.12)`, text `#B45309`.
  - Completed / Discharged: Background `rgba(16, 185, 129, 0.12)`, text `#047857`.

### Doctor & Department Cards
- Clean white background container, 16px radius, featuring avatar integration, specialty badge, doctor schedule summary, and a subtle Bondi Blue (`#007EA7`) right-chevron disclosure indicator.

### Input Fields & Search
- Frosted or `#FFFFFF` containers with 12px rounded borders, framed by a delicate `1px solid #E2E8F0` stroke. Transitions to a `2px solid #007EA7` outline upon active focus with keyboard accessibility.