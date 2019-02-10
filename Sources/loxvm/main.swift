import Foundation

let vm = VM()
var chunk = Chunk()

chunk.write(constant: 1.2, line: 1)
//chunk.write(opCode: .negate, line: 1)
chunk.write(constant: 3.4, line: 1)
chunk.write(opCode: .add, line: 1)
chunk.write(constant: 5.6, line: 1)
chunk.write(opCode: .divide, line: 1)

// Check .constantLong behavior
//for _ in 0..<UInt8.max {
//    chunk.write(constant: 0, line: 2)
//}
//chunk.write(constant: 1.2, line: 3)

chunk.write(opCode: .return, line: 4)

disassemble(chunk, name: "test chunk")

print("<<< Begin Interpretation >>>")

_ = vm.interpret(chunk: chunk)
