const c = @import("c.zig").imports;
const std = @import("std");
const Allocator = std.mem.Allocator;

const defaultHeight = 500;
const defaultWidth = 500;
const defaultBorder = 100;
const rowHeight = 15;
const fontName = "fixed";
const unitWidth = 20;
const unitHeight = 30;
const cursorBorder = 25;

const Vector2d = struct { x: f64, y: f64 };
const ArrayList = std.ArrayList;
const MouseButtons = enum(u32) { LMB = 1, RMB = 3, SCROLL_UP = 4, SCROLL_DOWN = 5, THUMB_BACK = 8, THUMB_FRONT = 9 };
pub const Window = struct {
    content_buffer: ArrayList(u8),
    cursor: Vector2d = .{ .x = cursorBorder, .y = cursorBorder * 2 },
    connection: ?*c.xcb_connection_t,
    screen: *c.xcb_screen_t,
    window: c.xcb_window_t,
    ctx: *c.cairo_t,
    surface: *c.cairo_surface_t,
    height: u16 = defaultHeight,
    width: u16 = defaultWidth,
    border: u16 = defaultBorder,
    shifted: u8 = 0,

    pub fn init(allocator: Allocator) !Window {
        const conn = c.xcb_connect(null, null);
        errdefer c.xcb_disconnect(conn);

        const screen: *c.xcb_screen_t = c.xcb_setup_roots_iterator(c.xcb_get_setup(conn)).data;

        const wid = c.xcb_generate_id(conn);
        const win_mask: c_int = c.XCB_CW_BACK_PIXEL | c.XCB_CW_BORDER_PIXEL | c.XCB_CW_EVENT_MASK;
        const win_cookie = c.xcb_create_window_checked(conn, c.XCB_COPY_FROM_PARENT, wid, screen.root, 0, 0, defaultWidth, defaultHeight, defaultBorder, c.XCB_WINDOW_CLASS_INPUT_OUTPUT, screen.root_visual, win_mask, &@as(
            [3]u32,
            .{ screen.white_pixel, screen.black_pixel, c.XCB_EVENT_MASK_EXPOSURE | c.XCB_EVENT_MASK_BUTTON_PRESS | c.XCB_EVENT_MASK_KEY_PRESS | c.XCB_EVENT_MASK_KEY_RELEASE | c.XCB_EVENT_MASK_STRUCTURE_NOTIFY },
        ));
        testCookie(conn, win_cookie, "xcb_create_window_checked");

        const map_cookie = c.xcb_map_window_checked(conn, wid);
        testCookie(conn, map_cookie, "xcb_map_window_checked");

        flush(conn);

        const visual = lookupVisual(screen, screen.root_visual).?;
        const surface = c.cairo_xcb_surface_create(conn, wid, visual, defaultWidth, defaultHeight).?;
        const ctx = c.cairo_create(surface).?;

        c.cairo_select_font_face(ctx, "monospace", c.CAIRO_FONT_SLANT_NORMAL, c.CAIRO_FONT_WEIGHT_NORMAL);
        c.cairo_set_font_size(ctx, 32);
        // var te: c.cairo_text_extents_t = undefined;
        // c.cairo_text_extents(ctx, "aaaaaaaaaaaaaaaaaaaaaaaaa", &te);
        // c.cairo_set_source_rgb(ctx, 0, 0, 0);
        // c.cairo_move_to(ctx, 0.5 - te.width / 2 - te.x_bearing, 0.5 - te.height / 2 - te.y_bearing);
        // c.cairo_show_text(ctx, "aaaaaaaaaaaaaaaaaaaaaaaaa");
        // c.cairo_paint_with_alpha(ctx, 0.5);

        const content_buffer = ArrayList(u8).init(allocator);
        const win: Window = .{ .connection = conn, .screen = screen, .window = wid, .ctx = ctx, .surface = surface, .content_buffer = content_buffer };

        return win;
    }

    fn render(_: *Window) !void {
        // const str = "Hello World!";
        // const rectangles: [1]c.xcb_rectangle_t = .{.{
        //     .x = 15,
        //     .y = 15,
        //     .width = self.width - 30,
        //     .height = self.height - 30,
        // }};
        // var cookie = c.xcb_poly_rectangle_checked(self.connection, self.window, self.gc, rectangles.len, &rectangles);
        // self.testCookie(cookie, "xcb_poly_rectangle_checked");
        // cookie = c.xcb_image_text_8_checked(self.connection, str.len, self.window, self.gc, 10, defaultHeight - 10, str);
        // self.testCookie(cookie, "xcb_image_text_8_checked");

        // try self.content_buffer.append(0);
        // // const str_ptr: [*c]const u8 = self.content_buffer.items.ptr;
        // var te: c.cairo_text_extents_t = undefined;
        // c.cairo_text_extents(self.ctx, self.content_buffer.items.ptr, &te);
        // std.debug.print("{any}", .{te});
        // c.cairo_move_to(self.ctx, 0, te.height);
        // c.cairo_show_text(self.ctx, self.content_buffer.items.ptr);
        // _ = self.content_buffer.pop();

        // c.cairo_surface_flush(self.surface);

        // flush(self.connection);
    }

    pub fn loop(self: *Window) !bool {
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
                // try self.render();
                c.cairo_rectangle(self.ctx, self.cursor.x, self.cursor.y, 3, -unitHeight);
                c.cairo_fill(self.ctx);
                c.cairo_move_to(self.ctx, self.cursor.x, self.cursor.y);
                c.cairo_surface_flush(self.surface);
                flush(self.connection);
            },
            c.XCB_CONFIGURE_NOTIFY => {
                std.log.debug("configure notify", .{});
                const cfg: *c.xcb_configure_notify_event_t = @ptrCast(event);
                self.height = cfg.height;
                self.width = cfg.width;
                c.cairo_xcb_surface_set_size(self.surface, cfg.width, cfg.height);
                std.log.debug("bw: {d}", .{cfg.border_width}); // TODO why 0
            },
            c.XCB_BUTTON_PRESS => {
                const press: *c.xcb_button_press_event_t = @ptrCast(event);
                std.log.debug("mb{d} ev at ({d},{d})", .{ press.detail, press.event_x, press.event_y });
                switch (@as(MouseButtons, @enumFromInt(press.detail))) {
                    MouseButtons.LMB => {
                        std.log.debug("LMB", .{});
                    },
                    else => {
                        std.log.debug("Other MB", .{});
                    },
                }
            },
            c.XCB_KEY_PRESS => {
                const press: *c.xcb_key_press_event_t = @ptrCast(event);
                if (press.detail < keymap.len) {
                    if (keymap[press.detail]) |key| {
                        switch (key) {
                            .char => |char| {
                                var ch: u8 = undefined;
                                if (self.shifted > 0) {
                                    ch = shiftedKeymap[press.detail].?.char;
                                } else {
                                    ch = char;
                                }
                                std.log.debug("Pressed key {c}", .{ch});
                                try self.content_buffer.append(ch);
                                // try self.render();
                                const buf: [2]u8 = .{ ch, 0 };
                                var te: c.cairo_text_extents_t = undefined;
                                c.cairo_text_extents(self.ctx, &buf, &te);
                                std.debug.print("{any}", .{te});

                                c.cairo_set_source_rgb(self.ctx, 1, 1, 1);
                                c.cairo_rectangle(self.ctx, self.cursor.x, self.cursor.y, 3, -unitHeight);
                                c.cairo_fill(self.ctx);
                                c.cairo_move_to(self.ctx, self.cursor.x, self.cursor.y);
                                self.cursor.x += unitWidth;
                                if (self.cursor.x >= @as(f64, @floatFromInt(self.width)) - cursorBorder) {
                                    self.cursor.x = cursorBorder;
                                    self.cursor.y += unitHeight;
                                }
                                c.cairo_set_source_rgb(self.ctx, 0, 0, 0);
                                c.cairo_show_text(self.ctx, &buf);
                                c.cairo_rectangle(self.ctx, self.cursor.x, self.cursor.y, 3, -unitHeight);
                                c.cairo_fill(self.ctx);
                                c.cairo_surface_flush(self.surface);
                                flush(self.connection);
                            },
                            .mod => |mod| {
                                if (mod == ModKeys.Shift) {
                                    self.shifted += 1;
                                    std.debug.print("shift\n", .{});
                                }
                            },
                        }
                    }
                }
            },
            c.XCB_KEY_RELEASE => {
                const press: *c.xcb_key_press_event_t = @ptrCast(event);
                std.log.debug("keypress {d} {d} ev", .{ press.event, press.detail });
                if (press.detail < keymap.len) {
                    if (keymap[press.detail]) |key| {
                        switch (key) {
                            .mod => |mod| {
                                if (mod == ModKeys.Shift) {
                                    self.shifted -= 1;
                                    std.debug.print("unshift\n", .{});
                                }
                            },
                            .char => {},
                        }
                    }
                }
            },
            0 => {
                const err: *c.xcb_generic_error_t = @ptrCast(event);
                std.log.err("XCB Error Event Details {any}", .{err});
                // for (self.cookies.items) |cookie| {
                //     if (cookie.sequence == err.sequence) {
                //         std.log.err("XCB Error Event Source: {s}", .{cookie.src});
                //     }
                // }
                return false;
            },
            else => {
                std.log.debug("other ev", .{});
            },
        }
        c.free(event);
        return true;
    }

    /// Do not call this if closing the window is intended to be the end of the program.
    /// Only call when the program is intended to stay running.
    pub fn free(self: *Window) void {
        std.log.info("Freeing window memory {any}", .{self});
        // TODO
    }

    /// Always call this when closing a window
    pub fn deinit(self: *Window) void {
        std.log.info("Disconnecting from X11 server", .{});
        c.xcb_disconnect(self.connection);
    }
};

