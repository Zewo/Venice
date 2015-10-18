import Venice
//: Channel Synchronization
//: -----------------------
//:
//: We can use channels to synchronize execution
//: across coroutines. Here's an example of using a
//: blocking receive to wait for a coroutine to finish.
//:
//: This is the function we'll run in a coroutine. The
//: `done` channel will be used to notify another
//: coroutine that this function's work is done.
func worker(done: Channel<Bool>) {
    print("working...")
    nap(1 * second)
    print("done")
    done <- true // Send a value to notify that we're done.
}
//: Start a worker coroutine, giving it the channel to
//: notify on.
let done = Channel<Bool>(bufferSize: 1)
co(worker(done))
//: Block until we receive a notification from the
//: worker on the channel.
<-done
//: If you removed the `<-done` line from this program, the program would
//: exit before the worker even started.
//:
//: Next example: [Channel Directions](@next)
