# Formats and everyday actions

[Guide home](../README.md) · [中文](../zh/features.md)

| Format | Extension | Initial content | Default |
|---|---|---|---|
| Word / Excel / PowerPoint | .docx / .xlsx / .pptx | Blank Office document | On |
| Text / Markdown | .txt / .md | Blank UTF-8 | On |
| JSON | .json | Valid empty object `{}` | Off |
| JavaScript / TypeScript | .js / .ts | Blank UTF-8 | Off |
| Vue | .vue | Minimal script setup, template and scoped style | Off |
| HTML | .html | Minimal UTF-8 HTML document | Off |
| CSS / YAML | .css / .yaml | Blank UTF-8 | Off |

PDF is excluded. Enable each developer format under General → Developer Files. Enabled formats follow submenu/flat and language preferences. Collisions receive numbered names without overwriting existing items.

![Developer formats; screenshot in Chinese](../screenshots/developer-files.png)

## File actions

- Terminal and VS Code target the current folder. VS Code must be installed for its action.
- Cut records a pending move without moving files or changing the system clipboard.
- Paste performs the move, numbers collisions and retains failures for retry. Same-directory items are not moved again.
- Copy Absolute Path uses the system clipboard; consider privacy before sharing.

Menus retain the folder and selection from when they opened. Actions requiring a valid folder or selection are disabled when unavailable. For creation failures, check the destination and diagnostic logs before repeatedly retrying.
