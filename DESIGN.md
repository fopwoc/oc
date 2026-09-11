<!-- Hallmark · genre: modern-minimal · macrostructure: Workbench · design-system: ColorStyle · designed-as-app -->
<!-- Hallmark · pre-emit critique: P5 H5 E5 S5 R5 V4 -->

# Design — OC consoles

This is the shared visual contract for applications rendered on OpenComputers
character screens.

## Character

Modern-minimal industrial console. Information density is useful; decoration
is not. The interface should read in this order: current state, consequential
metrics, operational detail, history.

## Shared shell

- Every application uses `components.Entrypoint` for the top bar, bottom bar,
  hardware context, lifecycle, and quit behavior.
- Every application obtains its palette through `components.ColorStyle`.
- The top and bottom bars remain one row tall.
- `Entrypoint` owns the one-cell content inset so app content remains centered
  between the edge-to-edge bars at every supported resolution.
- The top bar uses the stronger raised surface and carries app identity. The
  bottom bar uses the quieter surface and carries service/runtime metadata.

## Color roles

- `background`: quiet canvas.
- `surface`: ordinary panels and alternating rows.
- `surfaceVariant`: panel headings and selected controls.
- `primary`: a restrained blue-green used for structure, labels, navigation,
  and neutral live data.
- `good`, `warning`, `bad`: operational state only. Do not use status colors
  decoratively.
- `text`: primary values; `muted`: metadata and secondary explanations.

## Structure

- Prefer one compact summary band at the top of each application.
- Repeated entities belong in dense tables, not individual cards.
- A panel heading is part of the panel; do not spend a blank row separating it
  from its content.
- Avoid repeating the same diagnosis in multiple sections.
- Use horizontal-only cell padding to leave one cell between table columns.
  Truncate content before allowing labels or values to visually merge.
- Charts may expand into spare space, but their controls and captions remain
  compact.

## Application emphasis

- Power Monitor: state and stored energy first, current flow second, history
  third.
- Line Monitor: state, health, and input keep-up share one summary; inputs and
  outputs are the working surface. Keep-up is the consumed-to-arrival ratio,
  while health is the composite operational score.
- Crafter: scheduler state in the shell; one compact row per target.
- Dashboard: fleet scanability. Offline or unhealthy state must be findable
  faster than source metadata. Every source table ends with `SEEN`, then `UP`.
  Crafters use one aggregate row per source; individual targets remain in the
  crafter application and are not duplicated into telemetry payloads. Their
  satisfaction is the average clamped stock-to-target percentage.

## Interaction

- Selected controls use `primary`; inactive controls use `muted`.
- Actions use short bracketed labels that remain readable at narrow widths.
- Do not add animation: state changes and framebuffer diffs provide sufficient
  feedback on this platform.
