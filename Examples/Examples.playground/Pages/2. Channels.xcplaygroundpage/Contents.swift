import SwiftGo
//: Channels
//: --------
//:
//: *Channels* are the pipes that connect concurrent
//: goroutines. You can send values into channels from one
//: goroutine and receive those values into another
//: goroutine.
//:
//: Create a new channel with `Channel<Type>()`.
//: Channels are typed by the values they convey.
let messages = Channel<String>()
//: _Send_ a value into a channel using the `channel <- value`
//: syntax. Here we send `"ping"`  to the `messages`
//: channel we made above, from a new goroutine.
go(messages <- "ping")
//: The `<-channel` syntax _receives_ a value from the
//: channel. Here we'll receive the `"ping"` message
//: we sent above and print it out.
let message = <-messages
print(message!)
//: When we run the program the "ping" message is successfully passed from 
//: one goroutine to another via our channel.
//:
//: By default sends and receives block until both the sender and receiver 
//: are ready. This property allowed us to wait at the end of our program 
//: for the "ping" message without having to use any other 
//: synchronization.
//:
//: Values received from channels are `Optional`s. If you try to get a value 
//: from a closed channel with no values left in the buffer, it'll return 
//: `nil`.
//:
//: Next example: [Channel Buffering](@next)
