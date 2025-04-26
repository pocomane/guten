#!/usr/bin/lua5.4

local function log(...)
  --print(os.date('![%H:%M:%S ')..tostring(os.clock())..']', ...)
  print(...)
  io.flush()
end

local function exec(cmd)
  log("+ "..cmd)
  if not os.execute(cmd) then
    error('command execution failed: '..tostring(cmd))
  end
end

local function readcommand(cmd)
  local f, e = io.popen(cmd, 'w')
  if e then
    error('can not run '..cmd..' - '..e)
  end
  local result = f:read('a')
  f:close()
  return result
end

local function readfile(path)
  local f, e = io.open(path, 'r')
  if e then
    error('can not open '..cmd..' - '..e)
  end
  local result = f:read('a')
  f:close()
  return result
end

local function writeefile(str, path)
  local f, e = io.open(path, 'w')
  if e then
    error('can not write '..path..' - '..e)
  end
  f:write(str)
  f:close()
end

local function prepare()
  exec[[mkdir -p build]]
end

local success = 0
local fail = 0
local first = true
local function test(str, exp, arg)
  if first then
    prepare()
    first = false
  end
  writeefile(str, "build/in.tmp")
  local command = [[cd build && ../guten.lua]]
  if arg and arg ~= "" then
    command = command .. " " .. arg
  end
  command = command .. [[ in.tmp]]
  exec(command)
  if not exp then
    exec[[cd build && cat in.tmp && echo ""]]
    exec[[cd build && cat in.tmp.out && echo ""]]
  else
    local out = readfile('build/in.tmp.out')
    if out == exp then
      success = success + 1
    else
      fail = fail + 1
      log('!>> test failed - input:[\n'..str..'] output:[\n'..out..'] expected:[\n'..exp..']')
    end
  end
end

-- --------------------------------------------------------------------------------

test( [[test @{1+1} !]], [[test 2 !]] )

test( [[Hello @{{for k=1,3 do}}World @{{end}}!]], [[Hello World World World !]])

test( [[
@{{local count = 0; increase = function() count = count + 1 end}}
first value: @{count}
@{{count = count + 1}
second value: @{count}
@{{increase()}}
third value: @{count}]], [[

first value: 0
@{{count = count + 1}
second value: 0

third value: 1]] )

test([[@{option.foo}]], [[bar]], [[--foo=bar]])

-- --------------------------------------------------------------------------------

log("done.")
log(tostring(success).." tests passed.")
log(tostring(fail).." tests failed.")

