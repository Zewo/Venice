import Venice
//: Coroutines
//: ----------
//:
//: A *coroutine* is a lightweight thread of execution.
func f(from: String) {
    for i in 0 ..< 4 {
        print("\(from): \(i)")
        yield
    }
}
//: Suppose we have a function call `f(s)`. Here's how we'd call
//: that in the usual way, running it synchronously.
f("direct")
//: To invoke this function in a coroutine, use `co(f(s))`. This new 
//: coroutine will execute concurrently with the calling one.
co(f("coroutine"))
//: You can also start a coroutine with a closure.
co {
    print("going")
}
//: Our two function calls are running asynchronously in separate 
//: coroutines now, so execution falls through to here. We wait 1 second 
//: before the program exits
nap(1 * second)
print("done")
//: When we run this program, we see the output of the blocking call 
//: first, then the interleaved output of the two coroutines. This 
//: interleaving reflects the coroutines being run concurrently by the
//: runtime.
//:
//: Next we’ll look at a complement to coroutines: channels.
//:
//: Next example: [Channels](@next)
