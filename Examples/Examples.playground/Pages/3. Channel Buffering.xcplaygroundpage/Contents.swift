import SwiftGo
//: Channel Buffering
//: -----------------
//:
//: By default channels are *unbuffered*, meaning that they
//: will only accept receiving values (`channel <-`) if there is a
//: corresponding receive (`<- channel`) ready to receive the
//: value sent by the channel. _Buffered channels_ accept a limited
//: number of  values without a corresponding receiver for
//: those values.
//:
//: Here we make a channel of strings buffering up to
//: 2 values.
let messages = Channel<String>(bufferSize: 2)
//: Because this channel is buffered, we can send these
//: values into the channel without a corresponding
//: concurrent receive.
messages <- "buffered"
messages <- "channel"
//: Later we can receive these two values as usual.
print(!<-messages)
print(!<-messages)
//:
//: Next example: [Channel Synchronization](@next)
