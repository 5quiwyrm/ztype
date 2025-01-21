const std = @import("std");
pub var allocator = std.heap.page_allocator;

pub const SaveOptions = struct {
    overwrite: bool = false,
};

pub const Layout = struct {
    name: []const u8,
    rows: []const []const u8,
    fingermap: []const []const u8,
    magicTriggers: ?[]const []const u8,
    magicResults: ?[]const []const u8,

    pub fn save(self: *const Layout, args: SaveOptions) !void {
        const layout_path = try allocator.alloc(u8, self.name.len + 5);
        std.mem.copyForwards(u8, layout_path, self.name);
        layout_path[self.name.len] = '.';
        layout_path[self.name.len + 1] = 'j';
        layout_path[self.name.len + 2] = 's';
        layout_path[self.name.len + 3] = 'o';
        layout_path[self.name.len + 4] = 'n';
        const layout_dir = try std.fs.cwd().openDir("layouts", .{});
        const layout_file = try layout_dir.createFile(layout_path, .{ .exclusive = args.overwrite });
        _ = try std.json.stringify(self, .{}, layout_file.writer());
    }
};

pub fn loadLayout(layoutname: []const u8) !Layout {
    var layout_dir = try std.fs.cwd().openDir("layouts", .{});
    defer layout_dir.close();
    const layout_path = try allocator.alloc(u8, layoutname.len + 5);
    defer allocator.free(layout_path);
    std.mem.copyForwards(u8, layout_path, layoutname);
    layout_path[layoutname.len] = '.';
    layout_path[layoutname.len + 1] = 'j';
    layout_path[layoutname.len + 2] = 's';
    layout_path[layoutname.len + 3] = 'o';
    layout_path[layoutname.len + 4] = 'n';
    const layout_file = layout_dir.openFile(layout_path, .{ .mode = .read_only }) catch |err| switch (@TypeOf(err)) {
        std.fs.File.OpenError => {
            std.debug.print("{s}.json doesn't exist!\n", .{layoutname});
            return err;
        },
        else => {
            std.debug.print("{}\n", .{err});
            return err;
        },
    };
    return (try std.json.parseFromSlice(Layout, allocator, try layout_file.readToEndAlloc(allocator, 2e6), .{})).value;
}

test "makekuntum" {
    const kuntum = Layout{
        .name = &.{ 'k', 'u', 'n', 't', 'u', 'm' },
        .rows = &.{
            &.{ 'v', 'l', 'n', 'd', 'k', 'j', 'w', 'o', 'u', ',' },
            &.{ 't', 's', 'r', 'h', 'f', 'g', 'c', 'a', 'e', 'i' },
            &.{ 'z', 'x', 'p', 'b', '\'', 'm', 'y', 'q', '/', '.' },
        },
        .fingermap = &.{
            &.{ 0, 1, 2, 3, 3, 4, 4, 5, 6, 7 },
            &.{ 0, 1, 2, 3, 3, 4, 4, 5, 6, 7 },
            &.{ 1, 2, 3, 3, 3, 4, 4, 5, 6, 7 },
        },
        .magicTriggers = null,
        .magicResults = null,
    };
    try kuntum.save(.{});
    const sturdy = try loadLayout("sturdy");
    std.debug.print("{any}\n", .{sturdy});
}
