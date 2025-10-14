const std = @import("std");
const mem = std.mem;

const common = @import("common.zig");
const chunk_ = @import("chunk.zig");
const debug = @import("../debug/debug.zig");
const value_ = @import("value.zig");

const Chunk = chunk_.Chunk;
const OpCode = chunk_.OpCode;
const Value = value_.Value;
const Stack = @import("stack.zig").Stack;

const DEBUG_FLAG: bool = true;

pub const InterpretResult = enum {
    ok,
    compile_error,
    runtime_error,
};

pub const VM = struct {
    gpa: *const mem.Allocator,
    chunk: *Chunk,
    ip: [*]u8,
    stack: Stack(Value, common.VMConfig.STACK_SIZE),

    pub fn init(gpa: *const mem.Allocator, chunk: *Chunk) VM {
        return VM{
            .gpa = gpa,
            .chunk = chunk,
            .ip = chunk.code.items.ptr,
            .stack = Stack(Value, common.VMConfig.STACK_SIZE).init(),
        };
    }

    fn resetStack(s: *VM) void {
        s.stack.resetStack();
    }

    fn push(s: *VM, value: Value) void {
        s.stack.pushUnsafe(value);
    }

    fn pop(s: *VM) Value {
        return s.stack.popUnsafe();
    }

    pub fn run(s: *VM) InterpretResult {
        while (true) {
            if (DEBUG_FLAG) {
                std.debug.print("          ", .{});

                var idx: usize = 0;
                while (idx < s.stack.stack_top) : (idx += 1) {
                    std.debug.print("[ ", .{});
                    value_.printValue(s.stack.items[idx]);
                    std.debug.print(" ]", .{});
                }

                std.debug.print("\n", .{});
                s.debugTraceExecution();
            }

            const instruction: OpCode = @enumFromInt(s.readByte());

            switch (instruction) {
                .op_constant => {
                    const constant: Value = s.readConstant();
                    s.push(constant);

                    // std.debug.print("constant: {d}\n", .{constant});
                },
                .op_addition,
                .op_subtraction,
                .op_multiply,
                .op_divide,
                => s.binaryOp(instruction),
                .op_negate => s.push(-s.pop()),
                .op_return => {
                    value_.printValue(s.pop());
                    std.debug.print("\n", .{});
                    return InterpretResult.ok;
                },
                // else => return InterpretResult.compile_error,
            }
        }
    }

    fn readByte(s: *VM) u8 {
        const retval = s.ip[0];
        s.ip += 1;
        // @ptrFromInt(@intFromPtr(s.ip) + 1);
        // @as(*u8, @ptrFromInt(@intFromPtr(s.ip) + 1));

        return retval;
    }

    fn readConstant(s: *VM) Value {
        return s.chunk.constants.items[s.readByte()];
    }

    fn binaryOp(s: *VM, op: OpCode) void {
        const b = s.pop();
        const a = s.pop();

        return switch (op) {
            .op_addition => s.push(a + b),
            .op_subtraction => s.push(a - b),
            .op_multiply => s.push(a * b),
            .op_divide => s.push(a / b),
            else => @panic("Not a supported op code"),
        };
    }

    fn debugTraceExecution(s: *VM) void {
        _ = debug.disassembleInstruction(
            s.chunk,
            @as(usize, @intFromPtr(s.ip) - @intFromPtr(s.chunk.code.items.ptr)),
        );
    }
};

pub fn interpret(gpa: *const mem.Allocator, chunk: *Chunk) InterpretResult {
    var vm = VM.init(gpa, chunk);
    return vm.run();
}
