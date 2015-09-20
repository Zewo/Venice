SwiftGo
=======

[![Carthage compatible](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat)](https://github.com/Carthage/Carthage)
[![Swift 2](https://img.shields.io/badge/Swift-2.0-orange.svg)](https://developer.apple.com/swift/)

**SwiftGo** is a pure Swift/C library that allows you to use *Go*'s concurrency features in **Swift 2**.

## Features

- [x] No `Foundation` depency (**Linux ready**)
- [x] Goroutines
- [x] Channels
- [x] Select
- [x] Timer
- [x] Ticker

**SwiftGo** wraps a modified version of the C library [libmill](https://github.com/sustrik/libmill).

## Installation

### Carthage

[Carthage](https://github.com/Carthage/Carthage) is a decentralized dependency manager that automates the process of adding frameworks to your Cocoa application.

You can install Carthage with [Homebrew](http://brew.sh/) using the following command:

```bash
$ brew update
$ brew install carthage
```

To integrate **SwiftGo** into your Xcode project using Carthage, specify it in your `Cartfile`:

```ogdl
github "Zewo/SwiftGo" ~> 0.1
```

### Manually

If you prefer not to use a dependency manager, you can integrate **SwiftGo** into your project manually.

#### Embedded Framework

- Open up Terminal, `cd` into your top-level project directory, and run the following command "if" your project is not initialized as a git repository:

```bash
$ git init
```

- Add **SwiftGo** as a git [submodule](http://git-scm.com/docs/git-submodule) by running the following command:

```bash
$ git submodule add https://github.com/Zewo/SwiftGo.git
```

- Open the new `SwiftGo` folder, and drag the `SwiftGo.xcodeproj` into the Project Navigator of your application's Xcode project.

    > It should appear nested underneath your application's blue project icon. Whether it is above or below all the other Xcode groups does not matter.

- Select the `SwiftGo.xcodeproj` in the Project Navigator and verify the deployment target matches that of your application target.
- Next, select your application project in the Project Navigator (blue project icon) to navigate to the target configuration window and select the application target under the "Targets" heading in the sidebar.
- In the tab bar at the top of that window, open the "General" panel.
- Click on the `+` button under the "Embedded Binaries" section.
- You will see two different `SwiftGo.xcodeproj` folders each with two different versions of the `SwiftGo.framework` nested inside a `Products` folder.

    > It does not matter which `Products` folder you choose from, but it does matter whether you choose the top or bottom `SwiftGo.framework`. 
    
- Select the top `SwiftGo.framework` for OS X and the bottom one for iOS.

    > You can verify which one you selected by inspecting the build log for your project. The build target for `SwiftGo` will be listed as either `SwiftGo iOS` or `SwiftGo OSX`.

- And that's it!

> The `SwiftGo.framework` is automagically added as a target dependency, linked framework and embedded framework in a copy files build phase which is all you need to build on the simulator and a device.

---

Examples
========

The examples were taken from [gobyexample](http://gobyexample.com) and translated from Go to Swift using **SwiftGo**. The Xcode project contains a playground with all the examples below. Compile the framework at least once and then you're free to play with the playground examples.

Goroutines
----------

A *goroutine* is a lightweight thread of execution.

```swift
func f(from: String) {
    for i in 0 ..< 4 {
        print("\(from): \(i)")
        yield
    }
}
```

Suppose we have a function call `f(s)`. Here's how we'd call
that in the usual way, running it synchronously.

```
f("direct")
```

To invoke this function in a goroutine, use `go(f(s))`. This new 
goroutine will execute concurrently with the calling one.

```
go(f("goroutine"))
```

You can also start a goroutine with a closure.

```
go {
    print("going")
}
```

Our two function calls are running asynchronously in separate 
goroutines now, so execution falls through to here. We wait 1 second 
before the program exits

```swift
nap(now + 1 * second)
print("done")
```

When we run this program, we see the output of the blocking call 
first, then the interleaved output of the two gouroutines. This 
interleaving reflects the goroutines being run concurrently by the
runtime.

###Output

```
direct: 0
direct: 1
direct: 2
direct: 3
goroutine: 0
going
goroutine: 1
goroutine: 2
goroutine: 3
done
```

Channels
--------

*Channels* are the pipes that connect concurrent
goroutines. You can send values into channels from one
goroutine and receive those values into another
goroutine.

Create a new channel with `Channel<Type>()`.
Channels are typed by the values they convey.

```swift
let messages = Channel<String>()
```

_Send_ a value into a channel using the `channel <- value`
syntax. Here we send `"ping"`  to the `messages`
channel we made above, from a new goroutine.

```swift
go(messages <- "ping")
```

The `<-channel` syntax _receives_ a value from the
channel. Here we'll receive the `"ping"` message
we sent above and print it out.

```swift
let message = <-messages
print(message!)
```

When we run the program the "ping" message is successfully passed from 
one goroutine to another via our channel. By default sends and receives block until both the sender and receiver are ready. This property allowed us to wait at the end of our program for the "ping" message without having to use any other synchronization.

Values received from channels are `Optional`s. If you try to get a value from a closed channel with no values left in the buffer, it'll return `nil`.

###Output

```
ping
```

Channel Buffering
-----------------

By default channels are *unbuffered*, meaning that they
will only accept receiving values (`channel <- value`) if there is a
corresponding receive (`let value = <-channel`) ready to receive the
value sent by the channel. _Buffered channels_ accept a limited
number of  values without a corresponding receiver for
those values.

Here we make a channel of strings buffering up to
2 values.

```swift
let messages = Channel<String>(bufferSize: 2)
```

Because this channel is buffered, we can send these
values into the channel without a corresponding
concurrent receive.

```swift
messages <- "buffered"
messages <- "channel"
```

Later we can receive these two values as usual.

```swift
print((<-messages)!)
print((<-messages)!)
```

###Output

```
buffered
channel
```

Channel Synchronization
-----------------------

We can use channels to synchronize execution
across goroutines. Here's an example of using a
blocking receive to wait for a goroutine to finish.

This is the function we'll run in a goroutine. The
`done` channel will be used to notify another
goroutine that this function's work is done.

```swift
func worker(done: Channel<Bool>) {
    print("working...")
    nap(now + 1 * second)
    print("done")
    done <- true // Send a value to notify that we're done.
}
```

Start a worker goroutine, giving it the channel to
notify on.

```swift
let done = Channel<Bool>(bufferSize: 1)
go(worker(done))
```

Block until we receive a notification from the
worker on the channel.

```swift
<-done
```

If you removed the `<-done` line from this program, the program would
exit before the worker even started.

###Output

```
working...
done
```

Channel Directions
------------------

When using channels as function parameters, you can
specify if a channel is meant to only send or receive
values. This specificity increases the type-safety of
the program.

This `ping` function only accepts a channel that receives
values. It would be a compile-time error to try to
receive values from this channel.

```swift
func ping(pings: ReceivingChannel<String>, message: String) {
    pings <- message
}
```

The `pong` function accepts one channel that only sends values
(`pings`) and a second that only receives values (`pongs`).

```swift
func pong(pings: SendingChannel<String>, _ pongs: ReceivingChannel<String>) {
    let message = <-pings
    pongs <- message!
}

let pings = Channel<String>(bufferSize: 1)
let pongs = Channel<String>(bufferSize: 1)

ping(pings.receivingChannel, message: "passed message")
pong(pings.sendingChannel, pongs.receivingChannel)

print((<-pongs)!)
```

###Output

```
passed message
```

Select
------

_Select_ lets you wait on multiple channel
operations. Combining goroutines and channels with
select is an extremely powerful feature.

For our example we'll select across two channels.

```swift
let channel1 = Channel<String>()
let channel2 = Channel<String>()
```

Each channel will receive a value after some amount
of time, to simulate e.g. blocking RPC operations
executing in concurrent goroutines.

```swift
go {
    nap(now + 1 * second)
    channel1 <- "one"
}

go {
    nap(now + 2 * second)
    channel2 <- "two"
}
```

We'll use `select` to await both of these values
simultaneously, printing each one as it arrives.

```swift
for _ in 0 ..< 2 {
    select { when in
        when.receiveFrom(channel1) { msg1 in
            print("received \(msg1)")
        }
        when.receiveFrom(channel2) { msg2 in
            print("received \(msg2)")
        }
    }
}
```

We receive the values `"one"` and then `"two"` as expected.
Note that the total execution time is only ~2 seconds since
both the 1 and 2 second `nap`s execute concurrently.

###Output

```
received one
received two
```

Timeouts
--------

_Timeouts_ are important for programs that connect to
external resources or that otherwise need to bound
execution time. Implementing timeouts is easy and
elegant thanks to channels and `select`.

For our example, suppose we're executing an external
call that returns its result on a channel `channel1`
after 2s.

```swift
let channel1 = Channel<String>(bufferSize: 1)

go {
    nap(now + 2 * second)
    channel1 <- "result 1"
}
```

Here's the `select` implementing a timeout.
`receiveFrom(channel1)` awaits the result and `timeout(now + 1 * second)`
awaits a value to be sent after the timeout of
1s. Since `select` proceeds with the first
receive that's ready, we'll take the timeout case
if the operation takes more than the allowed 1s.

```swift
select { when in
    when.receiveFrom(channel1) { result in
        print(result)
    }
    when.timeout(now + 1 * second) {
        print("timeout 1")
    }
}
```

If we allow a longer timeout of 3s, then the receive
from `channel2` will succeed and we'll print the result.

```swift
let channel2 = Channel<String>(bufferSize: 1)

go {
    nap(now + 2 * second)
    channel2 <- "result 2"
}

select { when in
    when.receiveFrom(channel2) { result in
        print(result)
    }
    when.timeout(now + 3 * second) {
        print("timeout 2")
    }
}
```

Running this program shows the first operation timing out and the second succeeding.

Using this select timeout pattern requires communicating results over channels. This is a 
good idea in general because other important features are based on channels and select. 
We’ll look at two examples of this next: timers and tickers.

###Output

```
timeout 1
result 2
```

Non-Blocking Channel Operations
-------------------------------

Basic sends and receives on channels are blocking.
However, we can use `select` with a `otherwise` clause to
implement _non-blocking_ sends, receives, and even
non-blocking multi-way `select`s.

```swift
let messages = Channel<String>()
let signals = Channel<Bool>()
```

Here's a non-blocking receive. If a value is
available on `messages` then `select` will take
the `receiveFrom(messages)` case with that value. If not
it will immediately take the `otherwise` case.

```swift
select { when in
    when.receiveFrom(messages) { msg in
        print("received message \(msg)")
    }
    when.otherwise {
        print("no message received")
    }
}
```

A non-blocking send works similarly.

```swift
let msg = "hi"

select { when in
    when.sendValue(msg, to: messages) {
        print("sent message \(msg)")
    }
    when.otherwise {
        print("no message sent")
    }
}
```

We can use multiple cases above the `otherwise`
clause to implement a multi-way non-blocking
select. Here we attempt non-blocking receives
on both `messages` and `signals`.

```swift
select { when in
    when.receiveFrom(messages) { msg in
        print("receive message \(msg)")
    }
    when.receiveFrom(signals) { sig in
        print("received signal \(sig)")
    }
    when.otherwise {
        print("no activity")
    }
}
```

###Output

```
no message received
no message sent
no activity
```

Closing Channels
----------------

_Closing_ a channel indicates that no more values
can be sent to it. This can be useful to communicate
completion to the channel's receivers.

In this example we'll use a `jobs` channel to
communicate work to be done to a worker goroutine. When we have no more jobs for
the worker we'll `close` the `jobs` channel.

```swift
let jobs = Channel<Int>(bufferSize: 5)
let done = Channel<Bool>()
```

Here's the worker goroutine. It repeatedly receives
from `jobs` with `j = <-jobs`. The return value
will be `nil` if `jobs` has been `close`d and all
values in the channel have already been received.
We use this to notify on `done` when we've worked
all our jobs.

```swift
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
```

This sends 3 jobs to the worker over the `jobs`
channel, then closes it.

```swift
for j in 1 ... 3 {
    print("sent job \(j)")
    jobs <- j
}

jobs.close()
print("sent all jobs")
```

We await the worker using the synchronization approach
we saw earlier.

```swift
<-done
```

The idea of closed channels leads naturally to our next example: iterating over channels.

###Output

```
sent job 1
received job 1
sent job 2
received job 2
sent job 3
received job 3
sent all jobs
received job 3
received all jobs
```

Iterating Over Channels
-----------------------

We can use `for in` to iterate over
values received from a channel.
We'll iterate over 2 values in the `queue` channel.

```swift
let queue =  Channel<String>(bufferSize: 2)

queue <- "one"
queue <- "two"
queue.close()
```

This `for in` loop iterates over each element as it's
received from `queue`. Because we `close`d the
channel above, the iteration terminates after
receiving the 2 elements. If we didn't `close` it
we'd block on a 3rd receive in the loop.

```swift
for elem in queue {
    print(elem)
}
```

This example also showed that it’s possible to close a non-empty channel but still have the 
remaining values be received.

###Output

```
one
two
```

Timers
------

We often want to execute code at some point in the
future, or repeatedly at some interval. _Timer_ and
_ticker_ features make both of these tasks
easy. We'll look first at timers and then
at tickers.

Timers represent a single event in the future. You
tell the timer how long you want to wait, and it
provides a channel that will be notified at that
time. This timer will wait 2 seconds.

```swift
let timer1 = Timer(deadline: now + 2 * second)
```

The `<-timer1.channel` blocks on the timer's channel
until it sends a value indicating that the timer
expired.

```swift
<-timer1.channel
print("Timer 1 expired")
```

If you just wanted to wait, you could have used
`nap`. One reason a timer may be useful is
that you can cancel the timer before it expires.
Here's an example of that.

```swift
let timer2 = Timer(deadline: now + 1 * second)

go {
    <-timer2.channel
    print("Timer 2 expired")
}

let stop2 = timer2.stop()

if stop2 {
    print("Timer 2 stopped")
}
```

The first timer will expire ~2s after we start the program, but the second should be stopped 
before it has a chance to expire.

###Output

```
Timer 1 expired
Timer 2 stopped
```

Tickers
-------

Timers are for when you want to do
something once in the future - _tickers_ are for when
you want to do something repeatedly at regular
intervals. Here's an example of a ticker that ticks
periodically until we stop it.

Tickers use a similar mechanism to timers: a
channel that is sent values. Here we'll use the
`generator` builtin on the channel to iterate over
the values as they arrive every 500ms.

```swift
let ticker = Ticker(period: 500)

go {
    for t in ticker.channel {
        print("Tick at \(t)")
    }
}
```

Tickers can be stopped like timers. Once a ticker
is stopped it won't receive any more values on its
channel. We'll stop ours after 1600ms.

```swift
nap(now + 1600)
ticker.stop()
print("Ticker stopped")
```

When we run this program the ticker should tick 3 times before we stop it.

###Output

```
Tick at 37024098
Tick at 37024599
Tick at 37025105
Ticker stopped
```

Worker Pools
------------

In this example we'll look at how to implement
a _worker pool_ using goroutines and channels.

Here's the worker, of which we'll run several
concurrent instances. These workers will receive
work on the `jobs` channel and send the corresponding
results on `results`. We'll sleep a second per job to
simulate an expensive task.

```swift
func worker(id: Int, jobs: Channel<Int>, results: Channel<Int>) {
    for j in jobs {
        print("worker \(id) processing job \(j)")
        nap(now + 1 * second)
        results <- j * 2
    }
}
```

In order to use our pool of workers we need to send
them work and collect their results. We make 2
channels for this.

```swift
let jobs = Channel<Int>(bufferSize: 100)
let results = Channel<Int>(bufferSize: 100)
```

This starts up 3 workers, initially blocked
because there are no jobs yet.

```swift
for w in 1 ... 3 {
    go(worker(w, jobs: jobs, results: results))
}
```

Here we send 9 `jobs` and then `close` that
channel to indicate that's all the work we have.

```swift
for j in 1 ... 9 {
    jobs <- j
}

jobs.close()
```

Finally we collect all the results of the work.

```swift
for _ in 1 ... 9 {
    <-results
}
```

Our running program shows the 9 jobs being executed by various workers. The program only 
takes about 3 seconds despite doing about 9 seconds of total work because there are 3 
workers operating concurrently.

###Output

```
worker 1 processing job 1
worker 2 processing job 2
worker 3 processing job 3
worker 1 processing job 4
worker 2 processing job 5
worker 3 processing job 6
worker 1 processing job 7
worker 2 processing job 8
worker 3 processing job 9
```

Rate Limiting
-------------

_[Rate limiting](http://en.wikipedia.org/wiki/Rate_limiting)_
is an important mechanism for controlling resource
utilization and maintaining quality of service. SwiftGo
elegantly supports rate limiting with goroutines,
channels, and tickers.

First we'll look at basic rate limiting. Suppose
we want to limit our handling of incoming requests.
We'll serve these requests off a channel of the
same name.

```swift
var requests = Channel<Int>(bufferSize: 5)

for i in 1 ... 5 {
    requests <- i
}

requests.close()
```

This `limiter` channel will receive a value
every 200 milliseconds. This is the regulator in
our rate limiting scheme.

```swift
let limiter = Ticker(period: 200 * millisecond)
```

By blocking on a receive from the `limiter` channel
before serving each request, we limit ourselves to
1 request every 200 milliseconds.

```swift
for request in requests {
    <-limiter.channel
    print("request \(request) \(now)")
}

print("")
```

We may want to allow short bursts of requests in
our rate limiting scheme while preserving the
overall rate limit. We can accomplish this by
buffering our limiter channel. This `burstyLimiter`
channel will allow bursts of up to 3 events.

```swift
let burstyLimiter = Channel<Int>(bufferSize: 3)
```

Fill up the channel to represent allowed bursting.

```swift
for _ in 0 ..< 3 {
    burstyLimiter <- now
}
```

Every 200 milliseconds we'll try to add a new
value to `burstyLimiter`, up to its limit of 3.

```swift
go {
    for t in Ticker(period: 200).channel {
        burstyLimiter <- t
    }
}
```

Now simulate 5 more incoming requests. The first
3 of these will benefit from the burst capability
of `burstyLimiter`.

```swift
let burstyRequests = Channel<Int>(bufferSize: 5)

for i in 1 ... 5 {
    burstyRequests <- i
}

burstyRequests.close()

for request in burstyRequests {
    <-burstyLimiter
    print("request \(request) \(now)")
}
```

Running our program we see the first batch of requests handled once every ~200 milliseconds 
as desired.

For the second batch of requests we serve the first 3 immediately because of the burstable 
rate limiting, then serve the remaining 2 with ~200ms delays each.

###Output

```
request 1 37221046
request 2 37221251
request 3 37221453
request 4 37221658
request 5 37221860

request 1 37221863
request 2 37221864
request 3 37221865
request 4 37222064
request 5 37222265
```

Stateful Goroutines
-------------------

In this example our state will be owned by a single
goroutine. This will guarantee that the data is never
corrupted with concurrent access. In order to read or
write that state, other goroutines will send messages
to the owning goroutine and receive corresponding
replies. These `ReadOperation` and `WriteOperation` `struct`s
encapsulate those requests and a way for the owning
goroutine to respond.

```swift
struct ReadOperation {
    let key: Int
    let responses: Channel<Int>
}

struct WriteOperation {
    let key: Int
    let value: Int
    let responses: Channel<Bool>
}
```

We'll count how many operations we perform.

```swift
var operations = 0
```

The `reads` and `writes` channels will be used by
other goroutines to issue read and write requests,
respectively.

```swift
let reads = Channel<ReadOperation>()
let writes = Channel<WriteOperation>()
```

Here is the goroutine that owns the `state`, which
is a dictionary private
to the stateful goroutine. This goroutine repeatedly
selects on the `reads` and `writes` channels,
responding to requests as they arrive. A response
is executed by first performing the requested
operation and then sending a value on the response
channel `responses` to indicate success (and the desired
value in the case of `reads`).

```swift
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
```

This starts 100 goroutines to issue reads to the
state-owning goroutine via the `reads` channel.
Each read requires constructing a `ReadOperation`, sending
it over the `reads` channel, and then receiving the
result over the provided `responses` channel.

```swift
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
```

We start 10 writes as well, using a similar
approach.

```swift
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
```

Let the goroutines work for a second.

```swift
nap(now + 1 * second)
```

Finally, capture and report the `operations` count.

```swift
print("operations: \(operations)")
```

###Output

```
operations: 55798
```

Chinese Whispers
----------------

![!Gophers Chinese Whisper](https://talks.golang.org/2012/concurrency/images/gophereartrumpet.jpg)

```swift
func whisper(left: ReceivingChannel<Int>, _ right: SendingChannel<Int>) {
    left <- 1 + (<-right)!
}

let n = 1000

let leftmost = Channel<Int>()
var right = leftmost
var left = leftmost

for _ in 0 ..< n {
    right = Channel<Int>()
    go(whisper(left.receivingChannel, right.sendingChannel))
    left = right
}

go {
    right <- 1
}

print((<-leftmost)!)
```

###Output

```
1001
```

License
-------

**SwiftGo** is released under the MIT license. See LICENSE for details.