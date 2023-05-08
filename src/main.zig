const std = @import("std");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len != 2) {
        std.debug.print("Expected one file path!\n", .{});
        std.process.exit(1);
    }

    const file = try std.fs.cwd().openFile(args[1], .{ .mode = std.fs.File.OpenMode.read_only });
    defer file.close();
    const file_contents = try file.readToEndAlloc(allocator, std.math.maxInt(u32));
    defer allocator.free(file_contents);

    var ch_ptr: usize = 0;
    var ptr: usize = 0;
    var memory = [_]u8{0} ** 30_000;
    var loop_starts = std.ArrayList(usize).init(allocator);
    defer loop_starts.deinit();

    const stdout = std.io.getStdOut().writer();
    const stdin = std.io.getStdIn().reader();

    while (ch_ptr < file_contents.len) {
        switch (file_contents[ch_ptr]) {
            '>' => ptr +|= 1,
            '<' => ptr -|= 1,
            '+' => memory[ptr] +%= 1,
            '-' => memory[ptr] -%= 1,
            '.' => try stdout.writeByte(memory[ptr]),
            ',' => memory[ptr] = try stdin.readByte(),
            '[' => {
                try loop_starts.append(ch_ptr);
                if (memory[ptr] == 0) {
                    var loop_depth: usize = 1;
                    while (ch_ptr < file_contents.len and loop_depth > 0) {
                        ch_ptr += 1;
                        if (ch_ptr < file_contents.len) {
                            switch (file_contents[ch_ptr]) {
                                '[' => loop_depth += 1,
                                ']' => loop_depth -= 1,
                                else => {},
                            }
                        }
                    }
                    if (file_contents[ch_ptr] != ']') {
                        std.debug.print("Unclosed loop at {} index!\n", .{loop_starts.pop()});
                        std.process.exit(1);
                    }
                    ch_ptr -= 1;
                }
            },
            ']' => {
                if (loop_starts.popOrNull()) |loop_start| {
                    if (memory[ptr] != 0)
                        ch_ptr = loop_start - 1;
                } else {
                    std.debug.print("No matching loop at {} index!\n", .{ch_ptr});
                    std.process.exit(1);
                }
            },
            else => {},
        }
        ch_ptr += 1;
        ptr = std.math.clamp(ptr, 0, 30_000 - 1);
    }
}
