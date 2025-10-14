const std = @import("std");
const mem = std.mem;

const zlox = @import("common_utils");
const debug = @import("debug/debug.zig");
const VM = @import("core/VM.zig");

const core = @import("core/core.zig");
const OpCode = core.OpCode;

var stdout_writer = std.fs.File.stdout().writer(&.{});
var stderr_writer = std.fs.File.stderr().writer(&.{});

const stdout = &stdout_writer.interface;
const stderr = &stderr_writer.interface;

fn repl() !void {
    var buffer: [1024]u8 = undefined;
    var stdin_reader = std.fs.File.stdin().reader(&buffer);
    const stdin = &stdin_reader.interface;

    try stdout.writeAll("zlox-repl> ");

    while (stdin.takeDelimiterExclusive('\n')) |line| {
        _ = try stdout.write(line);
        try stdout.flush();

        // interpret();

        try stdout.writeAll("\n\nzlox-repl> ");
    } else |err| switch (err) {
        error.StreamTooLong => @panic("Entered stream in too long"),
        error.ReadFailed => @panic("Failed to read stream"),
        else => {},
    }
}

fn interpret(source: []const u8) VM.InterpretResult {
    _ = source;

    return .ok;
}

fn readFile(gpa: mem.Allocator, path: []const u8) []const u8 {
    const file = std.fs.cwd().openFile(path, .{ .mode = .read_only }) catch |err| {
        @panic(@errorName(err));
    };
    defer file.close();

    const file_size = file.getEndPos() catch @panic("Failed to get file size");
    const buffer = gpa.alloc(u8, file_size + 1) //
        catch @panic("Failed to allocate buffer for file contents");

    const bytes_read = file.read(buffer[0..file_size]) //
        catch @panic("Failed to read file contents");
    buffer[bytes_read] = 0; // Null terminator

    return buffer;
}

fn runFile(gpa: mem.Allocator, path: []const u8) !void {
    const source = readFile(gpa, path);
    defer gpa.free(source);

    try stdout.writeAll(source);

    const result: VM.InterpretResult = interpret(source);

    switch (result) {
        .compile_error => std.process.exit(65),
        .runtime_error => std.process.exit(70),
        else => {},
    }
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    errdefer _ = gpa.deinit();

    const ally = gpa.allocator();

    // const vm = VM.init(&ally);
    // _ = vm;

    // const argv = std.os.argv;
    // if (argv.len == 1) {
    //     try repl();
    // } else if (argv.len == 2) {
    //     runFile(ally, mem.span(argv[1])) catch |err| {
    //         @panic(@errorName(err));
    //     };
    // } else {
    //     try stderr.writeAll("Usage: zlox [path]\n");
    //     std.process.exit(64);
    // }

    _ = VM.interpret(ally, "dksjfsldkjf");

    // debug.disassembleChunk(&chunk, "test chunk");
    // chunk.code.insert()
}

test "addConstant test" {
    const gpa = std.testing.allocator;

    var chunk = core.Chunk.init(gpa);
    defer chunk.deinit();
    errdefer chunk.deinit();

    // chunk.addConstant(ally, 3.6) catch @panic("Failed to add constant");
    // chunk.addConstant(ally, 5.6) catch @panic("Failed to add constant");

    const constant_index = chunk.writeConstant(gpa, 1.2);
    chunk.write(@intFromEnum(OpCode.op_constant), 123);
    chunk.write(@as(u8, @truncate(constant_index)), 123);

    chunk.write(@intFromEnum(OpCode.op_addition), 123);
    chunk.write(@intFromEnum(OpCode.op_return), 123);
}

test "simple test" {
    const gpa = std.testing.allocator;
    var list: std.ArrayList(i32) = .empty;
    defer list.deinit(gpa); // Try commenting this out and see if zig detects the memory leak!
    try list.append(gpa, 42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}

test "fuzz example" {
    const Context = struct {
        fn testOne(context: @This(), input: []const u8) anyerror!void {
            _ = context;
            // Try passing `--fuzz` to `zig build test` and see if it manages to fail this test case!
            try std.testing.expect(!std.mem.eql(u8, "canyoufindme", input));
        }
    };
    try std.testing.fuzz(Context{}, Context.testOne, .{});
}
