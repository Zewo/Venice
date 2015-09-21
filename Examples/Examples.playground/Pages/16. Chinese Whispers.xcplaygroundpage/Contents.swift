import SwiftGo
//: Chinese Whispers
//: ----------------
//:
//: ![!Gophers Chinese Whisper](https://talks.golang.org/2012/concurrency/images/gophereartrumpet.jpg)
func whisper(left: ReceivingChannel<Int>, _ right: SendingChannel<Int>) {
    left <- 1 + !<-right
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

print(!<-leftmost)
