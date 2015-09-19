import SwiftGo
//: Channel Synchronization
//: -----------------------
//:
//: We can use channels to synchronize execution
//: across goroutines. Here's an example of using a
//: blocking receive to wait for a goroutine to finish.
//:
//: This is the function we'll run in a goroutine. The
//: `done` channel will be used to notify another
//: goroutine that this function's work is done.
func worker(done: Channel<Bool>) {
    print("working...")
    nap(now + 1 * second)
    print("done")
    done <- true // Send a value to notify that we're done.
}
//: Start a worker goroutine, giving it the channel to
//: notify on.
let done = Channel<Bool>(bufferSize: 1)
go(worker(done))
//: Block until we receive a notification from the
//: worker on the channel.
<-done
//: If you removed the `<-done` line from this program, the program would
//: exit before the worker even started.
//:
//: Next example: [Channel Directions](@next)
