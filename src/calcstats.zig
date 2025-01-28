const std = @import("std");
const loadlayout = @import("loadLayout.zig");
const parsecorpus = @import("parseCorpus.zig");
const allocator = std.heap.page_allocator;
const arraylist = std.ArrayList;
const time = std.time;

pub fn sortfreqs(_: @TypeOf(.{}), lhs: parsecorpus.WordFreq, rhs: parsecorpus.WordFreq) bool {
    return (lhs.freq < rhs.freq);
}

pub const StatPrintOptions = struct {
    clear: bool = false,
};

pub const Stats = struct {
    layout: loadlayout.Layout,
    corpusname: []const u8,

    SFBtotal: f32,
    SFB: []parsecorpus.WordFreq,

    SFRtotal: f32,
    SFR: []parsecorpus.WordFreq,

    FSBtotal: f32,
    FSB: []parsecorpus.WordFreq,

    HSBtotal: f32,
    HSB: []parsecorpus.WordFreq,

    DSFBtotal: f32,
    DSFB: []parsecorpus.WordFreq,

    DSFRtotal: f32,
    DSFR: []parsecorpus.WordFreq,

    Redtotal: f32,
    Red: []parsecorpus.WordFreq,

    Onehtotal: f32,
    Oneh: []parsecorpus.WordFreq,

    alttotal: f32,
    alt: []parsecorpus.WordFreq,

    BInRtotal: f32,
    BInR: []parsecorpus.WordFreq,

    TInRtotal: f32,
    TInR: []parsecorpus.WordFreq,

    BOutRtotal: f32,
    BOutR: []parsecorpus.WordFreq,

    TOutRtotal: f32,
    TOutR: []parsecorpus.WordFreq,

    In3Rtotal: f32,
    In3R: []parsecorpus.WordFreq,

    Out3Rtotal: f32,
    Out3R: []parsecorpus.WordFreq,

    un_bigram: f32,
    un_trigram: f32,

    pub fn init(givenlayout: loadlayout.Layout, givencorpus: parsecorpus.Ngrams) !Stats {
        var sfblist = arraylist(parsecorpus.WordFreq).init(allocator);
        var sfbtotal: f32 = 0;
        var sfrlist = arraylist(parsecorpus.WordFreq).init(allocator);
        var sfrtotal: f32 = 0;
        var fsblist = arraylist(parsecorpus.WordFreq).init(allocator);
        var fsbtotal: f32 = 0;
        var hsblist = arraylist(parsecorpus.WordFreq).init(allocator);
        var hsbtotal: f32 = 0;
        var binlist = arraylist(parsecorpus.WordFreq).init(allocator);
        var bintotal: f32 = 0;
        var boutlist = arraylist(parsecorpus.WordFreq).init(allocator);
        var bouttotal: f32 = 0;
        var validbigrams: f32 = 0;
        var bigrams: f32 = 0;
        for (givencorpus.bigrams) |token| {
            bigrams += @floatFromInt(token.freq);
            const sfbness = givenlayout.isSFB(token.word) catch |err| switch (err) {
                loadlayout.statError.LetterNotFound => continue,
                loadlayout.statError.BadNGramLen => return err,
                else => unreachable,
            };
            if (sfbness) {
                try sfblist.append(token.toWordFreq());
                sfbtotal += @floatFromInt(token.freq);
            }
            const sfrness = givenlayout.isSFR(token.word) catch |err| switch (err) {
                loadlayout.statError.LetterNotFound => continue,
                loadlayout.statError.BadNGramLen => return err,
                else => unreachable,
            };
            if (sfrness) {
                try sfrlist.append(token.toWordFreq());
                sfrtotal += @floatFromInt(token.freq);
            }
            const fsbness = givenlayout.isFSB(token.word) catch |err| switch (err) {
                loadlayout.statError.LetterNotFound => continue,
                loadlayout.statError.BadNGramLen => return err,
                else => unreachable,
            };
            if (fsbness) {
                try fsblist.append(token.toWordFreq());
                fsbtotal += @floatFromInt(token.freq);
            }
            const hsbness = givenlayout.isHSB(token.word) catch |err| switch (err) {
                loadlayout.statError.LetterNotFound => continue,
                loadlayout.statError.BadNGramLen => return err,
                else => unreachable,
            };
            if (hsbness) {
                try hsblist.append(token.toWordFreq());
                hsbtotal += @floatFromInt(token.freq);
            }
            const binness = givenlayout.isBigramInroll(token.word) catch |err| switch (err) {
                loadlayout.statError.LetterNotFound => continue,
                loadlayout.statError.BadNGramLen => return err,
                else => unreachable,
            };
            if (binness) {
                try binlist.append(token.toWordFreq());
                bintotal += @floatFromInt(token.freq);
            }
            const boutness = givenlayout.isBigramOutroll(token.word) catch |err| switch (err) {
                loadlayout.statError.LetterNotFound => continue,
                loadlayout.statError.BadNGramLen => return err,
                else => unreachable,
            };
            if (boutness) {
                try boutlist.append(token.toWordFreq());
                bouttotal += @floatFromInt(token.freq);
            }
            validbigrams += @floatFromInt(token.freq);
        }
        for (sfblist.items) |*t| t.*.freq /= validbigrams;
        std.mem.sort(parsecorpus.WordFreq, sfblist.items, .{}, sortfreqs);
        sfbtotal /= validbigrams;
        for (sfrlist.items) |*t| t.*.freq /= validbigrams;
        sfrtotal /= validbigrams;
        for (fsblist.items) |*t| t.*.freq /= validbigrams;
        fsbtotal /= validbigrams;
        for (hsblist.items) |*t| t.*.freq /= validbigrams;
        hsbtotal /= validbigrams;
        for (binlist.items) |*t| t.*.freq /= validbigrams;
        bintotal /= validbigrams;
        for (boutlist.items) |*t| t.*.freq /= validbigrams;
        bouttotal /= validbigrams;
        const unaccounted_bigrams = 1 - validbigrams / bigrams;
        var dsfblist = arraylist(parsecorpus.WordFreq).init(allocator);
        var dsfbtotal: f32 = 0;
        var dsfrlist = arraylist(parsecorpus.WordFreq).init(allocator);
        var dsfrtotal: f32 = 0;
        var altlist = arraylist(parsecorpus.WordFreq).init(allocator);
        var alttotal: f32 = 0;
        var redlist = arraylist(parsecorpus.WordFreq).init(allocator);
        var redtotal: f32 = 0;
        var onehlist = arraylist(parsecorpus.WordFreq).init(allocator);
        var onehtotal: f32 = 0;
        var inrolllist = arraylist(parsecorpus.WordFreq).init(allocator);
        var inrolltotal: f32 = 0;
        var outrolllist = arraylist(parsecorpus.WordFreq).init(allocator);
        var outrolltotal: f32 = 0;
        var in3rolllist = arraylist(parsecorpus.WordFreq).init(allocator);
        var in3rolltotal: f32 = 0;
        var out3rolllist = arraylist(parsecorpus.WordFreq).init(allocator);
        var out3rolltotal: f32 = 0;
        var validtrigrams: f32 = 0;
        var trigrams: f32 = 0;
        for (givencorpus.trigrams) |token| {
            trigrams += @floatFromInt(token.freq);
            const dsfbness = givenlayout.isDSFB(token.word) catch |err| switch (err) {
                loadlayout.statError.LetterNotFound => continue,
                loadlayout.statError.BadNGramLen => return err,
                else => unreachable,
            };
            if (dsfbness) {
                try dsfblist.append(token.toWordFreq());
                dsfbtotal += @floatFromInt(token.freq);
            }
            const dsfrness = givenlayout.isDSFR(token.word) catch |err| switch (err) {
                loadlayout.statError.LetterNotFound => continue,
                loadlayout.statError.BadNGramLen => return err,
                else => unreachable,
            };
            if (dsfrness) {
                try dsfrlist.append(token.toWordFreq());
                dsfrtotal += @floatFromInt(token.freq);
            }
            const altness = givenlayout.isAlt(token.word) catch |err| switch (err) {
                loadlayout.statError.LetterNotFound => continue,
                loadlayout.statError.BadNGramLen => return err,
                else => unreachable,
            };
            if (altness) {
                try altlist.append(token.toWordFreq());
                alttotal += @floatFromInt(token.freq);
            }
            const redness = givenlayout.isRed(token.word) catch |err| switch (err) {
                loadlayout.statError.LetterNotFound => continue,
                loadlayout.statError.BadNGramLen => return err,
                else => unreachable,
            };
            if (redness) {
                try redlist.append(token.toWordFreq());
                redtotal += @floatFromInt(token.freq);
            }
            const onehness = givenlayout.isOneh(token.word) catch |err| switch (err) {
                loadlayout.statError.LetterNotFound => continue,
                loadlayout.statError.BadNGramLen => return err,
                else => unreachable,
            };
            if (onehness) {
                try onehlist.append(token.toWordFreq());
                onehtotal += @floatFromInt(token.freq);
            }
            const inrollness = givenlayout.isInroll(token.word) catch |err| switch (err) {
                loadlayout.statError.LetterNotFound => continue,
                loadlayout.statError.BadNGramLen => return err,
                else => unreachable,
            };
            if (inrollness) {
                try inrolllist.append(token.toWordFreq());
                inrolltotal += @floatFromInt(token.freq);
            }
            const in3rollness = givenlayout.isIn3roll(token.word) catch |err| switch (err) {
                loadlayout.statError.LetterNotFound => continue,
                loadlayout.statError.BadNGramLen => return err,
                else => unreachable,
            };
            if (in3rollness) {
                try in3rolllist.append(token.toWordFreq());
                in3rolltotal += @floatFromInt(token.freq);
            }
            const outrollness = givenlayout.isOutroll(token.word) catch |err| switch (err) {
                loadlayout.statError.LetterNotFound => continue,
                loadlayout.statError.BadNGramLen => return err,
                else => unreachable,
            };
            if (outrollness) {
                try outrolllist.append(token.toWordFreq());
                outrolltotal += @floatFromInt(token.freq);
            }
            const out3rollness = givenlayout.isOut3roll(token.word) catch |err| switch (err) {
                loadlayout.statError.LetterNotFound => continue,
                loadlayout.statError.BadNGramLen => return err,
                else => unreachable,
            };
            if (out3rollness) {
                try out3rolllist.append(token.toWordFreq());
                out3rolltotal += @floatFromInt(token.freq);
            }
            validtrigrams += @floatFromInt(token.freq);
        }
        for (dsfblist.items) |*t| t.*.freq /= validtrigrams;
        dsfbtotal /= validtrigrams;
        for (dsfrlist.items) |*t| t.*.freq /= validtrigrams;
        dsfrtotal /= validtrigrams;
        for (altlist.items) |*t| t.*.freq /= validtrigrams;
        alttotal /= validtrigrams;
        for (redlist.items) |*t| t.*.freq /= validtrigrams;
        redtotal /= validtrigrams;
        for (onehlist.items) |*t| t.*.freq /= validtrigrams;
        onehtotal /= validtrigrams;
        for (inrolllist.items) |*t| t.*.freq /= validtrigrams;
        inrolltotal /= validtrigrams;
        for (outrolllist.items) |*t| t.*.freq /= validtrigrams;
        outrolltotal /= validtrigrams;
        for (in3rolllist.items) |*t| t.*.freq /= validtrigrams;
        in3rolltotal /= validtrigrams;
        for (out3rolllist.items) |*t| t.*.freq /= validtrigrams;
        out3rolltotal /= validtrigrams;
        const unaccounted_trigrams = 1 - validtrigrams / trigrams;
        return Stats{
            .layout = givenlayout,
            .corpusname = givencorpus.corpusname,

            .SFBtotal = sfbtotal,
            .SFB = try sfblist.toOwnedSlice(),

            .SFRtotal = sfrtotal,
            .SFR = try sfrlist.toOwnedSlice(),

            .FSBtotal = fsbtotal,
            .FSB = try fsblist.toOwnedSlice(),

            .HSBtotal = hsbtotal,
            .HSB = try hsblist.toOwnedSlice(),

            .DSFBtotal = dsfbtotal,
            .DSFB = try dsfblist.toOwnedSlice(),

            .DSFRtotal = dsfrtotal,
            .DSFR = try dsfrlist.toOwnedSlice(),

            .Redtotal = redtotal,
            .Red = try redlist.toOwnedSlice(),

            .Onehtotal = onehtotal,
            .Oneh = try onehlist.toOwnedSlice(),

            .alttotal = alttotal,
            .alt = try altlist.toOwnedSlice(),

            .BInRtotal = bintotal,
            .BInR = try binlist.toOwnedSlice(),

            .BOutRtotal = bouttotal,
            .BOutR = try boutlist.toOwnedSlice(),

            .TInRtotal = inrolltotal,
            .TInR = try inrolllist.toOwnedSlice(),

            .TOutRtotal = outrolltotal,
            .TOutR = try outrolllist.toOwnedSlice(),

            .In3Rtotal = in3rolltotal,
            .In3R = try in3rolllist.toOwnedSlice(),

            .Out3Rtotal = out3rolltotal,
            .Out3R = try out3rolllist.toOwnedSlice(),

            .un_bigram = unaccounted_bigrams,
            .un_trigram = unaccounted_trigrams,
        };
    }

    pub fn print(self: *const Stats, options: StatPrintOptions) !void {
        if (options.clear) std.debug.print("\x1Bc", .{});
        std.debug.print("Layout: {s}\n", .{self.layout.name});
        for (self.layout.rows) |row| {
            for (row) |ch| {
                switch (ch) {
                    ' ' => {
                        std.debug.print("_ ", .{});
                    },
                    else => {
                        std.debug.print("{c} ", .{ch});
                    },
                }
            }
            std.debug.print("\n", .{});
        }
        if (self.layout.magicrules != null) {
            std.debug.print("Rules:\n", .{});
            for (self.layout.magicrules.?) |rule| {
                std.debug.print("{s} ", .{rule});
            }
            std.debug.print("\n", .{});
        }
        std.debug.print("\nCorpus: {s}\n\nOut of 10000:\n\n", .{self.corpusname});
        std.debug.print("SFB: {} | ", .{@as(i32, @intFromFloat(self.SFBtotal * 10000))});
        std.debug.print("SFS: {} | ", .{@as(i32, @intFromFloat(self.DSFBtotal * 10000))});
        std.debug.print("SFR: {}\n", .{@as(i32, @intFromFloat(self.SFRtotal * 10000))});
        std.debug.print("FSB: {} | ", .{@as(i32, @intFromFloat(self.FSBtotal * 10000))});
        std.debug.print("HSB: {}\n", .{@as(i32, @intFromFloat(self.HSBtotal * 10000))});
        std.debug.print("Oneh: {}\n", .{@as(i32, @intFromFloat(self.Onehtotal * 10000))});
        std.debug.print("Red: {}\n\n", .{@as(i32, @intFromFloat(self.Redtotal * 10000))});

        std.debug.print("Alt: {}\n", .{@as(i32, @intFromFloat(self.alttotal * 10000))});
        std.debug.print("Inroll: {} (3roll: {})\n", .{ @as(i32, @intFromFloat(self.TInRtotal * 10000)), @as(i32, @intFromFloat(self.In3Rtotal * 10000)) });
        std.debug.print("Outroll: {} (3roll: {})\n", .{ @as(i32, @intFromFloat(self.TOutRtotal * 10000)), @as(i32, @intFromFloat(self.Out3Rtotal * 10000)) });
        std.debug.print("Total roll: {} (3roll: {})\n\n", .{ @as(i32, @intFromFloat(self.TInRtotal * 10000)) + @as(i32, @intFromFloat(self.TOutRtotal * 10000)), @as(i32, @intFromFloat(self.In3Rtotal * 10000)) + @as(i32, @intFromFloat(self.Out3Rtotal * 10000)) });
        std.debug.print("Unaccounted bigrams: {}\n", .{@as(i32, @intFromFloat(self.un_bigram * 10000))});
        std.debug.print("Unaccounted trigrams: {}\n", .{@as(i32, @intFromFloat(self.un_trigram * 10000))});
    }
};

pub fn main() !void {
    var argiter = try std.process.argsWithAllocator(allocator);
    defer argiter.deinit();
    var layout = try loadlayout.loadLayout("whirl");
    _ = argiter.next();
    if (argiter.next()) |val| {
        layout = try loadlayout.loadLayout(val);
    }
    const start = try time.Instant.now();
    const grams = try parsecorpus.loadCorpus(layout, "mr");
    const stats = try Stats.init(layout, grams);
    try stats.print(.{});
    const end = try time.Instant.now();
    std.debug.print("Runtime: {}ns", .{end.since(start)});
}
