const c = @import("c.zig").imports;
const std = @import("std");

const ArrayList = std.ArrayList;
pub const Window = struct {
    connection: ?*c.xcb_connection_t,
    cookies: ArrayList(XcbCookieWithSrc),
    screen: *c.xcb_screen_t,
    window: c.xcb_window_t,

    pub fn init(allocator: std.mem.Allocator) Window {
        const conn = c.xcb_connect(null, null);
        const screen: *c.xcb_screen_t = c.xcb_setup_roots_iterator(c.xcb_get_setup(conn)).data;
        const gcid = c.xcb_generate_id(conn);
        const gc_cookie = c.xcb_create_gc(conn, gcid, screen.root, c.XCB_GC_FOREGROUND | c.XCB_GC_GRAPHICS_EXPOSURES, &@as([2]u32, .{ screen.black_pixel, 0 }));
        var cookies = ArrayList(XcbCookieWithSrc).init(allocator);
        cookies.append(.{ .sequence = gc_cookie.sequence, .src = "xcb_create_gc" }) catch |e| {
            std.log.err("Error: {any}\n", .{e});
        };

        const wid = c.xcb_generate_id(conn);
        const win_mask: c_int = c.XCB_CW_BACK_PIXEL | c.XCB_CW_BORDER_PIXEL | c.XCB_CW_EVENT_MASK;
        const win_cookie = c.xcb_create_window(conn, c.XCB_COPY_FROM_PARENT, wid, screen.root, 0, 0, 500, 500, 15, c.XCB_WINDOW_CLASS_INPUT_OUTPUT, screen.root_visual, win_mask, &@as(
            [3]u32,
            .{ screen.white_pixel, screen.black_pixel, c.XCB_EVENT_MASK_EXPOSURE | c.XCB_EVENT_MASK_BUTTON_PRESS | c.XCB_EVENT_MASK_KEY_PRESS },
        ));
        cookies.append(.{ .sequence = win_cookie.sequence, .src = "xcb_create_window" }) catch |e| {
            std.log.err("Error: {any}\n", .{e});
        };

        const map_cookie = c.xcb_map_window(conn, wid);
        cookies.append(.{ .sequence = map_cookie.sequence, .src = "xcb_map_window" }) catch |e| {
            std.log.err("Error: {any}\n", .{e});
        };

        const win: Window = .{ .connection = conn, .cookies = cookies, .screen = screen, .window = wid };

        const flush = c.xcb_flush(conn);
        if (flush != 1) std.log.warn("Abnormal XCB Flush Response Code {d}\n", .{flush});

        return win;
    }

    pub fn loop(self: *Window) bool {
        const code = c.xcb_connection_has_error(self.connection);
        if (code > 0) {
            std.log.err("XCB Connection Error Code {d}\n", .{code});
            return false;
        }
        const event: *c.xcb_generic_event_t = c.xcb_wait_for_event(self.connection) orelse return false;
        const ev_code = event.response_type & ~@as(u8, 0x80);
        switch (ev_code) {
            c.XCB_EXPOSE => {
                std.log.debug("expose ev\n", .{});
            },
            0 => {
                const err: *c.xcb_generic_error_t = @ptrCast(event);
                std.log.err("XCB Error Event Details {any}", .{err});
                for (self.cookies.items) |cookie| {
                    if (cookie.sequence == err.sequence) {
                        std.log.err("XCB Error Event Source: {s}", .{cookie.src});
                    }
                }
                return false;
            },
            else => {
                std.log.debug("other ev", .{});
            },
        }
        return true;
    }

    pub fn deinit(self: *Window) void {
        std.log.info("Disconnecting from X11 server", .{});
        _ = c.xcb_disconnect(self.connection);
        self.cookies.deinit();
    }
};
const XcbCookieWithSrc = struct { sequence: c_uint, src: []const u8 };
