import SwiftGo
//: Goroutines
//: ----------
//:
//: A *goroutine* is a lightweight thread of execution.
func f(from: String) {
    for i in 0 ..< 4 {
        print("\(from): \(i)")
        yield
    }
}
//: Suppose we have a function call `f(s)`. Here's how we'd call
//: that in the usual way, running it synchronously.
f("direct")
//: To invoke this function in a goroutine, use `go(f(s))`. This new 
//: goroutine will execute concurrently with the calling one.
go(f("goroutine"))
//: You can also start a goroutine with a closure.
go {
    print("going")
}
//: Our two function calls are running asynchronously in separate 
//: goroutines now, so execution falls through to here. We wait 1 second 
//: before the program exits
nap(now + 1 * second)
print("done")
//: When we run this program, we see the output of the blocking call 
//: first, then the interleaved output of the two gouroutines. This 
//: interleaving reflects the goroutines being run concurrently by the
//: runtime.
//:
//: Next we’ll look at a complement to goroutines: channels.
//:
//: Next example: [Channels](@next)
