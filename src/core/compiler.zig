const std = @import("std");
const mem = std.mem;

const core = @import("core.zig");

const Cursor = @import("Cursor.zig");
const Chunk = core.Chunk;
const Token = Cursor.Token;
const OpCode = core.OpCode;
const Value = core.Value;

var stdout_writer = std.fs.File.stdout().writer(&.{});
var stderr_writer = std.fs.File.stderr().writer(&.{});

const stdout = &stdout_writer.interface;
const stderr = &stderr_writer.interface;

pub const Parser = struct {
    gpa: mem.Allocator = undefined,
    curr_tkn: Token,
    prev_tkn: Token = undefined,
    cursor: Cursor = undefined,
    had_error: bool = false,
    panic_mode: bool = false,
};

var parser = Parser{
    .curr_tkn = Token{
        .type = .tkn_error,
        .line = 0,
        .literal = "",
    },
};

var compiling_chunk: *Chunk = undefined;

pub fn compile(source: []const u8, chunk: *Chunk) bool {
    const cursor = Cursor.init(source);
    _ = cursor;

    compiling_chunk = chunk;

    advance();
    // expression();

    consume(.tkn_eof, "Expect end of expression.");
    endCompiler();

    return !parser.had_error;
}

fn advance() void {
    parser.prev_tkn = parser.curr_tkn;

    while (true) {
        parser.curr_tkn = parser.cursor.nextToken();

        if (parser.curr_tkn.type != .tkn_error) break;

        errorAtCurrent(parser.curr_tkn.literal);
    }
}

fn expression() void {}

fn number() void {
    const value: f32 = std.fmt.parseFloat(f32, parser.prev_tkn.literal) catch |err| {
        @panic(@errorName(err));
    };

    emitConstant(value);
}

fn makeConstant(value: Value) u8 {
    const const_idx: usize = currentChunk().writeConstant(value);

    if (const_idx > std.math.maxInt(u8)) {
        @"error"("Too many constant in one chunk.");
        return 0;
    }

    return @as(u8, @truncate(const_idx));
}

fn emitConstant(value: Value) void {
    emitBytes(.{ @intFromEnum(OpCode.op_constant), makeConstant(value) });
}

fn consume(token_type: Token.Type, message: []const u8) void {
    if (parser.curr_tkn.type == token_type) {
        advance();
        return;
    }

    errorAtCurrent(message);
}

fn currentChunk() *Chunk {
    return compiling_chunk;
}

fn endCompiler() void {
    emitReturn();
}

fn emitReturn() void {
    emitByte(OpCode.op_return);
}

fn emitByte(byte: u8) void {
    currentChunk().write(byte, parser.prev_tkn.line);
}

fn emitBytes(bytes: []const u8) void {
    for (bytes) |byte| emitByte(byte);
}

fn errorAtCurrent(message: []const u8) void {
    errorAt(&parser.curr_tkn, message);
}

fn @"error"(message: []const u8) void {
    errorAt(&parser.curr_tkn, message);
}
fn errorAt(token: *Token, message: []const u8) void {
    if (parser.panic_mode) return;
    parser.panic_mode = true;
    stderr.print("[line {d}] Error", token.line) catch unreachable;

    switch (token.type) {
        .tkn_eof => _ = stderr.write(" at end") catch unreachable,
        .tkn_error => {},
        else => stderr.print(" at '{s}'", .{token.literal}) catch unreachable,
    }

    stderr.print(": {s}\n", .{message}) catch unreachable;
    stderr.flush() catch @panic("Failed to flush bufr");

    parser.had_error = true;
}
