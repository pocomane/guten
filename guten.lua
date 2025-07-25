#!/usr/bin/lua5.4

-- Guten - released under MIT license by Mimmo Mane, 2025

-----------------------------------------------------------------------------------
-- luasnip-templua WITH MOD

-- NOTE: this is almost iddentical to the luasnip version.
-- THE IMPROVEMENT is the handling of the Transformations

local setmetatable, load = setmetatable, load
local fmt, tostring = string.format, tostring
local error = error

local function templua( template, transform ) --> ( sandbox ) --> expstr, err
   local function expr(e) return ' out('..e..')' end

   -- Generate a script that expands the template
   local script, position, max = '', 1, #template
   while position <= max do -- TODO : why '(.-)@(%b{})([^@]*)' is so much slower? The loop is needed to avoid a simpler gsub on that pattern!
     local start, finish = template:find('@%b{}', position)
     if not start then
       script = script .. expr( fmt( '%q', template:sub(position, max) ) )
       position = max + 1
     else
       if start > position then
         script = script .. expr( fmt( '%q', template:sub(position, start-1) ) )
       end
       if template:match( '^@{{.*}}', start ) then
          script = script .. template:sub( start+3, finish-2 )
       else
          script = script .. expr( template:sub( start+2, finish-1 ) )
       end
       position = finish + 1
     end
   end

   -- Utility to append the script to the error string
   local function report_error( err )
     return nil, err..'\nTemplate script: [[\n'..script..'\n]]'
   end

   -- Special case when no template tag is found
   if script == template then
     return function() return script end
   end

   -- Compile the template expander in a empty environment
   local env, outfunc -- set into the returned function
   local generate, err = load(
     'local _ENV, out = _ENV(); ' ..  script,
     'templua_script', 't',
     function() return env, outfunc end
   )
   if err ~= nil then return report_error( err ) end

   -- Return a function that runs the expander with a custom environment
   return function( sandbox )
     local result = {}

     -- Template environment and output generation
     env = sandbox
     if not transform then
       outfunc = function( out ) result[1+#result] = tostring( out ) end
     else
       outfunc = function( out ) result[1+#result] = transform( tostring( out )) end
     end

     -- Run the template
     local ok, err = pcall(generate)
     if not ok then return report_error( err ) end
     return table.concat(result)
  end
end

-----------------------------------------------------------------------------------
-- pseudo-markdown

local next_class = nil
local function set_class(c) next_class = c end
local function get_class(c)
	if not next_class then return "" end
	local result = ' class="'..next_class..'"'
	next_class = nil -- next_class = "base"
	return result
end
get_class()

local demarkdown_block
local demarkdown

function demarkdown_block(s)

	local done = false
	local function first_or_skip_sub(str, pat, sub)
	  if done then return str end
	  local result = str:gsub(pat, sub)
	  if not result then result = str end
	  if result ~= str then done = true end
	  return result
	end

	  s = s:gsub('^ *', '')
	  if s == "" then return "" end

    -- TODO's
	  s = s:gsub('^[ ]*[Tt][Oo][Dd][Oo].*', function(a, b)
		  return ''
	  end)

	  -- links
	  s = s:gsub('%[([^]]*)%]%(([^)]*)%)[^\n]*', function(a, b)
		  if a == "" or b == "" then
			  -- If one is missin, it will be parsed as "class extension"
			  return nil
		  end
		  return '<a href="'..b..'">'..a..'</a>'
	  end)

	  -- class extension
	  s = first_or_skip_sub(s, '^%[([^]]*)%]%(([^)]*)%)[^\n]*\n?(.*)', function(a, b, c)
		  if not a or a == "" then a = b end
		  set_class(a)
		  if #c < 1 then return ""
		  else return demarkdown_block(c)
		  end
	  end)

	   -- headers
	  s = first_or_skip_sub(s, '^(##*) *(.*)', function(a, b)
		   return '\n<h'..#a..'>'..b..'</h'..#a..'>'
	  end)

	  -- code block
	  s = first_or_skip_sub(s, '^~~*[^\n]*\n(.*)\n~~*$', function(a)
       local class = get_class()
       if class == "" then class = ' class="example"' end
		   return '<div'..class..'>'..demarkdown(a)..'</div>'
       -- -- TODO : change to:
		   -- return '<code'..get_class()..'>'..a..'</code>'
	  end)

	  -- list
	  s = first_or_skip_sub(s, '^%-.*', function(a)
      a = a:gsub("^[ ]*%-[ ]*","<li>")
      a = a:gsub("\n[ ]*%-[ ]*","</li>\n<li>")
      a = a .. '</li>'
		  return "<ul"..get_class()..">\n"..a.."</ul>"
	  end)

	  -- table
	  s = first_or_skip_sub(s, '^|[^\n]*|[^\n]*\n|[^\n:-]*(:?)%-(:?)[^\n]*\n(.*)', function(l, r, a)
       local align = "left"
       if l ~= '' and r ~= '' then align = "center" end
       if l == '' and r ~= '' then align = "right" end
		   a = a:gsub('\n|', '\n')
		   a = a:gsub('|[ ]*\n', '\n')
		   a = a:gsub('^|', '<tr><td>')
		   a = a:gsub('|', '</td><td>')
		   a = a:gsub('\n', '</td></tr>\n<tr><td>')
		   a = '<div style="text-align:'..align..'"><table'..get_class()..'>\n'..a..'</td></tr>\n</table></div>'
		   return a
	  end)

	  -- default block
	  s = first_or_skip_sub(s, '(.*)', function(a)
		  return '<p'..get_class()..'>'..a..'</p>'
	  end)

	  return s .. '\n\n'
end

function demarkdown(str)

	-- clean up / normalize whitespaces to simplify further processing
	str = str:gsub('\r\n','\n')
	str = str:gsub('\r','\n')
	str = str:gsub('^\n*','')
	str = str:gsub('\n*$','')
	str = str:gsub('\t','  ')
	str = str:gsub(' *\n','\n')
	str = str:gsub('\n\n\n*','\n\n\n\n')
	str = '\n\n'..str..'\n\n'
  if str:match("^[\n ]*$") then
    return str
  end

	-- parse text block by block
	local pieces = {}
	local maxpos = #str
	local position = 1
	while position < maxpos do
		--print(">>>>>>>>>> ---------------------------------------------------------")
		--print(">>>>>>>>>> first part of processing block ["..str:sub(position,position+10).."] at", s)
		local s, e = str:find('\n\n.-\n\n', position)
		if not s then break end
		local start_fence, ee = str:find('\n~~~~*\n', position)
		--print(">>>>>>>>>> start fence", start_fence, ee)
		if start_fence and start_fence <= e then
		  local has_terminal_fence, end_fence = str:find('\n~~~~*\n\n', ee + 1)
		  --print(">>>>>>>>>> end fence", has_terminal_fence, end_fence)
		  if has_terminal_fence then
			  e = end_fence
		  end
		end
		position = e + 1
		s = s + 2
		e = e - 2
		--print(">>>>>>>>>> final processing block ["..str:sub(s,e).."] at", s)
		--print(">>>>>>>>>> ---------------------------------------------------------")
		local block = str:sub(s, e)
		if #block > 0 then
			pieces[1+#pieces] = demarkdown_block(block)
		end
	end

	return table.concat(pieces)
end

-----------------------------------------------------------------------------------
-- render

local SCRIPTDIR = arg[0]:gsub('[^/]*$', '')

package.path = package.path .. ';'..SCRIPTDIR..'?.lua'

local function exec(cmd)
  --print("EXEC: "..cmd)
  if not os.execute(cmd) then
    error('command execution failed: '..tostring(cmd))
  end
end

local function log(...)
  print(os.date('![%H:%M:%S ')..tostring(os.clock())..']', ...)
  io.flush()
end

local function load_file(path)
  local f, e = io.open(path, 'r')
  if e then
    return nil, 'can not find '..path
  end
  local c = f:read('a')
  f:close()
  return c
end

local function get_content(wrk, filename)
  local content = wrk.file_cache[filename]
  if content then return content end
  local content, e = load_file("./"..filename, 'r')
  if e then
    error('can not find ./'..filename)
  end
  wrk.file_cache[filename] = content
  return content
end

local function tweak_example_block(x)
  x = x:gsub('<pre><code>(.-)</code></pre>',function(content)
    return '<div class="example"><p>'..(content:gsub('(\n\n)','</p>%1<p>'))..'</p></div>'
  end)
  return x
end

-- TODO : find another way
local function add_front_page(wrk, x)
  return ''
         .. '<div class="title">\n'
         .. '  <div class="title_text">'.. wrk.title.text .. '</div>\n'
         .. '  <div class="title_author">'.. wrk.title.author .. '</div>\n'
         .. '  <img class="title_image" src="../asset/'.. wrk.title.image .. '" />\n'
         .. '</div>\n'
         .. x
end

local function find_last_match(str, pat)
  local begin, finish = 1, 0
  while finish + 1 < #str do
    local a, b = str:find(pat, finish + 1)
    if not b then break end
    begin, finish = a, b
  end
  if finish == 0 then return nil, nil end
  return begin, finish
end

local function split_content_meta(content)
  local metascript = ""
  local position = content:find('%-%-*[ \t\n\r]*$')
  if position and position > 1 then
    content = content:sub(1, position-1)
    local begin, finish = find_last_match(content, '[\n\r]%-+[\n\r]')
    if begin then
      metascript = content:sub(finish + 1)
      content = content:sub(1, begin-1)
    end
  end
  return content, metascript
end

local function run_meta(env, content)
  local _, metascript = split_content_meta(content)
  if metascript ~= "" then
    local fun, err = load( metascript, 'meta_script', 't', env)
    if err then
      log('ERROR - while compiling metascript '..metascript)
      error(err)
    end
    return (function(ok, arg, ...)
      if ok then
        return arg, ...
      else
        log('ERROR - while executing metascript '..metascript)
        error(arg)
      end
    end)(pcall(fun))
  end
end

local function expand_content(wrk, src, env, apply_transform)
  if env == nil then
    local pipeline = {}
    local function transform( f )
      if type(f) ~= 'function' then error('argument must be a function', 1) end
      pipeline[1+#pipeline] = f
    end
    local function readcommand(cmd)
      local f, e = io.popen(cmd, 'r')
      if e then
        log('ERROR - while running the command: "'..tostring(cmd))
        error(e)
      end
      local c = f:read('a')
      f:close()
      return c
    end
    local opt = {}
    for k, v in pairs(wrk.env) do
      opt[k] = v
    end
-- TODO : rename "clear" utility function ???
    env = {
      pairs = pairs, ipairs = ipairs,
      log = log,
      option = opt,
      readcommand = readcommand,
      include = function(src, pat) return expand_content(wrk, src, env, apply_transform) end,
      mdtohtml = function(src) return demarkdown(src) end,
      date = os.date('!%Y-%m-%d %H:%M:%SZ'),
      clear = function() pipeline = {} end,
      transform = transform,
      done = function() pipeline[#pipeline] = nil end,
      getmeta = function(path) return run_meta(env, get_content(wrk, path)) end,

    }
    apply_transform = function( str )
      for k = #pipeline, 1, -1 do
        --if str ~= "" then
          -- Apply tranform only on non-empty strings. Transform can be used
          -- just to add suffix/postfix decorations: without this check it
          -- could be triggered by the empty string between tags.
          -- TODO : remove ? it can be emulated with subst function, and actually
          -- pure prepend/postpend without pre-matching is rare (and can be
          -- done witout tranformation)
          str = pipeline[k](str)
        --end
      end
      return str
    end
  end
  local content = get_content(wrk, src)
  content = split_content_meta(content)
  local generate, err = templua(content, apply_transform)
  if err ~= nil then
    log('ERROR - while compiling template '..src)
    error(err)
  end
  local expanded, err = generate(env)
  if err ~= nil then
    log('ERROR - while expanding '..src)
    error(err)
  end
  return expanded
end

local function render_output(wrk, src, dst)
  local content = expand_content(wrk, src)
  content = tweak_example_block(content)
  wrk.output[dst] = content
end

-----------------------------------------------------------------------------------
-- pdfize

local function render_file(wrk, src)
  local basename = src:gsub("^.*/",""):gsub('%.[Tt][m][p][l]$','')
  local outpath = src..'.out'
  if wrk.env.out then
    local basename = src:match("[^/\\]*$"):gsub("%.[^%.]*$", "")
    outpath = wrk.env.out:gsub("%%", basename)
  end
  log("generating", outpath)
  local parent = outpath:gsub("[^/\\]*$", "")
  if parent and parent ~= "" then
    exec("mkdir -p '"..parent.."'")
  end
  render_output(wrk, src, outpath)
  local x = wrk.output[outpath]
  local f, e = io.open(outpath, 'wb')
  if e then error(e) end
  f:write(x)
  f:close()
end

local stop_parsing_option = false
--
local function check_command_flag(env, opt)
  if stop_parsing_option or opt:sub(1,2) == "--" then
    if opt == "--" then
      stop_parsing_option = true
      return false
    end
    local k, v = opt:match("%-%-([^=]*)(.*)")
    if v ~= "" then
      v = v:sub(2)
    end
    env[k] = v
    return true
  end
  return false
end

local function main(arg)
  log("Working in folder:")
  exec("pwd")
  local wrk = {output={},file_cache={},env={}}
  for k = 1, #arg do
    if not check_command_flag(wrk.env, arg[k]) then
      render_file(wrk, arg[k])
    end
  end
end

-----------------------------------------------------------------------------------

main(arg)

