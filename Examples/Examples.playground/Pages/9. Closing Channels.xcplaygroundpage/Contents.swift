import SwiftGo
//: Closing Channels
//: ----------------
//:
//: _Closing_ a channel indicates that no more values
//: can be sent to it. This can be useful to communicate
//: completion to the channel's receivers.
//:
//: In this example we'll use a `jobs` channel to
//: communicate work to be done to a worker goroutine. When we have no more jobs for
//: the worker we'll `close` the `jobs` channel.
let jobs = Channel<Int>(bufferSize: 5)
let done = Channel<Bool>()
//: Here's the worker goroutine. It repeatedly receives
//: from `jobs` with `j = <-jobs`. The return value
//: will be `nil` if `jobs` has been `close`d and all
//: values in the channel have already been received.
//: We use this to notify on `done` when we've worked
//: all our jobs.
go {
    while true {
        if let j = <-jobs {
            print("received job \(j)")
        } else {
            print("received all jobs")
            done <- true
            return
        }
    }
}
//: This sends 3 jobs to the worker over the `jobs`
//: channel, then closes it.
for j in 1 ... 3 {
    print("sent job \(j)")
    jobs <- j
}

jobs.close()
print("sent all jobs")
//: We await the worker using the
//: [synchronization](4.%20Channel%20Synchronization) approach
//: we saw earlier.
<-done
//:
//: The idea of closed channels leads naturally to our next example: iterating over channels.
//:
//: Next example: [Iterating Over Channels](@next)
