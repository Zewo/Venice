import Venice

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
