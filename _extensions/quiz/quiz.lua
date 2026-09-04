-- A quiz question with answers, revealed step by step.
--
--   ::: {.quiz}
--   :::: {.question}    <the question, may hold a code block>  ::::
--   :::: {.answer .incorrect}  <text or output>                ::::
--   :::: {.answer .correct}    <text or output>                ::::
--   :::: {.solution}    <shown on the slide, optional>         ::::
--   :::: {.explanation} <the reasoning, optional>              ::::
--   :::
--
-- Three outputs, three shapes:
--
--   revealjs  check boxes next to the answers that the presenter reveals
--             (`.incremental` on the quiz reveals them one at a time); the
--             `.solution` follows as the last fragment, the `.explanation` goes
--             into the speaker notes — it is spoken, not read
--   html      a self-explanatory quiz: answers can be picked, a button reveals
--             which are right and unfolds solution *and* explanation, because
--             here nobody is talking
--   latex     question, answers as an (a)/(b)/(c) list, below it "Solution: b)"
--             plus solution and explanation
--
-- `.solution` and `.explanation` are deliberately two things: the solution
-- belongs on the slide (for a question without an answer list it is the only
-- thing to reveal), the reasoning belongs to the presenter.
--
-- Every word the filter writes itself can be set from the metadata:
--
--   quiz:
--     solution-label: "Answer key"   # latex, default "Solution"
--     reveal-label: "Show me"        # html button, default "Reveal"
--     hide-label: "Hide again"       # html button once revealed, default "Hide"

local pandoc = pandoc

local _dir = pandoc.path.directory(PANDOC_SCRIPT_FILE)
local _check_box_fragment = dofile(_dir .. "/check_box_fragment.lua")["check_box_fragment"]

local function make_check_box(correct, fragment_index)
  local result = _check_box_fragment({}, {
    correct = correct and "true" or "false",
    ["fragment-index"] = tostring(fragment_index),
  })
  return pandoc.Para(result)
end

-- Builds the Quarto panel layout string for n answers.
--   ≤3 answers → 1 row,  n cols       e.g. [1,20,-1,1,20]
--   4  answers → 2 rows, 2 cols each  e.g. [[1,20,-1,1,20],[1,20,-1,1,20]]
--   5-6 answers → 2 rows, ceil(n/3) cols per row (last row may be shorter)
--   6+ answers → 3 rows, ceil(n/3) cols per row (last row may be shorter)
local function build_layout(n)
  local num_rows = n <= 3 and 1 or (n <= 6 and 2 or 3)
  local num_cols = math.ceil(n / num_rows)

  local function row_str(k)
    local parts = {}
    for i = 1, k do
      if i > 1 then table.insert(parts, "-1") end
      table.insert(parts, "1")
      table.insert(parts, "20")
    end
    return table.concat(parts, ",")
  end

  local rows = {}
  local remaining = n
  for _ = 1, num_rows do
    local k = math.min(num_cols, remaining)
    remaining = remaining - k
    table.insert(rows, row_str(k))
  end

  if num_rows == 1 then
    return "[" .. rows[1] .. "]"
  end
  local wrapped = {}
  for _, r in ipairs(rows) do
    table.insert(wrapped, "[" .. r .. "]")
  end
  return "[" .. table.concat(wrapped, ",") .. "]"
end

-- Labels, from the metadata; English unless the document says otherwise.
local labels = {
	["solution-label"] = "Solution",
	["reveal-label"] = "Reveal",
	["hide-label"] = "Hide",
}

local function read_labels(meta)
	local conf = meta["quiz"]
	if conf == nil then
		return
	end
	for key, _ in pairs(labels) do
		if conf[key] ~= nil then
			labels[key] = pandoc.utils.stringify(conf[key])
		end
	end
end

