import SwiftGo
//: Stateful Goroutines
//: -------------------
//:
//: In this example our state will be owned by a single
//: goroutine. This will guarantee that the data is never
//: corrupted with concurrent access. In order to read or
//: write that state, other goroutines will send messages
//: to the owning goroutine and receive corresponding
//: replies. These `ReadOperation` and `WriteOperation` `struct`s
//: encapsulate those requests and a way for the owning
//: goroutine to respond.
struct ReadOperation {
    let key: Int
    let responses: Channel<Int>
}

struct WriteOperation {
    let key: Int
    let value: Int
    let responses: Channel<Bool>
}
//: We'll count how many operations we perform.
var operations = 0
//: The `reads` and `writes` channels will be used by
//: other goroutines to issue read and write requests,
//: respectively.
let reads = Channel<ReadOperation>()
let writes = Channel<WriteOperation>()
//: Here is the goroutine that owns the `state`, which
//: is a dictionary private
//: to the stateful goroutine. This goroutine repeatedly
//: selects on the `reads` and `writes` channels,
//: responding to requests as they arrive. A response
//: is executed by first performing the requested
//: operation and then sending a value on the response
//: channel `responses` to indicate success (and the desired
//: value in the case of `reads`).
go {
    var state: [Int: Int] = [:]
    while true {
        select { when in
            when.receiveFrom(reads) { read in
                read.responses <- state[read.key] ?? 0
            }
            when.receiveFrom(writes) { write in
                state[write.key] = write.value
                write.responses <- true
            }
        }
    }
}
//: This starts 100 goroutines to issue reads to the
//: state-owning goroutine via the `reads` channel.
//: Each read requires constructing a `ReadOperation`, sending
//: it over the `reads` channel, and then receiving the
//: result over the provided `responses` channel.
for _ in 0 ..< 100 {
    go {
        while true {
            let read = ReadOperation(
                key: Int(arc4random_uniform(5)),
                responses: Channel<Int>()
            )
            reads <- read
            <-read.responses
            operations++
        }
    }
}
//: We start 10 writes as well, using a similar
//: approach.
for _ in 0 ..< 10 {
    go {
        while true {
            let write = WriteOperation(
                key: Int(arc4random_uniform(5)),
                value: Int(arc4random_uniform(100)),
                responses: Channel<Bool>()
            )
            writes <- write
            <-write.responses
            operations++
        }
    }
}
//: Let the goroutines work for a second.
nap(now + 1 * second)
//: Finally, capture and report the `operations` count.
print("operations: \(operations)")
//:
//: Next example: [Chinese Whispers](@next)
