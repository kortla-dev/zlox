const std = @import("std");
const mem = std.mem;

const ArrayList = std.ArrayList;
const Value = @import("value.zig").Value;

pub const OpCode = enum(u8) {
    op_constant,
    op_addition,
    op_subtraction,
    op_multiply,
    op_divide,
    op_negate,
    op_return,

    pub fn byte(@"type": OpCode) u8 {
        return @as(u8, @intFromEnum(@"type"));
    }
};

pub const Chunk = struct {
    gpa: *const mem.Allocator,
    code: ArrayList(u8),
    constants: ArrayList(Value),
    lines: ArrayList(usize),

    pub fn init(gpa: *const mem.Allocator) Chunk {
        return Chunk{
            .gpa = gpa,
            .code = .empty,
            .constants = .empty,
            .lines = .empty,
        };
    }

    pub fn deinit(s: *Chunk) void {
        s.constants.deinit(s.gpa.*);
        s.code.deinit(s.gpa.*);
        s.lines.deinit(s.gpa.*);
    }

    pub fn write(s: *Chunk, byte: u8, line: usize) void {
        s.code.append(s.gpa.*, byte) catch @panic("OOM while compiling: failed to allocate in writeChunk");
        s.lines.append(s.gpa.*, line) catch unreachable;
    }

    pub fn writeConstant(s: *Chunk, value: Value) usize {
        s.constants.append(s.gpa.*, value) catch unreachable;
        return s.constants.items.len - 1;
    }
};
