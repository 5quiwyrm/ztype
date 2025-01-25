const std = @import("std");
pub var allocator = std.heap.page_allocator;

pub const SaveOptions = struct {
    overwrite: bool = false,
};

pub const MagicRule = [2]u8;
pub const statError = error{
    LetterNotFound,
    BadNGramLen,
};

pub const Layout = struct {
    name: []const u8,
    rows: []const []const u8,
    fingermap: []const []const u8,
    magicrules: ?[]const MagicRule,
    magicchar: u8,

    pub fn save(self: *const Layout, args: SaveOptions) !void {
        const layout_path = try allocator.alloc(u8, self.name.len + 5);
        std.mem.copyForwards(u8, layout_path, self.name);
        layout_path[self.name.len] = '.';
        layout_path[self.name.len + 1] = 'j';
        layout_path[self.name.len + 2] = 's';
        layout_path[self.name.len + 3] = 'o';
        layout_path[self.name.len + 4] = 'n';
        const layout_dir = try std.fs.cwd().openDir("layouts", .{});
        const layout_file = try layout_dir.createFile(layout_path, .{ .exclusive = !args.overwrite });
        _ = try std.json.stringify(self, .{}, layout_file.writer());
    }

    /// Returns an error if letter isn't found.
    pub fn getFinger(self: *const Layout, letter: u8) !u8 {
        for (0..self.rows.len) |rowN| {
            const row = self.rows[rowN];
            if (std.mem.containsAtLeast(u8, row, 1, &.{letter})) {
                const idx = std.mem.indexOf(u8, row, &.{letter});
                return self.fingermap[rowN][idx];
            }
        }
        return statError.LetterNotFound;
    }

    /// Returns an error if the letter isn't found.
    pub fn getRow(self: *const Layout, letter: u8) !u8 {
        for (0..self.rows.len) |rowN| {
            if (std.mem.containsAtLeast(u8, self.rows[rowN], 1, &.{letter})) {
                return rowN;
            }
        }
        return statError.LetterNotFound;
    }

    pub fn isSfb(self: *const Layout, bigram: []const u8) !bool {
        if (bigram.len != 2) return statError.BadNGramLen;
        return (bigram[0] != bigram[1]) and (self.getFinger(bigram[0]) == self.getFinger(bigram[1]));
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
            &.{ 0, 1, 2, 3, 3, 6, 6, 7, 8, 9 },
            &.{ 0, 1, 2, 3, 3, 6, 6, 7, 8, 9 },
            &.{ 1, 2, 3, 3, 3, 6, 6, 7, 8, 9 },
        },
        .magicrules = &.{[2]u8{ 'q', 'u' }},
        .magicchar = '*',
    };
    try kuntum.save(.{ .overwrite = true });
}
