--[[
rev_highlight.lua -- show or hide the revision markup for a reviewer round.

Every insertion made for a revision is wrapped in the sources as

    inline:  [new words, with @RN5 and Figure [-@fig-x]A]{.rev}
    block:   ::: {.rev}
             New paragraph(s), list items, a new heading ...
             :::

and this filter decides what the wrapper becomes, from the metadata key `rev-mode`:

    rev-mode: clean   (the DEFAULT, also when the key is absent)
        The wrapper is removed and its content kept, with no trace in any output --
        the file the journal typesets.
    rev-mode: marked  (quarto render ... -M rev-mode:marked)
        The content is highlighted -- the "Marked Revision" upload:
          docx   <w:highlight w:val="yellow"/> on every run (pandoc's own mapping of a
                 Span with class "mark"; valid transitional OOXML), inline-math runs
                 included (see docx_math); display math is not highlighted
          html   <mark>
          typst  #highlight[...]
        A block .rev highlights all inline content of every paragraph, list item and
        heading inside it.

Any other value is an error, so a typo cannot silently produce the clean build. The
key is deleted from the metadata once read: pandoc's docx writer would otherwise copy
it into docProps/custom.xml, leaving "rev-mode" visible in Word's document properties.

ORDER MATTERS, AND THIS FILTER RUNS FIRST. It is listed in ms/_metadata.yml under
`filters:` without a `quarto` entry, so Quarto runs it BEFORE its own crossref and
citation processing. Those stages therefore still see the original Cite elements
inside the wrapper (@RN.., @fig-x, Figure [-@fig-x]A), and italics, superscripts and
math pass through untouched -- only the wrapper changes.

WHY THE TYPST BRANCH EMITS RAW TYPST. Pandoc 3.6's Typst writer ignores class "mark"
(the words come out with no highlight and no warning), so the wrapper is written as
raw `#highlight[` ... `];`. The trailing `;` is not decoration: without it, text that
follows directly -- `].foo`, `][`, `](` -- continues the Typst expression (a field
access, a second content argument) and the render fails or changes meaning. Pandoc
closes its own `#emph[...]` the same way.

Elements other than Span, Div and Header that carry .rev (a Link, Image, Code ...)
lose the class and keep their content; a warning names them, because only the three
supported kinds are highlighted.

KNOWN GAPS -- marked mode only; the clean build is unaffected by all of them, and the
marked deliverable is the DOCX:
  - docx: DISPLAY math is not highlighted (kept a real Math element, see docx_math).
  - typst: #highlight does not paint math, inline or display; the words around it are.
  - typst: a heading carrying .rev (or inside a block .rev) is highlighted in the
    outline / table of contents as well, because the outline repeats the heading body.
  - every format: cells of a table BUILT IN R (a flextable or gt object) never pass
    through this filter as Span/Div content. Such a builder has to highlight its own
    cells, from the REV_MODE environment variable that the revision build driver
    exports alongside -M rev-mode.
--]]

local CLASS = "rev"
local KEY = "rev-mode"
local MODES = { clean = true, marked = true }

local mode = "clean"
local n_inline, n_block, n_other = 0, 0, 0

local function warn(msg)
  io.stderr:write("[rev_highlight] WARNING: " .. msg .. "\n")
end

local function has_rev(el)
  return el.classes ~= nil and el.classes:includes(CLASS)
end

-- A wrapper whose only job is .rev: no id, no other class, no attribute. Those are
-- removed outright; anything else keeps its element and just loses the class.
local function pure(el)
  return el.identifier == "" and #el.classes == 1 and #el.attributes == 0
end

local function drop_class(el)
  el.classes = el.classes:filter(function(c) return c ~= CLASS end)
  return el
end

local function is_typst()
  return FORMAT:match("typst") ~= nil
end