fn lookupVisual(s: *c.xcb_screen_t, visual: c.xcb_visualid_t) ?*c.xcb_visualtype_t {
    var d = c.xcb_screen_allowed_depths_iterator(s);
    while (d.rem != 0) {
        var v = c.xcb_depth_visuals_iterator(d.data);
        while (v.rem != 0) {
            const vtype: *c.xcb_visualtype_t = @ptrCast(v.data);
            if (vtype.visual_id == visual) {
                return v.data;
            }
            c.xcb_visualtype_next(&v);
        }
        c.xcb_depth_next(&d);
    }
    return null;
}

fn testCookie(conn: ?*c.xcb_connection_t, cookie: c.xcb_void_cookie_t, err_msg: []const u8) void {
    const opterr: ?*c.xcb_generic_error_t = c.xcb_request_check(conn, cookie);
    if (opterr) |err| {
        std.log.err("{s} : {d}, disconnecting from X11 server", .{ err_msg, err.error_code });
        c.xcb_disconnect(conn);
        @panic("Program closed from X11 error");
    }
}

fn flush(conn: ?*c.xcb_connection_t) void {
    const res = c.xcb_flush(conn);
    if (res != 1) std.log.warn("Abnormal XCB Flush Response Code {d}", .{res});
}

const ModKeys = enum {
    Shift,
};
const Keymap = union(enum) { char: u8, mod: ModKeys };

