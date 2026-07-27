# Localization

Lucius supports exactly these locales in both the interface and vocabulary learning: `en`, `es`, `fr`, `de`, `pt-BR`, `it`, `pl`, `uk`, `ja`, `ko`, and `zh-Hans`.

`SupportedLanguage` is the single source of truth. Do not add language arrays to individual screens or selectors. When adding a user-visible string:

1. Create one lowercase, dot-separated semantic key.
2. Add a natural translation to all 11 `Localizable.strings` files.
3. Use the key from SwiftUI or `String(localized:)`; never hardcode the visible text.
4. Keep user-generated content, imported text, API content, and technical identifiers out of localization.

Use one complete localized format string for runtime values (including counts and percentages); do not concatenate translated fragments or branch on `count == 1` in a view. If a future screen needs grammatical plural forms, add the plural resource alongside the same 11 approved locales and keep the plural rule out of the view.

The localization consistency tests compare every file with the English canonical key set and reject missing, extra, or empty values. Run the tests before committing localization changes.
