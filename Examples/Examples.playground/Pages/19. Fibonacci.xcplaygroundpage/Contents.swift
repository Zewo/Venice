import SwiftGo

func fibonacci(n: Int, channel: Channel<Int>) {
    var x = 0
    var y = 1
    var z = 0
    for _ in 0 ..< n {
        channel <- x
        z = x
        x = y
        y = z + y
    }
    channel.close()
}

let fibonacciChannel = Channel<Int>(bufferSize: 10)

go(fibonacci(fibonacciChannel.bufferSize, channel: fibonacciChannel))

for n in fibonacciChannel {
    print(n)
}