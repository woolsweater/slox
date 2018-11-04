import Foundation

var chunk = Chunk()
let idx = chunk.add(constant: 1.2)
chunk.write(opCode: .constant, line: 123)
chunk.write(byte: idx, line: 123)
chunk.write(opCode: .return, line: 123)

disassemble(chunk, name: "test chunk")
