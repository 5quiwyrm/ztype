const std = @import("std");
const loadlayout = @import("loadLayout.zig");

pub const Corpus = struct {
    name: []const u8,
    extended_monograms: []WordCount,
    extended_bigrams: []WordCount,
    extended_trigrams: []WordCount,
};

pub const WordFreq = struct {
    word: []const u8,
    freq: f32,
};

pub const WordCount = struct {
    word: []const u8,
    freq: u32,

    pub fn FromHashMap(allocator: std.mem.Allocator, hashmap: anytype) ![]WordCount {
        var hashmap_arr = try allocator.alloc(WordCount, hashmap.count());
        var n: usize = 0;
        var hashmap_iter = hashmap.keyIterator();
        while (hashmap_iter.next()) |entry| {
            hashmap_arr[n] = WordCount{ .word = try allocator.dupe(u8, entry.*), .freq = hashmap.get(entry.*).? };
            n += 1;
        }
        return hashmap_arr;
    }

    pub fn ToHashMap(allocator: std.mem.Allocator, wordfreqs: []WordCount) !std.json.ArrayHashMap(u32) {
        var hashmap = std.StringHashMap(u32).init(allocator);
        for (wordfreqs) |entry| {
            try hashmap.put(entry.word, entry.freq);
        }
        return hashmap;
    }

    pub fn toWordFreq(self: WordCount, allocator: std.mem.Allocator) !WordFreq {
        const newword = try allocator.dupe(u8, self.word);
        return WordFreq{
            .word = newword,
            .freq = @floatFromInt(self.freq),
        };
    }
};

fn GenNgram(allocator: std.mem.Allocator, corpus: []const u8, gramsize: usize) ![]WordCount {
    var extended_ngrams = std.json.ArrayHashMap(u32){};
    try extended_ngrams.map.put(allocator, corpus[0..(gramsize + 1)], 1);
    for (1..(corpus.len - gramsize - 1)) |n| {
        const ngram = corpus[(n - 1)..(n + gramsize)];
        const val_ptr_opt = extended_ngrams.map.getPtr(ngram);
        if (val_ptr_opt) |val_ptr| {
            val_ptr.* += 1;
        } else {
            try extended_ngrams.map.put(allocator, ngram, 1);
        }
    }
    const extended_ngrams_arr = try WordCount.FromHashMap(extended_ngrams.map);
    return extended_ngrams_arr;
}

pub fn GenData(allocator: std.mem.Allocator, corpus_name: []const u8, overwrite: bool) !void {
    const parsed_path = try allocator.alloc(u8, corpus_name.len + 5);
    // defer allocator.free(parsed_path);
    std.mem.copyForwards(u8, parsed_path, corpus_name);
    parsed_path[corpus_name.len] = '.';
    parsed_path[corpus_name.len + 1] = 'j';
    parsed_path[corpus_name.len + 2] = 's';
    parsed_path[corpus_name.len + 3] = 'o';
    parsed_path[corpus_name.len + 4] = 'n';
    var parsed_dir = try std.fs.cwd().openDir("parsed", .{});
    defer parsed_dir.close();

    var skip: bool = true;
    parsed_dir.access(parsed_path, .{}) catch |err| {
        std.debug.print("{}\nDoesn't exist yet, continuing...\n", .{err});
        skip = false;
    };

    if (skip and !overwrite) {
        std.debug.print("{s} already exists, exiting...\n", .{corpus_name});
        return;
    }
    const corpus_path = try allocator.alloc(u8, corpus_name.len + 4);
    // defer allocator.free(corpus_path);
    std.mem.copyForwards(u8, corpus_path, corpus_name);
    corpus_path[corpus_name.len] = '.';
    corpus_path[corpus_name.len + 1] = 't';
    corpus_path[corpus_name.len + 2] = 'x';
    corpus_path[corpus_name.len + 3] = 't';
    var corpora_dir = try std.fs.cwd().openDir("corpora", .{});
    defer corpora_dir.close();
    const corpus_file = try corpora_dir.openFile(corpus_path, .{ .mode = .read_only });
    defer corpus_file.close();
    const crlf_corpus_text = try corpus_file.readToEndAlloc(allocator, 2e8);
    const corpus_text = try allocator.alloc(u8, crlf_corpus_text.len);
    // defer allocator.free(corpus_text);
    _ = std.mem.replace(u8, crlf_corpus_text, "\r\n", "\n", corpus_text);
    // decrlfification

    const parsed_file = try parsed_dir.createFile(parsed_path, .{ .exclusive = !overwrite });
    defer parsed_file.close();
    const parsed_writer = parsed_file.writer();

    const ext_monograms = try GenNgram(corpus_text, 1);
    const ext_bigrams = try GenNgram(corpus_text, 2);
    const ext_trigrams = try GenNgram(corpus_text, 3);
    const corpus = Corpus{
        .name = corpus_name,
        .extended_monograms = ext_monograms,
        .extended_bigrams = ext_bigrams,
        .extended_trigrams = ext_trigrams,
    };
    try std.json.stringify(corpus, .{}, parsed_writer);
}

