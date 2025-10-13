-- cv.lua : convierte ::: cvrow ... <span class="cvdate">DATE</span> ::: a \cvrow{...}{DATE} en LaTeX
local stringify = (function()
  local f = pandoc.utils and pandoc.utils.stringify or pandoc.utils.stringify
  return f
end)()

function Div(el)
  if not el.classes:includes('cvrow') then return nil end

  -- Extrae fecha de <span class="cvdate">...</span>
  local dateText = nil
  local leftBlocks = {}

  for _, blk in ipairs(el.content) do
    if blk.t == 'Para' then
      -- separa spans dentro del párrafo
      local newInlines = {}
      for _, inl in ipairs(blk.content) do
        if inl.t == 'Span' and inl.classes:includes('cvdate') then
          dateText = stringify(inl.content)
          -- no añadimos este span al texto izquierdo
        else
          table.insert(newInlines, inl)
        end
      end
      table.insert(leftBlocks, pandoc.Para(newInlines))
    else
      table.insert(leftBlocks, blk)
    end
  end

  -- Si no hay fecha, la dejamos vacía
  if dateText == nil then dateText = "" end

  if FORMAT:match('latex') then
    -- Convierte el contenido izquierdo a LaTeX inline
    local leftLatex = pandoc.write(pandoc.Pandoc(leftBlocks), 'latex')
    -- Limpia dobles saltos de párrafo que meterían espacio extra
    leftLatex = leftLatex:gsub("\n+\n+", " ")
    local raw = string.format("\\cvrow{%s}{%s}\n", leftLatex, dateText)
    return pandoc.RawBlock('latex', raw)
  else
    -- En HTML/otros formatos, deja la estructura tal cual
    return el
  end
end
