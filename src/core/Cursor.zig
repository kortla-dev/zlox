const std = @import("std");
const mem = std.mem;

const Cursor = @This();

source: []const u8,
chr_ptr: usize,
peek: usize,
line: usize,

pub fn init(source: []const u8) Cursor {
    return Cursor{
        .source = source,
        .chr_ptr = 0,
        .peek = 0,
        .line = 1,
    };
}

pub fn nextToken(self: *Cursor) Token {
    self.skipWhitespace();
    self.chr_ptr = self.peek;

    if (self.isAtEnd()) return self.makeToken(.tkn_eof);

    const chr: u8 = self.advance();

    if (isAlpha(chr)) return self.makeIdentifierToken();
    if (isDigit(chr)) return self.makeNumberToken();

    return switch (chr) {
        '(' => self.makeToken(.tkn_left_paren),
        ')' => self.makeToken(.tkn_right_paren),
        '{' => self.makeToken(.tkn_left_brace),
        '}' => self.makeToken(.tkn_right_brace),
        ';' => self.makeToken(.tkn_semicolon),
        ',' => self.makeToken(.tkn_comma),
        '.' => self.makeToken(.tkn_dot),
        '-' => self.makeToken(.tkn_dash),
        '+' => self.makeToken(.tkn_plus),
        '/' => self.makeToken(.tkn_slash),
        '*' => self.makeToken(.tkn_star),

        // TODO: you have to increment self.peek if it matches the longer expresion
        //       (do the matching in a function or use inner labels (choose what you think is more maintainable))
        '!' => if (self.match('=')) self.makeToken(.tkn_bang_equal) else self.makeToken(.tkn_bang),
        '=' => if (self.match('=')) self.makeToken(.tkn_equal_equal) else self.makeToken(.tkn_equal),
        '<' => if (self.match('=')) self.makeToken(.tkn_less_equal) else self.makeToken(.tkn_less),
        '>' => if (self.match('=')) self.makeToken(.tkn_greater_equal) else self.makeToken(.tkn_greater),
        '"' => self.makeStringToken(),
        else => self.makeErrorToken("Unexpected charcter."),
    };

    // return self.makeErrorToken("Unexpected charcter.");
}

fn makeToken(self: *Cursor, token_type: Token.Type) Token {
    const token = Token{
        .type = token_type,
        .literal = self.source[self.chr_ptr..self.peek],
        .line = self.line,
    };
    // token.type = token_type;
    // token.literal = self.source[self.ptr..self.peek];
    // token.line = self.line;

    return token;
}

fn checkkeyword(
    self: *Cursor,
    start: usize,
    len: usize,
    rest: []const u8,
    token_type: Token.Type,
) Token.Type {
    const start_idx: usize = self.chr_ptr + start;
    const end_idx: usize = start_idx + len;

    if ((self.peek - self.chr_ptr == start + len) and
        mem.eql(u8, self.source[start_idx..end_idx], rest))
    {
        return token_type;
    }

    return .tkn_identifier;
}

fn identifierType(self: *Cursor) Token.Type {
    return switch (self.source[self.chr_ptr]) {
        'a' => self.checkkeyword(1, 2, "nd", .tkn_and),
        'c' => self.checkkeyword(1, 4, "lass", .tkn_class),
        'e' => self.checkkeyword(1, 3, "lse", .tkn_else),
        'f' => blk: {
            break :blk switch (self.source[self.chr_ptr + 1]) {
                'a' => self.checkkeyword(2, 3, "lse", .tkn_false),
                'o' => self.checkkeyword(2, 1, "r", .tkn_for),
                'u' => self.checkkeyword(2, 1, "n", .tkn_fun),
                else => .tkn_identifier,
            };
        },
        'i' => self.checkkeyword(1, 1, "f", .tkn_if),
        'n' => self.checkkeyword(1, 2, "il", .tkn_nil),
        'o' => self.checkkeyword(1, 1, "r", .tkn_or),
        'p' => self.checkkeyword(1, 4, "rint", .tkn_print),
        'r' => self.checkkeyword(1, 5, "eturn", .tkn_return),
        's' => self.checkkeyword(1, 4, "uper", .tkn_super),
        't' => blk: {
            break :blk switch (self.source[self.chr_ptr + 1]) {
                'h' => self.checkkeyword(2, 2, "is", .tkn_this),
                'r' => self.checkkeyword(2, 2, "ue", .tkn_true),
                else => .tkn_identifier,
            };
        },
        'v' => self.checkkeyword(1, 2, "ar", .tkn_var),
        'w' => self.checkkeyword(1, 4, "hile", .tkn_while),
        else => .tkn_identifier,
    };
}

