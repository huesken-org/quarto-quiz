local pandoc = pandoc

return {
  ["check_box_fragment"] = function(args, kwargs)
    local correct = pandoc.utils.stringify(kwargs["correct"] or {}) == "true"
    local fragment_index = pandoc.utils.stringify(kwargs["fragment-index"]) or "0"

    local check_symbol = correct and "☑" or "☒"
    local check_color = correct and "green" or "red"

    -- Ordered lists rather than maps: Lua's `pairs` has no stable order, so a
    -- map makes the rendered attribute order differ between two runs of the
    -- same source.
    local fade_out_kv = {}
    local fade_in_kv = { { "style", "position:absolute; left:0; color:" .. check_color } }

    if fragment_index then
      table.insert(fade_out_kv, { "fragment-index", fragment_index })
      table.insert(fade_in_kv, { "fragment-index", fragment_index })
    end

    local empty_box = pandoc.Span(
      { pandoc.Str("☐") },
      pandoc.Attr("", { "fragment", "fade-out" }, fade_out_kv)
    )

    local check_box = pandoc.Span(
      { pandoc.Str(check_symbol) },
      pandoc.Attr("", { "fragment", "fade-in" }, fade_in_kv)
    )

    return {
      pandoc.Span(
        { empty_box, check_box },
        pandoc.Attr("", {}, { { "style", "display:inline-block; position:relative; font-size:1.5em; vertical-align:middle" } })
      )
    }
  end
}
