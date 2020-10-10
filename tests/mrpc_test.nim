import json, tables, strutils, macros, options
import net, os
import times

import nesper/servers/rpc/router
import msgpack4nim
import msgpack4nim/msgpack2json

import parseopt

# var p = initOptParser("-ab -e:5 --foo --bar=20 file.txt")
var p = initOptParser()

var count = 1
var jsonArg = ""
var ipAddr = ""
var port = Port(5555)

for kind, key, val in p.getopt():
  case kind
  of cmdArgument:
    jsonArg = key
  of cmdLongOption, cmdShortOption:
    case key
    of "count", "c":
      count = parseInt(val)
    of "ip", "i":
      ipAddr = val
    of "port", "p":
      port = Port(parseInt(val))
  of cmdEnd: assert(false) # cannot happen

if ipAddr == "":
  # no filename has been given, so we show the help
  raise newException(ValueError, "missing ip address")
  
var totalTime = 0'i64
var totalCalls = 0'i64

template timeBlock(n: string, blk: untyped): untyped =
  let t0 = getTime()
  blk

  let td = getTime() - t0
  echo "[took: ", $(td.inMilliseconds()), " millis]"
  totalCalls.inc()
  totalTime = totalTime + td.inMilliseconds()

var callDefault = %* { "jsonrpc": "2.0", "id": 1, "method": "add", "params": [1, 2] }

var call: JsonNode

if jsonArg == "":
  call = callDefault
else:
  call = parseJson(jsonArg)

let client: Socket = newSocket(buffered=false)
client.connect(ipAddr, Port(5555))
echo("[connected to server]")

let mcall = call.fromJsonNode()

for i in 0..<count:

  timeBlock("call"):
    client.send( mcall )
    var msg = client.recv(4095, timeout = -1)

  echo("[read bytes: " & $msg.len() & "]")
  echo($(msg.toJsonNode()))


client.close()

echo("\n")
echo("[total time: " & $(totalTime) & " millis]")
echo("[avg time: " & $(float(totalTime)/(1.0 * float(totalCalls))) & " millis]")
