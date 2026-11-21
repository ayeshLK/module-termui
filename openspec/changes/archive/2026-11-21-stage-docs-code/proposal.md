# Proposal

## Why

The build-along pages (the Quick start and tutorial steps 1 to 5) show the program as excerpts of one finished file: `state`, `update`, `view` and so on. A reader cannot build or run anything until they have assembled every excerpt, and a mistake shows up only at the end. A page that grows the program in stages, with something that compiles after each stage, lets the reader check their work as they go and see what each piece adds.

## What Changes

- Rewrite "The program" in the Quick start and in tutorial steps 1 to 5 as a sequence of stages. Each stage adds one concern (types, a skeleton with stub `update` and `view`, state, `update`, `view`, storage, `main`) and the program compiles after each one.
- The page's stage snippets are written in the page. The complete program is still included from the compiled file under `examples/`, so a reader can copy the finished result and CI still builds it.
- Each snippet says whether it replaces something the reader already has or is added inside it, and each stage introduces only the imports it uses, so no stage leaves an unused import or a call to something not yet defined.
- In tutorial steps 2 to 5 the first stage is the previous step's complete program, and the page says what changed.
- Verify once, locally, that every stage of every rewritten page compiles and that the last stage matches the compiled example. CI is not changed to repeat this check.
- Remove `// region` markers from the example sources of the rewritten pages once no page uses them.

Out of scope: the concepts and best-practices pages and tutorial step 6, which show focused excerpts or tests and keep the existing excerpt style; a CI check for the staged snippets; changes to the example programs' behaviour or to the library.

## Capabilities

### New Capabilities

None.

### Modified Capabilities
- `docs-site`: "Code in pages comes from compiled programs" is reworded so that the complete program on a build-along page comes from a compiled file, and the staged snippets on the page build up to it, each stage compiling.

## Impact

- `site/src/content/docs/start/quick-start.mdx` and `site/src/content/docs/tutorial/01-counter.mdx` to `05-approval.mdx` are rewritten in their program sections.
- `examples/quick-start/main.bal` and `examples/tutorial/step1-counter` to `step5-approval` lose their `// region` markers where no longer needed.
- `site/src/components/ExampleCode.astro` is unchanged, because the excerpt pages still use it.
- No package code, API, CI script or release is affected.
