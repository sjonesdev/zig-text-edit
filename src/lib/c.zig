pub const imports = @cImport({
    @cInclude("stdlib.h");
    @cInclude("xcb/xcb.h");
    @cInclude("cairo/cairo-xcb.h");
    @cInclude("cairo/cairo.h");
});
