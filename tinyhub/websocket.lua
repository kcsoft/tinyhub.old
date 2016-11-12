package.preload['websocket.sync'] = (function (...)
local frame = require'websocket.frame'
local handshake = require'websocket.handshake'
local tools = require'websocket.tools'
local ssl = require'ssl'
local tinsert = table.insert
local tconcat = table.concat

local receive = function(self)
  if self.state ~= 'OPEN' and not self.is_closing then
    return nil,nil,false,1006,'wrong state'
  end
  local first_opcode
  local frames
  local bytes = 3
  local encoded = ''
  local clean = function(was_clean,code,reason)
    self.state = 'CLOSED'
    self:sock_close()
    if self.on_close then
      self:on_close()
    end
    return nil,nil,was_clean,code,reason or 'closed'
  end
  while true do
    local chunk,err = self:sock_receive(bytes)
    if err then
      return clean(false,1006,err)
    end
    encoded = encoded..chunk
    local decoded,fin,opcode,_,masked = frame.decode(encoded)
    if not self.is_server and masked then
      return clean(false,1006,'Websocket receive failed: frame was not masked')
    end
    if decoded then
      if opcode == frame.CLOSE then
        if not self.is_closing then
          local code,reason = frame.decode_close(decoded)
          -- echo code
          local msg = frame.encode_close(code)
          local encoded = frame.encode(msg,frame.CLOSE,not self.is_server)
          local n,err = self:sock_send(encoded)
          if n == #encoded then
            return clean(true,code,reason)
          else
            return clean(false,code,err)
          end
        else
          return decoded,opcode
        end
      end
      if not first_opcode then
        first_opcode = opcode
      end
      if not fin then
        if not frames then
          frames = {}
        elseif opcode ~= frame.CONTINUATION then
          return clean(false,1002,'protocol error')
        end
        bytes = 3
        encoded = ''
        tinsert(frames,decoded)
      elseif not frames then
        return decoded,first_opcode
      else
        tinsert(frames,decoded)
        return tconcat(frames),first_opcode
      end
    else
      assert(type(fin) == 'number' and fin > 0)
      bytes = fin
    end
  end
  assert(false,'never reach here')
end

local send = function(self,data,opcode)
  if self.state ~= 'OPEN' then
    return nil,false,1006,'wrong state'
  end
  local encoded = frame.encode(data,opcode or frame.TEXT,not self.is_server)
  local n,err = self:sock_send(encoded)
  if n ~= #encoded then
    return nil,self:close(1006,err)
  end
  return true
end

local close = function(self,code,reason)
  if self.state ~= 'OPEN' then
    return false,1006,'wrong state'
  end
  if self.state == 'CLOSED' then
    return false,1006,'wrong state'
  end
  local msg = frame.encode_close(code or 1000,reason)
  local encoded = frame.encode(msg,frame.CLOSE,not self.is_server)
  local n,err = self:sock_send(encoded)
  local was_clean = false
  local code = 1005
  local reason = ''
  if n == #encoded then
    self.is_closing = true
    local rmsg,opcode = self:receive()
    if rmsg and opcode == frame.CLOSE then
      code,reason = frame.decode_close(rmsg)
      was_clean = true
    end
  else
    reason = err
  end
  self:sock_close()
  if self.on_close then
    self:on_close()
  end
  self.state = 'CLOSED'
  return was_clean,code,reason or ''
end

local connect = function(self,ws_url,ws_protocol,ssl_params)
  if self.state ~= 'CLOSED' then
    return nil,'wrong state'
  end
  local protocol,host,port,uri = tools.parse_url(ws_url)
  -- Preconnect (for SSL if needed)
  local _,err = self:sock_connect(host,port)
  if err then
    return nil,err
  end
  if protocol == 'wss' then
    self.sock = ssl.wrap(self.sock, ssl_params)
    self.sock:dohandshake()
  elseif protocol ~= "ws" then
    return nil, 'bad protocol'
  end
  local ws_protocols_tbl = {''}
  if type(ws_protocol) == 'string' then
      ws_protocols_tbl = {ws_protocol}
  elseif type(ws_protocol) == 'table' then
      ws_protocols_tbl = ws_protocol
  end
  local key = tools.generate_key()
  local req = handshake.upgrade_request
  {
    key = key,
    host = host,
    port = port,
    protocols = ws_protocols_tbl,
    uri = uri
  }
  local n,err = self:sock_send(req)
  if n ~= #req then
    return nil,err
  end
  local resp = {}
  repeat
    local line,err = self:sock_receive('*l')
    resp[#resp+1] = line
    if err then
      return nil,err
    end
  until line == ''
  local response = table.concat(resp,'\r\n')
  local headers = handshake.http_headers(response)
  local expected_accept = handshake.sec_websocket_accept(key)
  if headers['sec-websocket-accept'] ~= expected_accept then
    local msg = 'Websocket Handshake failed: Invalid Sec-Websocket-Accept (expected %s got %s)'
    return nil,msg:format(expected_accept,headers['sec-websocket-accept'] or 'nil')
  end
  self.state = 'OPEN'
  return true
end

local extend = function(obj)
  assert(obj.sock_send)
  assert(obj.sock_receive)
  assert(obj.sock_close)

  assert(obj.is_closing == nil)
  assert(obj.receive    == nil)
  assert(obj.send       == nil)
  assert(obj.close      == nil)
  assert(obj.connect    == nil)

  if not obj.is_server then
    assert(obj.sock_connect)
  end

  if not obj.state then
    obj.state = 'CLOSED'
  end

  obj.receive = receive
  obj.send = send
  obj.close = close
  obj.connect = connect

  return obj
end

return {
  extend = extend
}
 end)
package.preload['websocket.server'] = (function (...)
return setmetatable({},{__index = function(self, name)
  local backend = require("websocket.server_" .. name)
  self[name] = backend
  return backend
end})
 end)
package.preload['websocket.server_uloop'] = (function (...)

local socket = require'socket'
local tools = require'websocket.tools'
local frame = require'websocket.frame'
local handshake = require'websocket.handshake'
local sync = require'websocket.sync'
require'uloop'
local tconcat = table.concat
local tinsert = table.insert

local clients = {}
local sock_clients = {}
local sock_events = {}

local client = function(sock,protocol)
  
  local self = {}
  
  self.state = 'OPEN'
  self.is_server = true
    
  self.sock_send = function(self,...)
    return sock:send(...)
  end
  
  self.sock_receive = function(self,...)
    return sock:receive(...)
  end
  
  self.sock_close = function(self)
    sock_clients[sock:getfd()] = nil
    sock_events[sock:getfd()]:delete()
    sock_events[sock:getfd()] = nil
    sock:shutdown()
    sock:close()
  end
  
  self = sync.extend(self)
  
  self.on_close = function(self)
    clients[protocol][self] = nil
  end
  
  self.broadcast = function(self,...)
    for client in pairs(clients[protocol]) do
      if client ~= self then
        client:send(...)
      end
    end
    self:send(...)
  end
  
  return self
end


local listen = function(opts)
  
  assert(opts and (opts.protocols or opts.default))
  local on_error = opts.on_error or function(s) print(s) end
  local listener = socket.tcp()
  listener:setoption("reuseaddr", true)
  listener:settimeout(0)
  listener:bind("*", opts.port or 80)
  listener:listen()

  local protocols = {}
  if opts.protocols then
    for protocol in pairs(opts.protocols) do
      clients[protocol] = {}
      tinsert(protocols,protocol)
    end
  end
  -- true is the 'magic' index for the default handler
  clients[true] = {}

  tcp_event = uloop.fd_add(listener, function(tfd, events)
    tfd:settimeout(3)
    local new_conn = assert(tfd:accept())
    if new_conn ~= nil then
      local request = {}
      repeat
        local line,err = new_conn:receive('*l')
        if line then
          request[#request+1] = line
        else
          new_conn:close()
          if on_error then
            on_error('invalid request')
          end
          return
        end
      until line == ''
      local upgrade_request = tconcat(request,'\r\n')
      local response,protocol = handshake.accept_upgrade(upgrade_request,protocols)
      if not response then
        new_conn:send(protocol)
        new_conn:close()
        if on_error then
          on_error('invalid request')
        end
        return
      end
      new_conn:send(response)
      local handler
      local new_client
      local protocol_index
      if protocol and opts.protocols[protocol] then
        protocol_index = protocol
        handler = opts.protocols[protocol]
      elseif opts.default then
        -- true is the 'magic' index for the default handler
        protocol_index = true
        handler = opts.default
      else
        new_conn:close()
        if on_error then
          on_error('bad protocol')
        end
        return
      end
      new_client = client(new_conn, protocol_index)
      sock_clients[new_conn:getfd()] = new_client
      clients[protocol_index][new_client] = true
      
      sock_events[new_conn:getfd()] = uloop.fd_add(new_conn, function(csocket, events)
        handler(sock_clients[csocket:getfd()])
      end, uloop.ULOOP_READ)
    end
  end, uloop.ULOOP_READ)
end  

return {
  listen = listen,
  clients = clients
}
 end)
package.preload['websocket.handshake'] = (function (...)
local sha1 = require'websocket.tools'.sha1
local base64 = require'websocket.tools'.base64
local tinsert = table.insert

local guid = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"

local sec_websocket_accept = function(sec_websocket_key)
  local a = sec_websocket_key..guid
  local sha1 = sha1(a)
  assert((#sha1 % 2) == 0)
  return base64.encode(sha1)
end

local http_headers = function(request)
  local headers = {}
  if not request:match('.*HTTP/1%.1') then
    return headers
  end
  request = request:match('[^\r\n]+\r\n(.*)')
  local empty_line
  for line in request:gmatch('[^\r\n]*\r\n') do
    local name,val = line:match('([^%s]+)%s*:%s*([^\r\n]+)')
    if name and val then
      name = name:lower()
      if not name:match('sec%-websocket') then
        val = val:lower()
      end
      if not headers[name] then
        headers[name] = val
      else
        headers[name] = headers[name]..','..val
      end
    elseif line == '\r\n' then
      empty_line = true
    else
      assert(false,line..'('..#line..')')
    end
  end
  return headers,request:match('\r\n\r\n(.*)')
end

local upgrade_request = function(req)
  local format = string.format
  local lines = {
    format('GET %s HTTP/1.1',req.uri or ''),
    format('Host: %s',req.host),
    'Upgrade: websocket',
    'Connection: Upgrade',
    format('Sec-WebSocket-Key: %s',req.key),
    format('Sec-WebSocket-Protocol: %s',table.concat(req.protocols,', ')),
    'Sec-WebSocket-Version: 13',
  }
  if req.origin then
    tinsert(lines,string.format('Origin: %s',req.origin))
  end
  if req.port and req.port ~= 80 then
    lines[2] = format('Host: %s:%d',req.host,req.port)
  end
  tinsert(lines,'\r\n')
  return table.concat(lines,'\r\n')
end

local accept_upgrade = function(request,protocols)
  local headers = http_headers(request)
  if headers['upgrade'] ~= 'websocket' or
  not headers['connection'] or
  not headers['connection']:match('upgrade') or
  headers['sec-websocket-key'] == nil or
  headers['sec-websocket-version'] ~= '13' then
    return nil,'HTTP/1.1 400 Bad Request\r\n\r\n'
  end
  local prot
  if headers['sec-websocket-protocol'] then
    for protocol in headers['sec-websocket-protocol']:gmatch('([^,%s]+)%s?,?') do
      for _,supported in ipairs(protocols) do
        if supported == protocol then
          prot = protocol
          break
        end
      end
      if prot then
        break
      end
    end
  end
  local lines = {
    'HTTP/1.1 101 Switching Protocols',
    'Upgrade: websocket',
    'Connection: '..headers['connection'],
    string.format('Sec-WebSocket-Accept: %s',sec_websocket_accept(headers['sec-websocket-key'])),
  }
  if prot then
    tinsert(lines,string.format('Sec-WebSocket-Protocol: %s',prot))
  end
  tinsert(lines,'\r\n')
  return table.concat(lines,'\r\n'),prot
end

return {
  sec_websocket_accept = sec_websocket_accept,
  http_headers = http_headers,
  accept_upgrade = accept_upgrade,
  upgrade_request = upgrade_request,
}
 end)
package.preload['websocket.tools'] = (function (...)
local bit = require'websocket.bit'
local mime = require'mime'
local rol = bit.rol
local bxor = bit.bxor
local bor = bit.bor
local band = bit.band
local bnot = bit.bnot
local lshift = bit.lshift
local rshift = bit.rshift
local sunpack = string.unpack
local srep = string.rep
local schar = string.char
local tremove = table.remove
local tinsert = table.insert
local tconcat = table.concat
local mrandom = math.random

local read_n_bytes = function(str, pos, n)
  pos = pos or 1
  return pos+n, string.byte(str, pos, pos + n - 1)
end

local read_int8 = function(str, pos)
  return read_n_bytes(str, pos, 1)
end

local read_int16 = function(str, pos)
  local new_pos,a,b = read_n_bytes(str, pos, 2)
  return new_pos, lshift(a, 8) + b
end

local read_int32 = function(str, pos)
  local new_pos,a,b,c,d = read_n_bytes(str, pos, 4)
  return new_pos,
  lshift(a, 24) +
  lshift(b, 16) +
  lshift(c, 8 ) +
  d
end

local pack_bytes = string.char

local write_int8 = pack_bytes

local write_int16 = function(v)
  return pack_bytes(rshift(v, 8), band(v, 0xFF))
end

local write_int32 = function(v)
  return pack_bytes(
    band(rshift(v, 24), 0xFF),
    band(rshift(v, 16), 0xFF),
    band(rshift(v,  8), 0xFF),
    band(v, 0xFF)
  )
end

-- used for generate key random ops
math.randomseed(os.time())

-- SHA1 hashing from luacrypto, if available
local sha1_crypto
local done,crypto = pcall(require,'crypto')
if done then
  sha1_crypto = function(msg)
    return crypto.digest('sha1',msg,true)
  end
end

-- from wiki article, not particularly clever impl
local sha1_wiki = function(msg)
  local h0 = 0x67452301
  local h1 = 0xEFCDAB89
  local h2 = 0x98BADCFE
  local h3 = 0x10325476
  local h4 = 0xC3D2E1F0

  local bits = #msg * 8
  -- append b10000000
  msg = msg..schar(0x80)

  -- 64 bit length will be appended
  local bytes = #msg + 8

  -- 512 bit append stuff
  local fill_bytes = 64 - (bytes % 64)
  if fill_bytes ~= 64 then
    msg = msg..srep(schar(0),fill_bytes)
  end

  -- append 64 big endian length
  local high = math.floor(bits/2^32)
  local low = bits - high*2^32
  msg = msg..write_int32(high)..write_int32(low)

  assert(#msg % 64 == 0,#msg % 64)

  for j=1,#msg,64 do
    local chunk = msg:sub(j,j+63)
    assert(#chunk==64,#chunk)
    local words = {}
    local next = 1
    local word
    repeat
      next,word = read_int32(chunk, next)
      tinsert(words, word)
    until next > 64
    assert(#words==16)
    for i=17,80 do
      words[i] = bxor(words[i-3],words[i-8],words[i-14],words[i-16])
      words[i] = rol(words[i],1)
    end
    local a = h0
    local b = h1
    local c = h2
    local d = h3
    local e = h4

    for i=1,80 do
      local k,f
      if i > 0 and i < 21 then
        f = bor(band(b,c),band(bnot(b),d))
        k = 0x5A827999
      elseif i > 20 and i < 41 then
        f = bxor(b,c,d)
        k = 0x6ED9EBA1
      elseif i > 40 and i < 61 then
        f = bor(band(b,c),band(b,d),band(c,d))
        k = 0x8F1BBCDC
      elseif i > 60 and i < 81 then
        f = bxor(b,c,d)
        k = 0xCA62C1D6
      end

      local temp = rol(a,5) + f + e + k + words[i]
      e = d
      d = c
      c = rol(b,30)
      b = a
      a = temp
    end

    h0 = h0 + a
    h1 = h1 + b
    h2 = h2 + c
    h3 = h3 + d
    h4 = h4 + e

  end

  -- necessary on sizeof(int) == 32 machines
  h0 = band(h0,0xffffffff)
  h1 = band(h1,0xffffffff)
  h2 = band(h2,0xffffffff)
  h3 = band(h3,0xffffffff)
  h4 = band(h4,0xffffffff)

  return write_int32(h0)..write_int32(h1)..write_int32(h2)..write_int32(h3)..write_int32(h4)
end

local base64_encode = function(data)
  return (mime.b64(data))
end

local DEFAULT_PORTS = {ws = 80, wss = 443}

local parse_url = function(url)
  local protocol, address, uri = url:match('^(%w+)://([^/]+)(.*)$')
  if not protocol then error('Invalid URL:'..url) end
  protocol = protocol:lower()
  local host, port = address:match("^(.+):(%d+)$")
  if not host then
    host = address
    port = DEFAULT_PORTS[protocol]
  end
  if not uri or uri == '' then uri = '/' end
  return protocol, host, tonumber(port), uri
end

local generate_key = function()
  local r1 = mrandom(0,0xfffffff)
  local r2 = mrandom(0,0xfffffff)
  local r3 = mrandom(0,0xfffffff)
  local r4 = mrandom(0,0xfffffff)
  local key = write_int32(r1)..write_int32(r2)..write_int32(r3)..write_int32(r4)
  assert(#key==16,#key)
  return base64_encode(key)
end

return {
  sha1 = sha1_crypto or sha1_wiki,
  base64 = {
    encode = base64_encode
  },
  parse_url = parse_url,
  generate_key = generate_key,
  read_int8 = read_int8,
  read_int16 = read_int16,
  read_int32 = read_int32,
  write_int8 = write_int8,
  write_int16 = write_int16,
  write_int32 = write_int32,
}
 end)
package.preload['websocket.frame'] = (function (...)
-- Following Websocket RFC: http://tools.ietf.org/html/rfc6455
local bit = require'websocket.bit'
local band = bit.band
local bxor = bit.bxor
local bor = bit.bor
local tremove = table.remove
local srep = string.rep
local ssub = string.sub
local sbyte = string.byte
local schar = string.char
local band = bit.band
local rshift = bit.rshift
local tinsert = table.insert
local tconcat = table.concat
local mmin = math.min
local mfloor = math.floor
local mrandom = math.random
local unpack = unpack or table.unpack
local tools = require'websocket.tools'
local write_int8 = tools.write_int8
local write_int16 = tools.write_int16
local write_int32 = tools.write_int32
local read_int8 = tools.read_int8
local read_int16 = tools.read_int16
local read_int32 = tools.read_int32

local bits = function(...)
  local n = 0
  for _,bitn in pairs{...} do
    n = n + 2^bitn
  end
  return n
end

local bit_7 = bits(7)
local bit_0_3 = bits(0,1,2,3)
local bit_0_6 = bits(0,1,2,3,4,5,6)

-- TODO: improve performance
local xor_mask = function(encoded,mask,payload)
  local transformed,transformed_arr = {},{}
  -- xor chunk-wise to prevent stack overflow.
  -- sbyte and schar multiple in/out values
  -- which require stack
  for p=1,payload,2000 do
    local last = mmin(p+1999,payload)
    local original = {sbyte(encoded,p,last)}
    for i=1,#original do
      local j = (i-1) % 4 + 1
      transformed[i] = bxor(original[i],mask[j])
    end
    local xored = schar(unpack(transformed,1,#original))
    tinsert(transformed_arr,xored)
  end
  return tconcat(transformed_arr)
end

local encode_header_small = function(header, payload)
  return schar(header, payload)
end

local encode_header_medium = function(header, payload, len)
  return schar(header, payload, band(rshift(len, 8), 0xFF), band(len, 0xFF))
end

local encode_header_big = function(header, payload, high, low)
  return schar(header, payload)..write_int32(high)..write_int32(low)
end

local encode = function(data,opcode,masked,fin)
  local header = opcode or 1-- TEXT is default opcode
  if fin == nil or fin == true then
    header = bor(header,bit_7)
  end
  local payload = 0
  if masked then
    payload = bor(payload,bit_7)
  end
  local len = #data
  local chunks = {}
  if len < 126 then
    payload = bor(payload,len)
    tinsert(chunks,encode_header_small(header,payload))
  elseif len <= 0xffff then
    payload = bor(payload,126)
    tinsert(chunks,encode_header_medium(header,payload,len))
  elseif len < 2^53 then
    local high = mfloor(len/2^32)
    local low = len - high*2^32
    payload = bor(payload,127)
    tinsert(chunks,encode_header_big(header,payload,high,low))
  end
  if not masked then
    tinsert(chunks,data)
  else
    local m1 = mrandom(0,0xff)
    local m2 = mrandom(0,0xff)
    local m3 = mrandom(0,0xff)
    local m4 = mrandom(0,0xff)
    local mask = {m1,m2,m3,m4}
    tinsert(chunks,write_int8(m1,m2,m3,m4))
    tinsert(chunks,xor_mask(data,mask,#data))
  end
  return tconcat(chunks)
end

local decode = function(encoded)
  local encoded_bak = encoded
  if #encoded < 2 then
    return nil,2-#encoded
  end
  local pos,header,payload
  pos,header = read_int8(encoded,1)
  pos,payload = read_int8(encoded,pos)
  local high,low
  encoded = ssub(encoded,pos)
  local bytes = 2
  local fin = band(header,bit_7) > 0
  local opcode = band(header,bit_0_3)
  local mask = band(payload,bit_7) > 0
  payload = band(payload,bit_0_6)
  if payload > 125 then
    if payload == 126 then
      if #encoded < 2 then
        return nil,2-#encoded
      end
      pos,payload = read_int16(encoded,1)
    elseif payload == 127 then
      if #encoded < 8 then
        return nil,8-#encoded
      end
      pos,high = read_int32(encoded,1)
      pos,low = read_int32(encoded,pos)
      payload = high*2^32 + low
      if payload < 0xffff or payload > 2^53 then
        assert(false,'INVALID PAYLOAD '..payload)
      end
    else
      assert(false,'INVALID PAYLOAD '..payload)
    end
    encoded = ssub(encoded,pos)
    bytes = bytes + pos - 1
  end
  local decoded
  if mask then
    local bytes_short = payload + 4 - #encoded
    if bytes_short > 0 then
      return nil,bytes_short
    end
    local m1,m2,m3,m4
    pos,m1 = read_int8(encoded,1)
    pos,m2 = read_int8(encoded,pos)
    pos,m3 = read_int8(encoded,pos)
    pos,m4 = read_int8(encoded,pos)
    encoded = ssub(encoded,pos)
    local mask = {
      m1,m2,m3,m4
    }
    decoded = xor_mask(encoded,mask,payload)
    bytes = bytes + 4 + payload
  else
    local bytes_short = payload - #encoded
    if bytes_short > 0 then
      return nil,bytes_short
    end
    if #encoded > payload then
      decoded = ssub(encoded,1,payload)
    else
      decoded = encoded
    end
    bytes = bytes + payload
  end
  return decoded,fin,opcode,encoded_bak:sub(bytes+1),mask
end

local encode_close = function(code,reason)
  if code then
    local data = write_int16(code)
    if reason then
      data = data..tostring(reason)
    end
    return data
  end
  return ''
end

local decode_close = function(data)
  local _,code,reason
  if data then
    if #data > 1 then
      _,code = read_int16(data,1)
    end
    if #data > 2 then
      reason = data:sub(3)
    end
  end
  return code,reason
end

return {
  encode = encode,
  decode = decode,
  encode_close = encode_close,
  decode_close = decode_close,
  encode_header_small = encode_header_small,
  encode_header_medium = encode_header_medium,
  encode_header_big = encode_header_big,
  CONTINUATION = 0,
  TEXT = 1,
  BINARY = 2,
  CLOSE = 8,
  PING = 9,
  PONG = 10
}
 end)
package.preload['websocket.bit'] = (function (...)
local has_bit32,bit = pcall(require,'bit32')
if has_bit32 then
  -- lua 5.2 / bit32 library
  bit.rol = bit.lrotate
  bit.ror = bit.rrotate
  return bit
else
  -- luajit / lua 5.1 + luabitop
  return require'bit'
end
 end)
local frame = require'websocket.frame'

return {
--  client = require'websocket.client',
  server = require'websocket.server',
  CONTINUATION = frame.CONTINUATION,
  TEXT = frame.TEXT,
  BINARY = frame.BINARY,
  CLOSE = frame.CLOSE,
  PING = frame.PING,
  PONG = frame.PONG
}