-- Adjacent Str elements are merged where a wrapper was spliced out, so the clean
-- build is what the reader would have produced from the same words written bare.
local function merge_str(inlines)
  local out = pandoc.Inlines({})
  for _, el in ipairs(inlines) do
    local last = out[#out]
    if el.t == "Str" and last ~= nil and last.t == "Str" then
      out[#out] = pandoc.Str(last.text .. el.text)
    else
      out:insert(el)
    end
  end
  return out
end

-- Pandoc's docx writer puts the highlight on text runs only; an equation inside a
-- .rev (OMML, <m:oMath>) would come out unhighlighted. So, in docx, inline math in a
-- marked span is rendered to OMML here (pandoc.write + pandoc.zip, i.e. by the same
-- writer that would otherwise have emitted it) and every math run gets
-- <w:rPr><w:highlight/></w:rPr>, placed after its optional <m:rPr> as the OMML schema
-- orders them. Display math is left alone: an `{#eq-...}` label on it is a
-- cross-reference target and must stay a real Math element for Quarto.
local HL_RPR = '<w:rPr><w:highlight w:val="yellow"/></w:rPr>'
local math_warned = false

local function docx_math(m)
  if m.mathtype ~= "InlineMath" then return nil end
  local ok, xml = pcall(function()
    local bytes = pandoc.write(pandoc.Pandoc({ pandoc.Plain({ m }) }), "docx")
    for _, e in ipairs(pandoc.zip.Archive(bytes).entries) do
      if e.path == "word/document.xml" then return e:contents() end
    end
  end)
  local omml = ok and type(xml) == "string" and xml:match("<m:oMath>.-</m:oMath>") or nil
  if omml == nil then
    if not math_warned then
      warn("could not render inline math to OMML; it is kept but NOT highlighted")
      math_warned = true
    end
    return nil
  end
  omml = omml:gsub("<m:r>", "<m:r>\1")
             :gsub("\1(<m:rPr>.-</m:rPr>)", "%1" .. HL_RPR)
             :gsub("\1", HL_RPR)
  return pandoc.RawInline("openxml", omml)
end

local function highlighted(inlines)
  if FORMAT == "docx" then
    inlines = inlines:walk({ Math = docx_math })
  end
  if is_typst() then
    local out = pandoc.Inlines({ pandoc.RawInline("typst", "#highlight[") })
    out:extend(inlines)
    out:insert(pandoc.RawInline("typst", "];"))
    return out
  end
  return pandoc.Inlines({ pandoc.Span(inlines, pandoc.Attr("", { "mark" })) })
end

-- ------------------------------------------------------------ pass 1: block .rev

-- Marked mode: a block .rev becomes an inline .rev around the content of every
-- paragraph, plain block (tight list items, table cells) and heading inside it, so the
-- inline pass below does all the actual highlighting.
local function wrap_content(blk)
  if #blk.content > 0 then
    blk.content = pandoc.Inlines({ pandoc.Span(blk.content, pandoc.Attr("", { CLASS })) })
  end
  return blk
end

local expand_div
expand_div = function(div)
  if not has_rev(div) then return nil end
  n_block = n_block + 1
  -- Nested block .rev first, explicitly, so the result does not depend on the order
  -- in which pandoc visits a Div and the Divs inside it.
  local content = div.content:walk({ Div = expand_div })
  if mode == "marked" then
    content = content:walk({ Para = wrap_content, Plain = wrap_content, Header = wrap_content })
  end
  if pure(div) then return content end
  div = drop_class(div)
  div.content = content
  return div
end

local function header_rev(h)
  if not has_rev(h) then return nil end
  n_block = n_block + 1
  h = drop_class(h)
  if mode == "marked" then h = wrap_content(h) end
  return h
end

-- ------------------------------------------------------------ pass 2: flatten

-- An inline .rev inside another (a .rev span inside a .rev paragraph, say) would
-- otherwise highlight twice; Typst's highlight is translucent, so it shows.
local function flatten(span)
  if not has_rev(span) then return nil end
  span.content = span.content:walk({
    Span = function(inner)
      if not has_rev(inner) then return nil end
      if pure(inner) then return inner.content end
      return drop_class(inner)
    end,
  })
  return span
end

-- ------------------------------------------------------------ pass 3: inline .rev

local function convert(inlines)
  local out, changed = pandoc.Inlines({}), false
  for _, el in ipairs(inlines) do
    if el.t == "Span" and has_rev(el) then
      changed = true
      n_inline = n_inline + 1
      if mode == "clean" then
        if pure(el) then
          out:extend(el.content)
        else
          out:insert(drop_class(el))
        end
      elseif pure(el) then
        out:extend(highlighted(el.content))
      else
        el = drop_class(el)
        el.content = highlighted(el.content)
        out:insert(el)
      end
    else
      out:insert(el)
    end
  end
  if not changed then return nil end
  return mode == "clean" and merge_str(out) or out
end

-- Anything else carrying .rev: strip the class, keep the element, say so.
local function other(el)
  if el.classes == nil or not has_rev(el) then return nil end
  n_other = n_other + 1
  warn(el.t .. " carries .rev, which only Span, Div and Header support; "
       .. "class removed, content NOT highlighted. Wrap it in [ ]{.rev} instead.")
  return drop_class(el)
end

-- ------------------------------------------------------------ driver

function Pandoc(doc)
  local raw = doc.meta[KEY]
  if raw ~= nil then
    mode = pandoc.utils.stringify(raw):lower():gsub("^%s+", ""):gsub("%s+$", "")
  end
  if not MODES[mode] then
    -- Not error(): Quarto replaces error() inside filters with a logger and carries on,
    -- so a typo would still produce a document. os.exit() does stop the render (quarto
    -- exits 1 and writes no output), which is what the header promises.
    io.stderr:write("ERROR rev_highlight.lua: " .. KEY .. " must be 'clean' or 'marked', got '"
                    .. tostring(mode) .. "'\n")
    os.exit(1)
  end
  -- Pandoc's docx writer copies every metadata key it does not know into
  -- docProps/custom.xml, where Word shows it under File > Properties. Left in place,
  -- the key itself would be a trace of the revision markup in the delivered file.
  doc.meta[KEY] = nil

  doc.blocks = doc.blocks:walk({ Div = expand_div, Header = header_rev })
  doc = doc:walk({ Span = flatten })
  doc = doc:walk({ Inlines = convert })
  doc = doc:walk({
    Link = other, Image = other, Code = other,
    CodeBlock = other, Table = other, Figure = other,
  })

  if mode == "marked" then
    io.stderr:write(string.format(
      "[rev_highlight] rev-mode=marked: %d block(s), %d inline highlight(s)\n",
      n_block, n_inline))
  end
  return doc
end
