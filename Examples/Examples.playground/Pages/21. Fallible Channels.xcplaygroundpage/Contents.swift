import SwiftGo
import Darwin

struct Error : ErrorType, CustomStringConvertible { let description: String }

func flipCoin(result: FallibleChannel<String>) {
    if arc4random_uniform(2) == 0 {
        result <- "Success"
    } else {
        result <- Error(description: "Something went wrong.")
    }
}

let results = FallibleChannel<String>()
var done = false

go(flipCoin(results))

while !done {
    do {
        let value = try !<-results
        print(value)
        done = true
    } catch {
        print("\(error) Retrying...")
        go(flipCoin(results))
    }
}