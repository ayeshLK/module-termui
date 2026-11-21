# Design

## Context

See proposal.md - Why. Today a build-along page includes excerpts of one example file through `ExampleCode` with a `region`, then the whole file in a `<details>`. The excerpts are not programs on their own. The new style keeps the example files as the complete programs and writes the stage snippets in the page. The first sample of the style is the Quick start's "Write the program" (types, a skeleton, state, `update`, `view`, storage, `main`).

Constraints: unused imports are compile errors in Ballerina, so imports must follow the stages. Tutorial steps 2 to 5 each extend the previous step's program, which the pages already say.

## Goals / Non-Goals

**Goals:**
- A fixed shape for a staged page, so the Quick start and steps 1 to 5 read the same way.
- A way to say, for every snippet, how it applies to what the reader has.
- A one-time local proof that each stage compiles.

**Non-Goals:**
- A CI check, a generator, or any new tooling for the stages.
- Staging for the concepts, best-practices and testing pages.

## Decisions

### Stages live in the page; the complete program comes from the file

Stage snippets are fenced code written in the `.mdx`. The complete program stays an `ExampleCode` include of the whole file, shown once at the end ("The whole program"), where it also says CI builds it. Alternatives: a snapshot package per stage (an exact match, but seven or more near-identical packages per page that must be edited together), or stage markers in one file with a generator (one source, but new tooling and an example file that is hard to read). Neither is wanted for what is a one-time check.

### A skeleton comes first

The first stage is the smallest program that compiles and has the right shape: the program class with stub `update` and `view`. Each later stage fills in a stub or adds a field or function, so later snippets always have a place to go. Step 1 starts from nothing; steps 2 to 5 start from the previous step's complete program, which the page links to.

### Each snippet says how it applies

Every snippet is introduced with one of three phrases, in this order of preference:
- **Replace** the whole thing (the snippet is the complete new text of a class or function).
- **Add** the snippet inside a named class or function, saying where.
- **Add** the snippet at the end of the file.

Placeholder comments such as `// ... other logic` are not used. Where a class is replaced, the snippet shows the whole class, with stubs for what a later stage fills in, so a reader can paste it over the old one.

### Imports and helpers follow the stages

A stage that needs a module adds the import line it needs, as its own small snippet, and shows no import it does not use. A function that a stage calls (such as `summary()` in the Quick start) is defined in the same stage, as a stub if its logic belongs to a later stage. A stub has the right signature and returns an empty value.

### Verifying once, locally

For each rewritten page, assemble the stages in a scratch package under the scratchpad, run `bal build` after each stage, and diff the last stage against the example file. Report each stage that fails and fix the snippet, not the example. The scratch packages are not committed. The example sources then lose their `// region` markers where no page uses them; `ExampleCode` keeps its region support for the excerpt pages.

## Risks / Trade-offs

- [The snippets drift from the example file when it is edited later] -> Accepted, because CI for the stages is out of scope. The complete program is still compiled and included, so the page's final code is always right. A cheap guard (every non-stub snippet appears in the final file) can be added later without changing this design.
- [Reordering code into stages makes the examples longer to read] -> Keep each stage to one concern and show the whole class only where it is replaced.
- [Seven pages is a lot of writing and build cycles] -> Do the Quick start first, review it as the pattern, then the tutorial steps in order.

## Open Questions

- Does `bal build` accept an application package with no `main`? If not, the skeleton stage needs a minimal `main`. It is answered the first time a skeleton is built.
- Is an unused import an error or a warning in the Ballerina version used here? It is checked on the first build; the staging rule stays the same either way.
