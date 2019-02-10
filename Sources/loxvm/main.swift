import Foundation

let vm = VM()
var chunk = Chunk()

// chunk.write(constant: 1.2, line: 1)
// //chunk.write(opCode: .negate, line: 1)
// chunk.write(constant: 3.4, line: 1)
// chunk.write(opCode: .add, line: 1)
// chunk.write(constant: 5.6, line: 1)
// chunk.write(opCode: .divide, line: 1)
//
// // Check .constantLong behavior
// //for _ in 0..<UInt8.max {
// //    chunk.write(constant: 0, line: 2)
// //}
// //chunk.write(constant: 1.2, line: 3)
//

// 1 * 2 + 3
// expected yield: 5
//chunk.write(constant: 1, line: 1)
//chunk.write(constant: 2, line: 1)
//chunk.write(opCode: .multiply, line: 1)
//chunk.write(constant: 3, line: 1)
//chunk.write(opCode: .add, line: 1)

// 1 + 2 * 3
// expected yield: 7
//chunk.write(constant: 2, line: 1)
//chunk.write(constant: 3, line: 1)
//chunk.write(opCode: .multiply, line: 1)
//chunk.write(constant: 1, line: 1)
//chunk.write(opCode: .add, line: 1)

// 3 - 2 - 1
// expected yield: 0
//chunk.write(constant: 3, line: 1)
//chunk.write(constant: 2, line: 1)
//chunk.write(opCode: .subtract, line: 1)
//chunk.write(constant: 1, line: 1)
//chunk.write(opCode: .subtract, line: 1)

// 1 + 2 * 3 - 4 / -5
// Or: 1 + (2 * 3) - (4 / (-5))
// expected yield: 7.8
//chunk.write(constant: 2, line: 1)
//chunk.write(constant: 3, line: 1)
//chunk.write(opCode: .multiply, line: 1)
//chunk.write(constant: 1, line: 1)  // (1, add) can also go after subtract
//chunk.write(opCode: .add, line: 1)
//chunk.write(constant: 4, line: 1)
//chunk.write(constant: 5, line: 1)
//chunk.write(opCode: .negate, line: 1)
//chunk.write(opCode: .divide, line: 1)
//chunk.write(opCode: .subtract, line: 1)

// 4 - 3 * -2
// no OpCode.negate
// expected yield: 10
//chunk.write(constant: 4, line: 1)
//chunk.write(constant: 3, line: 1)
//chunk.write(constant: 0, line: 1)
//chunk.write(constant: 2, line: 1)
//chunk.write(opCode: .subtract, line: 1)
//chunk.write(opCode: .multiply, line: 1)
//chunk.write(opCode: .subtract, line: 1)

// 4 - 3 * -2
// no OpCode.subtract
// expected yield: 10
chunk.write(constant: 4, line: 1)
chunk.write(constant: 3, line: 1)
chunk.write(constant: 2, line: 1)
chunk.write(opCode: .negate, line: 1)
chunk.write(opCode: .multiply, line: 1)
chunk.write(opCode: .negate, line: 1)
chunk.write(opCode: .add, line: 1)

disassemble(chunk, name: "test chunk")

print("<<< Begin Interpretation >>>")

chunk.write(opCode: .return, line: 4)

_ = vm.interpret(chunk: chunk)
