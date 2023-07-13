
## Bro aka NimSass
## A super fast stylesheet language for cool kids.
## 
## Full list of CSS Properties and Values, parser grammar and other cool things.
## 
## Auto-generated at Compile Time with Nim language from WebKit source:
## https://github.com/WebKit/WebKit/blob/main/Source/WebCore/css/CSSProperties.json
## 
## (c) 2023 George Lemon | MIT License
##          Made by Humans from OpenPeep
##          https://github.com/openpeep/bro
import
  std / tables

type
  Separator* = enum
    commaSep = ",", spaceSep = " "
  Status* = enum
    Implemented, NonStandard, Unimplemented, Experimental, Obsolete, Removed,
    Deprecated
  Property* = ref object
    status: Status
    longhands: seq[string]
    values: TableRef[string, Status]
    url: string

  PropertiesTable* = TableRef[string, Property]

proc hasStrictValue*(prop: Property; key: string): tuple[
    exists: bool, status: Status] =
  if prop.values != nil:
    if prop.values.hasKey(key):
      result.exists = true
      result.status = prop.values[key]

proc initPropsTable*(): PropertiesTable =
  result = newTable[string, Property]()
  ## 
  ## Property `accent-color`
  ## 
  result["accent-color"] = Property(url: "https://www.w3.org/TR/css-ui-4/#widget-accent",
                                        values: newTable({"auto": Implemented}))
  ## 
  ## Property `align-tracks`
  ## 
  result["align-tracks"] = Property(url: "https://drafts.csswg.org/css-grid-3/#tracks-alignment", values: newTable({
      "normal": Implemented, "first": Implemented, "last": Implemented,
      "baseline": Implemented, "space-between": Implemented,
      "space-around": Implemented, "space-evenly": Implemented,
      "stretch": Implemented, "unsafe": Implemented, "safe": Implemented,
      "center": Implemented, "start": Implemented, "end": Implemented,
      "flex-start": Implemented, "flex-end": Implemented}))
  ## 
  ## Property `caret-color`
  ## 
  result["caret-color"] = Property(url: "https://drafts.csswg.org/css-ui-3/#propdef-caret-color",
                                       values: newTable({"auto": Implemented}))
  ## 
  ## Property `color`
  ## 
  result["color"] = Property(url: "https://www.w3.org/TR/css-color-4/#the-color-property")
  ## 
  ## Property `direction`
  ## 
  result["direction"] = Property(url: "https://www.w3.org/TR/css-writing-modes-3/#propdef-direction", values: newTable(
      {"ltr": Implemented, "rtl": Implemented}))
  ## 
  ## Property `display`
  ## 
  result["display"] = Property(url: "https://www.w3.org/TR/css-display-3/#the-display-properties", values: newTable({
      "inline": Implemented, "block": Implemented, "flow": Implemented,
      "flow-root": Implemented, "list-item": Implemented,
      "inline-block": Implemented, "table": Implemented,
      "inline-table": Implemented, "table-row-group": Implemented,
      "table-header-group": Implemented, "table-footer-group": Implemented,
      "table-row": Implemented, "table-column-group": Implemented,
      "table-column": Implemented, "table-cell": Implemented,
      "table-caption": Implemented, "flex": Implemented,
      "inline-flex": Implemented, "grid": Implemented, "inline-grid": Implemented,
      "ruby": Unimplemented, "ruby-text-container": Unimplemented,
      "ruby-base": Unimplemented, "ruby-text": Unimplemented,
      "ruby-base-container": Unimplemented, "contents": Implemented,
      "none": Implemented, "-webkit-box": Obsolete,
      "-webkit-inline-box": Obsolete, "-webkit-flex": Obsolete,
      "-webkit-inline-flex": Obsolete, "compact": Removed, "run-in": Removed}))
  ## 
  ## Property `font-family`
  ## 
  result["font-family"] = Property(url: "https://www.w3.org/TR/css-fonts-3/#font-family-prop", values: newTable({
      "serif": Implemented, "sans-serif": Implemented, "cursive": Implemented,
      "fantasy": Implemented, "monospace": Implemented,
      "system-ui": Unimplemented, "emoji": Unimplemented, "math": Unimplemented,
      "fangsong": Unimplemented, "ui-serif": Unimplemented,
      "ui-sans-serif": Unimplemented, "ui-monospace": Unimplemented,
      "ui-rounded": Unimplemented, "-webkit-body": NonStandard}))
  ## 
  ## Property `font-size`
  ## 
  result["font-size"] = Property(url: "https://www.w3.org/TR/css-fonts-3/#font-size-prop", values: newTable({
      "x-small": Implemented, "xx-small": Implemented, "small": Implemented,
      "medium": Implemented, "large": Implemented, "x-large": Implemented,
      "xx-large": Implemented, "xxx-large": Implemented, "smaller": Implemented,
      "larger": Implemented, "-webkit-xxx-large": NonStandard,
      "-webkit-ruby-text": NonStandard}))
  ## 
  ## Property `font-size-adjust`
  ## 
  result["font-size-adjust"] = Property(
      url: "https://www.w3.org/TR/css-fonts-4/#font-size-adjust-prop",
      values: newTable({"none": Implemented}))
  ## 
  ## Property `font-style`
  ## 
  result["font-style"] = Property(url: "https://www.w3.org/TR/css-fonts-4/#font-style-prop", values: newTable(
      {"normal": Implemented, "italic": Implemented, "oblique": Implemented}))
  ## 
  ## Property `font-weight`
  ## 
  result["font-weight"] = Property(url: "https://www.w3.org/TR/css-fonts-4/#font-weight-prop", values: newTable({
      "normal": Implemented, "bold": Implemented, "bolder": Implemented,
      "lighter": Implemented}))
  ## 
  ## Property `font-stretch`
  ## 
  result["font-stretch"] = Property(url: "https://www.w3.org/TR/css-fonts-4/#font-stretch-prop", values: newTable({
      "normal": Implemented, "ultra-condensed": Implemented,
      "extra-condensed": Implemented, "condensed": Implemented,
      "semi-condensed": Implemented, "semi-expanded": Implemented,
      "expanded": Implemented, "extra-expanded": Implemented,
      "ultra-expanded": Implemented}))
  ## 
  ## Property `text-edge`
  ## 
  result["text-edge"] = Property(url: "https://www.w3.org/TR/css-inline-3/#text-edges", values: newTable({
      "leading": Implemented, "text": Implemented, "ex": Implemented,
      "ideographic": Implemented, "ideographic-ink": Implemented,
      "alphabetic": Implemented, "cap": Implemented}))
  ## 
  ## Property `text-rendering`
  ## 
  result["text-rendering"] = Property(url: "https://www.w3.org/TR/SVG11/painting.html#TextRenderingProperty", values: newTable({
      "auto": Implemented, "optimizeSpeed": Implemented,
      "optimizeLegibility": Implemented, "geometricPrecision": Implemented}))
  ## 
  ## Property `font-feature-settings`
  ## 
  result["font-feature-settings"] = Property(
      url: "https://drafts.csswg.org/css-fonts-4/#propdef-font-feature-settings",
      values: newTable({"normal": Implemented}))
  ## 
  ## Property `font-variation-settings`
  ## 
  result["font-variation-settings"] = Property(
      url: "https://drafts.csswg.org/css-fonts-4/#font-variation-settings-def",
      values: newTable({"normal": Implemented}))
  ## 
  ## Property `font-kerning`
  ## 
  result["font-kerning"] = Property(url: "https://drafts.csswg.org/css-fonts-4/#font-kerning-prop", values: newTable(
      {"auto": Implemented, "normal": Implemented, "none": Implemented}))
  ## 
  ## Property `font-palette`
  ## 
  result["font-palette"] = Property(url: "https://drafts.csswg.org/css-fonts/#font-palette-prop")
  ## 
  ## Property `-webkit-font-smoothing`
  ## 
  result["-webkit-font-smoothing"] = Property(values: newTable({
      "auto": Implemented, "none": Implemented, "antialiased": Implemented,
      "subpixel-antialiased": Implemented}))
  ## 
  ## Property `font-variant-ligatures`
  ## 
  result["font-variant-ligatures"] = Property(
      url: "https://drafts.csswg.org/css-fonts-4/#font-variant-ligatures-prop", values: newTable({
      "normal": Implemented, "none": Implemented, "common-ligatures": Implemented,
      "no-common-ligatures": Implemented, "discretionary-ligatures": Implemented,
      "no-discretionary-ligatures": Implemented,
      "historical-ligatures": Implemented, "no-historical-ligatures": Implemented,
      "contextual": Implemented, "no-contextual": Implemented}))
  ## 
  ## Property `font-variant-position`
  ## 
  result["font-variant-position"] = Property(
      url: "https://drafts.csswg.org/css-fonts-3/#propdef-font-variant-position", values: newTable(
      {"normal": Implemented, "sub": Implemented, "super": Implemented}))
  ## 
  ## Property `font-variant-caps`
  ## 
  result["font-variant-caps"] = Property(
      url: "https://drafts.csswg.org/css-fonts-3/#font-variant-caps-prop", values: newTable({
      "normal": Implemented, "small-caps": Implemented,
      "all-small-caps": Implemented, "petite-caps": Implemented,
      "all-petite-caps": Implemented, "unicase": Implemented,
      "titling-caps": Implemented}))
  ## 
  ## Property `font-variant-numeric`
  ## 
  result["font-variant-numeric"] = Property(
      url: "https://drafts.csswg.org/css-fonts-3/#font-variant-numeric-prop", values: newTable({
      "normal": Implemented, "lining-nums": Implemented,
      "oldstyle-nums": Implemented, "proportional-nums": Implemented,
      "tabular-nums": Implemented, "diagonal-fractions": Implemented,
      "stacked-fractions": Implemented, "ordinal": Implemented,
      "slashed-zero": Implemented}))
  ## 
  ## Property `font-variant-alternates`
  ## 
  result["font-variant-alternates"] = Property(
      url: "https://drafts.csswg.org/css-fonts-4/#font-variant-alternates-prop")
  ## 
  ## Property `font-variant-east-asian`
  ## 
  result["font-variant-east-asian"] = Property(
      url: "https://drafts.csswg.org/css-fonts-4/#font-variant-east-asian-prop", values: newTable({
      "normal": Implemented, "jis78": Implemented, "jis83": Implemented,
      "jis90": Implemented, "jis04": Implemented, "simplified": Implemented,
      "traditional": Implemented, "diagonal-fractions": Implemented,
      "stacked-fractions": Implemented, "ruby": Implemented}))
  ## 
  ## Property `font-synthesis`
  ## 
  result["font-synthesis"] = Property(url: "https://drafts.csswg.org/css-fonts-4/#font-synthesis", longhands: @[
      "font-synthesis-weight", "font-synthesis-style", "font-synthesis-small-caps"])
  ## 
  ## Property `font-synthesis-weight`
  ## 
  result["font-synthesis-weight"] = Property(
      url: "https://drafts.csswg.org/css-fonts-4/#font-synthesis-weight",
      values: newTable({"auto": Implemented, "none": Implemented}))
  ## 
  ## Property `font-synthesis-style`
  ## 
  result["font-synthesis-style"] = Property(
      url: "https://drafts.csswg.org/css-fonts-4/#font-synthesis-style",
      values: newTable({"auto": Implemented, "none": Implemented}))
  ## 
  ## Property `font-synthesis-small-caps`
  ## 
  result["font-synthesis-small-caps"] = Property(
      url: "https://drafts.csswg.org/css-fonts-4/#font-synthesis-small-caps",
      values: newTable({"auto": Implemented, "none": Implemented}))
  ## 
  ## Property `font-optical-sizing`
  ## 
  result["font-optical-sizing"] = Property(
      url: "https://drafts.csswg.org/css-fonts-4/#font-optical-sizing-def",
      values: newTable({"auto": Implemented, "none": Implemented}))
  ## 
  ## Property `font`
  ## 
  result["font"] = Property(url: "https://www.w3.org/TR/css-fonts-3/#font-prop", longhands: @[
      "font-style", "font-variant-caps", "font-weight", "font-stretch",
      "font-size", "line-height", "font-family", "font-size-adjust",
      "font-kerning", "font-variant-alternates", "font-variant-ligatures",
      "font-variant-numeric", "font-variant-east-asian", "font-variant-position",
      "font-feature-settings", "", ""])
  ## 
  ## Property `font-variant`
  ## 
  result["font-variant"] = Property(url: "https://www.w3.org/TR/css-fonts-3/#propdef-font-variant", longhands: @[
      "font-variant-ligatures", "font-variant-caps", "font-variant-alternates",
      "font-variant-numeric", "font-variant-east-asian", "font-variant-position"])
  ## 
  ## Property `justify-tracks`
  ## 
  result["justify-tracks"] = Property(url: "https://drafts.csswg.org/css-grid-3/#tracks-alignment", values: newTable({
      "normal": Implemented, "space-between": Implemented,
      "space-around": Implemented, "space-evenly": Implemented,
      "stretch": Implemented, "unsafe": Implemented, "safe": Implemented,
      "center": Implemented, "start": Implemented, "end": Implemented,
      "flex-start": Implemented, "flex-end": Implemented, "left": Implemented,
      "right": Implemented}))
  ## 
  ## Property `-webkit-locale`
  ## 
  result["-webkit-locale"] = Property()
  ## 
  ## Property `text-orientation`
  ## 
  result["text-orientation"] = Property(
      url: "https://www.w3.org/TR/css-writing-modes-3/#text-orientation", values: newTable(
      {"sideways": Implemented, "mixed": Implemented, "upright": Implemented}))
  ## 
  ## Property `-webkit-text-orientation`
  ## 
  result["-webkit-text-orientation"] = Property(
      url: "https://www.w3.org/TR/css-writing-modes-3/#text-orientation",
      longhands: @["text-orientation"], values: newTable({"sideways": Implemented,
      "sideways-right": Deprecated, "mixed": Implemented, "upright": Implemented}))
  ## 
  ## Property `-webkit-text-size-adjust`
  ## 
  result["-webkit-text-size-adjust"] = Property()
  ## 
  ## Property `text-spacing-trim`
  ## 
  result["text-spacing-trim"] = Property(
      values: newTable({"auto": Implemented, "space-all": Implemented}))
  ## 
  ## Property `text-autospace`
  ## 
  result["text-autospace"] = Property(values: newTable(
      {"auto": Implemented, "no-autospace": Implemented}))
  ## 
  ## Property `writing-mode`
  ## 
  result["writing-mode"] = Property(values: newTable({
      "horizontal-tb": Implemented, "vertical-lr": Implemented,
      "vertical-rl": Implemented, "sideways-lr": Unimplemented,
      "sideways-rl": Unimplemented, "lr-tb": Deprecated, "rl-tb": Deprecated,
      "tb-rl": Deprecated, "lr": Deprecated, "rl": Deprecated, "tb": Deprecated,
      "horizontal-bt": NonStandard}))
  ## 
  ## Property `-webkit-text-zoom`
  ## 
  result["-webkit-text-zoom"] = Property(
      values: newTable({"normal": Implemented, "reset": Implemented}))
  ## 
  ## Property `zoom`
  ## 
  result["zoom"] = Property(url: "https://msdn.microsoft.com/en-us/library/ms531189(v=vs.85).aspx", values: newTable(
      {"normal": Implemented, "reset": Implemented, "document": Implemented}))
  ## 
  ## Property `-webkit-ruby-position`
  ## 
  result["-webkit-ruby-position"] = Property(
      url: "https://www.w3.org/TR/css-ruby-1/#rubypos", values: newTable({
      "before": Deprecated, "after": Deprecated, "inter-character": Implemented,
      "over": Unimplemented, "under": Unimplemented}))
  ## 
  ## Property `alignment-baseline`
  ## 
  result["alignment-baseline"] = Property(
      url: "https://www.w3.org/TR/SVG11/text.html#AlignmentBaselineProperty", values: newTable({
      "auto": Implemented, "baseline": Implemented, "before-edge": Implemented,
      "text-before-edge": Implemented, "middle": Implemented,
      "central": Implemented, "after-edge": Implemented,
      "text-after-edge": Implemented, "ideographic": Implemented,
      "alphabetic": Implemented, "hanging": Implemented,
      "mathematical": Implemented}))
  ## 
  ## Property `all`
  ## 
  result["all"] = Property(url: "https://www.w3.org/TR/css-cascade-3/#all-shorthand",
                               longhands: @["all"])
  ## 
  ## Property `animation`
  ## 
  result["animation"] = Property(url: "https://www.w3.org/TR/css3-animations/#animation-shorthand-property", longhands: @[
      "animation-duration", "animation-timing-function", "animation-delay",
      "animation-iteration-count", "animation-direction", "animation-fill-mode",
      "animation-play-state", "animation-name"])
  ## 
  ## Property `animation-composition`
  ## 
  result["animation-composition"] = Property(
      url: "https://drafts.csswg.org/css-animations-2/#animation-composition", values: newTable(
      {"add": Implemented, "accumulate": Implemented, "replace": Implemented}))
  ## 
  ## Property `animation-delay`
  ## 
  result["animation-delay"] = Property(
      url: "https://www.w3.org/TR/css3-animations/#animation-delay-property")
  ## 
  ## Property `animation-direction`
  ## 
  result["animation-direction"] = Property(
      url: "https://www.w3.org/TR/css3-animations/#animation-direction-property", values: newTable({
      "normal": Implemented, "reverse": Implemented, "alternate": Implemented,
      "alternate-reverse": Implemented}))
  ## 
  ## Property `animation-duration`
  ## 
  result["animation-duration"] = Property(
      url: "https://www.w3.org/TR/css3-animations/#animation-duration-property")
  ## 
  ## Property `animation-fill-mode`
  ## 
  result["animation-fill-mode"] = Property(
      url: "https://www.w3.org/TR/css3-animations/#animation-fill-mode-property", values: newTable({
      "none": Implemented, "forwards": Implemented, "backwards": Implemented,
      "both": Implemented}))
  ## 
  ## Property `animation-iteration-count`
  ## 
  result["animation-iteration-count"] = Property(url: "https://www.w3.org/TR/css3-animations/#animation-iteration-count-property")
  ## 
  ## Property `animation-name`
  ## 
  result["animation-name"] = Property(url: "https://www.w3.org/TR/css3-animations/#animation-name-property")
  ## 
  ## Property `animation-play-state`
  ## 
  result["animation-play-state"] = Property(url: "https://www.w3.org/TR/css3-animations/#animation-play-state-property",
      values: newTable({"running": Implemented, "paused": Implemented}))
  ## 
  ## Property `animation-timing-function`
  ## 
  result["animation-timing-function"] = Property(url: "https://www.w3.org/TR/css3-animations/#animation-timing-function-property")
  ## 
  ## Property `background`
  ## 
  result["background"] = Property(url: "https://www.w3.org/TR/css3-background/#the-background", longhands: @[
      "background-color", "background-image", "background-position-x",
      "background-position-y", "background-size", "background-repeat",
      "background-attachment", "background-origin", "background-clip"])
  ## 
  ## Property `background-attachment`
  ## 
  result["background-attachment"] = Property(
      url: "https://www.w3.org/TR/css3-background/#the-background-attachment", values: newTable(
      {"scroll": Implemented, "fixed": Implemented, "local": Implemented}))
  ## 
  ## Property `background-blend-mode`
  ## 
  result["background-blend-mode"] = Property(
      url: "https://www.w3.org/TR/compositing-1/#background-blend-mode", values: newTable({
      "normal": Implemented, "multiply": Implemented, "screen": Implemented,
      "overlay": Implemented, "darken": Implemented, "lighten": Implemented,
      "color-dodge": Implemented, "color-burn": Implemented,
      "hard-light": Implemented, "soft-light": Implemented,
      "difference": Implemented, "exclusion": Implemented, "hue": Implemented,
      "saturation": Implemented, "color": Implemented, "luminosity": Implemented,
      "plus-darker": Unimplemented, "plus-lighter": Unimplemented}))
  ## 
  ## Property `background-clip`
  ## 
  result["background-clip"] = Property(
      url: "https://www.w3.org/TR/css3-background/#the-background-clip", values: newTable({
      "border-box": Implemented, "padding-box": Implemented,
      "content-box": Implemented, "border": Unimplemented, "text": Implemented,
      "-webkit-text": NonStandard}))
  ## 
  ## Property `background-color`
  ## 
  result["background-color"] = Property(
      url: "https://www.w3.org/TR/css3-background/#the-background-color")
  ## 
  ## Property `background-image`
  ## 
  result["background-image"] = Property(
      url: "https://www.w3.org/TR/css3-background/#the-background-image")
  ## 
  ## Property `background-origin`
  ## 
  result["background-origin"] = Property(
      url: "https://www.w3.org/TR/css3-background/#the-background-origin")
  ## 
  ## Property `background-position`
  ## 
  result["background-position"] = Property(
      url: "https://www.w3.org/TR/css3-background/#background-position",
      longhands: @["background-position-x", "background-position-y"])
  ## 
  ## Property `background-position-x`
  ## 
  result["background-position-x"] = Property(url: "https://drafts.csswg.org/css-backgrounds-4/#propdef-background-position-x")
  ## 
  ## Property `background-position-y`
  ## 
  result["background-position-y"] = Property(url: "https://drafts.csswg.org/css-backgrounds-4/#propdef-background-position-y")
  ## 
  ## Property `background-repeat`
  ## 
  result["background-repeat"] = Property(
      url: "https://www.w3.org/TR/css3-background/#background-repeat")
  ## 
  ## Property `background-size`
  ## 
  result["background-size"] = Property(
      url: "https://www.w3.org/TR/css3-background/#background-size")
  ## 
  ## Property `baseline-shift`
  ## 
  result["baseline-shift"] = Property(url: "https://www.w3.org/TR/SVG11/text.html#BaselineShiftProperty", values: newTable(
      {"baseline": Implemented, "sub": Implemented, "super": Implemented}))
  ## 
  ## Property `block-size`
  ## 
  result["block-size"] = Property(url: "https://www.w3.org/TR/css-logical/#dimension-properties")
  ## 
  ## Property `border`
  ## 
  result["border"] = Property(url: "https://www.w3.org/TR/css3-background/#the-border-shorthands", longhands: @[
      "border-top-width", "border-right-width", "border-bottom-width",
      "border-left-width", "border-top-style", "border-right-style",
      "border-bottom-style", "border-left-style", "border-top-color",
      "border-right-color", "border-bottom-color", "border-left-color",
      "border-image-source", "border-image-slice", "border-image-width",
      "border-image-outset", "border-image-repeat"])
  ## 
  ## Property `border-block`
  ## 
  result["border-block"] = Property(url: "https://www.w3.org/TR/css-logical/#border-shorthands", longhands: @[
      "border-block-start-width", "border-block-end-width",
      "border-block-start-style", "border-block-end-style",
      "border-block-start-color", "border-block-end-color"])
  ## 
  ## Property `border-block-color`
  ## 
  result["border-block-color"] = Property(
      url: "https://www.w3.org/TR/css-logical/#border-color",
      longhands: @["border-block-start-color", "border-block-end-color"])
  ## 
  ## Property `border-block-end`
  ## 
  result["border-block-end"] = Property(
      url: "https://www.w3.org/TR/css-logical/#border-shorthands", longhands: @[
      "border-block-end-width", "border-block-end-style", "border-block-end-color"])
  ## 
  ## Property `border-block-end-color`
  ## 
  result["border-block-end-color"] = Property(
      url: "https://www.w3.org/TR/css-logical/#border-color")
  ## 
  ## Property `border-block-end-style`
  ## 
  result["border-block-end-style"] = Property(
      url: "https://www.w3.org/TR/css-logical/#border-style", values: newTable({
      "none": Implemented, "hidden": Implemented, "inset": Implemented,
      "groove": Implemented, "outset": Implemented, "ridge": Implemented,
      "dotted": Implemented, "dashed": Implemented, "solid": Implemented,
      "double": Implemented}))
  ## 
  ## Property `border-block-end-width`
  ## 
  result["border-block-end-width"] = Property(
      url: "https://www.w3.org/TR/css-logical/#border-width", values: newTable(
      {"thin": Implemented, "medium": Implemented, "thick": Implemented}))
  ## 
  ## Property `border-block-start`
  ## 
  result["border-block-start"] = Property(
      url: "https://www.w3.org/TR/css-logical/#border-shorthands", longhands: @[
      "border-block-start-width", "border-block-start-style",
      "border-block-start-color"])
  ## 
  ## Property `border-block-start-color`
  ## 
  result["border-block-start-color"] = Property(
      url: "https://www.w3.org/TR/css-logical/#border-color")
  ## 
  ## Property `border-block-start-style`
  ## 
  result["border-block-start-style"] = Property(
      url: "https://www.w3.org/TR/css-logical/#border-style", values: newTable({
      "none": Implemented, "hidden": Implemented, "inset": Implemented,
      "groove": Implemented, "outset": Implemented, "ridge": Implemented,
      "dotted": Implemented, "dashed": Implemented, "solid": Implemented,
      "double": Implemented}))
  ## 
  ## Property `border-block-start-width`
  ## 
  result["border-block-start-width"] = Property(
      url: "https://www.w3.org/TR/css-logical/#border-width", values: newTable(
      {"thin": Implemented, "medium": Implemented, "thick": Implemented}))
  ## 
  ## Property `border-block-style`
  ## 
  result["border-block-style"] = Property(
      url: "https://www.w3.org/TR/css-logical/#border-style",
      longhands: @["border-block-start-style", "border-block-end-style"])
  ## 
  ## Property `border-block-width`
  ## 
  result["border-block-width"] = Property(
      url: "https://www.w3.org/TR/css-logical/#border-width",
      longhands: @["border-block-start-width", "border-block-end-width"])
  ## 
  ## Property `border-bottom`
  ## 
  result["border-bottom"] = Property(url: "https://www.w3.org/TR/css3-background/#the-border-shorthands", longhands: @[
      "border-bottom-width", "border-bottom-style", "border-bottom-color"])
  ## 
  ## Property `border-bottom-color`
  ## 
  result["border-bottom-color"] = Property(
      url: "https://www.w3.org/TR/css3-background/#the-border-color")
  ## 
  ## Property `border-bottom-left-radius`
  ## 
  result["border-bottom-left-radius"] = Property(
      url: "https://www.w3.org/TR/css3-background/#the-border-radius")
  ## 
  ## Property `border-bottom-right-radius`
  ## 
  result["border-bottom-right-radius"] = Property(
      url: "https://www.w3.org/TR/css3-background/#the-border-radius")
  ## 
  ## Property `border-bottom-style`
  ## 
  result["border-bottom-style"] = Property(
      url: "https://www.w3.org/TR/css3-background/#the-border-style", values: newTable({
      "none": Implemented, "hidden": Implemented, "inset": Implemented,
      "groove": Implemented, "outset": Implemented, "ridge": Implemented,
      "dotted": Implemented, "dashed": Implemented, "solid": Implemented,
      "double": Implemented}))
  ## 
  ## Property `border-bottom-width`
  ## 
  result["border-bottom-width"] = Property(
      url: "https://www.w3.org/TR/css3-background/#the-border-width", values: newTable(
      {"thin": Implemented, "medium": Implemented, "thick": Implemented}))
  ## 
  ## Property `border-collapse`
  ## 
  result["border-collapse"] = Property(
      url: "https://www.w3.org/TR/CSS22/tables.html#borders",
      values: newTable({"collapse": Implemented, "separate": Implemented}))
  ## 
  ## Property `border-color`
  ## 
  result["border-color"] = Property(url: "https://www.w3.org/TR/css3-background/#the-border-color", longhands: @[
      "border-top-color", "border-right-color", "border-bottom-color",
      "border-left-color"])
  ## 
  ## Property `border-end-end-radius`
  ## 
  result["border-end-end-radius"] = Property(
      url: "https://drafts.csswg.org/css-logical-1/#border-radius-properties")
  ## 
  ## Property `border-end-start-radius`
  ## 
  result["border-end-start-radius"] = Property(
      url: "https://drafts.csswg.org/css-logical-1/#border-radius-properties")
  ## 
  ## Property `border-image`
  ## 
  result["border-image"] = Property(url: "https://www.w3.org/TR/css3-background/#the-border-image", longhands: @[
      "border-image-source", "border-image-slice", "border-image-width",
      "border-image-outset", "border-image-repeat"])
  ## 
  ## Property `border-image-outset`
  ## 
  result["border-image-outset"] = Property(
      url: "https://www.w3.org/TR/css3-background/#the-border-image-outset")
  ## 
  ## Property `border-image-repeat`
  ## 
  result["border-image-repeat"] = Property(
      url: "https://www.w3.org/TR/css3-background/#the-border-image-repeat", values: newTable({
      "stretch": Implemented, "repeat": Implemented, "round": Implemented,
      "space": Implemented}))
  ## 
  ## Property `border-image-slice`
  ## 
  result["border-image-slice"] = Property(
      url: "https://www.w3.org/TR/css3-background/#the-border-image-slice",
      values: newTable({"fill": Implemented}))
  ## 
  ## Property `border-image-source`
  ## 
  result["border-image-source"] = Property(
      url: "https://www.w3.org/TR/css3-background/#the-border-image-source",
      values: newTable({"none": Implemented}))
  ## 
  ## Property `border-image-width`
  ## 
  result["border-image-width"] = Property(
      url: "https://www.w3.org/TR/css3-background/#the-border-image-width",
      values: newTable({"auto": Implemented}))
  ## 
  ## Property `border-inline`
  ## 
  result["border-inline"] = Property(url: "https://www.w3.org/TR/css-logical/#border-shorthands", longhands: @[
      "border-inline-start-width", "border-inline-end-width",
      "border-inline-start-style", "border-inline-end-style",
      "border-inline-start-color", "border-inline-end-color"])
  ## 
  ## Property `border-inline-color`
  ## 
  result["border-inline-color"] = Property(
      url: "https://www.w3.org/TR/css-logical/#border-color",
      longhands: @["border-inline-start-color", "border-inline-end-color"])
  ## 
  ## Property `border-inline-end`
  ## 
  result["border-inline-end"] = Property(
      url: "https://www.w3.org/TR/css-logical/#border-shorthands", longhands: @[
      "border-inline-end-width", "border-inline-end-style",
      "border-inline-end-color"])
  ## 
  ## Property `border-inline-end-color`
  ## 
  result["border-inline-end-color"] = Property(
      url: "https://www.w3.org/TR/css-logical/#border-color")
  ## 
  ## Property `border-inline-end-style`
  ## 
  result["border-inline-end-style"] = Property(
      url: "https://www.w3.org/TR/css-logical/#border-style", values: newTable({
      "none": Implemented, "hidden": Implemented, "inset": Implemented,
      "groove": Implemented, "outset": Implemented, "ridge": Implemented,
      "dotted": Implemented, "dashed": Implemented, "solid": Implemented,
      "double": Implemented}))
  ## 
  ## Property `border-inline-end-width`
  ## 
  result["border-inline-end-width"] = Property(
      url: "https://www.w3.org/TR/css-logical/#border-width", values: newTable(
      {"thin": Implemented, "medium": Implemented, "thick": Implemented}))
  ## 
  ## Property `border-inline-start`
  ## 
  result["border-inline-start"] = Property(
      url: "https://www.w3.org/TR/css-logical/#border-shorthands", longhands: @[
      "border-inline-start-width", "border-inline-start-style",
      "border-inline-start-color"])
  ## 
  ## Property `border-inline-start-color`
  ## 
  result["border-inline-start-color"] = Property(
      url: "https://www.w3.org/TR/css-logical/#border-color")
  ## 
  ## Property `border-inline-start-style`
  ## 
  result["border-inline-start-style"] = Property(
      url: "https://www.w3.org/TR/css-logical/#border-style", values: newTable({
      "none": Implemented, "hidden": Implemented, "inset": Implemented,
      "groove": Implemented, "outset": Implemented, "ridge": Implemented,
      "dotted": Implemented, "dashed": Implemented, "solid": Implemented,
      "double": Implemented}))
  ## 
  ## Property `border-inline-start-width`
  ## 
  result["border-inline-start-width"] = Property(
      url: "https://www.w3.org/TR/css-logical/#border-width", values: newTable(
      {"thin": Implemented, "medium": Implemented, "thick": Implemented}))
  ## 
  ## Property `border-inline-style`
  ## 
  result["border-inline-style"] = Property(
      url: "https://www.w3.org/TR/css-logical/#border-style",
      longhands: @["border-inline-start-style", "border-inline-end-style"])
  ## 
  ## Property `border-inline-width`
  ## 
  result["border-inline-width"] = Property(
      url: "https://www.w3.org/TR/css-logical/#border-width",
      longhands: @["border-inline-start-width", "border-inline-end-width"])
  ## 
  ## Property `border-left`
  ## 
  result["border-left"] = Property(url: "https://www.w3.org/TR/css3-background/#the-border-shorthands", longhands: @[
      "border-left-width", "border-left-style", "border-left-color"])
  ## 
  ## Property `border-left-color`
  ## 
  result["border-left-color"] = Property(
      url: "https://www.w3.org/TR/css3-background/#the-border-color")
  ## 
  ## Property `border-left-style`
  ## 
  result["border-left-style"] = Property(
      url: "https://www.w3.org/TR/css3-background/#the-border-style", values: newTable({
      "none": Implemented, "hidden": Implemented, "inset": Implemented,
      "groove": Implemented, "outset": Implemented, "ridge": Implemented,
      "dotted": Implemented, "dashed": Implemented, "solid": Implemented,
      "double": Implemented}))
  ## 
  ## Property `border-left-width`
  ## 
  result["border-left-width"] = Property(
      url: "https://www.w3.org/TR/css3-background/#the-border-width", values: newTable(
      {"thin": Implemented, "medium": Implemented, "thick": Implemented}))
  ## 
  ## Property `border-radius`
  ## 
  result["border-radius"] = Property(url: "https://www.w3.org/TR/css3-background/#the-border-radius", longhands: @[
      "border-top-left-radius", "border-top-right-radius",
      "border-bottom-right-radius", "border-bottom-left-radius"])
  ## 
  ## Property `border-right`
  ## 
  result["border-right"] = Property(url: "https://www.w3.org/TR/css3-background/#the-border-shorthands", longhands: @[
      "border-right-width", "border-right-style", "border-right-color"])
  ## 
  ## Property `border-right-color`
  ## 
  result["border-right-color"] = Property(
      url: "https://www.w3.org/TR/css3-background/#the-border-color")
  ## 
  ## Property `border-right-style`
  ## 
  result["border-right-style"] = Property(
      url: "https://www.w3.org/TR/css3-background/#the-border-style", values: newTable({
      "none": Implemented, "hidden": Implemented, "inset": Implemented,
      "groove": Implemented, "outset": Implemented, "ridge": Implemented,
      "dotted": Implemented, "dashed": Implemented, "solid": Implemented,
      "double": Implemented}))
  ## 
  ## Property `border-right-width`
  ## 
  result["border-right-width"] = Property(
      url: "https://www.w3.org/TR/css3-background/#the-border-width", values: newTable(
      {"thin": Implemented, "medium": Implemented, "thick": Implemented}))
  ## 
  ## Property `border-spacing`
  ## 
  result["border-spacing"] = Property(url: "https://www.w3.org/TR/CSS22/tables.html#separated-borders", longhands: @[
      "-webkit-border-horizontal-spacing", "-webkit-border-vertical-spacing"])
  ## 
  ## Property `border-start-end-radius`
  ## 
  result["border-start-end-radius"] = Property(
      url: "https://drafts.csswg.org/css-logical-1/#border-radius-properties")
  ## 
  ## Property `border-start-start-radius`
  ## 
  result["border-start-start-radius"] = Property(
      url: "https://drafts.csswg.org/css-logical-1/#border-radius-properties")
  ## 
  ## Property `border-style`
  ## 
  result["border-style"] = Property(url: "https://www.w3.org/TR/css3-background/#the-border-style", longhands: @[
      "border-top-style", "border-right-style", "border-bottom-style",
      "border-left-style"])
  ## 
  ## Property `border-top`
  ## 
  result["border-top"] = Property(url: "https://www.w3.org/TR/css3-background/#the-border-shorthands", longhands: @[
      "border-top-width", "border-top-style", "border-top-color"])
  ## 
  ## Property `border-top-color`
  ## 
  result["border-top-color"] = Property(
      url: "https://www.w3.org/TR/css3-background/#the-border-color")
  ## 
  ## Property `border-top-left-radius`
  ## 
  result["border-top-left-radius"] = Property(
      url: "https://www.w3.org/TR/css3-background/#the-border-radius")
  ## 
  ## Property `border-top-right-radius`
  ## 
  result["border-top-right-radius"] = Property(
      url: "https://www.w3.org/TR/css3-background/#the-border-radius")
  ## 
  ## Property `border-top-style`
  ## 
  result["border-top-style"] = Property(
      url: "https://www.w3.org/TR/css3-background/#the-border-style", values: newTable({
      "none": Implemented, "hidden": Implemented, "inset": Implemented,
      "groove": Implemented, "outset": Implemented, "ridge": Implemented,
      "dotted": Implemented, "dashed": Implemented, "solid": Implemented,
      "double": Implemented}))
  ## 
  ## Property `border-top-width`
  ## 
  result["border-top-width"] = Property(
      url: "https://www.w3.org/TR/css3-background/#the-border-width", values: newTable(
      {"thin": Implemented, "medium": Implemented, "thick": Implemented}))
  ## 
  ## Property `border-width`
  ## 
  result["border-width"] = Property(url: "https://www.w3.org/TR/css3-background/#the-border-width", longhands: @[
      "border-top-width", "border-right-width", "border-bottom-width",
      "border-left-width"])
  ## 
  ## Property `bottom`
  ## 
  result["bottom"] = Property(url: "https://www.w3.org/TR/CSS22/visuren.html#propdef-bottom",
                                  values: newTable({"auto": Implemented}))
  ## 
  ## Property `box-shadow`
  ## 
  result["box-shadow"] = Property(url: "https://www.w3.org/TR/css3-background/#the-box-shadow", values: newTable(
      {"none": Implemented, "inset": Implemented}))
  ## 
  ## Property `box-sizing`
  ## 
  result["box-sizing"] = Property(url: "https://www.w3.org/TR/css-ui-3/#box-sizing", values: newTable(
      {"border-box": Implemented, "content-box": Implemented}))
  ## 
  ## Property `break-after`
  ## 
  result["break-after"] = Property(url: "https://www.w3.org/TR/css-break-3/#break-between", values: newTable({
      "auto": Implemented, "avoid": Implemented, "avoid-page": Implemented,
      "page": Implemented, "left": Implemented, "right": Implemented,
      "recto": Implemented, "verso": Implemented, "avoid-column": Implemented,
      "column": Implemented, "avoid-region": Unimplemented,
      "region": Unimplemented}))
  ## 
  ## Property `break-before`
  ## 
  result["break-before"] = Property(url: "https://www.w3.org/TR/css-break-3/#break-between", values: newTable({
      "auto": Implemented, "avoid": Implemented, "avoid-page": Implemented,
      "page": Implemented, "left": Implemented, "right": Implemented,
      "recto": Implemented, "verso": Implemented, "avoid-column": Implemented,
      "column": Implemented, "avoid-region": Unimplemented,
      "region": Unimplemented}))
  ## 
  ## Property `break-inside`
  ## 
  result["break-inside"] = Property(url: "https://www.w3.org/TR/css-break-3/#break-within", values: newTable({
      "auto": Implemented, "avoid": Implemented, "avoid-page": Implemented,
      "avoid-column": Implemented, "avoid-region": Unimplemented}))
  ## 
  ## Property `buffered-rendering`
  ## 
  result["buffered-rendering"] = Property(url: "https://www.w3.org/TR/SVGTiny12/painting.html#BufferedRenderingProperty", values: newTable(
      {"auto": Implemented, "dynamic": Implemented, "static": Implemented}))
  ## 
  ## Property `caption-side`
  ## 
  result["caption-side"] = Property(url: "https://www.w3.org/TR/CSS22/tables.html#propdef-caption-side", values: newTable({
      "left": Implemented, "right": Implemented, "top": Implemented,
      "bottom": Implemented, "inline-start": Unimplemented,
      "inline-end": Unimplemented}))
  ## 
  ## Property `clear`
  ## 
  result["clear"] = Property(url: "https://www.w3.org/TR/CSS22/visuren.html#propdef-clear", values: newTable({
      "none": Implemented, "left": Implemented, "right": Implemented,
      "both": Implemented, "inline-start": Implemented, "inline-end": Implemented}))
  ## 
  ## Property `clip`
  ## 
  result["clip"] = Property(url: "https://drafts.fxtf.org/css-masking/#clip-property",
                                values: newTable({"auto": Implemented}))
  ## 
  ## Property `clip-path`
  ## 
  result["clip-path"] = Property(url: "https://drafts.fxtf.org/css-masking/#propdef-clip-path", values: newTable({
      "none": Implemented, "content-box": Implemented, "margin-box": Implemented,
      "stroke-box": Implemented, "border-box": Implemented,
      "fill-box": Implemented, "view-box": Implemented, "padding-box": Implemented}))
  ## 
  ## Property `clip-rule`
  ## 
  result["clip-rule"] = Property(url: "https://drafts.fxtf.org/css-masking/#propdef-clip-rule", values: newTable(
      {"nonzero": Implemented, "evenodd": Implemented}))
  ## 
  ## Property `color-interpolation`
  ## 
  result["color-interpolation"] = Property(url: "https://www.w3.org/TR/SVG11/painting.html#ColorInterpolationProperty", values: newTable(
      {"auto": Implemented, "sRGB": Implemented, "linearRGB": Implemented}))
  ## 
  ## Property `color-interpolation-filters`
  ## 
  result["color-interpolation-filters"] = Property(url: "https://www.w3.org/TR/SVG11/painting.html#ColorInterpolationFiltersProperty", values: newTable(
      {"auto": Implemented, "sRGB": Implemented, "linearRGB": Implemented}))
  ## 
  ## Property `content`
  ## 
  result["content"] = Property(url: "https://www.w3.org/TR/css-content-3/#content-property")
  ## 
  ## Property `counter-increment`
  ## 
  result["counter-increment"] = Property(
      url: "https://www.w3.org/TR/css-lists-3/#propdef-counter-increment",
      values: newTable({"none": Implemented}))
  ## 
  ## Property `counter-reset`
  ## 
  result["counter-reset"] = Property(url: "https://www.w3.org/TR/css-lists-3/#counter-properties",
                                         values: newTable({"none": Implemented}))
  ## 
  ## Property `counter-set`
  ## 
  result["counter-set"] = Property(url: "https://www.w3.org/TR/css-lists-3/#propdef-counter-set")
  ## 
  ## Property `cursor`
  ## 
  result["cursor"] = Property(url: "https://www.w3.org/TR/css-ui-3/#cursor", values: newTable({
      "auto": Implemented, "default": Implemented, "none": Implemented,
      "context-menu": Implemented, "help": Implemented, "pointer": Implemented,
      "progress": Implemented, "wait": Implemented, "cell": Implemented,
      "crosshair": Implemented, "text": Implemented, "vertical-text": Implemented,
      "alias": Implemented, "copy": Implemented, "move": Implemented,
      "no-drop": Implemented, "not-allowed": Implemented, "grab": Implemented,
      "grabbing": Implemented, "e-resize": Implemented, "n-resize": Implemented,
      "ne-resize": Implemented, "nw-resize": Implemented, "s-resize": Implemented,
      "se-resize": Implemented, "sw-resize": Implemented, "w-resize": Implemented,
      "ew-resize": Implemented, "ns-resize": Implemented,
      "nesw-resize": Implemented, "nwse-resize": Implemented,
      "col-resize": Implemented, "row-resize": Implemented,
      "all-scroll": Implemented, "zoom-in": Implemented, "zoom-out": Implemented,
      "-webkit-grab": NonStandard, "-webkit-grabbing": NonStandard,
      "-webkit-zoom-in": NonStandard, "-webkit-zoom-out": NonStandard}))
  ## 
  ## Property `-webkit-cursor-visibility`
  ## 
  result["-webkit-cursor-visibility"] = Property(
      values: newTable({"auto": Implemented, "auto-hide": Implemented}))
  ## 
  ## Property `cx`
  ## 
  result["cx"] = Property(url: "https://www.w3.org/TR/SVG/shapes.html")
  ## 
  ## Property `cy`
  ## 
  result["cy"] = Property(url: "https://www.w3.org/TR/SVG/shapes.html")
  ## 
  ## Property `dominant-baseline`
  ## 
  result["dominant-baseline"] = Property(
      url: "https://www.w3.org/TR/SVG11/text.html#DominantBaselineProperty", values: newTable({
      "auto": Implemented, "use-script": Implemented, "no-change": Implemented,
      "reset-size": Implemented, "ideographic": Implemented,
      "alphabetic": Implemented, "hanging": Implemented,
      "mathematical": Implemented, "central": Implemented, "middle": Implemented,
      "text-before-edge": Implemented, "text-after-edge": Implemented}))
  ## 
  ## Property `empty-cells`
  ## 
  result["empty-cells"] = Property(url: "https://www.w3.org/TR/CSS2/tables.html#empty-cells", values: newTable(
      {"show": Implemented, "hide": Implemented}))
  ## 
  ## Property `fill`
  ## 
  result["fill"] = Property(url: "https://svgwg.org/svg2-draft/painting.html#SpecifyingFillPaint", values: newTable({
      "none": Implemented, "context-fill": Unimplemented,
      "context-stroke": Unimplemented}))
  ## 
  ## Property `fill-opacity`
  ## 
  result["fill-opacity"] = Property(url: "https://www.w3.org/TR/SVG/painting.html#FillOpacityProperty")
  ## 
  ## Property `fill-rule`
  ## 
  result["fill-rule"] = Property(url: "https://www.w3.org/TR/SVG/painting.html#FillRuleProperty", values: newTable(
      {"nonzero": Implemented, "evenodd": Implemented}))
  ## 
  ## Property `float`
  ## 
  result["float"] = Property(url: "https://www.w3.org/TR/CSS22/visuren.html#float-position", values: newTable({
      "left": Implemented, "right": Implemented, "none": Implemented,
      "inline-start": Implemented, "inline-end": Implemented}))
  ## 
  ## Property `flood-color`
  ## 
  result["flood-color"] = Property(url: "https://www.w3.org/TR/SVG/filters.html#FloodColorProperty")
  ## 
  ## Property `flood-opacity`
  ## 
  result["flood-opacity"] = Property(url: "https://www.w3.org/TR/filter-effects/#FloodOpacityProperty")
  ## 
  ## Property `glyph-orientation-horizontal`
  ## 
  result["glyph-orientation-horizontal"] = Property(url: "https://www.w3.org/TR/SVG11/text.html#GlyphOrientationHorizontalProperty")
  ## 
  ## Property `glyph-orientation-vertical`
  ## 
  result["glyph-orientation-vertical"] = Property(url: "https://www.w3.org/TR/SVG11/text.html#GlyphOrientationVerticalProperty",
      values: newTable({"auto": Implemented}))
  ## 
  ## Property `hanging-punctuation`
  ## 
  result["hanging-punctuation"] = Property(
      url: "https://www.w3.org/TR/css-text-3/#hanging-punctuation", values: newTable({
      "none": Implemented, "first": Implemented, "force-end": Implemented,
      "allow-end": Implemented, "last": Implemented}))
  ## 
  ## Property `height`
  ## 
  result["height"] = Property(url: "https://www.w3.org/TR/CSS22/visudet.html#the-height-property")
  ## 
  ## Property `image-orientation`
  ## 
  result["image-orientation"] = Property(
      url: "https://www.w3.org/TR/css3-images/#the-image-orientation",
      values: newTable({"from-image": Implemented, "none": Implemented}))
  ## 
  ## Property `image-rendering`
  ## 
  result["image-rendering"] = Property(
      url: "https://drafts.csswg.org/css-images-3/#propdef-image-rendering", values: newTable({
      "auto": Implemented, "smooth": Unimplemented, "high-quality": Unimplemented,
      "pixelated": Implemented, "crisp-edges": Implemented,
      "optimizeSpeed": Implemented, "optimizeQuality": Implemented,
      "-webkit-crisp-edges": NonStandard, "-webkit-optimize-contrast": NonStandard}))
  ## 
  ## Property `image-resolution`
  ## 
  result["image-resolution"] = Property(
      url: "https://www.w3.org/TR/css-images-4/#image-resolution",
      values: newTable({"from-image": Implemented, "snap": Implemented}))
  ## 
  ## Property `inline-size`
  ## 
  result["inline-size"] = Property(url: "https://www.w3.org/TR/css-logical/#dimension-properties")
  ## 
  ## Property `input-security`
  ## 
  result["input-security"] = Property(url: "https://drafts.csswg.org/css-ui-4/#input-security", values: newTable(
      {"auto": Implemented, "none": Implemented}))
  ## 
  ## Property `inset`
  ## 
  result["inset"] = Property(url: "https://www.w3.org/TR/css-logical/#inset-properties",
                                 longhands: @["top", "right", "bottom", "left"])
  ## 
  ## Property `inset-block`
  ## 
  result["inset-block"] = Property(url: "https://www.w3.org/TR/css-logical/#inset-properties", longhands: @[
      "inset-block-start", "inset-block-end"])
  ## 
  ## Property `inset-block-end`
  ## 
  result["inset-block-end"] = Property(
      url: "https://www.w3.org/TR/css-logical/#inset-properties")
  ## 
  ## Property `inset-block-start`
  ## 
  result["inset-block-start"] = Property(
      url: "https://www.w3.org/TR/css-logical/#inset-properties")
  ## 
  ## Property `inset-inline`
  ## 
  result["inset-inline"] = Property(url: "https://www.w3.org/TR/css-logical/#inset-properties", longhands: @[
      "inset-inline-start", "inset-inline-end"])
  ## 
  ## Property `inset-inline-end`
  ## 
  result["inset-inline-end"] = Property(
      url: "https://www.w3.org/TR/css-logical/#inset-properties")
  ## 
  ## Property `inset-inline-start`
  ## 
  result["inset-inline-start"] = Property(
      url: "https://www.w3.org/TR/css-logical/#inset-properties")
  ## 
  ## Property `kerning`
  ## 
  result["kerning"] = Property(url: "https://www.w3.org/TR/SVG11/text.html#KerningProperty")
  ## 
  ## Property `leading-trim`
  ## 
  result["leading-trim"] = Property(url: "https://www.w3.org/TR/css-inline-3/#leading-trim", values: newTable({
      "normal": Implemented, "start": Implemented, "end": Implemented,
      "both": Implemented}))
  ## 
  ## Property `left`
  ## 
  result["left"] = Property(url: "https://www.w3.org/TR/CSS22/visuren.html#propdef-left",
                                values: newTable({"auto": Implemented}))
  ## 
  ## Property `letter-spacing`
  ## 
  result["letter-spacing"] = Property(url: "https://www.w3.org/TR/css-text-3/#letter-spacing-property")
  ## 
  ## Property `lighting-color`
  ## 
  result["lighting-color"] = Property()
  ## 
  ## Property `line-height`
  ## 
  result["line-height"] = Property(url: "https://www.w3.org/TR/css-inline-3/#line-height-property")
  ## 
  ## Property `list-style`
  ## 
  result["list-style"] = Property(url: "https://www.w3.org/TR/css-lists-3/#list-style-property", longhands: @[
      "list-style-position", "list-style-image", "list-style-type"])
  ## 
  ## Property `list-style-image`
  ## 
  result["list-style-image"] = Property(
      url: "https://www.w3.org/TR/css-lists-3/#propdef-list-style-image")
  ## 
  ## Property `list-style-position`
  ## 
  result["list-style-position"] = Property(
      url: "https://www.w3.org/TR/css-lists-3/#propdef-list-style-position",
      values: newTable({"inside": Implemented, "outside": Implemented}))
  ## 
  ## Property `list-style-type`
  ## 
  result["list-style-type"] = Property(
      url: "https://www.w3.org/TR/css-lists-3/#propdef-list-style-type", values: newTable({
      "disc": Implemented, "circle": Implemented, "square": Implemented,
      "decimal": Implemented, "decimal-leading-zero": Implemented,
      "arabic-indic": Implemented, "binary": Implemented, "bengali": Implemented,
      "cambodian": Implemented, "khmer": Implemented, "devanagari": Implemented,
      "gujarati": Implemented, "gurmukhi": Implemented, "kannada": Implemented,
      "lower-hexadecimal": Implemented, "lao": Implemented,
      "malayalam": Implemented, "mongolian": Implemented, "myanmar": Implemented,
      "octal": Implemented, "oriya": Implemented, "persian": Implemented,
      "urdu": Implemented, "telugu": Implemented, "tibetan": Implemented,
      "thai": Implemented, "upper-hexadecimal": Implemented,
      "lower-roman": Implemented, "upper-roman": Implemented,
      "lower-greek": Implemented, "lower-alpha": Implemented,
      "lower-latin": Implemented, "upper-alpha": Implemented,
      "upper-latin": Implemented, "afar": Implemented,
      "ethiopic-halehame-aa-et": Implemented,
      "ethiopic-halehame-aa-er": Implemented, "amharic": Implemented,
      "ethiopic-halehame-am-et": Implemented, "amharic-abegede": Implemented,
      "ethiopic-abegede-am-et": Implemented, "cjk-earthly-branch": Implemented,
      "cjk-heavenly-stem": Implemented, "ethiopic": Implemented,
      "ethiopic-halehame-gez": Implemented, "ethiopic-abegede": Implemented,
      "ethiopic-abegede-gez": Implemented, "hangul-consonant": Implemented,
      "hangul": Implemented, "lower-norwegian": Implemented, "oromo": Implemented,
      "ethiopic-halehame-om-et": Implemented, "sidama": Implemented,
      "ethiopic-halehame-sid-et": Implemented, "somali": Implemented,
      "ethiopic-halehame-so-et": Implemented, "tigre": Implemented,
      "ethiopic-halehame-tig": Implemented, "tigrinya-er": Implemented,
      "ethiopic-halehame-ti-er": Implemented, "tigrinya-er-abegede": Implemented,
      "ethiopic-abegede-ti-er": Implemented, "tigrinya-et": Implemented,
      "ethiopic-halehame-ti-et": Implemented, "tigrinya-et-abegede": Implemented,
      "ethiopic-abegede-ti-et": Implemented, "upper-greek": Implemented,
      "upper-norwegian": Implemented, "asterisks": Implemented,
      "footnotes": Implemented, "hebrew": Implemented, "armenian": Implemented,
      "lower-armenian": Implemented, "upper-armenian": Implemented,
      "georgian": Implemented, "cjk-ideographic": Implemented,
      "hiragana": Implemented, "katakana": Implemented,
      "hiragana-iroha": Implemented, "katakana-iroha": Implemented,
      "cjk-decimal": Implemented, "tamil": Implemented,
      "disclosure-open": Implemented, "disclosure-closed": Implemented,
      "japanese-informal": Implemented, "japanese-formal": Implemented,
      "korean-hangul-formal": Implemented, "korean-hanja-informal": Implemented,
      "korean-hanja-formal": Implemented, "simp-chinese-informal": Implemented,
      "simp-chinese-formal": Implemented, "trad-chinese-informal": Implemented,
      "trad-chinese-formal": Implemented, "ethiopic-numeric": Implemented,
      "none": Implemented}))
  ## 
  ## Property `margin`
  ## 
  result["margin"] = Property(url: "https://www.w3.org/TR/CSS22/box.html#propdef-margin", longhands: @[
      "margin-top", "margin-right", "margin-bottom", "margin-left"])
  ## 
  ## Property `margin-block`
  ## 
  result["margin-block"] = Property(url: "https://www.w3.org/TR/css-logical/#margin-properties", longhands: @[
      "margin-block-start", "margin-block-end"])
  ## 
  ## Property `margin-block-end`
  ## 
  result["margin-block-end"] = Property(
      url: "https://www.w3.org/TR/css-logical/#margin-properties")
  ## 
  ## Property `margin-block-start`
  ## 
  result["margin-block-start"] = Property(
      url: "https://www.w3.org/TR/css-logical/#margin-properties")
  ## 
  ## Property `margin-bottom`
  ## 
  result["margin-bottom"] = Property(url: "https://www.w3.org/TR/CSS22/box.html#propdef-margin-bottom",
                                         values: newTable({"auto": Implemented}))
  ## 
  ## Property `margin-inline`
  ## 
  result["margin-inline"] = Property(url: "https://www.w3.org/TR/css-logical/#margin-properties", longhands: @[
      "margin-inline-start", "margin-inline-end"])
  ## 
  ## Property `margin-inline-end`
  ## 
  result["margin-inline-end"] = Property(
      url: "https://www.w3.org/TR/css-logical/#margin-properties")
  ## 
  ## Property `margin-inline-start`
  ## 
  result["margin-inline-start"] = Property(
      url: "https://www.w3.org/TR/css-logical/#margin-properties")
  ## 
  ## Property `margin-left`
  ## 
  result["margin-left"] = Property(url: "https://www.w3.org/TR/CSS22/box.html#propdef-margin-left",
                                       values: newTable({"auto": Implemented}))
  ## 
  ## Property `margin-right`
  ## 
  result["margin-right"] = Property(url: "https://www.w3.org/TR/CSS22/box.html#propdef-margin-right",
                                        values: newTable({"auto": Implemented}))
  ## 
  ## Property `margin-top`
  ## 
  result["margin-top"] = Property(url: "https://www.w3.org/TR/CSS22/box.html#propdef-margin-top",
                                      values: newTable({"auto": Implemented}))
  ## 
  ## Property `margin-trim`
  ## 
  result["margin-trim"] = Property(url: "https://www.w3.org/TR/css-box-4/#margin-trim", values: newTable({
      "none": Implemented, "block": Implemented, "inline": Implemented,
      "block-start": Implemented, "inline-start": Implemented,
      "block-end": Implemented, "inline-end": Implemented}))
  ## 
  ## Property `marker`
  ## 
  result["marker"] = Property(url: "https://www.w3.org/TR/SVG/painting.html#MarkerProperty", longhands: @[
      "marker-start", "marker-mid", "marker-end"])
  ## 
  ## Property `marker-end`
  ## 
  result["marker-end"] = Property(url: "https://www.w3.org/TR/SVG/painting.html#MarkerEndProperty",
                                      values: newTable({"none": Implemented}))
  ## 
  ## Property `marker-mid`
  ## 
  result["marker-mid"] = Property(url: "https://www.w3.org/TR/SVG/painting.html#MarkerMidProperty",
                                      values: newTable({"none": Implemented}))
  ## 
  ## Property `marker-start`
  ## 
  result["marker-start"] = Property(url: "https://www.w3.org/TR/SVG/painting.html#MarkerStartProperty",
                                        values: newTable({"none": Implemented}))
  ## 
  ## Property `mask`
  ## 
  result["mask"] = Property(url: "https://www.w3.org/TR/css-masking-1/#propdef-mask", longhands: @[
      "mask-image", "-webkit-mask-position-x", "-webkit-mask-position-y",
      "mask-size", "mask-repeat", "mask-origin", "mask-clip", "mask-composite",
      "mask-mode"])
  ## 
  ## Property `mask-clip`
  ## 
  result["mask-clip"] = Property(url: "https://www.w3.org/TR/css-masking-1/#propdef-mask-clip")
  ## 
  ## Property `mask-composite`
  ## 
  result["mask-composite"] = Property(url: "https://www.w3.org/TR/css-masking-1/#propdef-mask-composite")
  ## 
  ## Property `mask-image`
  ## 
  result["mask-image"] = Property(url: "https://www.w3.org/TR/css-masking-1/#propdef-mask-image")
  ## 
  ## Property `mask-mode`
  ## 
  result["mask-mode"] = Property(url: "https://www.w3.org/TR/css-masking-1/#propdef-mask-mode")
  ## 
  ## Property `mask-origin`
  ## 
  result["mask-origin"] = Property(url: "https://www.w3.org/TR/css-masking-1/#propdef-mask-origin")
  ## 
  ## Property `mask-position`
  ## 
  result["mask-position"] = Property(url: "https://www.w3.org/TR/css-masking-1/#propdef-mask-position", longhands: @[
      "-webkit-mask-position-x", "-webkit-mask-position-y"])
  ## 
  ## Property `-webkit-mask-position`
  ## 
  result["-webkit-mask-position"] = Property(
      url: "https://www.w3.org/TR/css-masking-1/#propdef-mask-position",
      longhands: @["-webkit-mask-position-x", "-webkit-mask-position-y"])
  ## 
  ## Property `-webkit-mask-position-x`
  ## 
  result["-webkit-mask-position-x"] = Property(
      url: "https://www.w3.org/TR/css-masking-1/#propdef-mask-position")
  ## 
  ## Property `-webkit-mask-position-y`
  ## 
  result["-webkit-mask-position-y"] = Property(
      url: "https://www.w3.org/TR/css-masking-1/#propdef-mask-position")
  ## 
  ## Property `mask-repeat`
  ## 
  result["mask-repeat"] = Property(url: "https://www.w3.org/TR/css-masking-1/#propdef-mask-repeat")
  ## 
  ## Property `mask-size`
  ## 
  result["mask-size"] = Property(url: "https://www.w3.org/TR/css-masking-1/#propdef-mask-size")
  ## 
  ## Property `mask-type`
  ## 
  result["mask-type"] = Property(url: "https://drafts.fxtf.org/css-masking-1/#propdef-mask-type", values: newTable(
      {"luminance": Implemented, "alpha": Implemented}))
  ## 
  ## Property `masonry-auto-flow`
  ## 
  result["masonry-auto-flow"] = Property(
      url: "https://drafts.csswg.org/css-grid-3/#masonry-auto-flow", values: newTable({
      "pack": Implemented, "next": Implemented, "definite-first": Implemented,
      "ordered": Implemented}))
  ## 
  ## Property `math-style`
  ## 
  result["math-style"] = Property(url: "https://mathml-refresh.github.io/mathml-core/#dfn-math-style", values: newTable(
      {"normal": Implemented, "compact": Implemented}))
  ## 
  ## Property `max-block-size`
  ## 
  result["max-block-size"] = Property(url: "https://www.w3.org/TR/css-logical/#dimension-properties")
  ## 
  ## Property `max-height`
  ## 
  result["max-height"] = Property(url: "https://www.w3.org/TR/CSS22/visudet.html#propdef-max-height")
  ## 
  ## Property `max-inline-size`
  ## 
  result["max-inline-size"] = Property(
      url: "https://www.w3.org/TR/css-logical/#dimension-properties")
  ## 
  ## Property `max-width`
  ## 
  result["max-width"] = Property(url: "https://www.w3.org/TR/CSS22/visudet.html#propdef-max-width")
  ## 
  ## Property `min-block-size`
  ## 
  result["min-block-size"] = Property(url: "https://www.w3.org/TR/css-logical/#dimension-properties")
  ## 
  ## Property `min-height`
  ## 
  result["min-height"] = Property(url: "https://www.w3.org/TR/CSS22/visudet.html#propdef-min-height")
  ## 
  ## Property `min-inline-size`
  ## 
  result["min-inline-size"] = Property(
      url: "https://www.w3.org/TR/css-logical/#dimension-properties")
  ## 
  ## Property `min-width`
  ## 
  result["min-width"] = Property(url: "https://www.w3.org/TR/CSS22/visudet.html#propdef-min-width")
  ## 
  ## Property `object-fit`
  ## 
  result["object-fit"] = Property(url: "https://www.w3.org/TR/css-images-3/#the-object-fit", values: newTable({
      "fill": Implemented, "contain": Implemented, "cover": Implemented,
      "none": Implemented, "scale-down": Implemented}))
  ## 
  ## Property `object-position`
  ## 
  result["object-position"] = Property(
      url: "https://www.w3.org/TR/css3-images/#object-position")
  ## 
  ## Property `offset-path`
  ## 
  result["offset-path"] = Property(url: "https://drafts.fxtf.org/motion-1/#offset-path-property",
                                       values: newTable({"none": Implemented}))
  ## 
  ## Property `offset-distance`
  ## 
  result["offset-distance"] = Property(
      url: "https://drafts.fxtf.org/motion-1/#offset-distance-property")
  ## 
  ## Property `offset-position`
  ## 
  result["offset-position"] = Property(
      url: "https://drafts.fxtf.org/motion-1/#offset-position-property",
      values: newTable({"auto": Implemented}))
  ## 
  ## Property `offset-anchor`
  ## 
  result["offset-anchor"] = Property(url: "https://drafts.fxtf.org/motion-1/#offset-anchor-property",
                                         values: newTable({"auto": Implemented}))
  ## 
  ## Property `offset-rotate`
  ## 
  result["offset-rotate"] = Property(url: "https://drafts.fxtf.org/motion-1/#offset-rotate-property", values: newTable(
      {"auto": Implemented, "reverse": Implemented}))
  ## 
  ## Property `offset`
  ## 
  result["offset"] = Property(url: "https://drafts.fxtf.org/motion-1/#offset-shorthand", longhands: @[
      "offset-position", "offset-path", "offset-distance", "offset-rotate",
      "offset-anchor"])
  ## 
  ## Property `opacity`
  ## 
  result["opacity"] = Property(url: "https://www.w3.org/TR/css-color-4/#propdef-opacity")
  ## 
  ## Property `orphans`
  ## 
  result["orphans"] = Property(url: "https://www.w3.org/TR/CSS22/page.html#propdef-orphans")
  ## 
  ## Property `outline`
  ## 
  result["outline"] = Property(url: "https://www.w3.org/TR/css-ui-3/#propdef-outline", longhands: @[
      "outline-color", "outline-style", "outline-width"])
  ## 
  ## Property `outline-color`
  ## 
  result["outline-color"] = Property(url: "https://www.w3.org/TR/css-ui-3/#propdef-outline-color")
  ## 
  ## Property `outline-offset`
  ## 
  result["outline-offset"] = Property(url: "https://www.w3.org/TR/css-ui-3/#propdef-outline-offset")
  ## 
  ## Property `outline-style`
  ## 
  result["outline-style"] = Property(url: "https://drafts.csswg.org/css-ui/#typedef-outline-line-style", values: newTable({
      "auto": Implemented, "none": Implemented, "inset": Implemented,
      "groove": Implemented, "outset": Implemented, "ridge": Implemented,
      "dotted": Implemented, "dashed": Implemented, "solid": Implemented,
      "double": Implemented}))
  ## 
  ## Property `outline-width`
  ## 
  result["outline-width"] = Property(url: "https://www.w3.org/TR/css-ui-3/#propdef-outline-width", values: newTable(
      {"thin": Implemented, "medium": Implemented, "thick": Implemented}))
  ## 
  ## Property `overflow`
  ## 
  result["overflow"] = Property(url: "https://www.w3.org/TR/css-overflow-3/#propdef-overflow",
                                    longhands: @["overflow-x", "overflow-y"])
  ## 
  ## Property `overflow-anchor`
  ## 
  result["overflow-anchor"] = Property(url: "https://www.w3.org/TR/css-scroll-anchoring-1/#propdef-overflow-anchor",
      values: newTable({"none": Implemented, "auto": Implemented}))
  ## 
  ## Property `overflow-wrap`
  ## 
  result["overflow-wrap"] = Property(url: "https://www.w3.org/TR/css-text-3/#overflow-wrap", values: newTable(
      {"normal": Implemented, "break-word": Implemented, "anywhere": Implemented}))
  ## 
  ## Property `overflow-x`
  ## 
  result["overflow-x"] = Property(url: "https://www.w3.org/TR/css-overflow-3/#propdef-overflow-x", values: newTable({
      "visible": Implemented, "hidden": Implemented, "clip": Implemented,
      "scroll": Implemented, "auto": Implemented, "overlay": NonStandard}))
  ## 
  ## Property `overflow-y`
  ## 
  result["overflow-y"] = Property(url: "https://www.w3.org/TR/css-overflow-3/#propdef-overflow-y", values: newTable({
      "visible": Implemented, "hidden": Implemented, "clip": Implemented,
      "scroll": Implemented, "auto": Implemented, "overlay": NonStandard,
      "-webkit-paged-x": NonStandard, "-webkit-paged-y": NonStandard}))
  ## 
  ## Property `overscroll-behavior`
  ## 
  result["overscroll-behavior"] = Property(url: "https://drafts.csswg.org/css-overscroll-1/#propdef-overscroll-behavior",
      longhands: @["overscroll-behavior-x", "overscroll-behavior-y"])
  ## 
  ## Property `overscroll-behavior-x`
  ## 
  result["overscroll-behavior-x"] = Property(url: "https://drafts.csswg.org/css-overscroll-1/#propdef-overscroll-behavior-x", values: newTable(
      {"contain": Implemented, "none": Implemented, "auto": Implemented}))
  ## 
  ## Property `overscroll-behavior-y`
  ## 
  result["overscroll-behavior-y"] = Property(url: "https://drafts.csswg.org/css-overscroll-1/#propdef-overscroll-behavior-y", values: newTable(
      {"contain": Implemented, "none": Implemented, "auto": Implemented}))
  ## 
  ## Property `overscroll-behavior-inline`
  ## 
  result["overscroll-behavior-inline"] = Property(url: "https://drafts.csswg.org/css-overscroll-1/#propdef-overscroll-behavior-x", values: newTable(
      {"contain": Implemented, "none": Implemented, "auto": Implemented}))
  ## 
  ## Property `overscroll-behavior-block`
  ## 
  result["overscroll-behavior-block"] = Property(url: "https://drafts.csswg.org/css-overscroll-1/#propdef-overscroll-behavior-x", values: newTable(
      {"contain": Implemented, "none": Implemented, "auto": Implemented}))
  ## 
  ## Property `padding`
  ## 
  result["padding"] = Property(url: "https://www.w3.org/TR/CSS22/box.html#propdef-padding", longhands: @[
      "padding-top", "padding-right", "padding-bottom", "padding-left"])
  ## 
  ## Property `padding-block`
  ## 
  result["padding-block"] = Property(url: "https://www.w3.org/TR/css-logical/#padding-properties", longhands: @[
      "padding-block-start", "padding-block-end"])
  ## 
  ## Property `padding-block-end`
  ## 
  result["padding-block-end"] = Property(
      url: "https://www.w3.org/TR/css-logical/#padding-properties")
  ## 
  ## Property `padding-block-start`
  ## 
  result["padding-block-start"] = Property(
      url: "https://www.w3.org/TR/css-logical/#padding-properties")
  ## 
  ## Property `padding-bottom`
  ## 
  result["padding-bottom"] = Property(url: "https://www.w3.org/TR/CSS22/box.html#propdef-padding-bottom")
  ## 
  ## Property `padding-inline`
  ## 
  result["padding-inline"] = Property(url: "https://www.w3.org/TR/css-logical/#padding-properties", longhands: @[
      "padding-inline-start", "padding-inline-end"])
  ## 
  ## Property `padding-inline-end`
  ## 
  result["padding-inline-end"] = Property(
      url: "https://www.w3.org/TR/css-logical/#padding-properties")
  ## 
  ## Property `padding-inline-start`
  ## 
  result["padding-inline-start"] = Property(
      url: "https://www.w3.org/TR/css-logical/#padding-properties")
  ## 
  ## Property `padding-left`
  ## 
  result["padding-left"] = Property(url: "https://www.w3.org/TR/CSS22/box.html#propdef-padding-left")
  ## 
  ## Property `padding-right`
  ## 
  result["padding-right"] = Property(url: "https://www.w3.org/TR/CSS22/box.html#propdef-padding-right")
  ## 
  ## Property `padding-top`
  ## 
  result["padding-top"] = Property(url: "https://www.w3.org/TR/CSS22/box.html#propdef-padding-top")
  ## 
  ## Property `page`
  ## 
  result["page"] = Property(url: "https://www.w3.org/TR/css3-page/#page",
                                values: newTable({"auto": Implemented}))
  ## 
  ## Property `page-break-after`
  ## 
  result["page-break-after"] = Property(
      url: "https://www.w3.org/TR/CSS22/page.html#propdef-page-break-after",
      longhands: @["break-after"])
  ## 
  ## Property `page-break-before`
  ## 
  result["page-break-before"] = Property(
      url: "https://www.w3.org/TR/CSS22/page.html#propdef-page-break-before",
      longhands: @["break-before"])
  ## 
  ## Property `page-break-inside`
  ## 
  result["page-break-inside"] = Property(
      url: "https://www.w3.org/TR/CSS22/page.html#propdef-page-break-inside",
      longhands: @["break-inside"])
  ## 
  ## Property `paint-order`
  ## 
  result["paint-order"] = Property()
  ## 
  ## Property `pointer-events`
  ## 
  result["pointer-events"] = Property(url: "https://www.w3.org/TR/SVG11/interact.html#PointerEventsProperty", values: newTable({
      "visiblePainted": Implemented, "visibleFill": Implemented,
      "visibleStroke": Implemented, "visible": Implemented,
      "painted": Implemented, "fill": Implemented, "stroke": Implemented,
      "all": Implemented, "none": Implemented, "auto": Implemented,
      "bounding-box": Implemented}))
  ## 
  ## Property `position`
  ## 
  result["position"] = Property(url: "https://www.w3.org/TR/CSS2/visuren.html#propdef-position", values: newTable({
      "static": Implemented, "relative": Implemented, "absolute": Implemented,
      "fixed": Implemented, "sticky": Implemented, "-webkit-sticky": Deprecated}))
  ## 
  ## Property `quotes`
  ## 
  result["quotes"] = Property(url: "https://www.w3.org/TR/css-content-3/#quotes-property", values: newTable(
      {"auto": Implemented, "none": Implemented}))
  ## 
  ## Property `r`
  ## 
  result["r"] = Property(url: "https://www.w3.org/TR/SVG/shapes.html")
  ## 
  ## Property `resize`
  ## 
  result["resize"] = Property(url: "https://www.w3.org/TR/css-ui-3/#propdef-resize", values: newTable({
      "none": Implemented, "both": Implemented, "horizontal": Implemented,
      "vertical": Implemented, "block": Implemented, "inline": Implemented,
      "auto": NonStandard}))
  ## 
  ## Property `right`
  ## 
  result["right"] = Property(url: "https://www.w3.org/TR/CSS22/visuren.html#propdef-right",
                                 values: newTable({"auto": Implemented}))
  ## 
  ## Property `rx`
  ## 
  result["rx"] = Property(url: "https://www.w3.org/TR/SVG/shapes.html",
                              values: newTable({"auto": Implemented}))
  ## 
  ## Property `ry`
  ## 
  result["ry"] = Property(url: "https://www.w3.org/TR/SVG/shapes.html",
                              values: newTable({"auto": Implemented}))
  ## 
  ## Property `shape-rendering`
  ## 
  result["shape-rendering"] = Property(
      url: "https://www.w3.org/TR/SVG11/painting.html#ShapeRenderingProperty", values: newTable({
      "auto": Implemented, "optimizeSpeed": Implemented,
      "crispedges": Implemented, "geometricPrecision": Implemented}))
  ## 
  ## Property `size`
  ## 
  result["size"] = Property(url: "https://www.w3.org/TR/css3-page/#page-size-prop")
  ## 
  ## Property `stop-color`
  ## 
  result["stop-color"] = Property(url: "https://www.w3.org/TR/SVG11/pservers.html#StopColorProperty")
  ## 
  ## Property `stop-opacity`
  ## 
  result["stop-opacity"] = Property(url: "https://www.w3.org/TR/SVG11/pservers.html#StopOpacityProperty")
  ## 
  ## Property `stroke`
  ## 
  result["stroke"] = Property(url: "https://svgwg.org/svg2-draft/painting.html#SpecifyingStrokePaint")
  ## 
  ## Property `stroke-dasharray`
  ## 
  result["stroke-dasharray"] = Property(
      url: "https://svgwg.org/svg2-draft/painting.html#StrokeDashing")
  ## 
  ## Property `stroke-dashoffset`
  ## 
  result["stroke-dashoffset"] = Property(
      url: "https://svgwg.org/svg2-draft/painting.html#StrokeDashoffsetProperty")
  ## 
  ## Property `stroke-linecap`
  ## 
  result["stroke-linecap"] = Property(url: "https://drafts.fxtf.org/fill-stroke-3/#propdef-stroke-linecap", values: newTable(
      {"butt": Implemented, "round": Implemented, "square": Implemented}))
  ## 
  ## Property `stroke-linejoin`
  ## 
  result["stroke-linejoin"] = Property(
      url: "https://drafts.fxtf.org/fill-stroke-3/#propdef-stroke-linejoin", values: newTable(
      {"miter": Implemented, "round": Implemented, "bevel": Implemented}))
  ## 
  ## Property `stroke-miterlimit`
  ## 
  result["stroke-miterlimit"] = Property(
      url: "https://drafts.fxtf.org/fill-stroke-3/#propdef-stroke-miterlimit")
  ## 
  ## Property `stroke-opacity`
  ## 
  result["stroke-opacity"] = Property(url: "https://www.w3.org/TR/SVG11/painting.html#StrokeOpacityProperty")
  ## 
  ## Property `stroke-color`
  ## 
  result["stroke-color"] = Property(url: "https://drafts.fxtf.org/fill-stroke-3/#propdef-stroke-color")
  ## 
  ## Property `stroke-width`
  ## 
  result["stroke-width"] = Property(url: "https://drafts.fxtf.org/fill-stroke-3/#propdef-stroke-width")
  ## 
  ## Property `speak-as`
  ## 
  result["speak-as"] = Property(url: "https://www.w3.org/TR/css3-speech/#speak-as", values: newTable({
      "normal": Implemented, "spell-out": Implemented, "digits": Implemented,
      "literal-punctuation": Implemented, "no-punctuation": Implemented}))
  ## 
  ## Property `table-layout`
  ## 
  result["table-layout"] = Property(url: "https://www.w3.org/TR/CSS22/tables.html#propdef-table-layout", values: newTable(
      {"auto": Implemented, "fixed": Implemented}))
  ## 
  ## Property `tab-size`
  ## 
  result["tab-size"] = Property(url: "https://drafts.csswg.org/css-text-3/#tab-size-property")
  ## 
  ## Property `text-align`
  ## 
  result["text-align"] = Property(url: "https://www.w3.org/TR/CSS22/text.html#propdef-text-align", values: newTable({
      "-webkit-auto": NonStandard, "left": Implemented, "right": Implemented,
      "center": Implemented, "justify": Implemented, "match-parent": Implemented,
      "justify-all": Unimplemented, "-webkit-left": NonStandard,
      "-webkit-right": NonStandard, "-webkit-center": NonStandard,
      "-webkit-match-parent": NonStandard, "-internal-th-center": Implemented,
      "start": Implemented, "end": Implemented}))
  ## 
  ## Property `text-align-last`
  ## 
  result["text-align-last"] = Property(
      url: "https://www.w3.org/TR/css-text-3/#text-align-last-property", values: newTable({
      "auto": Implemented, "start": Implemented, "end": Implemented,
      "left": Implemented, "right": Implemented, "center": Implemented,
      "justify": Implemented, "match-parent": Implemented}))
  ## 
  ## Property `text-anchor`
  ## 
  result["text-anchor"] = Property(url: "https://www.w3.org/TR/SVG/text.html#TextAnchorProperty", values: newTable(
      {"start": Implemented, "middle": Implemented, "end": Implemented}))
  ## 
  ## Property `text-decoration`
  ## 
  result["text-decoration"] = Property(
      url: "https://www.w3.org/TR/CSS2/text.html#propdef-text-decoration",
      longhands: @["text-decoration-line"])
  ## 
  ## Property `text-group-align`
  ## 
  result["text-group-align"] = Property(
      url: "https://drafts.csswg.org/css-text-4/#text-group-align-property", values: newTable({
      "none": Implemented, "start": Implemented, "end": Implemented,
      "left": Implemented, "right": Implemented, "center": Implemented}))
  ## 
  ## Property `text-indent`
  ## 
  result["text-indent"] = Property(url: "https://www.w3.org/TR/css-text-3/#text-indent-property")
  ## 
  ## Property `text-justify`
  ## 
  result["text-justify"] = Property(url: "https://www.w3.org/TR/css-text-3/#text-justify", values: newTable({
      "auto": Implemented, "none": Implemented, "inter-word": Implemented,
      "inter-character": Implemented, "distribute": Deprecated}))
  ## 
  ## Property `text-line-through`
  ## 
  result["text-line-through"] = Property(
      url: "https://www.w3.org/TR/2003/CR-css3-text-20030514/#text-line-through")
  ## 
  ## Property `text-line-through-color`
  ## 
  result["text-line-through-color"] = Property(url: "https://www.w3.org/TR/2003/CR-css3-text-20030514/#text-line-through-color")
  ## 
  ## Property `text-line-through-mode`
  ## 
  result["text-line-through-mode"] = Property(url: "https://www.w3.org/TR/2003/CR-css3-text-20030514/#text-line-through-mode", values: newTable(
      {"continuous": Implemented, "skip-white-space": Implemented}))
  ## 
  ## Property `text-line-through-style`
  ## 
  result["text-line-through-style"] = Property(url: "https://www.w3.org/TR/2003/CR-css3-text-20030514/#text-line-through-style", values: newTable({
      "none": Implemented, "solid": Implemented, "double": Implemented,
      "dashed": Implemented, "dot-dash": Implemented, "dot-dot-dash": Implemented,
      "wave": Implemented}))
  ## 
  ## Property `text-line-through-width`
  ## 
  result["text-line-through-width"] = Property(url: "https://www.w3.org/TR/2003/CR-css3-text-20030514/#text-line-through-width")
  ## 
  ## Property `text-overflow`
  ## 
  result["text-overflow"] = Property(url: "https://www.w3.org/TR/css-ui-3/#propdef-text-overflow", values: newTable(
      {"clip": Implemented, "ellipsis": Implemented}))
  ## 
  ## Property `text-overline`
  ## 
  result["text-overline"] = Property(url: "https://www.w3.org/TR/2003/CR-css3-text-20030514/#text-overline")
  ## 
  ## Property `text-overline-color`
  ## 
  result["text-overline-color"] = Property(url: "https://www.w3.org/TR/2003/CR-css3-text-20030514/#text-overline-color")
  ## 
  ## Property `text-overline-mode`
  ## 
  result["text-overline-mode"] = Property(url: "https://www.w3.org/TR/2003/CR-css3-text-20030514/#text-overline-mode", values: newTable(
      {"continuous": Implemented, "skip-white-space": Implemented}))
  ## 
  ## Property `text-overline-style`
  ## 
  result["text-overline-style"] = Property(url: "https://www.w3.org/TR/2003/CR-css3-text-20030514/#text-overline-style", values: newTable({
      "none": Implemented, "solid": Implemented, "double": Implemented,
      "dashed": Implemented, "dot-dash": Implemented, "dot-dot-dash": Implemented,
      "wave": Implemented}))
  ## 
  ## Property `text-overline-width`
  ## 
  result["text-overline-width"] = Property(url: "https://www.w3.org/TR/2003/CR-css3-text-20030514/#text-overline-width")
  ## 
  ## Property `text-shadow`
  ## 
  result["text-shadow"] = Property(url: "https://www.w3.org/TR/css-text-decor-3/#text-shadow-property")
  ## 
  ## Property `text-transform`
  ## 
  result["text-transform"] = Property(url: "https://www.w3.org/TR/CSS22/text.html#propdef-text-transform", values: newTable({
      "capitalize": Implemented, "uppercase": Implemented,
      "lowercase": Implemented, "full-size-kana": Implemented, "none": Implemented}))
  ## 
  ## Property `text-underline`
  ## 
  result["text-underline"] = Property(url: "https://www.w3.org/TR/2003/CR-css3-text-20030514/#text-underline")
  ## 
  ## Property `text-underline-color`
  ## 
  result["text-underline-color"] = Property(url: "https://www.w3.org/TR/2003/CR-css3-text-20030514/#text-underline-color")
  ## 
  ## Property `text-underline-mode`
  ## 
  result["text-underline-mode"] = Property(url: "https://www.w3.org/TR/2003/CR-css3-text-20030514/#text-underline-mode", values: newTable(
      {"continuous": Implemented, "skip-white-space": Implemented}))
  ## 
  ## Property `text-underline-style`
  ## 
  result["text-underline-style"] = Property(url: "https://www.w3.org/TR/2003/CR-css3-text-20030514/#text-underline-style", values: newTable({
      "none": Implemented, "solid": Implemented, "double": Implemented,
      "dashed": Implemented, "dot-dash": Implemented, "dot-dot-dash": Implemented,
      "wave": Implemented}))
  ## 
  ## Property `text-underline-width`
  ## 
  result["text-underline-width"] = Property(url: "https://www.w3.org/TR/2003/CR-css3-text-20030514/#text-underline-width")
  ## 
  ## Property `text-wrap`
  ## 
  result["text-wrap"] = Property(url: "https://www.w3.org/TR/css-text-4/#text-wrap", values: newTable({
      "wrap": Implemented, "nowrap": Implemented, "balance": Implemented,
      "stable": Implemented, "pretty": Implemented}))
  ## 
  ## Property `top`
  ## 
  result["top"] = Property(url: "https://www.w3.org/TR/CSS22/visuren.html#propdef-top",
                               values: newTable({"auto": Implemented}))
  ## 
  ## Property `transition`
  ## 
  result["transition"] = Property(url: "https://www.w3.org/TR/css3-transitions/#transition-shorthand-property", longhands: @[
      "transition-property", "transition-duration", "transition-timing-function",
      "transition-delay"])
  ## 
  ## Property `transition-delay`
  ## 
  result["transition-delay"] = Property(
      url: "https://www.w3.org/TR/css3-transitions/#transition-delay")
  ## 
  ## Property `transition-duration`
  ## 
  result["transition-duration"] = Property(
      url: "https://www.w3.org/TR/css3-transitions/#transition-duration")
  ## 
  ## Property `transition-property`
  ## 
  result["transition-property"] = Property(
      url: "https://www.w3.org/TR/css3-transitions/#transition-property",
      values: newTable({"none": Implemented}))
  ## 
  ## Property `transition-timing-function`
  ## 
  result["transition-timing-function"] = Property(
      url: "https://www.w3.org/TR/css3-transitions/#transition-timing-function")
  ## 
  ## Property `unicode-bidi`
  ## 
  result["unicode-bidi"] = Property(url: "https://www.w3.org/TR/CSS22/visuren.html#propdef-unicode-bidi", values: newTable({
      "normal": Implemented, "embed": Implemented, "bidi-override": Implemented,
      "isolate": Implemented, "isolate-override": Implemented,
      "plaintext": Implemented, "-webkit-isolate": Deprecated,
      "-webkit-isolate-override": Deprecated, "-webkit-plaintext": Deprecated}))
  ## 
  ## Property `vector-effect`
  ## 
  result["vector-effect"] = Property(url: "https://www.w3.org/TR/SVGTiny12/painting.html#VectorEffectProperty", values: newTable(
      {"none": Implemented, "non-scaling-stroke": Implemented}))
  ## 
  ## Property `vertical-align`
  ## 
  result["vertical-align"] = Property(url: "https://www.w3.org/TR/CSS22/visudet.html#propdef-vertical-align")
  ## 
  ## Property `visibility`
  ## 
  result["visibility"] = Property(url: "https://www.w3.org/TR/CSS22/visufx.html#propdef-visibility", values: newTable(
      {"visible": Implemented, "hidden": Implemented, "collapse": Implemented}))
  ## 
  ## Property `white-space`
  ## 
  result["white-space"] = Property(url: "https://www.w3.org/TR/CSS22/text.html#propdef-white-space", values: newTable({
      "normal": Implemented, "pre": Implemented, "pre-wrap": Implemented,
      "pre-line": Implemented, "nowrap": Implemented, "break-spaces": Implemented}))
  ## 
  ## Property `widows`
  ## 
  result["widows"] = Property(url: "https://www.w3.org/TR/CSS22/page.html#propdef-orphans")
  ## 
  ## Property `width`
  ## 
  result["width"] = Property(url: "https://www.w3.org/TR/CSS22/visudet.html#the-width-property")
  ## 
  ## Property `will-change`
  ## 
  result["will-change"] = Property(url: "https://www.w3.org/TR/css-will-change/#propdef-will-change")
  ## 
  ## Property `word-break`
  ## 
  result["word-break"] = Property(url: "https://www.w3.org/TR/css-text-3/#word-break", values: newTable({
      "normal": Implemented, "break-all": Implemented, "keep-all": Implemented,
      "break-word": Implemented}))
  ## 
  ## Property `word-spacing`
  ## 
  result["word-spacing"] = Property(url: "https://www.w3.org/TR/CSS22/text.html#propdef-word-spacing",
                                        values: newTable({"normal": Implemented}))
  ## 
  ## Property `x`
  ## 
  result["x"] = Property(url: "https://www.w3.org/TR/SVG/")
  ## 
  ## Property `y`
  ## 
  result["y"] = Property(url: "https://www.w3.org/TR/SVG/")
  ## 
  ## Property `z-index`
  ## 
  result["z-index"] = Property(url: "https://www.w3.org/TR/CSS22/visuren.html#propdef-z-index",
                                   values: newTable({"auto": Implemented}))
  ## 
  ## Property `alt`
  ## 
  result["alt"] = Property()
  ## 
  ## Property `appearance`
  ## 
  result["appearance"] = Property(url: "https://www.w3.org/TR/css-ui-4/#propdef-appearance", values: newTable({
      "checkbox": Implemented, "radio": Implemented, "push-button": Implemented,
      "square-button": Implemented, "button": Implemented, "listbox": Implemented,
      "menulist": Implemented, "menulist-button": Implemented,
      "meter": Implemented, "progress-bar": Implemented,
      "slider-horizontal": Implemented, "slider-vertical": Implemented,
      "searchfield": Implemented, "textfield": Implemented,
      "textarea": Implemented, "auto": Implemented, "none": Implemented,
      "-apple-pay-button": NonStandard, "default-button": NonStandard,
      "attachment": NonStandard, "borderless-attachment": Implemented}))
  ## 
  ## Property `aspect-ratio`
  ## 
  result["aspect-ratio"] = Property(url: "https://drafts.csswg.org/css-sizing-4/#aspect-ratio",
                                        values: newTable({"auto": Implemented}))
  ## 
  ## Property `contain-intrinsic-size`
  ## 
  result["contain-intrinsic-size"] = Property(
      url: "https://www.w3.org/TR/css-sizing-4/#intrinsic-size-override",
      longhands: @["contain-intrinsic-width", "contain-intrinsic-height"])
  ## 
  ## Property `contain-intrinsic-height`
  ## 
  result["contain-intrinsic-height"] = Property(
      url: "https://www.w3.org/TR/css-sizing-4/#intrinsic-size-override")
  ## 
  ## Property `contain-intrinsic-width`
  ## 
  result["contain-intrinsic-width"] = Property(
      url: "https://www.w3.org/TR/css-sizing-4/#intrinsic-size-override")
  ## 
  ## Property `contain-intrinsic-block-size`
  ## 
  result["contain-intrinsic-block-size"] = Property(
      url: "https://www.w3.org/TR/css-sizing-4/#intrinsic-size-override")
  ## 
  ## Property `contain-intrinsic-inline-size`
  ## 
  result["contain-intrinsic-inline-size"] = Property(
      url: "https://www.w3.org/TR/css-sizing-4/#intrinsic-size-override")
  ## 
  ## Property `contain`
  ## 
  result["contain"] = Property(url: "https://drafts.csswg.org/css-contain-1/")
  ## 
  ## Property `container`
  ## 
  result["container"] = Property(url: "https://drafts.csswg.org/css-contain-3/#container-queries", longhands: @[
      "container-name", "container-type"])
  ## 
  ## Property `container-name`
  ## 
  result["container-name"] = Property(url: "https://drafts.csswg.org/css-contain-3/#container-name")
  ## 
  ## Property `container-type`
  ## 
  result["container-type"] = Property(url: "https://drafts.csswg.org/css-contain-3/#container-queries", values: newTable(
      {"normal": Implemented, "size": Implemented, "inline-size": Implemented}))
  ## 
  ## Property `content-visibility`
  ## 
  result["content-visibility"] = Property(
      url: "https://www.w3.org/TR/css-contain-2/#content-visibility", values: newTable(
      {"visible": Implemented, "hidden": Implemented, "auto": Implemented}))
  ## 
  ## Property `backface-visibility`
  ## 
  result["backface-visibility"] = Property(
      url: "https://www.w3.org/TR/css-transforms-1/#propdef-backface-visibility",
      values: newTable({"visible": Implemented, "hidden": Implemented}))
  ## 
  ## Property `-webkit-background-clip`
  ## 
  result["-webkit-background-clip"] = Property()
  ## 
  ## Property `-webkit-background-origin`
  ## 
  result["-webkit-background-origin"] = Property()
  ## 
  ## Property `-webkit-background-size`
  ## 
  result["-webkit-background-size"] = Property(
      longhands: @["background-size"])
  ## 
  ## Property `-webkit-border-horizontal-spacing`
  ## 
  result["-webkit-border-horizontal-spacing"] = Property()
  ## 
  ## Property `-webkit-border-image`
  ## 
  result["-webkit-border-image"] = Property(longhands: @[
      "border-image-source", "border-image-slice", "border-image-width",
      "border-image-outset", "border-image-repeat"])
  ## 
  ## Property `-webkit-border-radius`
  ## 
  result["-webkit-border-radius"] = Property(longhands: @[
      "border-top-left-radius", "border-top-right-radius",
      "border-bottom-right-radius", "border-bottom-left-radius"])
  ## 
  ## Property `-webkit-border-vertical-spacing`
  ## 
  result["-webkit-border-vertical-spacing"] = Property()
  ## 
  ## Property `-webkit-box-align`
  ## 
  result["-webkit-box-align"] = Property(url: "https://www.w3.org/TR/2009/WD-css3-flexbox-20090723/#propdef-box-align", values: newTable({
      "stretch": Implemented, "start": Implemented, "end": Implemented,
      "center": Implemented, "baseline": Implemented}))
  ## 
  ## Property `-webkit-box-direction`
  ## 
  result["-webkit-box-direction"] = Property(url: "https://www.w3.org/TR/2009/WD-css3-flexbox-20090723/#propdef-box-direction",
      values: newTable({"normal": Implemented, "reverse": Implemented}))
  ## 
  ## Property `-webkit-box-flex`
  ## 
  result["-webkit-box-flex"] = Property(url: "https://www.w3.org/TR/2009/WD-css3-flexbox-20090723/#propdef-box-flex")
  ## 
  ## Property `-webkit-box-flex-group`
  ## 
  result["-webkit-box-flex-group"] = Property(url: "https://www.w3.org/TR/2009/WD-css3-flexbox-20090723/#propdef-box-flex-group")
  ## 
  ## Property `-webkit-box-lines`
  ## 
  result["-webkit-box-lines"] = Property(url: "https://www.w3.org/TR/2009/WD-css3-flexbox-20090723/#propdef-box-lines",
      values: newTable({"single": Implemented, "multiple": Implemented}))
  ## 
  ## Property `-webkit-box-ordinal-group`
  ## 
  result["-webkit-box-ordinal-group"] = Property(url: "https://www.w3.org/TR/2009/WD-css3-flexbox-20090723/#propdef-box-ordinal-group")
  ## 
  ## Property `-webkit-box-orient`
  ## 
  result["-webkit-box-orient"] = Property(url: "https://www.w3.org/TR/2009/WD-css3-flexbox-20090723/#propdef-box-orient", values: newTable({
      "horizontal": Implemented, "vertical": Implemented,
      "inline-axis": Implemented, "block-axis": Implemented}))
  ## 
  ## Property `-webkit-box-pack`
  ## 
  result["-webkit-box-pack"] = Property(url: "https://www.w3.org/TR/2009/WD-css3-flexbox-20090723/#propdef-box-pack", values: newTable({
      "start": Implemented, "end": Implemented, "center": Implemented,
      "justify": Implemented}))
  ## 
  ## Property `-webkit-box-reflect`
  ## 
  result["-webkit-box-reflect"] = Property()
  ## 
  ## Property `-webkit-box-shadow`
  ## 
  result["-webkit-box-shadow"] = Property()
  ## 
  ## Property `-webkit-column-axis`
  ## 
  result["-webkit-column-axis"] = Property(values: newTable(
      {"horizontal": Implemented, "vertical": Implemented, "auto": Implemented}))
  ## 
  ## Property `-webkit-column-break-after`
  ## 
  result["-webkit-column-break-after"] = Property(
      url: "https://www.w3.org/TR/css3-multicol/#break-after",
      longhands: @["break-after"])
  ## 
  ## Property `-webkit-column-break-before`
  ## 
  result["-webkit-column-break-before"] = Property(
      url: "https://www.w3.org/TR/css3-multicol/#break-before",
      longhands: @["break-before"])
  ## 
  ## Property `-webkit-column-break-inside`
  ## 
  result["-webkit-column-break-inside"] = Property(
      url: "https://www.w3.org/TR/css3-multicol/#break-inside",
      longhands: @["break-inside"])
  ## 
  ## Property `column-count`
  ## 
  result["column-count"] = Property(url: "https://www.w3.org/TR/css3-multicol/#column-count")
  ## 
  ## Property `column-fill`
  ## 
  result["column-fill"] = Property(url: "https://www.w3.org/TR/css3-multicol/#column-fill", values: newTable(
      {"auto": Implemented, "balance": Implemented}))
  ## 
  ## Property `column-gap`
  ## 
  result["column-gap"] = Property(url: "https://drafts.csswg.org/css-align/#column-row-gap")
  ## 
  ## Property `row-gap`
  ## 
  result["row-gap"] = Property(url: "https://drafts.csswg.org/css-align/#column-row-gap")
  ## 
  ## Property `gap`
  ## 
  result["gap"] = Property(url: "https://drafts.csswg.org/css-align/#gap-shorthand",
                               longhands: @["row-gap", "column-gap"])
  ## 
  ## Property `-webkit-column-progression`
  ## 
  result["-webkit-column-progression"] = Property(
      values: newTable({"normal": Implemented, "reverse": Implemented}))
  ## 
  ## Property `column-rule`
  ## 
  result["column-rule"] = Property(url: "https://www.w3.org/TR/css3-multicol/#column-rule", longhands: @[
      "column-rule-width", "column-rule-style", "column-rule-color"])
  ## 
  ## Property `column-rule-color`
  ## 
  result["column-rule-color"] = Property(
      url: "https://www.w3.org/TR/css3-multicol/#column-rule-color")
  ## 
  ## Property `column-rule-style`
  ## 
  result["column-rule-style"] = Property(
      url: "https://www.w3.org/TR/css3-multicol/#column-rule-style", values: newTable({
      "none": Implemented, "hidden": Implemented, "inset": Implemented,
      "groove": Implemented, "outset": Implemented, "ridge": Implemented,
      "dotted": Implemented, "dashed": Implemented, "solid": Implemented,
      "double": Implemented}))
  ## 
  ## Property `column-rule-width`
  ## 
  result["column-rule-width"] = Property(
      url: "https://www.w3.org/TR/css3-multicol/#column-rule-width", values: newTable(
      {"thin": Implemented, "medium": Implemented, "thick": Implemented}))
  ## 
  ## Property `column-span`
  ## 
  result["column-span"] = Property(url: "https://www.w3.org/TR/css3-multicol/#column-span0", values: newTable(
      {"none": Implemented, "all": Implemented}))
  ## 
  ## Property `column-width`
  ## 
  result["column-width"] = Property(url: "https://www.w3.org/TR/css3-multicol/#column-width")
  ## 
  ## Property `columns`
  ## 
  result["columns"] = Property(url: "https://www.w3.org/TR/css3-multicol/#columns",
                                   longhands: @["column-width", "column-count"])
  ## 
  ## Property `-webkit-box-decoration-break`
  ## 
  result["-webkit-box-decoration-break"] = Property(
      url: "https://www.w3.org/TR/css-break-3/#propdef-box-decoration-break",
      values: newTable({"clone": Implemented, "slice": Implemented}))
  ## 
  ## Property `mix-blend-mode`
  ## 
  result["mix-blend-mode"] = Property(url: "https://www.w3.org/TR/compositing-1/#propdef-mix-blend-mode", values: newTable({
      "normal": Implemented, "multiply": Implemented, "screen": Implemented,
      "overlay": Implemented, "darken": Implemented, "lighten": Implemented,
      "color-dodge": Implemented, "color-burn": Implemented,
      "hard-light": Implemented, "soft-light": Implemented,
      "difference": Implemented, "exclusion": Implemented, "hue": Implemented,
      "saturation": Implemented, "color": Implemented, "luminosity": Implemented,
      "plus-darker": Implemented, "plus-lighter": Implemented}))
  ## 
  ## Property `isolation`
  ## 
  result["isolation"] = Property(url: "https://www.w3.org/TR/compositing-1/#isolation", values: newTable(
      {"auto": Implemented, "isolate": Implemented}))
  ## 
  ## Property `filter`
  ## 
  result["filter"] = Property(url: "https://www.w3.org/TR/filter-effects/#FilterProperty")
  ## 
  ## Property `-apple-color-filter`
  ## 
  result["-apple-color-filter"] = Property()
  ## 
  ## Property `align-content`
  ## 
  result["align-content"] = Property(url: "https://www.w3.org/TR/css-align-3/#propdef-align-content", values: newTable({
      "normal": Implemented, "flex-start": Implemented, "flex-end": Implemented,
      "center": Implemented, "space-between": Implemented,
      "space-around": Implemented, "space-evenly": Implemented,
      "stretch": Implemented, "first": Implemented, "last": Implemented,
      "baseline": Implemented, "unsafe": Implemented, "safe": Implemented,
      "start": Implemented, "end": Implemented}))
  ## 
  ## Property `align-items`
  ## 
  result["align-items"] = Property(url: "https://www.w3.org/TR/css-align-3/#propdef-align-items", values: newTable({
      "flex-start": Implemented, "flex-end": Implemented, "center": Implemented,
      "baseline": Implemented, "stretch": Implemented, "normal": Implemented,
      "first": Implemented, "last": Implemented, "safe": Implemented,
      "unsafe": Implemented, "start": Implemented, "end": Implemented,
      "self-start": Implemented, "self-end": Implemented}))
  ## 
  ## Property `align-self`
  ## 
  result["align-self"] = Property(url: "https://www.w3.org/TR/css-align-3/#propdef-align-self", values: newTable({
      "auto": Implemented, "flex-start": Implemented, "flex-end": Implemented,
      "center": Implemented, "baseline": Implemented, "stretch": Implemented,
      "normal": Implemented, "first": Implemented, "last": Implemented,
      "safe": Implemented, "unsafe": Implemented, "start": Implemented,
      "end": Implemented, "self-start": Implemented, "self-end": Implemented}))
  ## 
  ## Property `flex`
  ## 
  result["flex"] = Property(url: "https://www.w3.org/TR/css-flexbox-1/#propdef-flex", longhands: @[
      "flex-grow", "flex-shrink", "flex-basis"])
  ## 
  ## Property `flex-basis`
  ## 
  result["flex-basis"] = Property(url: "https://www.w3.org/TR/css-flexbox-1/#propdef-flex-basis")
  ## 
  ## Property `flex-direction`
  ## 
  result["flex-direction"] = Property(url: "https://www.w3.org/TR/css-flexbox-1/#propdef-flex-direction", values: newTable({
      "row": Implemented, "row-reverse": Implemented, "column": Implemented,
      "column-reverse": Implemented}))
  ## 
  ## Property `flex-flow`
  ## 
  result["flex-flow"] = Property(url: "https://www.w3.org/TR/css-flexbox-1/#propdef-flex-flow",
                                     longhands: @["flex-direction", "flex-wrap"])
  ## 
  ## Property `flex-grow`
  ## 
  result["flex-grow"] = Property(url: "https://www.w3.org/TR/css-flexbox-1/#propdef-flex-grow")
  ## 
  ## Property `flex-shrink`
  ## 
  result["flex-shrink"] = Property(url: "https://www.w3.org/TR/css-flexbox-1/#propdef-flex-shrink")
  ## 
  ## Property `flex-wrap`
  ## 
  result["flex-wrap"] = Property(url: "https://www.w3.org/TR/css-flexbox-1/#propdef-flex-wrap", values: newTable(
      {"nowrap": Implemented, "wrap": Implemented, "wrap-reverse": Implemented}))
  ## 
  ## Property `justify-content`
  ## 
  result["justify-content"] = Property(
      url: "https://www.w3.org/TR/css-align-3/#propdef-justify-content", values: newTable({
      "normal": Implemented, "flex-start": Implemented, "flex-end": Implemented,
      "center": Implemented, "space-between": Implemented,
      "space-around": Implemented, "space-evenly": Implemented,
      "stretch": Implemented, "safe": Implemented, "unsafe": Implemented,
      "start": Implemented, "end": Implemented, "left": Implemented,
      "right": Implemented}))
  ## 
  ## Property `-webkit-backdrop-filter`
  ## 
  result["-webkit-backdrop-filter"] = Property(
      url: "https://drafts.fxtf.org/filters-2/#BackdropFilterProperty")
  ## 
  ## Property `-webkit-font-size-delta`
  ## 
  result["-webkit-font-size-delta"] = Property()
  ## 
  ## Property `justify-self`
  ## 
  result["justify-self"] = Property(url: "https://www.w3.org/TR/css-align-3/#propdef-justify-self")
  ## 
  ## Property `justify-items`
  ## 
  result["justify-items"] = Property(url: "https://www.w3.org/TR/css-align-3/#propdef-justify-items")
  ## 
  ## Property `place-content`
  ## 
  result["place-content"] = Property(url: "https://www.w3.org/TR/css-align-3/#propdef-place-content", longhands: @[
      "align-content", "justify-content"])
  ## 
  ## Property `place-items`
  ## 
  result["place-items"] = Property(url: "https://drafts.csswg.org/css-align-3/#propdef-place-items", longhands: @[
      "align-items", "justify-items"])
  ## 
  ## Property `place-self`
  ## 
  result["place-self"] = Property(url: "https://drafts.csswg.org/css-align-3/#propdef-place-self",
                                      longhands: @["align-self", "justify-self"])
  ## 
  ## Property `grid`
  ## 
  result["grid"] = Property(url: "https://www.w3.org/TR/css-grid-1/#propdef-grid", longhands: @[
      "grid-template-rows", "grid-template-columns", "grid-template-areas",
      "grid-auto-flow", "grid-auto-rows", "grid-auto-columns"])
  ## 
  ## Property `grid-area`
  ## 
  result["grid-area"] = Property(url: "https://www.w3.org/TR/css-grid-1/#propdef-grid-area", longhands: @[
      "grid-row-start", "grid-column-start", "grid-row-end", "grid-column-end"])
  ## 
  ## Property `grid-auto-columns`
  ## 
  result["grid-auto-columns"] = Property(
      url: "https://www.w3.org/TR/css-grid-1/#propdef-grid-auto-columns")
  ## 
  ## Property `grid-auto-rows`
  ## 
  result["grid-auto-rows"] = Property(url: "https://www.w3.org/TR/css-grid-1/#propdef-grid-auto-rows")
  ## 
  ## Property `grid-column-end`
  ## 
  result["grid-column-end"] = Property(
      url: "https://www.w3.org/TR/css-grid-1/#propdef-grid-column-end")
  ## 
  ## Property `grid-column-start`
  ## 
  result["grid-column-start"] = Property(
      url: "https://www.w3.org/TR/css-grid-1/#propdef-grid-column-start")
  ## 
  ## Property `grid-template`
  ## 
  result["grid-template"] = Property(url: "https://www.w3.org/TR/css-grid-1/#propdef-grid-template", longhands: @[
      "grid-template-rows", "grid-template-columns", "grid-template-areas"])
  ## 
  ## Property `grid-template-columns`
  ## 
  result["grid-template-columns"] = Property(
      url: "https://www.w3.org/TR/css-grid-1/#propdef-grid-template-columns")
  ## 
  ## Property `grid-template-rows`
  ## 
  result["grid-template-rows"] = Property(
      url: "https://www.w3.org/TR/css-grid-1/#propdef-grid-template-rows")
  ## 
  ## Property `grid-row-end`
  ## 
  result["grid-row-end"] = Property(url: "https://www.w3.org/TR/css-grid-1/#propdef-grid-row-end")
  ## 
  ## Property `grid-row-start`
  ## 
  result["grid-row-start"] = Property(url: "https://www.w3.org/TR/css-grid-1/#propdef-grid-row-start")
  ## 
  ## Property `grid-column`
  ## 
  result["grid-column"] = Property(url: "https://www.w3.org/TR/css-grid-1/#propdef-grid-column", longhands: @[
      "grid-column-start", "grid-column-end"])
  ## 
  ## Property `grid-row`
  ## 
  result["grid-row"] = Property(url: "https://www.w3.org/TR/css-grid-1/#propdef-grid-row", longhands: @[
      "grid-row-start", "grid-row-end"])
  ## 
  ## Property `grid-template-areas`
  ## 
  result["grid-template-areas"] = Property(
      url: "https://www.w3.org/TR/css-grid-1/#propdef-grid-template-areas")
  ## 
  ## Property `grid-auto-flow`
  ## 
  result["grid-auto-flow"] = Property(url: "https://www.w3.org/TR/css-grid-1/#propdef-grid-auto-flow")
  ## 
  ## Property `-webkit-hyphenate-character`
  ## 
  result["-webkit-hyphenate-character"] = Property(
      url: "https://www.w3.org/TR/css-text-4/#hyphenate-character")
  ## 
  ## Property `-webkit-hyphenate-limit-after`
  ## 
  result["-webkit-hyphenate-limit-after"] = Property()
  ## 
  ## Property `-webkit-hyphenate-limit-before`
  ## 
  result["-webkit-hyphenate-limit-before"] = Property()
  ## 
  ## Property `-webkit-hyphenate-limit-lines`
  ## 
  result["-webkit-hyphenate-limit-lines"] = Property(
      url: "https://www.w3.org/TR/css-text-4/#propdef-hyphenate-limit-lines")
  ## 
  ## Property `-webkit-hyphens`
  ## 
  result["-webkit-hyphens"] = Property(
      url: "https://www.w3.org/TR/css-text-3/#hyphens-property", values: newTable(
      {"none": Implemented, "manual": Implemented, "auto": Implemented}))
  ## 
  ## Property `-webkit-initial-letter`
  ## 
  result["-webkit-initial-letter"] = Property(
      url: "https://www.w3.org/TR/css-inline/#propdef-initial-letter")
  ## 
  ## Property `-webkit-line-box-contain`
  ## 
  result["-webkit-line-box-contain"] = Property(values: newTable({
      "none": Implemented, "block": Implemented, "inline": Implemented,
      "font": Implemented, "glyphs": Implemented, "replaced": Implemented,
      "inline-box": Implemented, "initial-letter": Implemented}))
  ## 
  ## Property `-webkit-line-align`
  ## 
  result["-webkit-line-align"] = Property(
      url: "https://www.w3.org/TR/css-line-grid-1/",
      values: newTable({"none": Implemented, "edges": Implemented}))
  ## 
  ## Property `line-break`
  ## 
  result["line-break"] = Property(url: "https://www.w3.org/TR/css-text-3/#line-break", values: newTable({
      "auto": Implemented, "loose": Implemented, "normal": Implemented,
      "strict": Implemented, "after-white-space": NonStandard,
      "anywhere": Implemented}))
  ## 
  ## Property `-webkit-line-clamp`
  ## 
  result["-webkit-line-clamp"] = Property()
  ## 
  ## Property `-webkit-line-grid`
  ## 
  result["-webkit-line-grid"] = Property(
      url: "https://www.w3.org/TR/css-line-grid-1/#propdef-line-grid")
  ## 
  ## Property `-webkit-line-snap`
  ## 
  result["-webkit-line-snap"] = Property(
      url: "https://www.w3.org/TR/css-line-grid-1/#line-snap", values: newTable(
      {"none": Implemented, "baseline": Implemented, "contain": Implemented}))
  ## 
  ## Property `-webkit-box-snap`
  ## 
  result["-webkit-box-snap"] = Property(
      url: "https://www.w3.org/TR/css-line-grid-1/#box-snap", values: newTable({
      "block-start": Implemented, "block-end": Implemented, "center": Implemented,
      "first-baseline": Implemented, "last-baseline": Implemented}))
  ## 
  ## Property `-webkit-marquee-direction`
  ## 
  result["-webkit-marquee-direction"] = Property(values: newTable({
      "forwards": Implemented, "backwards": Implemented, "ahead": Implemented,
      "reverse": Implemented, "left": Implemented, "right": Implemented,
      "down": Implemented, "up": Implemented, "auto": Implemented}))
  ## 
  ## Property `-webkit-marquee-increment`
  ## 
  result["-webkit-marquee-increment"] = Property()
  ## 
  ## Property `-webkit-marquee-repetition`
  ## 
  result["-webkit-marquee-repetition"] = Property()
  ## 
  ## Property `-webkit-marquee-speed`
  ## 
  result["-webkit-marquee-speed"] = Property()
  ## 
  ## Property `-webkit-marquee-style`
  ## 
  result["-webkit-marquee-style"] = Property(values: newTable({
      "none": Implemented, "slide": Implemented, "scroll": Implemented,
      "alternate": Implemented}))
  ## 
  ## Property `-webkit-mask`
  ## 
  result["-webkit-mask"] = Property(url: "https://www.w3.org/TR/css-masking-1/#propdef-mask", longhands: @[
      "mask-image", "-webkit-mask-source-type", "-webkit-mask-position-x",
      "-webkit-mask-position-y", "mask-size", "mask-repeat", "mask-origin",
      "-webkit-mask-clip"])
  ## 
  ## Property `-webkit-mask-box-image`
  ## 
  result["-webkit-mask-box-image"] = Property(longhands: @[
      "-webkit-mask-box-image-source", "-webkit-mask-box-image-slice",
      "-webkit-mask-box-image-width", "-webkit-mask-box-image-outset",
      "-webkit-mask-box-image-repeat"])
  ## 
  ## Property `-webkit-mask-box-image-outset`
  ## 
  result["-webkit-mask-box-image-outset"] = Property()
  ## 
  ## Property `-webkit-mask-box-image-repeat`
  ## 
  result["-webkit-mask-box-image-repeat"] = Property()
  ## 
  ## Property `-webkit-mask-box-image-slice`
  ## 
  result["-webkit-mask-box-image-slice"] = Property()
  ## 
  ## Property `-webkit-mask-box-image-source`
  ## 
  result["-webkit-mask-box-image-source"] = Property()
  ## 
  ## Property `-webkit-mask-box-image-width`
  ## 
  result["-webkit-mask-box-image-width"] = Property()
  ## 
  ## Property `-webkit-mask-clip`
  ## 
  result["-webkit-mask-clip"] = Property(
      url: "https://www.w3.org/TR/css-masking-1/#propdef-mask-clip")
  ## 
  ## Property `-webkit-mask-composite`
  ## 
  result["-webkit-mask-composite"] = Property(
      url: "https://www.w3.org/TR/css-masking-1/#propdef-mask-composite")
  ## 
  ## Property `-webkit-mask-source-type`
  ## 
  result["-webkit-mask-source-type"] = Property()
  ## 
  ## Property `-webkit-nbsp-mode`
  ## 
  result["-webkit-nbsp-mode"] = Property(
      values: newTable({"normal": Implemented, "space": Implemented}))
  ## 
  ## Property `color-scheme`
  ## 
  result["color-scheme"] = Property(url: "https://www.w3.org/TR/css-color-adjust/#color-scheme-prop", values: newTable({
      "normal": Implemented, "light": Implemented, "dark": Implemented,
      "only": Implemented}))
  ## 
  ## Property `order`
  ## 
  result["order"] = Property(url: "https://www.w3.org/TR/css-flexbox-1/#order-property")
  ## 
  ## Property `perspective`
  ## 
  result["perspective"] = Property(url: "https://www.w3.org/TR/css-transforms-2/#perspective-property")
  ## 
  ## Property `-webkit-perspective`
  ## 
  result["-webkit-perspective"] = Property(
      url: "https://www.w3.org/TR/css-transforms-2/#perspective-property",
      longhands: @["perspective"])
  ## 
  ## Property `perspective-origin`
  ## 
  result["perspective-origin"] = Property(
      url: "https://www.w3.org/TR/css-transforms-1/#propdef-perspective-origin",
      longhands: @["perspective-origin-x", "perspective-origin-y"])
  ## 
  ## Property `perspective-origin-x`
  ## 
  result["perspective-origin-x"] = Property(
      url: "https://www.w3.org/TR/css-transforms-1/#propdef-perspective-origin")
  ## 
  ## Property `perspective-origin-y`
  ## 
  result["perspective-origin-y"] = Property(
      url: "https://www.w3.org/TR/css-transforms-1/#propdef-perspective-origin")
  ## 
  ## Property `print-color-adjust`
  ## 
  result["print-color-adjust"] = Property(
      url: "https://www.w3.org/TR/css-color-adjust/#print-color-adjust",
      values: newTable({"exact": Implemented, "economy": Implemented}))
  ## 
  ## Property `-webkit-rtl-ordering`
  ## 
  result["-webkit-rtl-ordering"] = Property(
      values: newTable({"logical": Implemented, "visual": Implemented}))
  ## 
  ## Property `-webkit-text-combine`
  ## 
  result["-webkit-text-combine"] = Property(
      values: newTable({"none": Implemented, "horizontal": Implemented}))
  ## 
  ## Property `text-combine-upright`
  ## 
  result["text-combine-upright"] = Property(
      url: "https://www.w3.org/TR/css-writing-modes-3/#propdef-direction",
      values: newTable({"none": Implemented, "all": Implemented}))
  ## 
  ## Property `-webkit-text-decoration`
  ## 
  result["-webkit-text-decoration"] = Property(
      url: "https://www.w3.org/TR/css-text-decor-3/#text-decoration", longhands: @[
      "text-decoration-line", "text-decoration-style", "text-decoration-color"])
  ## 
  ## Property `text-decoration-line`
  ## 
  result["text-decoration-line"] = Property(
      url: "https://www.w3.org/TR/css-text-decor-3/#text-decoration-line", values: newTable({
      "none": Implemented, "underline": Implemented, "overline": Implemented,
      "line-through": Implemented, "blink": Implemented}))
  ## 
  ## Property `text-decoration-style`
  ## 
  result["text-decoration-style"] = Property(
      url: "https://www.w3.org/TR/css-text-decor-3/#text-decoration-style", values: newTable({
      "solid": Implemented, "double": Implemented, "dotted": Implemented,
      "dashed": Implemented, "wavy": Implemented}))
  ## 
  ## Property `text-decoration-color`
  ## 
  result["text-decoration-color"] = Property(
      url: "https://www.w3.org/TR/css-text-decor-3/#text-decoration-color")
  ## 
  ## Property `text-decoration-skip`
  ## 
  result["text-decoration-skip"] = Property(
      url: "https://www.w3.org/TR/css-text-decor-3/#text-decoration-skip",
      longhands: @["text-decoration-skip-ink"])
  ## 
  ## Property `text-decoration-skip-ink`
  ## 
  result["text-decoration-skip-ink"] = Property(url: "https://drafts.csswg.org/css-text-decor-4/#text-decoration-skip-ink-property", values: newTable(
      {"auto": Implemented, "none": Implemented, "all": Implemented}))
  ## 
  ## Property `text-underline-position`
  ## 
  result["text-underline-position"] = Property(url: "https://www.w3.org/TR/css-text-decor-3/#text-underline-position-property", values: newTable(
      {"auto": Implemented, "under": Implemented, "from-font": Implemented}))
  ## 
  ## Property `text-underline-offset`
  ## 
  result["text-underline-offset"] = Property(
      url: "https://www.w3.org/TR/css-text-decor-4/#underline-offset")
  ## 
  ## Property `text-decoration-thickness`
  ## 
  result["text-decoration-thickness"] = Property(
      url: "https://www.w3.org/TR/css-text-decor-4/#text-decoration-thickness")
  ## 
  ## Property `-webkit-text-decorations-in-effect`
  ## 
  result["-webkit-text-decorations-in-effect"] = Property()
  ## 
  ## Property `-internal-text-autosizing-status`
  ## 
  result["-internal-text-autosizing-status"] = Property()
  ## 
  ## Property `text-emphasis`
  ## 
  result["text-emphasis"] = Property(url: "https://www.w3.org/TR/css-text-decor-3/#text-emphasis", longhands: @[
      "text-emphasis-style", "text-emphasis-color"])
  ## 
  ## Property `text-emphasis-color`
  ## 
  result["text-emphasis-color"] = Property(
      url: "https://www.w3.org/TR/css-text-decor-3/#text-emphasis-color")
  ## 
  ## Property `text-emphasis-position`
  ## 
  result["text-emphasis-position"] = Property(
      url: "https://www.w3.org/TR/css-text-decor-3/#text-emphasis-position")
  ## 
  ## Property `text-emphasis-style`
  ## 
  result["text-emphasis-style"] = Property(
      url: "https://www.w3.org/TR/css-text-decor-3/#text-emphasis-style")
  ## 
  ## Property `-webkit-text-fill-color`
  ## 
  result["-webkit-text-fill-color"] = Property()
  ## 
  ## Property `-webkit-text-security`
  ## 
  result["-webkit-text-security"] = Property(values: newTable({
      "disc": Implemented, "circle": Implemented, "square": Implemented,
      "none": Implemented}))
  ## 
  ## Property `-webkit-text-stroke`
  ## 
  result["-webkit-text-stroke"] = Property(
      longhands: @["-webkit-text-stroke-width", "-webkit-text-stroke-color"])
  ## 
  ## Property `-webkit-text-stroke-color`
  ## 
  result["-webkit-text-stroke-color"] = Property()
  ## 
  ## Property `-webkit-text-stroke-width`
  ## 
  result["-webkit-text-stroke-width"] = Property(values: newTable(
      {"thin": Implemented, "medium": Implemented, "thick": Implemented}))
  ## 
  ## Property `transform`
  ## 
  result["transform"] = Property(url: "https://www.w3.org/TR/css-transforms-1/#transform-property")
  ## 
  ## Property `transform-box`
  ## 
  result["transform-box"] = Property(url: "https://www.w3.org/TR/css-transforms/#propdef-transform-box", values: newTable({
      "content-box": Implemented, "border-box": Implemented,
      "fill-box": Implemented, "stroke-box": Implemented, "view-box": Implemented}))
  ## 
  ## Property `transform-origin`
  ## 
  result["transform-origin"] = Property(
      url: "https://www.w3.org/TR/css-transforms-1/#propdef-transform-origin", longhands: @[
      "transform-origin-x", "transform-origin-y", "transform-origin-z"])
  ## 
  ## Property `transform-origin-x`
  ## 
  result["transform-origin-x"] = Property(
      url: "https://www.w3.org/TR/css-transforms-1/#propdef-transform-origin")
  ## 
  ## Property `transform-origin-y`
  ## 
  result["transform-origin-y"] = Property(
      url: "https://www.w3.org/TR/css-transforms-1/#propdef-transform-origin")
  ## 
  ## Property `transform-origin-z`
  ## 
  result["transform-origin-z"] = Property(
      url: "https://www.w3.org/TR/css-transforms-1/#propdef-transform-origin")
  ## 
  ## Property `transform-style`
  ## 
  result["transform-style"] = Property(
      url: "https://www.w3.org/TR/css-transforms-1/#transform-style-property", values: newTable({
      "flat": Implemented, "preserve-3d": Implemented, "optimized-3d": Implemented}))
  ## 
  ## Property `translate`
  ## 
  result["translate"] = Property(url: "https://drafts.csswg.org/css-transforms-2/#propdef-translate")
  ## 
  ## Property `scale`
  ## 
  result["scale"] = Property(url: "https://drafts.csswg.org/css-transforms-2/#propdef-scale")
  ## 
  ## Property `rotate`
  ## 
  result["rotate"] = Property(url: "https://drafts.csswg.org/css-transforms-2/#propdef-rotate")
  ## 
  ## Property `-webkit-user-drag`
  ## 
  result["-webkit-user-drag"] = Property(values: newTable(
      {"auto": Implemented, "none": Implemented, "element": Implemented}))
  ## 
  ## Property `-webkit-user-modify`
  ## 
  result["-webkit-user-modify"] = Property(values: newTable({
      "read-only": Implemented, "read-write": Implemented,
      "read-write-plaintext-only": Implemented}))
  ## 
  ## Property `-webkit-user-select`
  ## 
  result["-webkit-user-select"] = Property(
      url: "https://www.w3.org/TR/css-ui-4/#propdef-user-select", values: newTable({
      "auto": Implemented, "text": Implemented, "none": Implemented,
      "contain": Unimplemented, "all": Implemented}))
  ## 
  ## Property `scroll-behavior`
  ## 
  result["scroll-behavior"] = Property(
      url: "https://drafts.csswg.org/cssom-view/#propdef-scroll-behavior",
      values: newTable({"auto": Implemented, "smooth": Implemented}))
  ## 
  ## Property `scroll-margin`
  ## 
  result["scroll-margin"] = Property(url: "https://www.w3.org/TR/css-scroll-snap-1/#propdef-scroll-margin", longhands: @[
      "scroll-margin-top", "scroll-margin-right", "scroll-margin-bottom",
      "scroll-margin-left"])
  ## 
  ## Property `scroll-margin-bottom`
  ## 
  result["scroll-margin-bottom"] = Property(
      url: "https://www.w3.org/TR/css-scroll-snap-1/#propdef-scroll-margin")
  ## 
  ## Property `scroll-margin-left`
  ## 
  result["scroll-margin-left"] = Property(
      url: "https://www.w3.org/TR/css-scroll-snap-1/#propdef-scroll-margin")
  ## 
  ## Property `scroll-margin-right`
  ## 
  result["scroll-margin-right"] = Property(
      url: "https://www.w3.org/TR/css-scroll-snap-1/#propdef-scroll-margin")
  ## 
  ## Property `scroll-margin-top`
  ## 
  result["scroll-margin-top"] = Property(
      url: "https://www.w3.org/TR/css-scroll-snap-1/#propdef-scroll-margin")
  ## 
  ## Property `scroll-margin-inline-start`
  ## 
  result["scroll-margin-inline-start"] = Property(url: "https://www.w3.org/TR/css-scroll-snap-1/#propdef-scroll-margin-inline-start")
  ## 
  ## Property `scroll-margin-block-start`
  ## 
  result["scroll-margin-block-start"] = Property(url: "https://www.w3.org/TR/css-scroll-snap-1/#propdef-scroll-margin-block-start")
  ## 
  ## Property `scroll-margin-inline-end`
  ## 
  result["scroll-margin-inline-end"] = Property(url: "https://www.w3.org/TR/css-scroll-snap-1/#propdef-scroll-margin-inline-end")
  ## 
  ## Property `scroll-margin-block-end`
  ## 
  result["scroll-margin-block-end"] = Property(url: "https://www.w3.org/TR/css-scroll-snap-1/#propdef-scroll-margin-block-end")
  ## 
  ## Property `scroll-margin-block`
  ## 
  result["scroll-margin-block"] = Property(url: "https://www.w3.org/TR/css-scroll-snap-1/#propdef-scroll-margin-block",
      longhands: @["scroll-margin-block-start", "scroll-margin-block-end"])
  ## 
  ## Property `scroll-margin-inline`
  ## 
  result["scroll-margin-inline"] = Property(url: "https://www.w3.org/TR/css-scroll-snap-1/#propdef-scroll-margin-inline",
      longhands: @["scroll-margin-inline-start", "scroll-margin-inline-end"])
  ## 
  ## Property `scroll-padding`
  ## 
  result["scroll-padding"] = Property(url: "https://www.w3.org/TR/css-scroll-snap-1/#propdef-scroll-padding", longhands: @[
      "scroll-padding-top", "scroll-padding-right", "scroll-padding-bottom",
      "scroll-padding-left"])
  ## 
  ## Property `scroll-padding-bottom`
  ## 
  result["scroll-padding-bottom"] = Property(url: "https://www.w3.org/TR/css-scroll-snap-1/#propdef-scroll-padding-bottom")
  ## 
  ## Property `scroll-padding-left`
  ## 
  result["scroll-padding-left"] = Property(
      url: "https://www.w3.org/TR/css-scroll-snap-1/#propdef-scroll-padding-left")
  ## 
  ## Property `scroll-padding-right`
  ## 
  result["scroll-padding-right"] = Property(url: "https://www.w3.org/TR/css-scroll-snap-1/#propdef-scroll-padding-right")
  ## 
  ## Property `scroll-padding-top`
  ## 
  result["scroll-padding-top"] = Property(
      url: "https://www.w3.org/TR/css-scroll-snap-1/#propdef-scroll-padding-top")
  ## 
  ## Property `scroll-padding-inline-start`
  ## 
  result["scroll-padding-inline-start"] = Property(url: "https://www.w3.org/TR/css-scroll-snap-1/#propdef-scroll-padding-inline-start")
  ## 
  ## Property `scroll-padding-block-start`
  ## 
  result["scroll-padding-block-start"] = Property(url: "https://www.w3.org/TR/css-scroll-snap-1/#propdef-scroll-padding-block-start")
  ## 
  ## Property `scroll-padding-inline-end`
  ## 
  result["scroll-padding-inline-end"] = Property(url: "https://www.w3.org/TR/css-scroll-snap-1/#propdef-scroll-padding-inline-end")
  ## 
  ## Property `scroll-padding-block-end`
  ## 
  result["scroll-padding-block-end"] = Property(url: "https://www.w3.org/TR/css-scroll-snap-1/#propdef-scroll-padding-block-end")
  ## 
  ## Property `scroll-padding-block`
  ## 
  result["scroll-padding-block"] = Property(url: "https://www.w3.org/TR/css-scroll-snap-1/#propdef-scroll-padding-block",
      longhands: @["scroll-padding-block-start", "scroll-padding-block-end"])
  ## 
  ## Property `scroll-padding-inline`
  ## 
  result["scroll-padding-inline"] = Property(url: "https://www.w3.org/TR/css-scroll-snap-1/#propdef-scroll-padding-inline",
      longhands: @["scroll-padding-inline-start", "scroll-padding-inline-end"])
  ## 
  ## Property `scroll-snap-align`
  ## 
  result["scroll-snap-align"] = Property(
      url: "https://www.w3.org/TR/css-scroll-snap-1/#scroll-snap-align")
  ## 
  ## Property `scroll-snap-type`
  ## 
  result["scroll-snap-type"] = Property(
      url: "https://www.w3.org/TR/css-scroll-snap-1/#scroll-snap-type")
  ## 
  ## Property `scroll-snap-stop`
  ## 
  result["scroll-snap-stop"] = Property(url: "https://drafts.csswg.org/css-scroll-snap-1/#propdef-scroll-snap-stop",
      values: newTable({"always": Implemented, "normal": Implemented}))
  ## 
  ## Property `shape-outside`
  ## 
  result["shape-outside"] = Property(url: "https://www.w3.org/TR/css-shapes/#propdef-shape-outside")
  ## 
  ## Property `shape-margin`
  ## 
  result["shape-margin"] = Property(url: "https://www.w3.org/TR/css-shapes/#propdef-shape-margin")
  ## 
  ## Property `shape-image-threshold`
  ## 
  result["shape-image-threshold"] = Property(
      url: "https://www.w3.org/TR/css-shapes/#propdef-shape-image-threshold")
  ## 
  ## Property `-webkit-tap-highlight-color`
  ## 
  result["-webkit-tap-highlight-color"] = Property()
  ## 
  ## Property `-webkit-overflow-scrolling`
  ## 
  result["-webkit-overflow-scrolling"] = Property(
      values: newTable({"auto": Implemented, "touch": Implemented}))
  ## 
  ## Property `touch-action`
  ## 
  result["touch-action"] = Property(url: "https://www.w3.org/TR/pointerevents/#the-touch-action-css-property", values: newTable({
      "auto": Implemented, "none": Implemented, "manipulation": Implemented,
      "pan-x": Implemented, "pan-left": Unimplemented, "pan-right": Unimplemented,
      "pan-y": Implemented, "pan-up": Unimplemented, "pan-down": Unimplemented,
      "pinch-zoom": Implemented}))
  ## 
  ## Property `-webkit-touch-callout`
  ## 
  result["-webkit-touch-callout"] = Property(
      values: newTable({"default": Implemented, "none": Implemented}))
  ## 
  ## Property `-apple-trailing-word`
  ## 
  result["-apple-trailing-word"] = Property()
  ## 
  ## Property `-apple-pay-button-style`
  ## 
  result["-apple-pay-button-style"] = Property(values: newTable(
      {"white": Implemented, "white-outline": Implemented, "black": Implemented}))
  ## 
  ## Property `-apple-pay-button-type`
  ## 
  result["-apple-pay-button-type"] = Property(values: newTable({
      "plain": Implemented, "buy": Implemented, "set-up": Implemented,
      "donate": Implemented, "check-out": Implemented, "book": Implemented,
      "subscribe": Implemented, "reload": Implemented, "add-money": Implemented,
      "top-up": Implemented, "order": Implemented, "rent": Implemented,
      "support": Implemented, "contribute": Implemented, "tip": Implemented}))
  ## 
  ## Property `fill-color`
  ## 
  result["fill-color"] = Property(url: "https://drafts.fxtf.org/paint/#fill-color")
  ## 
  ## Property `fill-image`
  ## 
  result["fill-image"] = Property(url: "https://drafts.fxtf.org/paint/#fill-image")
  ## 
  ## Property `fill-origin`
  ## 
  result["fill-origin"] = Property(url: "https://drafts.fxtf.org/paint/#fill-origin")
  ## 
  ## Property `fill-position`
  ## 
  result["fill-position"] = Property(url: "https://drafts.fxtf.org/paint/#fill-position")
  ## 
  ## Property `border-boundary`
  ## 
  result["border-boundary"] = Property(
      url: "https://www.w3.org/TR/css-round-display-1/#border-boundary-property")