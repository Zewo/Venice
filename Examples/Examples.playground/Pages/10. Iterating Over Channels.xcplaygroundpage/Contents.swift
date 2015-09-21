import SwiftGo
//: Iterating Over Channels
//: -----------------------
//:
//: We can use `for in` to iterate over
//: values received from a channel.
//: We'll iterate over 2 values in the `queue` channel.
let queue =  Channel<String>(bufferSize: 2)

queue <- "one"
queue <- "two"
queue.close()
//: This `for in` loop iterates over each element as it's
//: received from `queue`. Because we `close`d the
//: channel above, the iteration terminates after
//: receiving the 2 elements. If we didn't `close` it
//: we'd block on a 3rd receive in the loop.
for element in queue {
    print(element)
}
//: This example also showed that it’s possible to close a non-empty channel but still have the 
//: remaining values be received.
//:
//: Next example: [Timers](@next)
