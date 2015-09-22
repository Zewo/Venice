import SwiftGo

func fibonacci(channel: Channel<Int>, quit: Channel<Void>) {
    var x = 0
    var y = 1
    var done = false
    while !done {
        select { when in
            when.send(x, to: channel) {
                x = y
                y = x + y
            }
            when.receiveFrom(quit) { _ in
                print("quit")
                done = true
            }
        }
    }
}

let channel = Channel<Int>()
let quit =  Channel<Void>()

go {
    for _ in 0 ..< 10 {
        print(!<-channel)
    }
    quit <- Void()
}

fibonacci(channel, quit: quit)