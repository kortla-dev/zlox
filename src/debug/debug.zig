const std = @import("std");

const core = @import("../core/core.zig");
const Chunk = core.Chunk;
const OpCode = core.OpCode;

pub fn disassembleChunk(chunk: *Chunk, name: []const u8) void {
    std.debug.print("== {s} ==\n", .{name});

    var offset: usize = 0;
    while (offset < chunk.code.items.len) {
        offset = disassembleInstruction(chunk, offset);
    }
}

fn simpleInstruction(name: []const u8, offset: usize) usize {
    std.debug.print("{s}\n", .{name});

    return offset + 1;
}

fn constantInstruction(chunk: *Chunk, offset: usize) usize {
    const index = chunk.code.items[offset + 1];
    std.debug.print("{s:<16} {d:0>4} '{d}'\n", .{
        "op_constant",
        index,
        chunk.constants.items[index],
    });

    return offset + 2;
}

pub fn disassembleInstruction(chunk: *Chunk, offset: usize) usize {
    std.debug.print("{d:0>4} ", .{offset});

    if (offset > 0 and (chunk.lines.items[offset] == chunk.lines.items[offset - 1])) {
        std.debug.print("   | ", .{});
    } else {
        std.debug.print("{d:4} ", .{chunk.lines.items[offset]});
    }

    const instruction: OpCode = @enumFromInt(chunk.code.items[offset]);

    return switch (instruction) {
        .op_constant => constantInstruction(chunk, offset),
        .op_negate,
        .op_addition,
        .op_subtraction,
        .op_multiply,
        .op_divide,
        .op_return,
        => simpleInstruction(@tagName(instruction), offset),
        // else => {
        //     std.debug.print("Uknown opcode{d}\n", .{chunk.code.items[offset]});
        //     return offset + 1;
        // },
    };
}

// size_t disassembleInstruction(Chunk* chunk, size_t offset) {
//   printf("%04zu ", offset);
//
//   if (offset > 0 && chunk->lines[offset] == chunk->lines[offset - 1]) {
//     printf("   | ");
//   } else {
//     printf("%4zu ", chunk->lines[offset]);
//   }
//
//   uint8_t instruction = chunk->code[offset];
//
//   switch (instruction) {
//     case OP_CONSTANT: return constantInstruction("OP_CONSTANT", chunk, offset);
//     case OP_ADD: return simpleInstruction("OP_ADD", offset);
//     case OP_SUBTRACT: return simpleInstruction("OP_SUBTRACT", offset);
//     case OP_MULTIPLY: return simpleInstruction("OP_MULTIPLY", offset);
//     case OP_DIVIDE: return simpleInstruction("OP_DIVIDE", offset);
//     case OP_NEGATE: return simpleInstruction("OP_NEGATE", offset);
//     case OP_RETURN: return simpleInstruction("OP_RETURN", offset);
//
//     default: printf("Uknown opcode%d\n", instruction); return offset + 1;
//   }
// }