const keymap: [66]?Keymap = .{
    null, // keycode 0
    null, // keycode 1
    null, // keycode 2
    null, // keycode 3
    null, // keycode 4
    null, // keycode 5
    null, // keycode 6
    null, // keycode 7
    null, // keycode 8
    null, // ESC
    Keymap{ .char = '1' }, Keymap{ .char = '2' }, Keymap{ .char = '3' }, Keymap{ .char = '4' }, Keymap{ .char = '5' }, Keymap{ .char = '6' }, Keymap{ .char = '7' }, Keymap{ .char = '8' }, Keymap{ .char = '9' }, Keymap{ .char = '0' }, // nums
    Keymap{ .char = '-' }, Keymap{ .char = '=' },
    null, // BACKSPACE
    null, // TAB
    Keymap{ .char = 'q' }, Keymap{ .char = 'w' }, Keymap{ .char = 'e' }, Keymap{ .char = 'r' }, Keymap{ .char = 't' }, Keymap{ .char = 'y' }, Keymap{ .char = 'u' }, Keymap{ .char = 'i' }, Keymap{ .char = 'o' }, Keymap{ .char = 'p' }, Keymap{ .char = '[' }, Keymap{ .char = ']' }, // qwerty row
    null, // ENTER
    null, // LCTRL
    Keymap{ .char = 'a' }, Keymap{ .char = 's' }, Keymap{ .char = 'd' }, Keymap{ .char = 'f' }, Keymap{ .char = 'g' }, Keymap{ .char = 'h' }, Keymap{ .char = 'j' }, Keymap{ .char = 'k' }, Keymap{ .char = 'l' }, Keymap{ .char = ';' }, Keymap{ .char = '\'' }, // asdf row
    null,
    Keymap{ .mod = ModKeys.Shift }, // LSHIFT
    Keymap{ .char = '\\' }, Keymap{ .char = 'z' }, Keymap{ .char = 'x' }, Keymap{ .char = 'c' }, Keymap{ .char = 'v' }, Keymap{ .char = 'b' }, Keymap{ .char = 'n' }, Keymap{ .char = 'm' }, Keymap{ .char = ',' }, Keymap{ .char = '.' }, Keymap{ .char = '/' }, // zxcv row
    Keymap{ .mod = ModKeys.Shift }, // RSHIFT keycode 62
    null, // pretty sure tis is the menu button
    null, // LALT
    Keymap{ .char = ' ' },
};

