-- BEGIN struct.lua

--[[
 * Copyright (c) 2015-2018 Iryont <https://github.com/iryont/lua-struct>
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
]]

local struct = {}

function struct.pack(format, ...)
  local stream = {}
  local vars = {...}
  local endianness = true

  for i = 1, format:len() do
    local opt = format:sub(i, i)

    if opt == '<' then
      endianness = true
    elseif opt == '>' then
      endianness = false
    elseif opt:find('[bBhHiIlL]') then
      local n = opt:find('[hH]') and 2 or opt:find('[iI]') and 4 or opt:find('[lL]') and 8 or 1
      local val = tonumber(table.remove(vars, 1))

      local bytes = {}
      for j = 1, n do
        table.insert(bytes, string.char(val % (2 ^ 8)))
        val = math.floor(val / (2 ^ 8))
      end

      if not endianness then
        table.insert(stream, string.reverse(table.concat(bytes)))
      else
        table.insert(stream, table.concat(bytes))
      end
    elseif opt:find('[fd]') then
      local val = tonumber(table.remove(vars, 1))
      local sign = 0

      if val < 0 then
        sign = 1
        val = -val
      end

      local mantissa, exponent = math.frexp(val)
      if val == 0 then
        mantissa = 0
        exponent = 0
      else
        mantissa = (mantissa * 2 - 1) * math.ldexp(0.5, (opt == 'd') and 53 or 24)
        exponent = exponent + ((opt == 'd') and 1022 or 126)
      end

      local bytes = {}
      if opt == 'd' then
        val = mantissa
        for i = 1, 6 do
          table.insert(bytes, string.char(math.floor(val) % (2 ^ 8)))
          val = math.floor(val / (2 ^ 8))
        end
      else
        table.insert(bytes, string.char(math.floor(mantissa) % (2 ^ 8)))
        val = math.floor(mantissa / (2 ^ 8))
        table.insert(bytes, string.char(math.floor(val) % (2 ^ 8)))
        val = math.floor(val / (2 ^ 8))
      end

      table.insert(bytes, string.char(math.floor(exponent * ((opt == 'd') and 16 or 128) + val) % (2 ^ 8)))
      val = math.floor((exponent * ((opt == 'd') and 16 or 128) + val) / (2 ^ 8))
      table.insert(bytes, string.char(math.floor(sign * 128 + val) % (2 ^ 8)))
      val = math.floor((sign * 128 + val) / (2 ^ 8))

      if not endianness then
        table.insert(stream, string.reverse(table.concat(bytes)))
      else
        table.insert(stream, table.concat(bytes))
      end
    elseif opt == 's' then
      table.insert(stream, tostring(table.remove(vars, 1)))
      table.insert(stream, string.char(0))
    elseif opt == 'c' then
      local n = format:sub(i + 1):match('%d+')
      local length = tonumber(n)

      if length > 0 then
        local str = tostring(table.remove(vars, 1))
        if length - str:len() > 0 then
          str = str .. string.rep(' ', length - str:len())
        end
        table.insert(stream, str:sub(1, length))
      end
      i = i + n:len()
    end
  end

  return table.concat(stream)
end

function struct.unpack(format, stream)
  local vars = {}
  local iterator = 1
  local endianness = true

  for i = 1, format:len() do
    local opt = format:sub(i, i)

    if opt == '<' then
      endianness = true
    elseif opt == '>' then
      endianness = false
    elseif opt:find('[bBhHiIlL]') then
      local n = opt:find('[hH]') and 2 or opt:find('[iI]') and 4 or opt:find('[lL]') and 8 or 1
      local signed = opt:lower() == opt

      local val = 0
      for j = 1, n do
        local byte = string.byte(stream:sub(iterator, iterator))
        if endianness then
          val = val + byte * (2 ^ ((j - 1) * 8))
        else
          val = val + byte * (2 ^ ((n - j) * 8))
        end
        iterator = iterator + 1
      end

      if signed and val >= 2 ^ (n * 8 - 1) then
        val = val - 2 ^ (n * 8)
      end

      table.insert(vars, val)
    elseif opt:find('[fd]') then
      local n = (opt == 'd') and 8 or 4
      local x = stream:sub(iterator, iterator + n - 1)
      iterator = iterator + n

      if not endianness then
        x = string.reverse(x)
      end

      local sign = 1
      local mantissa = string.byte(x, (opt == 'd') and 7 or 3) % ((opt == 'd') and 16 or 128)
      for i = n - 2, 1, -1 do
        mantissa = mantissa * (2 ^ 8) + string.byte(x, i)
      end

      if string.byte(x, n) > 127 then
        sign = -1
      end

      local exponent = (string.byte(x, n) % 128) * ((opt == 'd') and 16 or 2) + math.floor(string.byte(x, n - 1) / ((opt == 'd') and 16 or 128))
      if exponent == 0 then
        table.insert(vars, 0.0)
      else
        mantissa = (math.ldexp(mantissa, (opt == 'd') and -52 or -23) + 1) * sign
        table.insert(vars, math.ldexp(mantissa, exponent - ((opt == 'd') and 1023 or 127)))
      end
    elseif opt == 's' then
      local bytes = {}
      for j = iterator, stream:len() do
        if stream:sub(j, j) == string.char(0) then
          break
        end

        table.insert(bytes, stream:sub(j, j))
      end

      local str = table.concat(bytes)
      iterator = iterator + str:len() + 1
      table.insert(vars, str)
    elseif opt == 'c' then
      local n = format:sub(i + 1):match('%d+')
      table.insert(vars, stream:sub(iterator, iterator + tonumber(n)-1))
      iterator = iterator + tonumber(n)
      i = i + n:len()
    end
  end

  return table.unpack(vars)
