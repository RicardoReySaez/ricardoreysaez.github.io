local current_section = nil

local section_titles = {
  ["education"] = "Education",
  ["additional-training"] = "Additional Training",
  ["teaching-and-educational-activities"] = "Teaching and Educational Activities",
  ["textbooks"] = "Textbooks",
  ["software"] = "Software",
  ["awards"] = "Awards",
  ["publications"] = "Publications",
  ["conference-presentations"] = "Conference Presentations",
}

local cventry_sections = {
  ["education"] = true,
  ["additional-training"] = true,
  ["teaching-and-educational-activities"] = true,
  ["awards"] = true,
}

local text_entry_sections = {
  ["textbooks"] = true,
  ["software"] = true,
}

local function trim(text)
  return (text:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function drop_strong_inlines(inlines)
  local result = pandoc.List()

  for _, inline in ipairs(inlines) do
    if inline.t == "Strong" then
      local inner = drop_strong_inlines(inline.content)
      for _, inner_inline in ipairs(inner) do
        result:insert(inner_inline)
      end
    elseif inline.t == "Emph" or inline.t == "Span" or inline.t == "Link" then
      inline.content = drop_strong_inlines(inline.content)
      result:insert(inline)
    else
      result:insert(inline)
    end
  end

  return result
end

local function blocks_to_latex(blocks)
  local latex = pandoc.write(pandoc.Pandoc(blocks), "latex")
  latex = latex:gsub("\r?\n+", " ")
  return trim(latex)
end

local function inlines_to_latex(inlines, strip_strong)
  if strip_strong then
    inlines = drop_strong_inlines(inlines)
  end

  return blocks_to_latex({ pandoc.Plain(inlines) })
end

local function split_date(text)
  local date, rest = text:match("^(.-)%s*\\textbar{}%s*(.+)$")
  if not date then
    date, rest = text:match("^(.-)%s*|%s*(.+)$")
  end
  if date then
    return trim(date), trim(rest)
  end
  return "", trim(text)
end

local function split_title_meta(text, section)
  if section == "education" or section == "additional-training" then
    local title, meta = text:match("^(.+),%s+([^,]+)$")
    if title then
      return trim(title), trim(meta)
    end
  end

  local title, meta = text:match("^(.-)%s*\\textbar{}%s*(.+)$")
  if title then
    return trim(title), trim(meta)
  end

  return trim(text), ""
end

local function collect_nested_items(item)
  local items = {}

  for _, block in ipairs(item) do
    if block.t == "BulletList" then
      for _, nested_item in ipairs(block.content) do
        table.insert(items, blocks_to_latex(nested_item))
      end
    end
  end

  return items
end

local function nested_items_to_cvitems(items)
  if #items == 0 then
    return "{}"
  end

  local latex_items = {}
  for _, item in ipairs(items) do
    table.insert(latex_items, "\\item " .. item)
  end

  return "{\\begin{cvitems}" .. table.concat(latex_items, "\n") .. "\\end{cvitems}}"
end

local function item_first_text(item, strip_strong)
  for _, block in ipairs(item) do
    if block.t == "Plain" or block.t == "Para" then
      return inlines_to_latex(block.content, strip_strong)
    end
  end
  return blocks_to_latex(item)
end

local function bullet_list_to_cventries(list)
  local entries = { "\\begin{rrsentries}" }

  for _, item in ipairs(list.content) do
    local date, title_text = split_date(item_first_text(item, true))
    local title, meta = split_title_meta(title_text, current_section)
    local nested_items = collect_nested_items(item)

    if current_section == "teaching-and-educational-activities" and meta == "" and #nested_items > 0 then
      meta = table.remove(nested_items, 1)
    end

    local details = nested_items_to_cvitems(nested_items)
    table.insert(entries, string.format("\\rrscventry{%s}{%s}{%s}%s", date, title, meta, details))
  end

  table.insert(entries, "\\end{rrsentries}")
  return pandoc.RawBlock("latex", table.concat(entries, "\n"))
end

local function bullet_list_to_text_entries(list)
  local entries = { "\\begin{rrsentries}" }

  for _, item in ipairs(list.content) do
    table.insert(entries, "\\rrstextentry{" .. item_first_text(item, true) .. "}")
  end

  table.insert(entries, "\\end{rrsentries}")
  return pandoc.RawBlock("latex", table.concat(entries, "\n"))
end

local function is_legacy_pdf_header(div)
  if not div.classes:includes("content-visible") then
    return false
  end

  for _, block in ipairs(div.content) do
    if block.t == "RawBlock" and block.format:match("tex") then
      local text = block.text or ""
      if text:match("minipage") or text:match("faGithub") then
        return true
      end
    end
  end

  return false
end

local function is_legacy_pdf_header_block(block)
  if current_section ~= nil then
    return false
  end

  if block.t ~= "RawBlock" or not block.format:match("tex") then
    return false
  end

  local text = block.text or ""
  local compact = trim(text)

  return compact == "\\noindent"
    or text:match("minipage")
    or text:match("PrettyPDF/profile_pic")
    or text:match("begin{tabular}")
    or text:match("faGithub")
    or text:match("faOrcid")
    or text:match("aiGoogleScholar")
end

local function is_html_only_div(div)
  if div.classes:includes("btn-group") then
    return true
  end

  return div.classes:includes("content-visible") and div.attributes["when-format"] == "html"
end

function Pandoc(doc)
  if not FORMAT:match("latex") then
    return nil
  end

  local blocks = pandoc.List()

  for _, block in ipairs(doc.blocks) do
    if block.t == "Header" then
      if block.level == 1 then
        -- The AwesomeCV template owns the name/contact header.
      else
        current_section = block.identifier
        block.level = 1
        block.content = { pandoc.Str(section_titles[current_section] or pandoc.utils.stringify(block.content)) }
        blocks:insert(block)
      end
    elseif block.t == "Div" and (is_legacy_pdf_header(block) or is_html_only_div(block)) then
      -- Drop the old PrettyPDF contact block and HTML-only buttons.
    elseif is_legacy_pdf_header_block(block) then
      -- Drop the old PrettyPDF contact block and HTML-only buttons.
    elseif block.t == "BulletList" and cventry_sections[current_section] then
      blocks:insert(bullet_list_to_cventries(block))
    elseif block.t == "BulletList" and text_entry_sections[current_section] then
      blocks:insert(bullet_list_to_text_entries(block))
    else
      blocks:insert(block)
    end
  end

  doc.blocks = blocks
  return doc
end
