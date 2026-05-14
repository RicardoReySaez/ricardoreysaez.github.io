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

function Pandoc(doc)
  if FORMAT:match("latex") and not meta_to_bool(doc.meta["cv-include-list-details"], true) then
    doc.blocks = process_blocks(doc.blocks)
    return doc
  end
end
