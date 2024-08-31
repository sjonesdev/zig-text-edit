const std = @import("std");
const log = std.log;
const Window = @import("lib/win.zig").Window;
const GeneralPurposeAllocator = std.heap.GeneralPurposeAllocator;

pub fn main() !void {
    log.info("Starting zig-text-edit...", .{});
    var gpa = GeneralPurposeAllocator(.{}){};
    var win = try Window.init(gpa.allocator());
    defer win.deinit();
    std.debug.print("win: {any}\n\n", .{win});
    while (try win.loop()) {}
}
