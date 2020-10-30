import nativesockets
import net
import selectors
import tables
import posix

import ../../consts
import ../../general
import ../tcpsocket
import router
import json

export tcpsocket, router


const TAG = "socketrpc"

proc rpcMsgPackWriteHandler*(srv: TcpServerInfo[RpcRouter], result: ReadyKey, sourceClient: Socket, rt: RpcRouter) =
  raise newException(OSError, "the request to the OS failed")

proc rpcMsgPackReadHandler*(srv: TcpServerInfo[RpcRouter], result: ReadyKey, sourceClient: Socket, rt: RpcRouter) =

  try:
    logd(TAG, "rpc server handler: router: %x", rt.buffer)

    let msg = sourceClient.recv(rt.buffer, -1)

    if msg.len() == 0:
      raise newException(TcpClientDisconnected, "")
    else:
      var rcall = parseJson(msg)

      var res: JsonNode = rt.route( rcall )
      var rmsg: string = $res

      if res["result"].getStr() == "quit":
        raise newException(OSError, "quit")

      logd(TAG, "sending to client: %s", $(sourceClient.getFd().int))
      discard sourceClient.send(addr rmsg[0], rmsg.len)

  except TimeoutError:
    echo("control server: error: socket timeout: ", $sourceClient.getFd().int)


proc startRpcSocketServer*(port: Port; router: var RpcRouter) =
  logi(TAG, "starting json rpc server: buffer: %s", $router.buffer)

  startSocketServer[RpcRouter](
    port,
    readHandler=rpcMsgPackReadHandler,
    writeHandler=rpcMsgPackWriteHandler,
    data=router)



when isMainModule:

  const MaxRpcReceiveBuffer {.intdefine.}: int = 4096

  var rt = createRpcRouter(MaxRpcReceiveBuffer)

  rpc(rt, "hello") do(input: string) -> string:
    result = "Hello " & input

  rpc(rt, "add") do(a: int, b: int) -> int:
    result = a + b

  rpc(rt, "quit") do() -> string:
    return "quit"

  rpc(rt, "sum") do(args: seq[int]) -> int:
    result = 0
    for v in args:
      result += v

  try:
    startRpcSocketServer(Port(5555), rt)
  except:
    logi(TAG, "exiting")

