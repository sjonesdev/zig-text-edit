const std = @import("std");
const log = std.log;
const Window = @import("lib/win.zig").Window;

pub fn main() !void {
    log.info("Starting zig-text-edit...", .{});
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    var win = Window.init(gpa.allocator());
    defer win.deinit();
    std.debug.print("win: {any}\n\n", .{win});
    while (win.loop()) {}
}