end

-- END struct.lua

local iup = require'iuplua'


local chunk_list = { 'INFO','DATA','BANK','RATE','plst','time','fade','tlbl','auth','text','NEND' }

local dlg
local nsfe = {}
local songs
local song_texts
local track_editor
local file_label = iup.label({title = "Loaded: none"})

local title_label = iup.label({title = "Game:"})
local title_text  = iup.text({expand = "HORIZONTAL"})

local artist_label = iup.label({title = "Artist:"})
local artist_text  = iup.text({expand = "HORIZONTAL"})

local copyright_label = iup.label({title = "Copyright:"})
local copyright_text  = iup.text({expand = "HORIZONTAL"})

local ripper_label = iup.label({title = "Ripped by:"})
local ripper_text  = iup.text({expand = "HORIZONTAL"})


local numsongs = 0

local function save_nsfe(filename)
  local f, err = io.open(filename,"wb")
  if err then return nil, err end
  
  f:write("NSFE")
  
  for i,v in ipairs(chunk_list) do
    if v ~= 'tlbl' and v~= 'auth' then
	  if nsfe[v] then
	    print('saving ' .. v)
        f:write(struct.pack('<I',string.len(nsfe[v])))
	    f:write(v)
	    f:write(nsfe[v])
	  end
	elseif v == 'tlbl' then
	  print('saving ' .. v)
	  local c = ""

	  for j,s in ipairs(songs) do
	    if j <= numsongs then
		  print("appending" .. s)
		  c = c .. s .. string.char(0)
		end
	  end
	  print("data length: " .. string.len(c))
	  f:write(struct.pack('<I',string.len(c)))
	  f:write(v)
	  f:write(c)
	elseif v == 'auth' then
	  print('saving ' .. v)
	  local c = title_text.value .. string.char(0)
	  c = c .. artist_text.value .. string.char(0)
	  c = c .. copyright_text.value .. string.char(0)
	  c = c .. ripper_text.value .. string.char(0)
	  print("data length: " .. string.len(c))
	  f:write(struct.pack('<I',string.len(c)))
	  f:write(v)
	  f:write(c)
	end
  
  end
  f:close()
  return true, nil
end

local function save_nsfe_action(self)
  if not songs then
    iup.Popup(
	  iup.messagedlg({
	    title = "Error!",
		value = "Please load an NSFE first",
		dialogtype = "ERROR"
	  }),
	  IUP_CURRENT,
	  IUP_CURRENT
	)
	return
  end
  
  local fd = iup.filedlg({
    dialogtype="SAVE",
	extdefault="nsfe",
	title="Save NSFE as...",
  })

  fd:popup()
  
  if(fd.status == "-1") then return end
  
  local ok, err = save_nsfe(fd.value)
  if err then
    iup.Popup(
	  iup.messagedlg({
	    title = "Error!",
		value = err,
		dialogtype = "ERROR"
	  }),
	  IUP_CURRENT,
	  IUP_CURRENT
	)
  end
 
end

local function update_track_names(self)
  for i,v in ipairs(song_texts) do
    if i <= numsongs then
    songs[i] = song_texts[i].value
	print(string.format("Song %d: %s",i,songs[i]))
	end
  end
  track_editor:destroy()

