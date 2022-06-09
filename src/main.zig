const std = @import("std");

const TotalDuration = @import("TotalDuration.zig").TotalDuration;
const ProjectDurations = @import("ProjectDurations.zig").ProjectDurations;
const Timeline = @import("Timeline.zig").Timeline;

const c = @cImport(@cInclude("sqlite3ext.h"));
var sqlite3_api: *c.sqlite3_api_routines = undefined;

comptime {
    std.testing.refAllDecls(@This());
}

// TODO
// Copied from https://github.com/ameerbrar/zig-generate_series/blob/main/src/generate_series.zig
// Copied from raw_c_allocator.
// Asserts allocations are within `@alignOf(std.c.max_align_t)` and directly calls
// `malloc`/`free`. Does not attempt to utilize `malloc_usable_size`.
// This allocator is safe to use as the backing allocator with
// `ArenaAllocator` for example and is more optimal in such a case
// than `c_allocator`.
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;

const sqlite_allocator = Allocator{ .ptr = undefined, .vtable = &sqlite_allocator_vtable };

const sqlite_allocator_vtable = Allocator.VTable{
    .alloc = sqliteAlloc,
    .resize = sqliteResize,
    .free = sqliteFree,
};

fn sqliteAlloc(
    _: *anyopaque,
    len: usize,
    ptr_align: u29,
    _: u29,
    _: usize,
) Allocator.Error![]u8 {
    //   if (ptr_align > MAX_ALIGN) { return error.OutOfMemory; }
    //   const ptr = e.enif_alloc(len) orelse return error.OutOfMemory;
    //   return @ptrCast([*]u8, ptr)[0..len];
    assert(ptr_align <= @alignOf(std.c.max_align_t));
    const ptr = @ptrCast([*]u8, sqlite3_api.malloc64.?(len) orelse return error.OutOfMemory);
    return ptr[0..len];
}

fn sqliteResize(
    _: *anyopaque,
    buf: []u8,
    _: u29,
    new_len: usize,
    _: u29,
    _: usize,
) ?usize {
    if (new_len == 0) {
        sqlite3_api.free.?(buf.ptr);
        return 0;
    }

    if (new_len <= buf.len) {
        // return std.mem.alignAllocLen(buf.len, new_len, len_align);
        return new_len;
    }

    // not error?
    return null;
}

fn sqliteFree(
    _: *anyopaque,
    buf: []u8,
    _: u29,
    _: usize,
) void {
    sqlite3_api.free.?(buf.ptr);
}

fn sliceFromValue(sqlite_value: *c.sqlite3_value) []const u8 {
    const size = @intCast(usize, sqlite3_api.value_bytes.?(sqlite_value));
    const value = sqlite3_api.value_text.?(sqlite_value); // TODO not null?
    return value.?[0..size];
}

// TODO state: [*c]

fn totalDurationStep(ctx: ?*c.sqlite3_context, argc: c_int, argv: [*c]?*c.sqlite3_value) callconv(.C) void {
    _ = argc;
    const state = @ptrCast(?*TotalDuration, @alignCast(@alignOf(TotalDuration), sqlite3_api.aggregate_context.?(ctx, @sizeOf(TotalDuration))));
    if (state == null) return sqlite3_api.result_error_nomem.?(ctx);
    // TODO ensure correct type
    const time: f64 = sqlite3_api.value_double.?(argv[0]);
    state.?.add(time);
}

fn totalDurationFinal(ctx: ?*c.sqlite3_context) callconv(.C) void {
    const state = @ptrCast(?*TotalDuration, @alignCast(@alignOf(TotalDuration), sqlite3_api.aggregate_context.?(ctx, @sizeOf(TotalDuration))));
    sqlite3_api.result_double.?(ctx, state.?.total);
}

fn projectDurationsStep(ctx: ?*c.sqlite3_context, argc: c_int, argv: [*c]?*c.sqlite3_value) callconv(.C) void {
    _ = argc;
    const state = @ptrCast(?*ProjectDurations, @alignCast(@alignOf(ProjectDurations), sqlite3_api.aggregate_context.?(ctx, @sizeOf(ProjectDurations))));
    if (state == null) return sqlite3_api.result_error_nomem.?(ctx);
    if (state.?.map == null) state.?.init(sqlite_allocator);
    // TODO ensure correct types
    const time: f64 = sqlite3_api.value_double.?(argv[0]);
    const project = sliceFromValue(argv[1].?);
    state.?.add(time, project) catch return sqlite3_api.result_error_nomem.?(ctx);
}

fn projectDurationsFinal(ctx: ?*c.sqlite3_context) callconv(.C) void {
    const state = @ptrCast(?*ProjectDurations, @alignCast(@alignOf(ProjectDurations), sqlite3_api.aggregate_context.?(ctx, @sizeOf(ProjectDurations))));
    defer if (state != null) state.?.deinit();

    const json = state.?.json(sqlite_allocator) catch return sqlite3_api.result_error_nomem.?(ctx);
    defer json.deinit();

    // TODO
    const text: [*c]const u8 = json.items.ptr;
    sqlite3_api.result_text.?(ctx, text, -1, c.SQLITE_STATIC);
}

fn timelineStep(ctx: ?*c.sqlite3_context, argc: c_int, argv: [*c]?*c.sqlite3_value) callconv(.C) void {
    _ = argc;
    const state = @ptrCast(?*Timeline, @alignCast(@alignOf(Timeline), sqlite3_api.aggregate_context.?(ctx, @sizeOf(Timeline))));
    if (state == null) return sqlite3_api.result_error_nomem.?(ctx);
    if (state.?.timeline == null) state.?.init(sqlite_allocator);
    // TODO ensure correct types
    const time: f64 = sqlite3_api.value_double.?(argv[0]);
    const project = sliceFromValue(argv[1].?);
    state.?.add(time, project) catch return sqlite3_api.result_error_nomem.?(ctx);
}

fn timelineFinal(ctx: ?*c.sqlite3_context) callconv(.C) void {
    const state = @ptrCast(?*Timeline, @alignCast(@alignOf(Timeline), sqlite3_api.aggregate_context.?(ctx, @sizeOf(Timeline))));
    defer if (state != null) state.?.deinit();

    state.?.finish() catch return sqlite3_api.result_error_nomem.?(ctx);

    const json = state.?.json(sqlite_allocator) catch return sqlite3_api.result_error_nomem.?(ctx);
    defer json.deinit();

    // TODO
    const text: [*c]const u8 = json.items.ptr;
    sqlite3_api.result_text.?(ctx, text, -1, c.SQLITE_STATIC); // or SQLITE_TRANSIENT
}

pub export fn sqlite3_extension_init(db: ?*c.sqlite3, pzErrMsg: [*c][*c]u8, pApi: [*c]c.sqlite3_api_routines) c_int {
    _ = pzErrMsg;
    sqlite3_api = pApi.?;
    _ = sqlite3_api.create_function.?(db, "total", 1, c.SQLITE_UTF8, null, null, totalDurationStep, totalDurationFinal);
    _ = sqlite3_api.create_function.?(db, "total", 2, c.SQLITE_UTF8, null, null, projectDurationsStep, projectDurationsFinal);
    _ = sqlite3_api.create_function.?(db, "timeline", 2, c.SQLITE_UTF8, null, null, timelineStep, timelineFinal);
    return c.SQLITE_OK;
}
