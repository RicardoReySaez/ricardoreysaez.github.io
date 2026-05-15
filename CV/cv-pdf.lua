local function meta_to_bool(value, default)
  if value == nil then
    return default
  end

  if type(value) == "boolean" then
    return value
  end

  if value.t == "MetaBool" then
    return value.c
  end

  local text = pandoc.utils.stringify(value):lower()
  if text == "false" or text == "no" or text == "0" then
    return false
  end

  return true
end

local pretty_pdf_header = [=[
\noindent
\begin{minipage}[t]{0.40\textwidth}
\vspace{-15pt}\includegraphics[width=\linewidth]{profile_pic.jpeg}
\end{minipage}\hfill\qquad\quad
\begin{minipage}[t]{0.60\textwidth}
\vspace{0pt}
\begin{tabular}{@{}ll}
\faGithub        & \href{https://github.com/rreysa}{rreysa}\\[0.60em]
\faOrcid         & \href{https://orcid.org/0000-0001-6739-2035}{0000-0001-6739-2035}\\[0.60em]
\faTwitter       & \href{https://x.com/RicardoRey_95}{@RicardoRey\_95}\\[0.60em]
\faExternalLink* & \href{https://bsky.app/profile/ricardoreysaez.bsky.social}{ricardoreysaez.bsky.social}\\[0.60em]
\faYoutube       & \href{https://www.youtube.com/@psicometries}{@psicometries}\\[0.60em]
\aiGoogleScholar & \href{https://scholar.google.com/citations?user=SxTNYh4AAAAJ&hl}{Google Scholar}\\[0.60em]
\faEnvelope      & \href{mailto:ricardoreysaez95@gmail.com}{ricardoreysaez95@gmail.com}
\end{tabular}
\end{minipage}
]=]

local process_blocks

local function process_block(block)
  if block.t == "BulletList" or block.t == "OrderedList" then
    for _, item in ipairs(block.content) do
      for i = #item, 1, -1 do
        if item[i].t == "BulletList" or item[i].t == "OrderedList" then
          item:remove(i)
        else
          item[i] = process_block(item[i])
        end
      end
    end
    return block
  end

  if block.t == "Div" or block.t == "BlockQuote" then
    block.content = process_blocks(block.content)
  end

  return block
end

process_blocks = function(blocks)
  for i, block in ipairs(blocks) do
    blocks[i] = process_block(block)
  end
  return blocks
end

local function insert_pretty_pdf_header(blocks)
  local result = pandoc.List()
  local inserted = false

  for _, block in ipairs(blocks) do
    result:insert(block)

    if not inserted and block.t == "Header" and block.level == 1 then
      result:insert(pandoc.RawBlock("latex", pretty_pdf_header))
      inserted = true
    end
  end

  return result
end

function Pandoc(doc)
  if not FORMAT:match("latex") then
    return nil
  end

  if not meta_to_bool(doc.meta["cv-include-list-details"], true) then
    doc.blocks = process_blocks(doc.blocks)
  end

  doc.blocks = insert_pretty_pdf_header(doc.blocks)
  return doc
end
