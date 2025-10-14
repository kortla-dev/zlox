// pub fn Stack(comptime T: type, comptime stack_size: usize) type {
//     return struct {
//         stack: [stack_size]T = undefined,
//         stack_top: usize = 0,
//
//         pub fn init() @This() {
//             return @This(){};
//         }
//
//         pub fn push(s: *@This(), value: T) void {
//             s.stack[s.stack_top] = value;
//             s.stack_top += 1;
//         }
//
//         pub fn pop(s: *@This()) T {
//             s.stack_top -= 1;
//             return s.stack[s.stack_top];
//         }
//     };
// }

pub fn Stack(comptime T: type, comptime size: usize) type {
    return struct {
        const Self = @This();

        items: [size]T = undefined,
        stack_top: usize = 0,

        pub const Error = error{
            StackOverflow,
            StackUnderflow,
        };

        pub fn init() Self {
            return Self{};
        }

        pub fn push(s: *Self, value: T) Self.Error.StackOverflow!void {
            if (s.stack_top > size) return Self.Error.StackOverflow;

            s.items[s.stack_top] = value;
            s.stack_top += 1;
        }

        pub fn pop(s: *Self) Self.Error!T {
            if (s.stack_top == 0) return Self.Error.StackUnderflow;

            s.stack_top -= 1;
            return s.items[s.stack_top];
        }

        pub fn popOrNull(s: *Self) ?T {
            if (s.stack_top == 0) return null;

            s.stack_top -= 1;
            return s.items[s.stack_top];
        }

        pub fn pushUnsafe(s: *Self, value: T) void {
            if (s.stack_top > size) @panic("StackOverflow");

            s.items[s.stack_top] = value;
            s.stack_top += 1;
        }

        pub fn popUnsafe(s: *Self) T {
            if (s.stack_top == 0) @panic("StackUnderflow");

            s.stack_top -= 1;
            return s.items[s.stack_top];
        }
    };
}

const std = @import("std");

test "stack push pop" {
    var stack = Stack(i8, 2).init();
    stack.pushUnsafe(2);
    stack.pushUnsafe(1);

    try std.testing.expectEqual(1, stack.popUnsafe());

    stack.pushUnsafe(3);

    try std.testing.expectEqual(3, stack.popUnsafe());
    try std.testing.expectEqual(2, stack.popUnsafe());
}