pub const Ngrams = struct {
    corpusname: []const u8,
    allocator: std.mem.Allocator,
    monograms: []WordCount,
    bigrams: []WordCount,
    trigrams: []WordCount,

    // pub fn deinit(self: *Ngrams) void {
    //     for (self.monograms) |mgrm| self.allocator.free(mgrm.word);
    //     for (self.bigrams) |bgrm| self.allocator.free(bgrm.word);
    //     for (self.trigrams) |tgrm| self.allocator.free(tgrm.word);
    // }
};

pub fn loadCorpus(allocator: std.mem.Allocator, layout: loadlayout.Layout, corpusname: []const u8) !Ngrams {
    const start = try std.time.Instant.now();
    var parsed_dir = try std.fs.cwd().openDir("parsed", .{});
    defer parsed_dir.close();
    const parsed_path = try allocator.alloc(u8, corpusname.len + 5);
    // defer allocator.free(parsed_path);
    std.mem.copyForwards(u8, parsed_path, corpusname);
    parsed_path[corpusname.len] = '.';
    parsed_path[corpusname.len + 1] = 'j';
    parsed_path[corpusname.len + 2] = 's';
    parsed_path[corpusname.len + 3] = 'o';
    parsed_path[corpusname.len + 4] = 'n';
    const parsed_file = try parsed_dir.openFile(parsed_path, .{ .mode = .read_only });
    const parsed_str = try parsed_file.readToEndAlloc(allocator, 2e8);
    const corpus_parsed = try std.json.parseFromSlice(Corpus, allocator, parsed_str, .{});
    // defer corpus_parsed.deinit();
    const corpusval = corpus_parsed.value;
    if (layout.magicrules == null) {
        var monograms_nonmagic = std.StringHashMap(u32).init(allocator);
        for (corpusval.extended_monograms) |mgrm| {
            if (monograms_nonmagic.getPtr(mgrm.word[1..])) |valueptr| {
                valueptr.* += mgrm.freq;
            } else {
                try monograms_nonmagic.put(try allocator.dupe(u8, mgrm.word[1..]), mgrm.freq);
            }
        }
        return Ngrams{
            .corpusname = corpusname,
            .allocator = allocator,
            .monograms = try WordCount.FromHashMap(allocator, monograms_nonmagic),
            .bigrams = corpusval.extended_monograms,
            .trigrams = corpusval.extended_bigrams,
        };
    }
    var monograms = std.StringHashMap(u32).init(allocator); // no need to deinit
    // defer {
    //     var keyIter = monograms.iterator();
    //     while (keyIter.next()) |key| {
    //         monograms.allocator.free(key.key_ptr.*);
    // }
    //     monograms.deinit();
    // }
    const corpustime = try std.time.Instant.now();
    std.debug.print("corpus time:    {}ns\n", .{corpustime.since(start)});
    for (corpusval.extended_monograms) |mgrm| {
        if (!layout.repeat) {
            var magicked = false;
            magic: for (layout.magicrules.?) |rule| {
                if (mgrm.word[0] == rule[0] and mgrm.word[1] == rule[1]) {
                    if (monograms.getPtr(&.{'*'})) |valueptr| {
                        valueptr.* += mgrm.freq;
                    } else {
                        try monograms.put(try allocator.dupe(u8, &.{'*'}), mgrm.freq);
                    }
                    magicked = true;
                    break :magic;
                }
            }
            if (!magicked) {
                if (monograms.getPtr(mgrm.word[1..])) |valueptr| {
                    valueptr.* += mgrm.freq;
                } else {
                    try monograms.put(try allocator.dupe(u8, mgrm.word[1..]), mgrm.freq);
                }
            }
        } else {
            if (mgrm.word[0] >= 'a' and mgrm.word[0] <= 'z' and mgrm.word[1] == layout.magicrules.?[mgrm.word[0] - 'a'][1]) {
                if (monograms.getPtr(&.{'*'})) |valueptr| {
                    valueptr.* += mgrm.freq;
                } else {
                    try monograms.put(try allocator.dupe(u8, &.{'*'}), mgrm.freq);
                }
            } else {
                if (monograms.getPtr(mgrm.word[1..])) |valueptr| {
                    valueptr.* += mgrm.freq;
                } else {
                    try monograms.put(try allocator.dupe(u8, mgrm.word[1..]), mgrm.freq);
                }
            }
        }
    }
    const monogramtime = try std.time.Instant.now();
    std.debug.print("Monograms time: {}ns\n", .{monogramtime.since(corpustime)});
    var bigrams = std.StringHashMap(u32).init(allocator); // no need to deinit
    // defer {
    //     var keyIter = bigrams.iterator();
    //     while (keyIter.next()) |key| {
    //         bigrams.allocator.free(key.key_ptr.*);
    // }
    //     bigrams.deinit();
    // }
    for (corpusval.extended_bigrams) |bgrm| {
        var app = try allocator.dupe(u8, bgrm.word);
        //         defer allocator.free(app);
        if (!layout.repeat) {
            var num_mag: u8 = 0;
            magic: for (layout.magicrules.?) |rule| {
                if (app[0] == rule[0] and app[1] == rule[1]) {
                    app[1] = layout.magicchar;
                    num_mag += 1;
                }
                if (app[1] == rule[0] and app[2] == rule[1]) {
                    app[2] = layout.magicchar;
                    num_mag += 1;
                }
                if (num_mag > 0) break :magic;
            }
        } else {
            if (app[0] >= 'a' and app[0] <= 'z') {
                if (app[1] == layout.magicrules.?[app[0] - 'a'][1]) {
                    app[1] = layout.magicchar;
                }
            } else {
                if (app[1] >= 'a' and app[1] <= 'z') {
                    if (app[2] == layout.magicrules.?[app[1] - 'a'][1]) {
                        app[2] = layout.magicchar;
                    }
                }
            }
        }
        if (bigrams.getPtr(app[1..3])) |valueptr| {
            valueptr.* += bgrm.freq;
        } else {
            try bigrams.put(try allocator.dupe(u8, app[1..3]), bgrm.freq);
        }
    }
    const bigramtime = try std.time.Instant.now();
    std.debug.print("Bigrams time:   {}ns\n", .{bigramtime.since(monogramtime)});
    var trigrams = std.StringHashMap(u32).init(allocator); // no need to deinit
    // defer {
    //     var keyIter = trigrams.iterator();
    //     while (keyIter.next()) |key| {
    //         trigrams.allocator.free(key.key_ptr.*);
    //     }
    //     trigrams.deinit();
    // }
    for (corpusval.extended_trigrams) |tgrm| {
        var app = try allocator.dupe(u8, tgrm.word);
        //         defer allocator.free(app);
        if (!layout.repeat) {
            var num_mag: u8 = 0;
            magic: for (layout.magicrules.?) |rule| {
                if (app[0] == rule[0] and app[1] == rule[1]) {
                    app[1] = layout.magicchar;
                    num_mag += 1;
                }
                if (app[2] == rule[0] and app[3] == rule[1]) {
                    app[3] = layout.magicchar;
                    num_mag += 1;
                }
                if (app[1] == rule[0] and app[2] == rule[1]) {
                    app[2] = layout.magicchar;
                    num_mag += 2;
                }
                if (num_mag > 1) break :magic;
            }
        } else {
            if (app[0] >= 'a' and app[0] <= 'z') {
                if (app[1] == layout.magicrules.?[app[0] - 'a'][1]) {
                    app[1] = layout.magicchar;
                }
            }
            if (app[1] >= 'a' and app[1] <= 'z') {
                if (app[2] == layout.magicrules.?[app[1] - 'a'][1]) {
                    app[2] = layout.magicchar;
                }
            }
            if (app[2] >= 'a' and app[2] <= 'z') {
                if (app[3] == layout.magicrules.?[app[2] - 'a'][1]) {
                    app[3] = layout.magicchar;
                }
            }
        }
        if (trigrams.getPtr(app[1..])) |valueptr| {
            valueptr.* += tgrm.freq;
        } else {
            try trigrams.put(try allocator.dupe(u8, app[1..]), tgrm.freq);
        }
    }
    const trigramtime = try std.time.Instant.now();
    std.debug.print("Trigrams time:  {}ns\n", .{trigramtime.since(bigramtime)});
    const m = try WordCount.FromHashMap(allocator, monograms);
    const b = try WordCount.FromHashMap(allocator, bigrams);
    const t = try WordCount.FromHashMap(allocator, trigrams);
    const magictime = try std.time.Instant.now();
    std.debug.print("Total Ngrams time: {}ns\n", .{magictime.since(start)});
    return Ngrams{
        .corpusname = corpusname,
        .allocator = allocator,
        .monograms = m,
        .bigrams = b,
        .trigrams = t,
    };
}

pub fn main() !void {
    // try GenData("e10k", true);
    // try GenData("e200", true);
    // try GenData("mr", true);
    // try GenData("o600", true);
}
