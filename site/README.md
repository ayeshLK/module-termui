# termui documentation site

The site is built with [Starlight](https://starlight.astro.build) (Astro) from Markdown and MDX, and
published to GitHub Pages at https://ayeshlk.github.io/module-termui/.

## Preview

Node 22.23.4 or later (24 works) and npm are required. Nothing else in the repository needs Node.

```sh
cd site
npm ci
npm run dev        # live preview at http://localhost:4321/module-termui/
npm run build      # the same build CI runs; output in dist/
npm run check-links  # after a build: every internal link and #fragment must resolve (CI runs it too)
npm run preview    # serve dist/ to check the built site
```

## Layout

```
src/content/docs/
  index.mdx          home page
  start/             install and first steps
  concepts/          how the pieces work
  best-practices/    what to do and avoid
  tutorial/          build a harness, step by step
src/components/      ExampleCode.astro (and the interactive components)
public/casts/        asciinema recordings
```

The sidebar is generated from these folders. Order pages with `sidebar.order` in the front matter.

## Writing pages

- **Code comes from files.** Show a program with `<ExampleCode file="examples/..." />`, never by pasting
  it. To show part of a file, mark it in the source with comment lines and name the region:

  ```ballerina
  // region update
  public function update(termui:Message message) returns termui:Command? { ... }
  // endregion update
  ```

  ```mdx
  <ExampleCode file="examples/counter/main.bal" region="update" />
  ```

  The marker lines are not shown, and a missing or unclosed region fails the site build, so editing an
  example cannot silently change a page. CI compiles everything under `examples/`, so a page cannot show
  code that does not build. Short inline snippets inside prose are fine; a full program is always included.
- **Link, do not copy, symbol docs.** Name a type or function and link to the API reference on
  [Ballerina Central](https://central.ballerina.io/ayesha/termui/1.0.0).
- **Use only released API** in tutorial programs, so a page matches what a reader can install.
- Internal links are relative (`../the-loop/`) so they work under the `/module-termui` base path.
