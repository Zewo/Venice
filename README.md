Venice
======

[![Swift 2.2](https://img.shields.io/badge/Swift-2.2-orange.svg?style=flat)](https://developer.apple.com/swift/)
[![Platforms Linux](https://img.shields.io/badge/Platforms-Linux-lightgray.svg?style=flat)](https://developer.apple.com/swift/)
[![License MIT](https://img.shields.io/badge/License-MIT-blue.svg?style=flat)](https://tldrlegal.com/license/mit-license)
[![Slack Status](https://zewo-slackin.herokuapp.com/badge.svg)](https://zewo-slackin.herokuapp.com)

**Venice** provides [CSP](https://en.wikipedia.org/wiki/Communicating_sequential_processes) for **Swift 2.2**.

## Features

- [x] No `Foundation` dependency (**Linux ready**)
- [x] Coroutines
- [x] Coroutine Preallocation
- [x] Channels
- [x] Fallible Channels
- [x] Receive-only Channels
- [x] Send-only Channels
- [x] Channel Iteration
- [x] Select
- [x] Timers
- [x] Tickers
- [x] File Descriptor Polling
- [x] IP
- [x] TCP Sockets
- [ ] UDP Sockets
- [ ] UNIX Sockets
- [ ] File

**Venice** wraps a fork of the C library [libmill](https://github.com/sustrik/libmill).

## Products

**Venice** is the base for:

- [Epoch](https://github.com/Zewo/Epoch) - HTTP server

##Usage

`co`
----

```swift
func doSomething() {
    print("did something")
}

// call sync
doSomething()

// call async
co(doSomething())

// async closure
co {
    print("did something else")
}
```

`nap` and `wakeUp`
------------------

```swift
co {
    // wakes up 1 second from now
    wakeUp(now + 1 * second)
    print("yawn")
}

// nap for two seconds so the program
// doesn't terminate before the print
nap(2 * second)
```

`after`
------------------

`after` runs the coroutine after the specified duration.

```swift
after(1 * second) {
    print("yoo")
}

// same as

co {
	nap(1 * second)
	print("yoo")
}
```

`Channel<Type>`
---------------

Channels are typed and return optionals wrapping the value or nil if the channel is closed and doesn't have any values left in the buffer.

```swift
let messages = Channel<String>()
co(messages <- "ping")
let message = <-messages
print(message!)

// without operators

let messages = Channel<String>()
co(messages.receive("ping"))
let message = messages.send()
print(message!)

// buffered channels

let messages = Channel<String>(bufferSize: 2)

messages <- "buffered"
messages <- "channel"

print(!<-messages)
print(!<-messages)
```

`ReceivingChannel<Type>` and `SendingChannel<Type>`
---------------------------------------------------

You can get a reference to a channel with receive or send only capabilities.

```swift
func receiveOnly(channel: ReceivingChannel<String>) {
    // can only receive
    channel <- "yo"
}

func sendOnly(channel: SendingChannel<String>) {
    // can only send
    <-channel
}

let channel = Channel<String>(bufferSize: 1)
receiveOnly(channel.receivingChannel)
sendOnly(channel.sendingChannel)
```

`FallibleChannel<Type>`
-----------------------

Fallible channels accept values and errors as well.

```swift
struct Error : ErrorType {}

let channel = FallibleChannel<String>(bufferSize: 2)

channel <- "yo"
channel <- Error()

do {
    let yo = try <-channel
    try <-channel // will throw
} catch {
    print("error")
}

```

`select`
--------

Sometimes `select` can clash with the system libraries function with the same name `select`. To solve this you can call Venice's select with `Venice.select`or with the terser alias `sel`.

```swift
let channel = Channel<String>()
let fallibleChannel = FallibleChannel<String>()

select { when in
    when.receiveFrom(channel) { value in
        print("received \(value)")
    }
    when.receiveFrom(fallibleChannel) { result in
        result.success { value in
            print(value)
        }
        result.failure { error in
            print(error)
        }
    }
    when.send("value", to: channel) {
        print("sent value")
    }
    when.send("value", to: fallibleChannel) {
        print("sent value")
    }
    when.throwError(Error(), into: fallibleChannel) {
        print("threw error")
    }
    when.timeout(now + 1 * second) {
        print("timeout")
    }
    when.otherwise {
        print("default case")
    }
}
```

You can disable a channel selection by turning it to nil

```swift

var channelA: Channel<String>? = Channel<String>()
var channelB: Channel<String>? = Channel<String>()

if arc4random_uniform(2) == 0 {
    channelA = nil
    print("disabled channel a")
} else {
    channelB = nil
    print("disabled channel b")
}

co { channelA?.receive("a") }
co { channelB?.receive("b") }

sel { when in
    when.receiveFrom(channelA) { value in
        print("received \(value) from channel a")
    }
    when.receiveFrom(channelB) { value in
        print("received \(value) from channel b")
    }
}
```

Another way to disable a channel selection is to simply put it's case inside an if.

```swift
let channelA = Channel<String>()
let channelB = Channel<String>()

co(channelA <- "a")
co(channelB <- "b")

select { when in
    if arc4random_uniform(2) == 0 {
        print("disabled channel b")
        when.receiveFrom(channelA) { value in
            print("received \(value) from channel a")
        }
    } else {
        print("disabled channel a")
        when.receiveFrom(channelB) { value in
            print("received \(value) from channel b")
        }
    }
}

```

`forSelect`
-----------

A lot of times we need to wrap our select inside a while loop. To make it easier to work with this pattern we can use `forSelect`. `forSelect` will loop until you call `done()`.

```swift
func flipCoin(result: FallibleChannel<String>) {
    if arc4random_uniform(2) == 0 {
        result <- "Success"
    } else {
        result <- Error(description: "Something went wrong")
    }
}

let results = FallibleChannel<String>()

co(flipCoin(results))

forSelect { when, done in
    when.receiveFrom(results) { result in
        result.success { value in
            print(value)
            done()
        }
        result.failure { error in
            print("\(error). Retrying...")
            co(flipCoin(results))
        }
    }
}
```

`IP`
----

```swift
// local
do {
    // all network interfaces
    let ip1 = try IP(port: 5555, mode: .IPV4)
    
    // specific network interface
    let ip2 = try IP(networkInterface: "en0", port: 5555, mode: .IPV6)
} catch {
    // something bad happened :(
}

// remote
do {
    // if the deadline is reached the call will throw
    let ip3 = try IP(address: "127.0.0.1", port: 5555, mode: .IPV4, deadline: now + 10 * second)
} catch {
    // something bad happened :(
}
```

`TCP`
----

```swift
// server
do {
	let ip = try IP(port: 5555)
	let serverSocket = try TCPServerSocket(ip: ip)
	let clientSocket = try serverSocket.accept()
	
	let yo = try clientSocket.receiveString(untilDelimiter: "\n")
} catch {
    // something bad happened :(
}

// client
do {
	let ip = try IP(address: "127.0.0.1", port: 5555)
	let clientSocket = try TCPClientSocket(ip: ip)
	let deadline = now + 10 * second
	
	// calls to send append the data to an internal
	// buffer to minimize system calls
	try clientSocket.sendString("yo\n", deadline: deadline)
	// flush actually sends all data in the buffer
	try clientSocket.flush()
} catch {
    // something bad happened :(
}
```

## Installation

- Install [`libvenice`](https://github.com/Zewo/libvenice)

```bash
$ git clone https://github.com/Zewo/libvenice.git
$ cd libvenice
$ make
$ dpkg -i libvenice.deb
```

- Add `Venice` to your `Package.swift`

```swift
import PackageDescription

let package = Package(
	dependencies: [
		.Package(url: "https://github.com/Zewo/Venice.git", majorVersion: 0, minor: 1)
	]
)
```

Examples
========

The examples 01-15 were taken from [gobyexample](http://gobyexample.com) and translated from Go to Swift using **Venice**.

01 - Coroutines
---------------

A *coroutine* is a lightweight thread of execution.

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

To invoke this function in a coroutine, use `co(f(s))`. This new
coroutine will execute concurrently with the calling one.

```
co(f("coroutine"))
```

You can also start a coroutine with a closure.

```
co {
    print("going")
}
```

Our two function calls are running asynchronously in separate
coroutines now, so execution falls through to here. We wait 1 second
before the program exits

```swift
nap(1 * second)
print("done")
```

When we run this program, we see the output of the blocking call
first, then the interleaved output of the two coroutines. This
interleaving reflects the coroutines being run concurrently by the
runtime.

###Output

```
direct: 0
direct: 1
direct: 2
direct: 3
coroutine: 0
going
coroutine: 1
coroutine: 2
coroutine: 3
done
```

02 - Channels
-------------

*Channels* are the pipes that connect concurrent
coroutines. You can send values into channels from one
coroutine and receive those values into another
coroutine.

Create a new channel with `Channel<Type>()`.
Channels are typed by the values they convey.

```swift
let messages = Channel<String>()
```

_Send_ a value into a channel using the `channel <- value`
syntax. Here we send `"ping"`  to the `messages`
channel we made above, from a new coroutine.

```swift
co(messages <- "ping")
```

The `<-channel` syntax _receives_ a value from the
channel. Here we'll receive the `"ping"` message
we sent above and print it out.

```swift
let message = <-messages
print(message!)
```

When we run the program the "ping" message is successfully passed from
one coroutine to another via our channel. By default sends and receives block until both the sender and receiver are ready. This property allowed us to wait at the end of our program for the "ping" message without having to use any other synchronization.

Values received from channels are `Optional`s. If you try to get a value from a closed channel with no values left in the buffer, it'll return `nil`. If you are sure that there is a value wraped in the `Optional`, you can use the `!<-` operator, which returns an implictly unwraped optional.

###Output

```
ping
```

03 - Channel Buffering
----------------------

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
print(!<-messages)
print(!<-messages)
```

###Output

```
buffered
channel
```

04 - Channel Synchronization
----------------------------

We can use channels to synchronize execution
across coroutines. Here's an example of using a
blocking receive to wait for a coroutine to finish.

This is the function we'll run in a coroutine. The
`done` channel will be used to notify another
coroutine that this function's work is done.

```swift
func worker(done: Channel<Bool>) {
    print("working...")
    nap(1 * second)
    print("done")
    done <- true // Send a value to notify that we're done.
}
```

Start a worker coroutine, giving it the channel to
notify on.

```swift
let done = Channel<Bool>(bufferSize: 1)
co(worker(done))
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

05 - Channel Directions
-----------------------

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
    let message = !<-pings
    pongs <- message
}

let pings = Channel<String>(bufferSize: 1)
let pongs = Channel<String>(bufferSize: 1)

ping(pings.receivingChannel, message: "passed message")
pong(pings.sendingChannel, pongs.receivingChannel)

print(!<-pongs)
```

###Output

```
passed message
```

06 - Select
-----------

_Select_ lets you wait on multiple channel
operations. Combining coroutines and channels with
select is an extremely powerful feature.

For our example we'll select across two channels.

```swift
let channel1 = Channel<String>()
let channel2 = Channel<String>()
```

Each channel will receive a value after some amount
of time, to simulate e.g. blocking RPC operations
executing in concurrent coroutines.

```swift
co {
    nap(1 * second)
    channel1 <- "one"
}

co {
    nap(2 * second)
    channel2 <- "two"
}
```

We'll use `select` to await both of these values
simultaneously, printing each one as it arrives.

```swift
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
```

We receive the values `"one"` and then `"two"` as expected.
Note that the total execution time is only ~2 seconds since
both the 1 and 2 second `nap`s execute concurrently.

###Output

```
received one
received two
```

07 - Timeouts
-------------

_Timeouts_ are important for programs that connect to
external resources or that otherwise need to bound
execution time. Implementing timeouts is easy and
elegant thanks to channels and `select`.

For our example, suppose we're executing an external
call that returns its result on a channel `channel1`
after 2s.

```swift
let channel1 = Channel<String>(bufferSize: 1)

co {
    nap(2 * second)
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

co {
    nap(2 * second)
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

08 - Non-Blocking Channel Operations
------------------------------------

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
    when.receiveFrom(messages) { message in
        print("received message \(message)")
    }
    when.otherwise {
        print("no message received")
    }
}
```

A non-blocking send works similarly.

```swift
let message = "hi"

select { when in
    when.send(message, to: messages) {
        print("sent message \(message)")
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
    when.receiveFrom(messages) { message in
        print("received message \(message)")
    }
    when.receiveFrom(signals) { signal in
        print("received signal \(signal)")
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

09 - Closing Channels
---------------------

_Closing_ a channel indicates that no more values
can be sent to it. This can be useful to communicate
completion to the channel's receivers.

In this example we'll use a `jobs` channel to
communicate work to be done to a worker coroutine. When we have no more jobs for
the worker we'll `close` the `jobs` channel.

```swift
let jobs = Channel<Int>(bufferSize: 5)
let done = Channel<Bool>()
```

Here's the worker coroutine. It repeatedly receives
from `jobs` with `j = <-jobs`. The return value
will be `nil` if `jobs` has been `close`d and all
values in the channel have already been received.
We use this to notify on `done` when we've worked
all our jobs.

```swift
co {
    while true {
        if let job = <-jobs {
            print("received job \(job)")
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
for job in 1 ... 3 {
    print("sent job \(job)")
    jobs <- job
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

10 - Iterating Over Channels
----------------------------

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
for element in queue {
    print(element)
}
```

This example also showed that it’s possible to close a non-empty channel but still have the
remaining values be received.

###Output

```
one
two
```

11 - Timers
-----------

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

co {
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

12 - Tickers
------------

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
let ticker = Ticker(period: 500 * millisecond)

co {
    for time in ticker.channel {
        print("Tick at \(time)")
    }
}
```

Tickers can be stopped like timers. Once a ticker
is stopped it won't receive any more values on its
channel. We'll stop ours after 1600ms.

```swift
nap(1600 * millisecond)
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

13 - Worker Pools
-----------------

In this example we'll look at how to implement
a _worker pool_ using coroutines and channels.

Here's the worker, of which we'll run several
concurrent instances. These workers will receive
work on the `jobs` channel and send the corresponding
results on `results`. We'll sleep a second per job to
simulate an expensive task.

```swift
func worker(id: Int, jobs: Channel<Int>, results: Channel<Int>) {
    for job in jobs {
        print("worker \(id) processing job \(job)")
        nap(1 * second)
        results <- job * 2
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
for workerId in 1 ... 3 {
    co(worker(workerId, jobs: jobs, results: results))
}
```

Here we send 9 `jobs` and then `close` that
channel to indicate that's all the work we have.

```swift
for job in 1 ... 9 {
    jobs <- job
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

14 - Rate Limiting
------------------

_[Rate limiting](http://en.wikipedia.org/wiki/Rate_limiting)_
is an important mechanism for controlling resource
utilization and maintaining quality of service. Venice
elegantly supports rate limiting with coroutines,
channels, and tickers.

First we'll look at basic rate limiting. Suppose
we want to limit our handling of incoming requests.
We'll serve these requests off a channel of the
same name.

```swift
var requests = Channel<Int>(bufferSize: 5)

for request in 1 ... 5 {
    requests <- request
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
let burstyLimiter = Channel<Int64>(bufferSize: 3)
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
co {
    for time in Ticker(period: 200 * millisecond).channel {
        burstyLimiter <- time
    }
}
```

Now simulate 5 more incoming requests. The first
3 of these will benefit from the burst capability
of `burstyLimiter`.

```swift
let burstyRequests = Channel<Int>(bufferSize: 5)

for request in 1 ... 5 {
    burstyRequests <- request
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

15 - Stateful Coroutines
------------------------

In this example our state will be owned by a single
coroutine. This will guarantee that the data is never
corrupted with concurrent access. In order to read or
write that state, other coroutines will send messages
to the owning coroutine and receive corresponding
replies. These `ReadOperation` and `WriteOperation` `struct`s
encapsulate those requests and a way for the owning
coroutine to respond.

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
other coroutines to issue read and write requests,
respectively.

```swift
let reads = Channel<ReadOperation>()
let writes = Channel<WriteOperation>()
```

Here is the coroutine that owns the `state`, which
is a dictionary private
to the stateful coroutine. This coroutine repeatedly
selects on the `reads` and `writes` channels,
responding to requests as they arrive. A response
is executed by first performing the requested
operation and then sending a value on the response
channel `responses` to indicate success (and the desired
value in the case of `reads`).

```swift
co {
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

This starts 100 coroutines to issue reads to the
state-owning coroutine via the `reads` channel.
Each read requires constructing a `ReadOperation`, sending
it over the `reads` channel, and then receiving the
result over the provided `responses` channel.

```swift
for _ in 0 ..< 100 {
    co {
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
    co {
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

Let the coroutines work for a second.

```swift
nap(1 * second)
```

Finally, capture and report the `operations` count.

```swift
print("operations: \(operations)")
```

###Output

```
operations: 55798
```

16 - Chinese Whispers
---------------------

```swift
func whisper(left: ReceivingChannel<Int>, _ right: SendingChannel<Int>) {
    left <- 1 + !<-right
}

let n = 1000

let leftmost = Channel<Int>()
var right = leftmost
var left = leftmost

for _ in 0 ..< n {
    right = Channel<Int>()
    co(whisper(left.receivingChannel, right.sendingChannel))
    left = right
}

co {
    right <- 1
}

print(!<-leftmost)
```

###Output

```
1001
```

17 - Ping Pong
--------------

```swift
final class Ball { var hits: Int = 0 }

func player(name: String, table: Channel<Ball>) {
    while true {
        let ball = !<-table
        ball.hits++
        print("\(name) \(ball.hits)")
        nap(100 * millisecond)
        table <- ball
    }
}

let table = Channel<Ball>()

co(player("ping", table: table))
co(player("pong", table: table))

table <- Ball()
nap(1 * second)
<-table
```

###Output

```
ping 1
pong 2
ping 3
pong 4
ping 5
pong 6
ping 7
pong 8
ping 9
pong 10
ping 11
```

18 - Disabling Channel Select
-----------------------------

```swift
var channelA: Channel<String>? = Channel<String>()
var channelB: Channel<String>? = Channel<String>()

if arc4random_uniform(2) == 0 {
    channelA = nil
    print("disabled channel a")
} else {
    channelB = nil
    print("disabled channel b")
}

co { channelA?.receive("a") }
co { channelB?.receive("b") }

select { when in
    when.receiveFrom(channelA) { value in
        print("received \(value) from channel a")
    }
    when.receiveFrom(channelB) { value in
        print("received \(value) from channel b")
    }
}
```

###Output

```
disabled channel b
received a from channel a
```

or

```
disabled channel a
received b from channel b
```

19 - Fibonacci
--------------

```swift
func fibonacci(n: Int, channel: Channel<Int>) {
    var x = 0
    var y = 1
    for _ in 0 ..< n {
        channel <- x
        (x, y) = (y, x + y)
    }
    channel.close()
}

let fibonacciChannel = Channel<Int>(bufferSize: 10)

co(fibonacci(fibonacciChannel.bufferSize, channel: fibonacciChannel))

for n in fibonacciChannel {
    print(n)
}
```

###Output

```
0
1
1
2
3
5
8
13
21
34
```

20 - Bomb
---------

```swift
let tick = Ticker(period: 100 * millisecond).channel
let boom = Timer(deadline: now + 500 * millisecond).channel

var done = false
while !done {
    select { when in
        when.receiveFrom(tick) { _ in
            print("tick")
        }
        when.receiveFrom(boom) { _ in
            print("BOOM!")
            done = true
        }
        when.otherwise {
            print("    .")
            nap(50 * millisecond)
        }
    }
}
```

###Output

```
    .
    .
tick
    .
    .
tick
    .
    .
tick
    .
    .
tick
    .
BOOM!
```

21 - Fallible Channels
----------------------

```swift
func flipCoin(result: FallibleChannel<String>) {
    struct Error : ErrorType, CustomStringConvertible { let description: String }
    if arc4random_uniform(2) == 0 {
        result <- "Success"
    } else {
        result <- Error(description: "Something went wrong.")
    }
}

let results = FallibleChannel<String>()
var done = false

co(flipCoin(results))

while !done {
    do {
        let value = try !<-results
        print(value)
        done = true
    } catch {
        print("\(error) Retrying...")
        co(flipCoin(results))
    }
}
```

###Output

```
Something went wrong. Retrying...
Something went wrong. Retrying...
Something went wrong. Retrying...
Something went wrong. Retrying...
Something went wrong. Retrying...
Success
```

22 - Select and Fallible Channels
---------------------------------

```swift
struct Error : ErrorType, CustomStringConvertible { let description: String }

func flipCoin(result: FallibleChannel<String>) {
    if arc4random_uniform(2) == 0 {
        result <- "Success"
    } else {
        result <- Error(description: "Something went wrong")
    }
}

let results = FallibleChannel<String>()

co(flipCoin(results))

select { when in
    when.receiveFrom(results) { result in
        result.success { value in
            print(value)
        }
        result.failure { error in
            print(error)
        }
    }
}
```

###Output

```
Success
```

or

```
Something went wrong
```

23 - Tree
---------

```swift
extension CollectionType where Index == Int {
    func shuffle() -> [Generator.Element] {
        var list = Array(self)
        list.shuffleInPlace()
        return list
    }
}

extension MutableCollectionType where Index == Int {
    mutating func shuffleInPlace() {
        if count < 2 { return }

        for i in 0..<count - 1 {
            let j = Int(arc4random_uniform(UInt32(count - i))) + i
            guard i != j else { continue }
            swap(&self[i], &self[j])
        }
    }
}

final class Tree<T> {
    var left: Tree?
    var value: T
    var right: Tree?

    init(left: Tree?, value: T, right: Tree?) {
        self.left = left
        self.value = value
        self.right = right
    }
}
```

Traverses a tree depth-first,
sending each Value on a channel.

```swift
func walk<T>(tree: Tree<T>?, channel: Channel<T>) {
    if let tree = tree {
        walk(tree.left, channel: channel)
        channel <- tree.value
        walk(tree.right, channel: channel)
    }
}
```

Launches a walk in a new coroutine,
and returns a read-only channel of values.

```swift
func walker<T>(tree: Tree<T>?) -> SendingChannel<T> {
    let channel = Channel<T>()
    co {
        walk(tree, channel: channel)
        channel.close()
    }
    return channel.sendingChannel
}
```

Reads values from two walkers
that run simultaneously, and returns true
if tree1 and tree2 have the same contents.

```swift
func ==<T : Equatable>(tree1: Tree<T>, tree2: Tree<T>) -> Bool {
    let channel1 = walker(tree1)
    let channel2 = walker(tree2)
    while true {
        let value1 = <-channel1
        let value2 = <-channel2
        if value1 == nil || value2 == nil {
            return value1 == value2
        }
        if value1 != value2 {
            break
        }
    }
    return false
}
```

Returns a new, random binary tree
holding the values 1*k, 2*k, ..., n*k.

```swift
func newTree(n n: Int, k: Int) -> Tree<Int> {
    var tree: Tree<Int>?
    for value in (1...n).shuffle() {
        tree = insert(tree, value: value * k)
    }
    return tree!
}
```

Inserts a value in the tree

```swift
func insert(tree: Tree<Int>?, value: Int) -> Tree<Int> {
    if let tree = tree {
        if value < tree.value {
            tree.left = insert(tree.left, value: value)
            return tree
        } else {
            tree.right = insert(tree.right, value: value)
            return tree
        }
    } else {
        return Tree<Int>(left: nil, value: value, right: nil)
    }
}

let tree = newTree(n: 100, k: 1)

print("Same contents \(tree == newTree(n: 100, k: 1))")
print("Differing sizes \(tree == newTree(n: 99, k: 1))")
print("Differing values \(tree == newTree(n: 100, k: 2))")
print("Dissimilar \(tree == newTree(n: 101, k: 2))")
```

###Output

```
Same contents true
Differing sizes false
Differing values false
Dissimilar false
```

24 - Disabling Channel Select ||
--------------------------------

```swift
let channelA = Channel<String>()
let channelB = Channel<String>()

co(channelA <- "a")
co(channelB <- "b")

select { when in
    if arc4random_uniform(2) == 0 {
        print("disabled channel b")
        when.receiveFrom(channelA) { value in
            print("received \(value) from channel a")
        }
    } else {
        print("disabled channel a")
        when.receiveFrom(channelB) { value in
            print("received \(value) from channel b")
        }
    }
}
```

###Output

```
disabled channel b
received a from channel a
```

or

```
disabled channel a
received b from channel b
```

25 - Fake RSS Client
--------------------

```swift
struct Item : Equatable {
    let domain: String
    let title: String
    let GUID: String
}

func ==(lhs: Item, rhs: Item) -> Bool {
    return lhs.GUID == rhs.GUID
}

struct FetchResponse {
    let items: [Item]
    let nextFetchTime: Int
}

protocol FetcherType {
    func fetch() -> Result<FetchResponse>
}

struct Fetcher : FetcherType {
    let domain: String

    func randomItems() -> [Item] {
        let items = [
            Item(domain: domain, title: "Swift 2.0", GUID: "1"),
            Item(domain: domain, title: "Strings in Swift 2", GUID: "2"),
            Item(domain: domain, title: "Swift-er SDK", GUID: "3"),
            Item(domain: domain, title: "Swift 2 Apps in the App Store", GUID: "4"),
            Item(domain: domain, title: "Literals in Playgrounds", GUID: "5"),
            Item(domain: domain, title: "Swift Open Source", GUID: "6")
        ]
        return [Item](items[0..<Int(arc4random_uniform(UInt32(items.count)))])
    }

    func fetch() -> Result<FetchResponse> {
        if arc4random_uniform(2) == 0 {
            let fetchResponse = FetchResponse(
                items: randomItems(),
                nextFetchTime: now + 300 * millisecond
            )
            return Result.Value(fetchResponse)
        } else {
            struct Error : ErrorType, CustomStringConvertible { let description: String }
            return Result.Error(Error(description: "Network Error"))
        }
    }
}

protocol SubscriptionType {
    var updates: SendingChannel<Item> { get }
    func close() -> ErrorType?
}

struct Subscription : SubscriptionType {
    let fetcher: FetcherType
    let items = Channel<Item>()
    let closing = Channel<Channel<ErrorType?>>()

    init(fetcher: FetcherType) {
        self.fetcher = fetcher
        co(self.getUpdates())
    }

    var updates: SendingChannel<Item> {
        return self.items.sendingChannel
    }

    func getUpdates() {
        let maxPendingItems = 10
        let fetchDone = Channel<Result<FetchResponse>>(bufferSize: 1)

        var lastError: ErrorType?
        var pendingItems: [Item] = []
        var seenItems: [Item] = []
        var nextFetchTime = now
        var fetching = false

        forSelect { when, done in
            when.receiveFrom(closing) { errorChannel in
                errorChannel <- lastError
                self.items.close()
                done()
            }

            if !fetching && pendingItems.count < maxPendingItems {
                when.timeout(nextFetchTime) {
                    fetching = true
                    co {
                        fetchDone <- self.fetcher.fetch()
                    }
                }
            }

            when.receiveFrom(fetchDone) { fetchResult in
                fetching = false
                fetchResult.success { response in
                    for item in response.items {
                        if !seenItems.contains(item) {
                            pendingItems.append(item)
                            seenItems.append(item)
                        }
                    }
                    lastError = nil
                    nextFetchTime = response.nextFetchTime
                }
                fetchResult.failure { error in
                    lastError = error
                    nextFetchTime = now + 1 * second
                }
            }

            if let item = pendingItems.first {
                when.send(item, to: items) {
                    pendingItems.removeFirst()
                }
            }
        }
    }

    func close() -> ErrorType? {
        let errorChannel = Channel<ErrorType?>()
        closing <- errorChannel
        return !<-errorChannel
    }
}

let fetcher = Fetcher(domain: "developer.apple.com/swift/blog/")
let subscription = Subscription(fetcher: fetcher)

after(5 * second) {
    if let lastError = subscription.close() {
        print("Closed with last error: \(lastError)")
    } else {
        print("Closed with no last error")
    }
}

for item in subscription.updates {
    print("\(item.domain): \(item.title)")
}
```

###Output

```
developer.apple.com/swift/blog/: Swift 2.0
developer.apple.com/swift/blog/: Strings in Swift 2
developer.apple.com/swift/blog/: Swift-er SDK
developer.apple.com/swift/blog/: Swift 2 Apps in the App Store
Closed with last error: Network Error
```

## Community

[![Slack](http://s13.postimg.org/ybwy92ktf/Slack.png)](https://zewo-slackin.herokuapp.com)

Join us on [Slack](https://zewo-slackin.herokuapp.com).

License
-------

**Venice** is released under the MIT license. See LICENSE for details.
