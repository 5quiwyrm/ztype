const std = @import("std");
const allocator = std.heap.page_allocator;

pub const WordFreq = struct {
    word: []const u8,
    freq: u32,

    pub fn FromHashMap(hashmap: std.StringHashMap(u32)) ![]WordFreq {
        var hashmap_arr = try allocator.alloc(WordFreq, hashmap.count());
        var n: usize = 0;
        var hashmap_iter = hashmap.iterator();
        while (hashmap_iter.next()) |entry| {
            hashmap_arr[n] = WordFreq{ .word = entry.key_ptr.*, .freq = entry.value_ptr.* };
            n += 1;
        }
        return hashmap_arr;
    }

    pub fn ToHashMap(wordfreqs: []WordFreq) !std.StringHashMap(u32) {
        var hashmap = std.StringHashMap(u32).init(allocator);
        for (wordfreqs) |entry| {
            try hashmap.put(entry.word, entry.freq);
        }
        return hashmap;
    }
};

pub fn GenData(corpus_name: []const u8, overwrite: bool) !void {
    const parsed_path = try allocator.alloc(u8, corpus_name.len + 5);
    defer allocator.free(parsed_path);
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
        std.debug.print("{}\nDoesn't exist yet, continuing...", .{err});
        skip = false;
    };

    if (skip and !overwrite) {
        std.debug.print("{s} already exists, exiting...\n", .{corpus_name});
        return;
    }

    const corpus_path = try allocator.alloc(u8, corpus_name.len + 4);
    defer allocator.free(corpus_path);
    std.mem.copyForwards(u8, corpus_path, corpus_name);
    corpus_path[corpus_name.len] = '.';
    corpus_path[corpus_name.len + 1] = 't';
    corpus_path[corpus_name.len + 2] = 'x';
    corpus_path[corpus_name.len + 3] = 't';
    var corpora_dir = try std.fs.cwd().openDir("corpora", .{});
    defer corpora_dir.close();
    const corpus_file = try corpora_dir.openFile(corpus_path, .{ .mode = .read_only });
    defer corpus_file.close();
    const corpus_text = try corpus_file.readToEndAlloc(allocator, 2e8);
    for (corpus_text) |*ch| {
        ch.* = std.ascii.toLower(ch.*);
    }
    var corpus_split = std.mem.tokenizeAny(u8, corpus_text, "\n\r ");
    var words_freqs = std.StringHashMap(u32).init(allocator);
    defer words_freqs.deinit();

    while (corpus_split.next()) |word| {
        const word_entry = words_freqs.getPtr(word);
        if (word_entry) |some| {
            some.* += 1;
        } else {
            _ = try words_freqs.put(word, 1);
        }
    }

    const parsed_file = try parsed_dir.createFile(parsed_path, .{});
    defer parsed_file.close();

    const owned = try WordFreq.FromHashMap(words_freqs);

    _ = try std.json.stringify(owned, .{}, parsed_file.writer());
}

test "test_comp_err" {
    var argiter = try std.process.argsWithAllocator(allocator);

    _ = argiter.next();

    var overwrite: bool = false;
    if (argiter.next()) |arg| {
        overwrite = std.mem.eql(u8, arg, "overwrite");
    }

    _ = try GenData("e200", overwrite);
    _ = try GenData("e10k", overwrite);
}
