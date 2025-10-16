const VM = @This();

const std = @import("std");
const mem = std.mem;

const common = @import("zlox/common");
const compiler = @import("compiler.zig");
const debug = @import("zlox/debug");
const value_ = @import("value.zig");

const core = @import("zlox/core");
const Chunk = core.Chunk;
const OpCode = core.OpCode;
const Value = core.Value;

var stdout_writer = std.fs.File.stdout().writer(&.{});
var stderr_writer = std.fs.File.stderr().writer(&.{});

const stdout = &stdout_writer.interface;
const stderr = &stderr_writer.interface;

pub const InterpretResult = enum {
    ok,
    compile_error,
    runtime_error,
};

gpa: mem.Allocator,
stack: *[common.VMConfig.STACK_SIZE]Value,
stack_top: [*]Value,
chunk: *Chunk,
ip: [*]u8,

pub fn init(gpa: mem.Allocator, chunk: *Chunk) VM {
    const stack_init = gpa.create([common.VMConfig.STACK_SIZE]Value) catch |err| {
        std.process.fatal("Error allocating VM stack: {s}\n", .{@errorName(err)});
    };

    return VM{
        .gpa = gpa,
        .chunk = chunk,
        .ip = chunk.code.items.ptr,
        .stack = stack_init,
        .stack_top = stack_init,
    };
}

pub fn deinit(self: *VM) void {
    self.gpa.destroy(self.stack);
}

fn resetStack(self: *VM) void {
    self.stack_top = self.stack;
}

pub fn pushVMStack(self: *VM, value: Value) void {
    self.stack_top[0] = value;
    self.stack_top += 1;
}

pub fn popVMStack(self: *VM) Value {
    self.stack_top -= 1;
    return self.stack_top[0];
}

fn printStack(self: *VM) void {
    _ = stdout.write("\x1b[38;2;255;191;0mStack ") catch unreachable;

    var idx: [*]Value = self.stack;
    while (@intFromPtr(idx) < @intFromPtr(self.stack_top)) : (idx += 1) {
        stdout.print("[ {d} ]", .{idx[0]}) catch unreachable;
    }

    _ = stdout.write("\x1b[0m\n") catch unreachable;
    stdout.flush() catch unreachable;
}

pub fn run(self: *VM) InterpretResult {
    while (true) {
        if (common.DEBUG_TRACE_EXECUTION_FLAG) {
            // std.debug.print("          ", .{});

            self.printStack();
            self.debugTraceExecution();
        }

        const instruction: OpCode = @enumFromInt(self.readByte());

        switch (instruction) {
            .op_constant => {
                const constant: Value = self.readConstant();
                self.pushVMStack(constant);

                // std.debug.print("constant: {d}\n", .{constant});
            },

            .op_addition,
            .op_subtraction,
            .op_multiply,
            .op_divide,
            => self.binaryOp(instruction),

            .op_negate => self.pushVMStack(-self.popVMStack()),

            .op_return => {
                value_.printValue(self.popVMStack());
                std.debug.print("\n", .{});
                return InterpretResult.ok;
            },
            // else => return InterpretResult.compile_error,
        }
    }
}

fn readByte(self: *VM) u8 {
    const retval = self.ip[0];
    self.ip += 1;
    // @ptrFromInt(@intFromPtr(s.ip) + 1);
    // @as(*u8, @ptrFromInt(@intFromPtr(s.ip) + 1));

    return retval;
}

fn readConstant(self: *VM) Value {
    return self.chunk.constants.items[self.readByte()];
}

fn binaryOp(self: *VM, op: OpCode) void {
    const b = self.popVMStack();
    const a = self.popVMStack();

    return switch (op) {
        .op_addition => self.pushVMStack(a + b),
        .op_subtraction => self.pushVMStack(a - b),
        .op_multiply => self.pushVMStack(a * b),
        .op_divide => self.pushVMStack(a / b),
        else => @panic("Not a supported op code"),
    };
}

fn debugTraceExecution(self: *VM) void {
    _ = debug.disassembleInstruction(
        self.chunk,
        @as(usize, @intFromPtr(self.ip) - @intFromPtr(self.chunk.code.items.ptr)),
    );
}

fn opByte(op_code: OpCode) u8 {
    return @intFromEnum(op_code);
}

pub fn interpret(gpa: mem.Allocator, source: []const u8) InterpretResult {
    var chunk = Chunk.init(&gpa);

    if (!compiler.compile(source)) {}

    // var chunk = core.Chunk.init(&gpa);
    // defer chunk.deinit();
    // errdefer chunk.deinit();
    //
    // var constant_index = chunk.writeConstant(1.2);
    // chunk.write(opByte(.op_constant), 123);
    // chunk.write(@as(u8, @truncate(constant_index)), 123);
    //
    // constant_index = chunk.writeConstant(3.4);
    // chunk.write(opByte(.op_constant), 123);
    // chunk.write(@as(u8, @truncate(constant_index)), 123);
    //
    // chunk.write(opByte(.op_addition), 123);
    //
    // constant_index = chunk.writeConstant(5.6);
    // chunk.write(opByte(.op_constant), 123);
    // chunk.write(@as(u8, @truncate(constant_index)), 123);
    //
    // chunk.write(opByte(.op_multiply), 123);
    // chunk.write(opByte(.op_negate), 123);
    //
    // chunk.write(opByte(.op_return), 123);
    //
    // var vm = VM.init(gpa, &chunk);
    // defer vm.deinit();
    //
    // return vm.run();
}
