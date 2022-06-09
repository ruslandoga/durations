const std = @import("std");

pub const TotalDuration = @import("TotalDuration.zig");
pub const ProjectDurations = @import("ProjectDurations.zig");

comptime {
    std.testing.refAllDecls(@This());
}
