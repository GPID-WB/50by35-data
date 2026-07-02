# Tachyons CSS Guide

## What Is Tachyons?

[Tachyons](https://tachyons.io/) is a functional (atomic) CSS library. Instead of writing custom CSS, you style elements by composing small, single-purpose utility classes directly in your HTML or Markdown. For example, `.pa3` adds padding, `.bg-light-yellow` sets a background color, and `.br2` rounds corners — no custom stylesheet required.

In this project, Tachyons is loaded automatically via the `tachyons` Quarto extension defined in `_extensions/tachyons/`. You do not need to import anything in your chapters; just use the classes.

---

## Using Tachyons in Quarto

Quarto uses Pandoc's div/span syntax to attach CSS classes to elements.

### Styled block (div)

Use `:::` fences and pass classes in curly braces:

```markdown
::: {.bg-light-yellow .pa3 .br2}
This is a styled callout box with a light yellow background, padding, and rounded corners.
:::
```

You can combine as many classes as you like in a single block:

```markdown
::: {.bg-washed-green .pa3 .br2 .ba .b--light-green}
**Tip:** This box has a border, a green wash background, and rounded corners.
:::
```

### Styled inline text (span)

Wrap text in square brackets and follow immediately with the class list in curly braces:

```markdown
[This text is bold and red]{.b .red}

[Small caps, gray, centered]{.f6 .gray .tc}
```

---

## Class Cheat Sheet

### Spacing

| Class | Effect |
|---|---|
| `.pa1` – `.pa4` | Padding on all sides (1 = small, 4 = large) |
| `.ma1` – `.ma4` | Margin on all sides |
| `.ph2` | Padding left + right |
| `.pv2` | Padding top + bottom |

### Background Colors

| Class | Color |
|---|---|
| `.bg-light-yellow` | Soft yellow (warnings, notes) |
| `.bg-light-blue` | Soft blue (information) |
| `.bg-washed-green` | Soft green (tips, success) |
| `.bg-washed-red` | Soft red (cautions, errors) |
| `.bg-near-white` | Off-white background |

### Typography

| Class | Effect |
|---|---|
| `.f4` – `.f7` | Font size (f4 = ~1.25rem, f7 = ~0.75rem) |
| `.b` | Bold |
| `.i` | Italic |
| `.tc` | Center-align text |
| `.tl` | Left-align text |
| `.tr` | Right-align text |
| `.gray` / `.dark-gray` | Gray text |

### Borders and Layout

| Class | Effect |
|---|---|
| `.br2` | Slightly rounded corners |
| `.br3` | More rounded corners |
| `.ba` | Border on all sides |
| `.b--light-gray` | Light gray border color |
| `.shadow-1` – `.shadow-4` | Box shadow (1 = subtle, 4 = strong) |

### Widths

| Class | Width |
|---|---|
| `.w-25` | 25% of container |
| `.w-50` | 50% |
| `.w-75` | 75% |
| `.w-100` | 100% |

---

## Copy-Paste Examples

**Note box:**
```markdown
::: {.bg-light-yellow .pa3 .br2 .f6}
**Note:** This indicator is under review and may change in future versions.
:::
```

**Info box:**
```markdown
::: {.bg-light-blue .pa3 .br2}
**Data note:** Figures for 2022 are preliminary and subject to revision.
:::
```

**Warning box:**
```markdown
::: {.bg-washed-red .pa3 .br2 .ba .b--light-red}
**Caution:** Do not commit raw microdata to this repository.
:::
```

**Inline highlight:**
```markdown
The primary outcome variable is [self-reliance score]{.b .dark-red}, defined in @sec-definitions.
```

**Narrow centered block:**
```markdown
::: {.w-50 .center .tc .pa3 .bg-near-white .br2}
This content is centered and takes up half the page width.
:::
```
