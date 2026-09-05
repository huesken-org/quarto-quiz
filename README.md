# quarto-quiz

> [!NOTE]
> Built with AI

A quiz question that fits three outputs from one source: check boxes the
presenter reveals on a slide, a self-explanatory quiz with a reveal button on a
website, and a lettered answer list with the solution below it on paper.

> [!WARNING]
> Built for my own presentations. Fit for that, not promised to
> fit anything else.


````markdown
::: {.quiz}
:::: {.question}
What does this print?

```{.python}
xs = [1, 2, 3]
print(xs[1:])
```
::::

:::: {.answer .incorrect}
`[1, 2]`
::::

:::: {.answer .correct}
`[2, 3]`
::::

:::: {.solution}
A slice starts at the index you give and runs to the end.
::::

:::: {.explanation}
Worth saying out loud: the second number is the *end*, not a count.
::::
:::
````

| Output   | Shape                                                                                                                                                     |
|----------|-----------------------------------------------------------------------------------------------------------------------------------------------------------|
| revealjs | a check box next to every answer, revealed by the presenter; the `.solution` follows as the last fragment; the `.explanation` goes into the speaker notes |
| html     | answers can be picked, a button reveals which are right and unfolds solution **and** explanation                                                          |
| latex    | question, answers as an (a)/(b)/(c) list, below it **Solution: b)** plus solution and explanation                                                         |

## Example

<https://huesken-org.github.io/quarto-quiz/> — the same two questions as a web
quiz, as slides and as a PDF handout.

The source is `example/`: the questions live once in `_questions.qmd`, and
`index.qmd`, `slides.qmd` and `handout.qmd` each include it and name their
format. `example/_extensions` is a symlink to the filter in this repo, so the
published site is built against the extension as it stands.

```bash
quarto preview example
```

Every push to `main` renders it and deploys to GitHub Pages
(`.github/workflows/publish.yml`); the repository needs *Settings → Pages →
Source: GitHub Actions* set once.

## Installation

```bash
quarto add huesken-org/quarto-quiz
```

```yaml
filters:
  - path: quiz
```

## Authoring

| Class                                     | Meaning                                                        |
|-------------------------------------------|----------------------------------------------------------------|
| `.quiz`                                   | the container; a div without a `.question` child is left alone |
| `.question`                               | the question, may hold a code block                            |
| `.answer .correct` / `.answer .incorrect` | one answer; several may be correct                             |
| `.solution`                               | shown on the slide, optional                                   |
| `.explanation`                            | the reasoning, optional                                        |
| `.quiz .incremental`                      | reveal the answers one at a time instead of all at once        |

Answers are laid out by Quarto's panel layout: up to three in one row, four in
two rows of two, up to six in two rows, more in three.

## Configurable wording

Every word the filter writes itself, set from the document or project metadata.
Defaults are English.

```yaml
quiz:
  solution-label: "Answer key"   # latex: "Answer key: b)"  (default "Solution")
  reveal-label: "Show me"        # html button              (default "Reveal")
  hide-label: "Hide again"       # html button, revealed    (default "Hide")
```

The two button labels travel to the browser as `data-reveal-label` /
`data-hide-label` on the `.quiz-web` element; without them `quiz.js` falls back
to its own English defaults.

## Bundled assets

Attached only when a quiz is actually present:

| File                   | when                                                                           |
|------------------------|--------------------------------------------------------------------------------|
| `quiz.css` + `quiz.js` | html: the button quiz, the answer colours, the question and explanation blocks |
| `quiz-revealjs.css`    | revealjs: the solution fragment                                                |

The look is deliberately plain and lives in two small stylesheets — override
`.quiz-question`, `.quiz-explanation` or `.reveal .quiz-solution` in your own
theme if it does not suit you.

## `check_box_fragment`

The shortcode behind the slide check boxes is contributed as well:

```markdown
{{< check_box_fragment correct="true" fragment-index="3" >}}
```

It renders `☐` and swaps it for a green `☑` or a red `☒` at that fragment step —
useful on its own for a hand-built list of claims to walk through.

## Tests

```bash
tests/run.sh                  # all cases
tests/run.sh latex reveal     # only cases whose name contains a pattern
tests/run.sh --update         # rewrite expected.txt (check the diff!)
```

Golden-file tests: every case under `tests/cases/` is an `input.qmd` that names
its format and the filter itself; what is compared is a recording of exit code,
rendered content, attached assets and warnings. Rendering happens with
**quarto**, not just pandoc — the revealjs shape leans on Quarto's panel layout
and its fragment handling, and only a real render shows that the generated
`layout=` still reaches Quarto's own pass.