const shiftedKeymap: [66]?Keymap = .{
    null, // keycode 0
    null, // keycode 1
    null, // keycode 2
    null, // keycode 3
    null, // keycode 4
    null, // keycode 5
    null, // keycode 6
    null, // keycode 7
    null, // keycode 8
    null, // ESC
    Keymap{ .char = '!' }, Keymap{ .char = '@' }, Keymap{ .char = '#' }, Keymap{ .char = '$' }, Keymap{ .char = '%' }, Keymap{ .char = '^' }, Keymap{ .char = '&' }, Keymap{ .char = '*' }, Keymap{ .char = '(' }, Keymap{ .char = ')' }, // nums
    Keymap{ .char = '_' }, Keymap{ .char = '+' },
    null, // BACKSPACE
    null, // TAB
    Keymap{ .char = 'Q' }, Keymap{ .char = 'W' }, Keymap{ .char = 'E' }, Keymap{ .char = 'R' }, Keymap{ .char = 'T' }, Keymap{ .char = 'Y' }, Keymap{ .char = 'U' }, Keymap{ .char = 'I' }, Keymap{ .char = 'O' }, Keymap{ .char = 'P' }, Keymap{ .char = '{' }, Keymap{ .char = '}' }, // qwerty row
    null, // ENTER
    null, // LCTRL
    Keymap{ .char = 'A' }, Keymap{ .char = 'S' }, Keymap{ .char = 'D' }, Keymap{ .char = 'F' }, Keymap{ .char = 'G' }, Keymap{ .char = 'H' }, Keymap{ .char = 'J' }, Keymap{ .char = 'K' }, Keymap{ .char = 'L' }, Keymap{ .char = ':' }, Keymap{ .char = '"' }, // asdf row
    null,
    Keymap{ .mod = ModKeys.Shift }, // LSHIFT
    Keymap{ .char = '|' }, Keymap{ .char = 'Z' }, Keymap{ .char = 'X' }, Keymap{ .char = 'C' }, Keymap{ .char = 'V' }, Keymap{ .char = 'B' }, Keymap{ .char = 'N' }, Keymap{ .char = 'M' }, Keymap{ .char = '<' }, Keymap{ .char = '>' }, Keymap{ .char = '?' }, // zxcv row
    Keymap{ .mod = ModKeys.Shift }, // RSHIFT
    null,
    null,
    Keymap{ .char = ' ' },
};
