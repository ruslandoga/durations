const std = @import("std");

pub const TotalDuration = @import("TotalDuration.zig");

comptime {
    std.testing.refAllDecls(@This());
}