-- Extracts question / answers / solution / explanation from a .quiz div.
-- Returns nil if there is no .question child.
local function parse_quiz(el)
  local question_blocks = nil
  local answers = {}
  local explanation_blocks = nil
  local solution_blocks = nil

  for _, block in ipairs(el.content) do
    if block.t == "Div" then
      if block.classes:includes("question") then
        question_blocks = block.content
      elseif block.classes:includes("answer") then
        table.insert(answers, {
          correct = block.classes:includes("correct"),
          content = block.content,
        })
      elseif block.classes:includes("explanation") then
        explanation_blocks = block.content
      elseif block.classes:includes("solution") then
        solution_blocks = block.content
      end
    end
  end

  if not question_blocks then
    return nil
  end
  return question_blocks, answers, explanation_blocks, solution_blocks
end

-- ----------------------------------------------------------------------------
-- revealjs rendering: check-box fragments revealed step by step by the speaker.
--
-- What ends up on the slide is the solution and nothing else: the revealed
-- answer list and, if there is one, the `.solution` block as the last fragment.
-- The `.explanation` is spoken, so it goes into the speaker notes.

local function render_reveal(el, question_blocks, answers, explanation_blocks, solution_blocks)
  quarto.doc.add_html_dependency({
    name = "quiz-revealjs",
    version = "0.1.0",
    stylesheets = { "quiz-revealjs.css" },
  })

  local incremental = el.classes:includes("incremental")

  local result = {}

  table.insert(result, pandoc.Div(
    question_blocks,
    pandoc.Attr("", { "quiz-question" })
  ))

  local n = #answers

  if n > 0 then
    local items = {}
    for i, ans in ipairs(answers) do
      local fi = incremental and (i - 1) or 0
      table.insert(items, make_check_box(ans.correct, fi))
      table.insert(items, pandoc.Div(ans.content, pandoc.Attr("", { "quiz-answer" })))
    end

    -- The `layout` attribute is what triggers Quarto's panel layout, so the
    -- fragment classes have to go on a wrapper rather than on this very div.
    -- `layout-valign` centres the cells of a row against each other — otherwise
    -- the check box sticks to the top while the answer next to it (a multi-line
    -- output block, say) grows downwards.
    -- Attributes as an ordered list, not a map: Lua's `pairs` has no stable
    -- order, so a map makes the rendered attribute order differ between two
    -- runs of the same source.
    table.insert(result, pandoc.Div(items, pandoc.Attr("", {}, {
      { "layout", build_layout(n) },
      { "layout-valign", "center" },
    })))
  end

  if solution_blocks then
    -- Appears one step after the last check box: index 1 for non-incremental
    -- (all boxes share index 0), or n for incremental (the last answer sits at
    -- n-1). Without answers this is simply the first step.
    local fi = incremental and n or 1
    table.insert(result, pandoc.Div(
      solution_blocks,
      pandoc.Attr("", { "quiz-solution", "fragment" }, { ["fragment-index"] = tostring(fi) })
    ))
  end

  if explanation_blocks then
    -- Speaker notes: on revealjs pandoc/Quarto turn `.notes` into an
    -- `<aside class="notes">`, and reveal.js merges several of them per slide in
    -- the presenter view — a `.notes` div the author wrote stays as it is.
    table.insert(result, pandoc.Div(explanation_blocks, pandoc.Attr("", { "notes" })))
  end

  return result
end

