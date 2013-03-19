class Binary
  @UInt8: -> {
    unpack: (buffer) -> [buffer.readUInt8(@byte_offset), @byte_offset + 1]
    pack: (buffer, value) -> buffer.writeUInt8(value, @byte_offset); [@byte_offset + 1]
  }
  @UInt16: -> {
    unpack: (buffer) -> [buffer['readUInt16' + @default_byte_order.toUpperCase()](@byte_offset), @byte_offset + 2]
    pack: (buffer, value) -> buffer['writeUInt16' + @default_byte_order.toUpperCase()](value, @byte_offset); [@byte_offset + 2]
  }
  @UInt16BE: -> {
    unpack: (buffer) -> [buffer.readUInt16BE(@byte_offset), @byte_offset + 2]
    pack: (buffer, value) -> buffer.writeUInt16BE(value, @byte_offset); [@byte_offset + 2]
  }
  @UInt16LE: -> {
    unpack: (buffer) -> [buffer.readUInt16LE(@byte_offset), @byte_offset + 2]
    pack: (buffer, value) -> buffer.writeUInt16LE(value, @byte_offset); [@byte_offset + 2]
  }
  @UInt32: -> {
    unpack: (buffer) -> [buffer['readUInt32' + @default_byte_order.toUpperCase()](@byte_offset), @byte_offset + 4]
    pack: (buffer, value) -> buffer['writeUInt32' + @default_byte_order.toUpperCase()](value, @byte_offset); [@byte_offset + 4]
  }
  @UInt32BE: -> {
    unpack: (buffer) -> [buffer.readUInt32BE(@byte_offset), @byte_offset + 4]
    pack: (buffer, value) -> buffer.writeUInt32BE(value, @byte_offset); [@byte_offset + 4]
  }
  @UInt32LE: -> {
    unpack: (buffer) -> [buffer.readUInt32LE(@byte_offset), @byte_offset + 4]
    pack: (buffer, value) -> buffer.writeUInt32LE(value, @byte_offset); [@byte_offset + 4]
  }
  
  @Bits: (num) -> {
    unpack: (buffer) ->
      byte = buffer.readUInt8(@byte_offset)
      s = 7 - (@bit_offset + num - 1)
      byte = byte >>> s
      [byte & ~(0xff << num), @byte_offset, @bit_offset + num]
    pack: (buffer, value) ->
      byte = buffer.readUInt8(@byte_offset)
      byte = byte | (value << (7 - @bit_offset))
      buffer.writeUInt8(byte, @byte_offset)
      [@byte_offset, @bit_offset + num]
  }
  
  @String: (encoding = 'ascii') -> {
    unpack: (buffer) ->
      o = @byte_offset
      ++o while buffer[o] isnt 0
      [buffer.slice(@byte_offset, o).toString(encoding), o + 1]
    pack: (buffer, value) ->
        new Buffer(value, 'ascii').copy(buffer, @byte_offset, 0, value.length)
        buffer.writeUInt8(0, @byte_offset + value.length)
        [@byte_offset + value.length + 1]
  }
  
  constructor: (@fields) ->
    @default_byte_order = 'BE'
  
  unpack: (buffer) ->
    new Unpacker(fields: @fields, default_byte_order: @default_byte_order).unpack(buffer)
  
  pack: (data) ->
    new Packer(fields: @fields, default_byte_order: @default_byte_order).pack(data)


class Unpacker
  constructor: (b) ->
    @[k] = v for k, v of b
    @bit_offset = @byte_offset = 0

  unpack: (buffer) ->
    unpacked = {}

    offset = 0
    for name, field of @fields
      if field.unpack and typeof field.unpack is 'function'
        [unpacked[name], @byte_offset, bit_offset] = field.unpack.call(@, buffer)
        if bit_offset?
          @byte_offset += parseInt(bit_offset / 8)
          @bit_offset = bit_offset % 8
      else
        struct = new Binary(field)
        sub_unpackr = new Unpacker(fields: struct.fields, default_byte_order: struct.default_byte_order)
        sub_unpackr.bit_offset = @bit_offset
        sub_unpackr.byte_offset = @byte_offset
        sub_unpackr.default_byte_order = @default_byte_order
        unpacked[name] = sub_unpackr.unpack(buffer)
        @bit_offset = sub_unpackr.bit_offset
        @byte_offset = sub_unpackr.byte_offset

    unpacked


class Packer
  constructor: (b) ->
    @[k] = v for k, v of b
    @bit_offset = @byte_offset = 0
  
  pack: (data, use_this_buffer) ->
    buffer = use_this_buffer or new Buffer(1024)
    buffer.fill(0) unless use_this_buffer?
    
    for name, field of @fields
      if field.pack and typeof field.pack is 'function'
        [@byte_offset, bit_offset] = field.pack.call(@, buffer, data[name])
        if bit_offset?
          @byte_offset += parseInt(bit_offset / 8) if bit_offset >= 8
          @bit_offset = bit_offset % 8
      else
        struct = new Binary(field)
        sub_packer = new Packer(fields: struct.fields, default_byte_order: struct.default_byte_order)
        sub_packer.bit_offset = @bit_offset
        sub_packer.byte_offset = @byte_offset
        sub_packer.default_byte_order = @default_byte_order
        sub_buffer = sub_packer.pack(data[name], buffer)
        @bit_offset = sub_packer.bit_offset
        @byte_offset = sub_packer.byte_offset
    
    buffer.slice(0, @byte_offset) unless use_this_buffer?


binary = (fields) ->
  new Binary(fields)

binary.__defineGetter__ 'uint8', -> Binary.UInt8()
binary.__defineGetter__ 'uint16', -> Binary.UInt16()
binary.__defineGetter__ 'uint16be', -> Binary.UInt16BE()
binary.__defineGetter__ 'uint16le', -> Binary.UInt16LE()
binary.__defineGetter__ 'uint16n', -> Binary.UInt16BE()
binary.__defineGetter__ 'uint32', -> Binary.UInt32()
binary.__defineGetter__ 'uint32be', -> Binary.UInt32BE()
binary.__defineGetter__ 'uint32le', -> Binary.UInt32LE()
binary.__defineGetter__ 'uint32n', -> Binary.UInt32BE()
binary.__defineGetter__ 'string', -> Binary.String()
binary.bits = Binary.Bits

module.exports = binary
