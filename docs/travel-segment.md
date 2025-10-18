# Travel Time Segment Logic

This document explains how the Oh My Posh travel time segment in
`new_config.omp.json` works.

## Purpose

Displays contextual travel time information (minutes and traffic density)
during active hours while remaining invisible outside configured active hours
or when the location status is `unavailable`.

## Data Source

Data is read from the JSON file:

```text
./data/travel_time.json
```

Expected (simplified) structure:

```json
{
  "is_active_hours": true,
  "location_status": "active", // possible: active, inactive, unavailable
  "travel_time_minutes": 17,    // integer minutes (optional)
  "traffic_status": "moderate", // possible: heavy, moderate, light
  "error": null                 // optional error message or boolean
}
```

## Rendering Conditions

1. File exists.
2. File content parses successfully to JSON.
3. `is_active_hours` is true.
4. `location_status` is not `unavailable`.

If any condition fails, the segment emits no output and the background becomes
`transparent`.

## Icon & Output Mapping

| Condition                       | Output Example             |
|---------------------------------|----------------------------|
| `location_status == inactive`  | `⏸️` pause icon            |
| `travel_time_minutes` present  | `17min` + traffic icon     |
| `traffic_status == heavy`      | heavy glyph                |
| `traffic_status == moderate`   | moderate glyph             |
| other traffic                  | light glyph                |
| `error` present                | `❌ Error`                 |
| none (fallback)                | `? Unknown`                |

## Background Color Logic

When the segment is rendered (conditions pass):

- `error` → red
- `travel_time_minutes > 30` → red
- `travel_time_minutes > 20` → orange
- Otherwise: default blue background from segment definition

When not rendered (inactive hours or `unavailable`):

- Background forced to `transparent`.

## Template Walkthrough

Refactored template (simplified for explanation):

```text
{{ $file := ".\\data\\travel_time.json" }}
{{ if (.Env.PWD | .File.Exists $file) }}
  {{ with ($file | .File.ReadFile | fromJson) }}
    {{ if and . .is_active_hours (ne .location_status "unavailable") }}
      {{ if eq .location_status "inactive" }} ⏸️
      {{ else if and .travel_time_minutes }} {{ .travel_time_minutes }}min
      {{ else if .error }} ❌ Error
      {{ else }} ? Unknown
      {{ end }}
    {{ end }}
  {{ end }}
{{ end }}
```

## Extending the Logic

Add new traffic states or alternate rendering by inserting conditions before
the existing ones. For example, to show a warning when
`travel_time_minutes > 45`:

```text
{{ else if and .travel_time_minutes (gt .travel_time_minutes 45) }} ⚠️ Delay
```

## Testing Tips

- Create different `travel_time.json` variants in `data/` and reload the shell.
- Ensure JSON validity (malformed JSON leads to silent no-output).
- Test edge cases: missing keys, `error` flag set, extremely high travel times.

## Future Improvements

- Externalize icon mappings to a small lookup file.
- Add a `last_updated` timestamp and display staleness indicator.
- Merge configuration for active hours into a separate settings file for reuse.

---
Maintainers: Update this doc when segment logic changes.