-- ----------------------------------------------------------------------------
-- html (website) rendering: self-explanatory quiz with an explicit reveal
-- button. Answers can be selected (optional), the button reveals which are
-- correct and unfolds solution and explanation. A quiz without answers (where
-- the answer is a program's output) uses the same button. Unlike on the slides,
-- `.solution` and `.explanation` are not separated here — with nobody talking,
-- both have to be readable.

local function render_html(question_blocks, answers, explanation_blocks, solution_blocks)
  quarto.doc.add_html_dependency({
    name = "quiz",
    version = "0.1.0",
    stylesheets = { "quiz.css" },
    scripts = { "quiz.js" },
  })

  local children = {}

  table.insert(children, pandoc.Div(
    question_blocks,
    pandoc.Attr("", { "quiz-question" })
  ))

  if #answers > 0 then
    local items = {}
    for _, ans in ipairs(answers) do
      table.insert(items, pandoc.Div(
        ans.content,
        pandoc.Attr("", { "quiz-answer" }, { ["data-correct"] = ans.correct and "true" or "false" })
      ))
    end
    table.insert(children, pandoc.Div(items, pandoc.Attr("", { "quiz-answers" })))
  end

  -- The two button labels travel to the browser as data attributes, the way
  -- every other word this filter writes is configurable. quiz.js falls back to
  -- its own English defaults when they are absent.
  table.insert(children, pandoc.RawBlock(
    "html",
    '<button class="quiz-reveal-btn" type="button">' .. labels["reveal-label"] .. "</button>"
  ))

  local revealed = pandoc.List()
  if solution_blocks then
    revealed:extend(pandoc.Blocks(solution_blocks))
  end
  if explanation_blocks then
    revealed:extend(pandoc.Blocks(explanation_blocks))
  end
  if #revealed > 0 then
    table.insert(children, pandoc.Div(revealed, pandoc.Attr("", { "quiz-explanation" })))
  end

  -- Container class is "quiz-web" (not "quiz") so this replacement is not
  -- re-processed by the Div filter.
  return pandoc.Div(children, pandoc.Attr("", { "quiz-web" }, {
    { "data-reveal-label", labels["reveal-label"] },
    { "data-hide-label", labels["hide-label"] },
  }))
end

-- ----------------------------------------------------------------------------
-- latex (PDF) rendering: on paper there is nothing to reveal. The answers
-- become an (a)/(b)/(c) list with "Solution: b)" plus the explanation below it.
-- Putting the mark *below* rather than *on* the answers keeps the question open
-- while reading — and without it there would be four equal-looking paragraphs
-- with nothing left to say which one is right.
local LETTERS = { "a", "b", "c", "d", "e", "f", "g", "h" }

local function render_latex(question_blocks, answers, explanation_blocks, solution_blocks)
	local children = pandoc.List()

	for _, b in ipairs(question_blocks) do
		children:insert(b)
	end

	local correct_letters = {}
	if #answers > 0 then
		local items = pandoc.List()
		for i, ans in ipairs(answers) do
			if ans.correct then
				table.insert(correct_letters, (LETTERS[i] or tostring(i)) .. ")")
			end
			items:insert(pandoc.Blocks(ans.content))
		end
		-- LowerAlpha + OneParen gives "(a) …" — the same label the solution line
		-- refers to.
		children:insert(pandoc.OrderedList(items, pandoc.ListAttributes(1, "LowerAlpha", "OneParen")))
	end

	local solution = pandoc.List()
	if #correct_letters > 0 then
		solution:insert(pandoc.Strong({
			pandoc.Str(labels["solution-label"] .. ": " .. table.concat(correct_letters, ", ")),
		}))
	else
		solution:insert(pandoc.Strong({ pandoc.Str(labels["solution-label"]) }))
	end

	local solution_div = pandoc.List()
	solution_div:insert(pandoc.Para(solution))
	if solution_blocks then
		for _, b in ipairs(solution_blocks) do
			solution_div:insert(b)
		end
	end
	if explanation_blocks then
		for _, b in ipairs(explanation_blocks) do
			solution_div:insert(b)
		end
	end
	children:insert(pandoc.Div(solution_div, pandoc.Attr("", { "quiz-solution" })))

	return pandoc.Div(children, pandoc.Attr("", { "quiz-print" }))
end

-- A div without a `.question` child is left alone: `.quiz` may well be someone
-- else's class, and half a quiz is not something to guess at.
local function Div(el)
  if not el.classes:includes("quiz") then
    return nil
  end

  local question_blocks, answers, explanation_blocks, solution_blocks = parse_quiz(el)
  if not question_blocks then
    return nil
  end

  if quarto.doc.is_format("revealjs") then
    return render_reveal(el, question_blocks, answers, explanation_blocks, solution_blocks)
  end
  if quarto.doc.is_format("latex") then
    return render_latex(question_blocks, answers, explanation_blocks, solution_blocks)
  end
  return render_html(question_blocks, answers, explanation_blocks, solution_blocks)
end

-- Two passes: the labels have to be read before the first quiz is built, and the
-- order of Meta and Div within one filter table is not guaranteed.
return {
  { Meta = read_labels },
  { Div = Div },
}
