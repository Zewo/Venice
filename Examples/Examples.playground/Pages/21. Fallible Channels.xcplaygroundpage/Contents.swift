import Venice
import Darwin

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
