import SwiftGo
//: Channel Directions
//: ------------------
//:
//: When using channels as function parameters, you can
//: specify if a channel is meant to only send or receive
//: values. This specificity increases the type-safety of
//: the program.
//:
//: This `ping` function only accepts a channel that receives
//: values. It would be a compile-time error to try to
//: receive values from this channel.
func ping(pings: ReceivingChannel<String>, message: String) {
    pings <- message
}
//: The `pong` function accepts one channel that only sends values
//: (`pings`) and a second that only receives values (`pongs`).
func pong(pings: SendingChannel<String>, _ pongs: ReceivingChannel<String>) {
    let message = !<-pings
    pongs <- message
}

let pings = Channel<String>(bufferSize: 1)
let pongs = Channel<String>(bufferSize: 1)

ping(pings.receivingChannel, message: "passed message")
pong(pings.sendingChannel, pongs.receivingChannel)

print(!<-pongs)
//:
//: Next example: [Select](@next)
