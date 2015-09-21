import SwiftGo
//: Select
//: ------
//:
//: _Select_ lets you wait on multiple channel
//: operations. Combining goroutines and channels with
//: select is an extremely powerful feature.
//:
//: For our example we'll select across two channels.
let channel1 = Channel<String>()
let channel2 = Channel<String>()
//: Each channel will receive a value after some amount
//: of time, to simulate e.g. blocking RPC operations
//: executing in concurrent goroutines.
go {
    nap(1 * second)
    channel1 <- "one"
}

go {
    nap(2 * second)
    channel2 <- "two"
}
//: We'll use `select` to await both of these values
//: simultaneously, printing each one as it arrives.
for _ in 0 ..< 2 {
    select { when in
        when.receiveFrom(channel1) { message1 in
            print("received \(message1)")
        }
        when.receiveFrom(channel2) { message2 in
            print("received \(message2)")
        }
    }
}
//: We receive the values "one" and then "two" as expected.
//: Note that the total execution time is only ~2 seconds since
//: both the 1 and 2 second `nap`s execute concurrently.
//:
//: Next example: [Timeouts](@next)