fn makeIdentifierToken(self: *Cursor) Token {
    while (isAlphaNumeric(self.peekCurrent())) _ = self.advance();

    return self.makeToken(self.identifierType());
}

fn makeStringToken(self: *Cursor) Token {
    while ((self.peekCurrent() != '"') and !self.isAtEnd()) {
        if (self.peekCurrent() != '\n') self.line += 1;
        _ = self.advance();
    }

    if (self.isAtEnd()) return self.makeErrorToken("Unterminated string.");
    _ = self.advance();

    return self.makeToken(.tkn_string);
}

fn makeNumberToken(self: *Cursor) Token {
    while (isDigit(self.peekCurrent())) _ = self.advance();

    if (self.peekCurrent() == '.' and isDigit(self.peekNext())) {
        _ = self.advance();

        while (isDigit(self.peekCurrent())) _ = self.advance();
    }

    return self.makeToken(.tkn_number);
}

fn makeErrorToken(self: *Cursor, message: []const u8) Token {
    var token = self.makeToken(.tkn_error);
    token.literal = message;

    return token;
}

fn match(self: *Cursor, expected: u8) bool {
    if (self.isAtEnd()) return false;
    if (self.peek != expected) return false;
    self.peek += 1;

    return true;
}

fn isAtEnd(self: *Cursor) bool {
    return self.source[self.peek] == 0;
}

/// Returns the current character under self.peek and advances by 1
fn advance(self: *Cursor) u8 {
    const chr = self.source[self.peek];
    self.peek += 1;

    return chr;
}

/// This function is used to peek at the next character in the stream
fn peekNext(self: *Cursor) u8 {
    if (self.isAtEnd()) return 0;

    return self.source[self.peek + 1];
}

fn peekCurrent(self: *Cursor) u8 {
    return self.source[self.peek];
}

fn skipWhitespace(self: *Cursor) void {
    while (true) {
        const chr = self.peekCurrent();

        switch (chr) {
            ' ',
            '\r',
            '\t',
            => _ = self.advance(),
            '\n' => {
                self.line += 1;
                _ = self.advance();
            },
            '/' => {
                if (self.peekNext() == '/') {
                    while ((self.peekCurrent() != '\n') and (!self.isAtEnd())) _ = self.advance();
                } else {
                    return;
                }
            },
            else => return,
        }
    }
}

fn isAlpha(chr: u8) bool {
    return switch (chr) {
        'a'...'z',
        'A'...'Z',
        '_',
        => true,
        else => false,
    };
}

fn isDigit(chr: u8) bool {
    return switch (chr) {
        '0'...'9' => true,
        else => false,
    };
}

fn isAlphaNumeric(chr: u8) bool {
    return isAlpha(chr) or isDigit(chr);
}

pub const Token = struct {
    type: Token.Type,
    literal: []const u8,
    line: usize,

    pub fn byte(@"type": Token.Type) u8 {
        return @as(u8, @intFromEnum(@"type"));
    }

    pub const Type = enum {
        // Single-character tokens.
        tkn_left_paren,
        tkn_right_paren,
        tkn_left_brace,
        tkn_right_brace,
        tkn_comma,
        tkn_dot,
        tkn_dash,
        tkn_plus,
        tkn_semicolon,
        tkn_slash,
        tkn_star,

        // One or two character tokens.
        tkn_bang,
        tkn_bang_equal,
        tkn_equal,
        tkn_equal_equal,
        tkn_greater,
        tkn_greater_equal,
        tkn_less,
        tkn_less_equal,

        // Literals.
        tkn_identifier,
        tkn_string,
        tkn_number,

        // Keywords.
        tkn_and,
        tkn_class,
        tkn_else,
        tkn_false,
        tkn_for,
        tkn_fun,
        tkn_if,
        tkn_nil,
        tkn_or,
        tkn_print,
        tkn_return,
        tkn_super,
        tkn_this,
        tkn_true,
        tkn_var,
        tkn_while,

        tkn_error,
        tkn_eof,
    };

    // pub fn format(
    //     self: @This(),
    //     writer: anytype,
    // ) !void {
    //     const maybe_tag = std.meta.intToEnum(@TypeOf(self.type), @intFromEnum(self.type));
    //     if (maybe_tag) |valid_tag| {
    //         try writer.print("Token({s}, \"{s}\")", .{ @tagName(valid_tag), self.literal });
    //     } else {
    //         try writer.print("Token(INVALID({}), \"{s}\")", .{ @intFromEnum(self.type), self.literal });
    //     }
    // }

    pub fn format(
        self: @This(),
        writer: *std.Io.Writer,
    ) std.Io.Writer.Error!void {
        try writer.print("Token({s}, \"{s}\")", .{ @tagName(self.type), self.literal });
    }
};
