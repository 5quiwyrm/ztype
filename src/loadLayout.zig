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
    pub fn getFinger(self: *const Layout, letter: u8) !i8 {
        for (0..self.rows.len) |rowN| {
            const row = self.rows[rowN];
            if (std.mem.containsAtLeast(u8, row, 1, &.{letter})) {
                const idx = std.mem.indexOf(u8, row, &.{letter}).?;
                return @as(i8, @intCast(self.fingermap[rowN][idx]));
            }
        }
        return statError.LetterNotFound;
    }

    /// true = right, false = left
    /// Returns an error if the letter isn't found.
    pub fn getHand(self: *const Layout, letter: u8) !bool {
        return ((try self.getFinger(letter)) <= 5);
    }

    /// Returns an error if the letter isn't found.
    pub fn getRow(self: *const Layout, letter: u8) !i8 {
        for (0..self.rows.len) |rowN| {
            if (std.mem.containsAtLeast(u8, self.rows[rowN], 1, &.{letter})) {
                return @as(i8, @intCast(rowN));
            }
        }
        return statError.LetterNotFound;
    }

    pub fn isThumb(self: *const Layout, letter: u8) !bool {
        const finger = try self.getFinger(letter);
        return (finger == 4) or (finger == 5);
    }

    pub fn isSFB(self: *const Layout, bigram: []const u8) !bool {
        if (bigram.len != 2) return statError.BadNGramLen;
        return (bigram[0] != bigram[1]) and ((try self.getFinger(bigram[0])) == (try self.getFinger(bigram[1])));
    }

    pub fn isSFR(self: *const Layout, bigram: []const u8) !bool {
        _ = self;
        if (bigram.len != 2) return statError.BadNGramLen;
        return (bigram[0] == bigram[1]);
    }

    pub fn isFSB(self: *const Layout, bigram: []const u8) !bool {
        if (bigram.len != 2) return statError.BadNGramLen;
        return (@abs((try self.getFinger(bigram[1])) - (try self.getFinger(bigram[0]))) == 1) and (@abs((try self.getRow(bigram[1])) - (try self.getRow(bigram[0]))) == 2);
    }

    pub fn isHSB(self: *const Layout, bigram: []const u8) !bool {
        if (bigram.len != 2) return statError.BadNGramLen;
        return (@abs((try self.getFinger(bigram[1])) - (try self.getFinger(bigram[0]))) == 1) and (@abs((try self.getRow(bigram[1])) - (try self.getRow(bigram[0]))) == 1);
    }

    pub fn isDSFB(self: *const Layout, trigram: []const u8) !bool {
        if (trigram.len != 3) return statError.BadNGramLen;
        return (trigram[0] != trigram[2]) and (try self.getFinger(trigram[0]) == try self.getFinger(trigram[2]));
    }

    pub fn isDSFR(self: *const Layout, trigram: []const u8) !bool {
        _ = self;
        if (trigram.len != 3) return statError.BadNGramLen;
        return (trigram[0] == trigram[2]);
    }

    pub fn isAlt(self: *const Layout, trigram: []const u8) !bool {
        if (trigram.len != 3) return statError.BadNGramLen;
        return (((try self.getHand(trigram[0])) != (try self.getHand(trigram[1]))) and ((try self.getHand(trigram[1])) != (try self.getHand(trigram[2]))));
    }

    pub fn isRed(self: *const Layout, trigram: []const u8) !bool {
        if (trigram.len != 3) return statError.BadNGramLen;
        return ((((try self.getHand(trigram[0])) == (try self.getHand(trigram[1]))) and ((try self.getHand(trigram[1])) == (try self.getHand(trigram[2])))) and (((try self.getFinger(trigram[0])) != (try self.getFinger(trigram[1]))) and ((try self.getFinger(trigram[1])) != (try self.getFinger(trigram[2])))) and (((try self.getFinger(trigram[0])) < (try self.getFinger(trigram[1]))) != ((try self.getFinger(trigram[1])) < (try self.getFinger(trigram[2])))) and (!(try self.isThumb(trigram[0])) and !(try self.isThumb(trigram[1])) and !(try self.isThumb(trigram[2]))));
    }

    pub fn isOneh(self: *const Layout, trigram: []const u8) !bool {
        if (trigram.len != 3) return statError.BadNGramLen;
        return (((try self.getHand(trigram[0])) == (try self.getHand(trigram[1]))) and ((try self.getHand(trigram[1])) == (try self.getHand(trigram[2]))));
    }

    pub fn isBigramInroll(self: *const Layout, bigram: []const u8) !bool {
        if (bigram.len != 2) return statError.BadNGramLen;
        return (((try self.getHand(bigram[0])) == (try self.getHand(bigram[1]))) and (((try self.getFinger(bigram[0])) < (try self.getFinger(bigram[1]))) == (try self.getHand(bigram[0]))));
    }

    pub fn isInroll(self: *const Layout, trigram: []const u8) !bool {
        if (trigram.len != 3) return statError.BadNGramLen;
        return ((!(try self.isOneh(trigram))) and ((try self.isBigramInroll(trigram[0..2])) or (try self.isBigramInroll(trigram[1..]))));
    }

    pub fn isIn3roll(self: *const Layout, trigram: []const u8) !bool {
        if (trigram.len != 3) return statError.BadNGramLen;
        return ((try self.isOneh(trigram)) and (((try self.getFinger(trigram[0])) > (try self.getFinger(trigram[1]))) and ((try self.getFinger(trigram[1])) > (try self.getFinger(trigram[2]))) != (try self.getHand(trigram[0]))));
    }

    pub fn isBigramOutroll(self: *const Layout, bigram: []const u8) !bool {
        if (bigram.len != 2) return statError.BadNGramLen;
        return (((try self.getHand(bigram[0])) == (try self.getHand(bigram[1]))) and (((try self.getFinger(bigram[0])) < (try self.getFinger(bigram[1]))) != (try self.getHand(bigram[0]))));
    }

    pub fn isOutroll(self: *const Layout, trigram: []const u8) !bool {
        if (trigram.len != 3) return statError.BadNGramLen;
        return ((!(try self.isOneh(trigram))) and ((try self.isBigramOutroll(trigram[0..2])) or (try self.isBigramOutroll(trigram[1..]))));
    }

    pub fn isOut3roll(self: *const Layout, trigram: []const u8) !bool {
        if (trigram.len != 3) return statError.BadNGramLen;
        return ((try self.isOneh(trigram)) and (((try self.getFinger(trigram[0])) > (try self.getFinger(trigram[1]))) and ((try self.getFinger(trigram[1])) > (try self.getFinger(trigram[2]))) == (try self.getHand(trigram[0]))));
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
    const sturdy = Layout{
        .name = &.{ 'w', 'h', 'i', 'r', 'l' },
        .rows = &.{
            &.{ 'q', 'g', 'd', 'f', 'v', 'z', 'l', 'u', 'o', 'y' },
            &.{ 'n', 's', 't', 'h', 'm', '\'', 'r', 'e', 'a', 'i' },
            &.{ 'b', 'c', 'p', 'w', 'k', 'x', 'j', ';', '.', ',' },
            &.{ ' ', '*' },
        },
        .fingermap = &.{
            &.{ 0, 1, 2, 3, 3, 6, 6, 7, 8, 9 },
            &.{ 0, 1, 2, 3, 3, 6, 6, 7, 8, 9 },
            &.{ 0, 1, 2, 3, 3, 6, 6, 7, 8, 9 },
            &.{ 4, 5 },
        },
        .magicrules = &.{ "wh".*, "y,".*, "gs".*, "sc".* },
        .magicchar = '*',
    };
    try sturdy.save(.{ .overwrite = true });
}
