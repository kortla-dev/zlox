const std = @import("std");

const Cursor = @import("Cursor.zig");
const Token = Cursor.Token;

pub const Compiler = struct {
    const U8_MAX = std.math.maxInt(u8);

    cursor: Cursor,
    curr_tkn: Token,
    prev_tkn: Token,

    had_error: bool = false,
    panic_mode: bool = false,

    pub fn init() Compiler {}
};
