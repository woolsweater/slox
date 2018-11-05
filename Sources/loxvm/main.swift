import Foundation

var chunk = Chunk()

chunk.write(constant: 1.2, line: 123)
chunk.write(constant: 456, line: 123)
chunk.write(opCode: .return, line: 124)

disassemble(chunk, name: "test chunk")
