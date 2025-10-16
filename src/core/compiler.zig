const std = @import("std");

const common = @import("zlox/common");
const core = @import("core.zig");
const debug = @import("zlox/debug");

const Cursor = @import("Cursor.zig");
const Token = Cursor.Token;
const Chunk = core.Chunk;
const OpCode = core.OpCode;
const Value = core.Value;

var stdout_writer = std.fs.File.stdout().writer(&.{});
var stderr_writer = std.fs.File.stderr().writer(&.{});

const stdout = &stdout_writer.interface;
const stderr = &stderr_writer.interface;

const Precedence = enum(u8) {
    none,
    assignment, // =
    @"or", // or
    @"and", // and
    equality, // == !=
    comparison, // < > <= >=
    term, // + -
    factor, // * /
    unary, // ! -
    call, // . ()
    primary,
};

const ParseFn = *const fn (*Compiler) void;

const ParseRule = struct {
    prefix: ?ParseFn = null,
    infix: ?ParseFn = null,
    precedence: Precedence = .none,
};

pub const Compiler = struct {
    const U8_MAX = std.math.maxInt(u8);

    const rules = blk: {
        var array = std.EnumArray(Token.Type, ParseRule).initUndefined();

        array.set(.tkn_left_paren, .{ .prefix = Compiler.grouping });
        array.set(.tkn_right_paren, .{});
        array.set(.tkn_left_brace, .{});
        array.set(.tkn_right_brace, .{});
        array.set(.tkn_comma, .{});
        array.set(.tkn_dot, .{});
        array.set(.tkn_dash, .{ .prefix = Compiler.unary, .infix = Compiler.binary, .precedence = .term });
        array.set(.tkn_plus, .{ .infix = Compiler.binary, .precedence = .term });
        array.set(.tkn_semicolon, .{});
        array.set(.tkn_slash, .{ .infix = Compiler.binary, .precedence = .factor });
        array.set(.tkn_star, .{ .infix = Compiler.binary, .precedence = .factor });
        array.set(.tkn_bang, .{});
        array.set(.tkn_bang_equal, .{});
        array.set(.tkn_equal, .{});
        array.set(.tkn_equal_equal, .{});
        array.set(.tkn_greater, .{});
        array.set(.tkn_greater_equal, .{});
        array.set(.tkn_less, .{});
        array.set(.tkn_less_equal, .{});
        array.set(.tkn_identifier, .{});
        array.set(.tkn_string, .{});
        array.set(.tkn_number, .{ .prefix = Compiler.number });
        array.set(.tkn_and, .{});
        array.set(.tkn_class, .{});
        array.set(.tkn_else, .{});
        array.set(.tkn_false, .{});
        array.set(.tkn_for, .{});
        array.set(.tkn_fun, .{});
        array.set(.tkn_if, .{});
        array.set(.tkn_nil, .{});
        array.set(.tkn_or, .{});
        array.set(.tkn_print, .{});
        array.set(.tkn_return, .{});
        array.set(.tkn_super, .{});
        array.set(.tkn_this, .{});
        array.set(.tkn_true, .{});
        array.set(.tkn_var, .{});
        array.set(.tkn_while, .{});
        array.set(.tkn_error, .{});
        array.set(.tkn_eof, .{});

        break :blk array;
    };

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

    /// usage self.emitBytes(&.{bytes});
    fn emitBytes(self: *Compiler, bytes: []const u8) void {
        for (bytes) |byte| self.emitByte(byte);
    }

    fn endCompiler(self: *Compiler) void {
        self.emitReturn();

        if (common.DEBUG_PRINT_CODE_FLAG) {
            if (!self.had_error) {
                debug.disassembleChunk(self.compiling_chunk, "code");
            }
        }
    }

    fn emitReturn(self: *Compiler) void {
        self.emitByte(OpCode.byte(.op_return));
    }

    fn number(self: *Compiler) void {
        const value: Value = std.fmt.parseFloat(self.prev_tkn.literal) catch |err| {
            @panic(@errorName(err));
        };

        self.emitConstant(value);
    }

    fn emitConstant(self: *Compiler, value: Value) void {
        self.emitBytes(&.{
            OpCode.byte(.op_constant),
            self.makeConstant(value),
        });
    }

    fn makeConstant(self: *Compiler, value: Value) u8 {
        const const_idx: usize = self.compiling_chunk.writeConstant(value);

        if (const_idx > Compiler.U8_MAX) {
            self.@"error"("Too many constants in one chunk.");
            return 0;
        }

        return @as(u8, @truncate(const_idx));
    }

    // Expression parsing

    fn parsePrecedence(self: *Compiler, precedence: Precedence) void {
        self.advance();

        const prefix_rule = Compiler.rules.get(self.prev_tkn.type).prefix;

        if (prefix_rule) |rule| {
            rule(self);
        } else {
            self.@"error"("Expected expression.");
            return;
        }

        while (@intFromEnum(precedence) <= @intFromEnum(Compiler.rules.get(self.curr_tkn.type).precedence)) {
            self.advance();
            const infix_rule = Compiler.rules.get(self.prev_tkn.type).infix;

            infix_rule.?(self);
        }
    }

    fn expression(self: *Compiler) void {
        self.parsePrecedence(.assignment);
    }

    fn grouping(self: *Compiler) void {
        self.expression();
        self.consume(.tkn_right_paren, "Expected ')' after expression.");
    }

    fn unary(self: *Compiler) void {
        const op_type: Token.Type = self.prev_tkn.type;

        // compile the operand.
        self.parsePrecedence(.unary);

        // emit the operator instruction
        switch (op_type) {
            .tkn_dash => self.emitByte(OpCode.byte(.op_negate)),
            else => unreachable, // confirm this
        }
    }

    fn binary(self: *Compiler) void {
        const op_type: Token.Type = self.prev_tkn.type;
        const rule: *ParseRule = Compiler.rules.get(op_type);
        self.parsePrecedence(rule.precedence);

        switch (op_type) {
            .tkn_plus => self.emitByte(OpCode.byte(.op_addition)),
            .tkn_dash => self.emitByte(OpCode.byte(.op_subtraction)),
            .tkn_star => self.emitByte(OpCode.byte(.op_multiply)),
            .tkn_slash => self.emitByte(OpCode.byte(.op_divide)),
            else => unreachable,
        }
    }

    // ==============================

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
