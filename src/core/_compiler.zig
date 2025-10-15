const std = @import("std");

const core = @import("core.zig");

const Cursor = @import("Cursor.zig");
const Token = Cursor.Token;
const Chunk = core.Chunk;
const OpCode = core.OpCode;

var stdout_writer = std.fs.File.stdout().writer(&.{});
var stderr_writer = std.fs.File.stderr().writer(&.{});

const stdout = &stdout_writer.interface;
const stderr = &stderr_writer.interface;

pub const Compiler = struct {
    const U8_MAX = std.math.maxInt(u8);

    cursor: Cursor = undefined,
    curr_tkn: Token = undefined,
    prev_tkn: Token = undefined,

    compiling_chunk: *Chunk = undefined,

    had_error: bool = false,
    panic_mode: bool = false,

    pub fn init() Compiler {
        return Compiler{};
    }

    pub fn compile(self: *Compiler, source: []const u8, chunk: *Chunk) !bool {
        self.cursor = Cursor.init(source);
        self.compiling_chunk = chunk;
        self.advance();
        self.expression();
        self.consume(Token.byte(.tkn_eof), "Expected end of expression.");
        self.endCompiler();

        return !self.had_error;
    }

    fn advance(self: *Compiler) void {
        self.prev_tkn = self.curr_tkn;

        while (true) {
            self.curr_tkn = self.cursor.nextToken();

            if (self.curr_tkn.type != .tkn_error) break;

            self.errorAtCurrent(self.curr_tkn.literal);
        }
    }

    fn consume(self: *Compiler, token_type: Token.Type, message: []const u8) void {
        if (self.curr_tkn.type == token_type) {
            self.advance();
            return;
        }

        self.errorAtCurrent(message);
    }

    fn emitByte(self: *Compiler, byte: u8) void {
        self.compiling_chunk.write(byte, self.prev_tkn.line);
    }

    // fn emitReturn()

    fn errorAtCurrent(self: *Compiler, message: []const u8) void {
        errorAt(&self.curr_tkn, message);
    }

    fn @"error"(self: *Compiler, message: []const u8) void {
        errorAt(&self.curr_tkn, message);
    }

    fn errorAt(self: *Compiler, token: *Token, message: []const u8) void {
        if (self.panic_mode) return;
        self.panic_mode = true;
        stderr.print("[line {d}] Error", token.line) catch unreachable;

        switch (token.type) {
            .tkn_eof => _ = stderr.write(" at end") catch unreachable,
            .tkn_error => {},
            else => stderr.print(" at '{s}'", .{token.literal}) catch unreachable,
        }

        stderr.print(": {s}\n", .{message}) catch unreachable;
        stderr.flush() catch @panic("Failed to flush bufr");

        self.had_error = true;
    }
};