end

local function open_track_editor(self)
  if not songs then
    iup.Popup(
	  iup.messagedlg({
	    title = "Error!",
		value = "Please load an NSFE first",
		dialogtype = "ERROR"
	  }),
	  IUP_CURRENT,
	  IUP_CURRENT
	)
	return
  end
  
  song_texts = {}
  
  track_editor_gb = iup.gridbox({
      orientation="HORIZONTAL",
	  numdiv=2,
      gaplin=20,
      gapcol=40,
	  margin="20x20",
  })
  
  for i,v in ipairs(songs) do
    if i <= numsongs then
	  local st = iup.text({expand = "HORIZONTAL", value = v})
	  song_texts[i] = st
	  track_editor_gb:append(iup.label({title = "Track " .. i}))
	  track_editor_gb:append(st)
	end
  end
  
  
  track_editor = iup.dialog({
    iup.vbox({
      iup.scrollbox({
        track_editor_gb,
	  }),
	  iup.button({title = "Save", action = update_track_names}),
	  gap = 20,
	}),
    title = "Track Editor",
    size="300x200",
  })

  iup.Popup(track_editor,dlg.x + 40,dlg.y + 40)
end

local function split(self,inSplitPattern)
  local res = {}
  local start = 1
  local splitStart, splitEnd = string.find(self,inSplitPattern,start)
  while splitStart do
    table.insert(res, string.sub(self,start,splitStart-1))
    start = splitEnd + 1
    splitStart, splitEnd = string.find(self,inSplitPattern, start)
  end
  table.insert(res, string.sub(self,start) )
  return res
end

local function parse_nsfe(filename)
  local err, file, header, data, i
  file = io.open(filename,"rb")
  header,err = file:read(4)
  if err then return nil, err end
  if header ~= "NSFE" then return nil,"not an NSFE file" end
  local data, err = file:read("*all")
  file:close()
  
  file_label.title = "Loaded: " .. filename
  
  i = 1
  while(i<string.len(data)) do
    local length, typ, chunk
    length = struct.unpack('<I',data:sub(i,i+3))
	typ = data:sub(i+4,i+7)
		print("found " .. typ .. ', len: ' .. length)
		
	if typ ~= "NEND" then
	  chunk = data:sub(i+8,i+8+length-1)
	  nsfe[typ] = chunk
	else
	  nsfe[typ] = ""
	end
	
	if typ == "INFO" then
	  numsongs = struct.unpack('<B',chunk:sub(9,9))
	  print('Number of songs:' .. numsongs)
	end
	
	if typ == "tlbl" then
	  songs = split(chunk,"\0")
	end
	
	if typ == "auth" then
	  meta = split(chunk,"\0")
	  for i,v in ipairs(meta) do
	    if i == 1 then
		  title_text.value = v
		elseif i == 2 then
		  artist_text.value = v
		elseif i == 3 then
		  copyright_text.value = v
		elseif i == 4 then
		  ripper_text.value = v
		end
	  end
	end
  
    i = i + 8 + length
  end
  iup.Refresh(dlg)

end

local function open_nsfe_action(self)
  local r
  local f, err = iup.GetFile("*.nsfe")
  if err == -1 then return end
  r, err = parse_nsfe(f)
  if err then
    iup.Popup(
	  iup.messagedlg({
	    title = "Error!",
		value = err,
		dialogtype = "ERROR"
	  }),
	  IUP_CURRENT,
	  IUP_CURRENT
	)
  end
end

dlg = iup.dialog({
  iup.vbox({
    iup.hbox({
      iup.button({
        title = "Choose NSFE",
	    action = open_nsfe_action,
      }),
	  iup.button({
	    title = "Save NSFE",
		action = save_nsfe_action,
	  }),
	}),
    file_label,
	iup.gridbox({
      title_label,
      title_text,
      artist_label,
      artist_text,
      copyright_label,
      copyright_text,
      ripper_label,
      ripper_text,
	  orientation="HORIZONTAL",
	  numdiv=2,
      gaplin=20,
      gapcol=40,
	}),
	iup.button({
	  title = "Edit tracks",
	  action = open_track_editor,
	}),
	gap=20,
  }),
  title = "NSFE Editor",
  size="300x200",
})

dlg:showxy(iup.CENTER,iup.CENTER)

if (iup.MainLoopLevel()==0) then
  iup.MainLoop()
  iup.Close()
end