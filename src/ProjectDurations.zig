const std = @import("std");

pub const ProjectDurations = struct {
    map: ?std.StringArrayHashMap(std.json.Value) = null,
    prev_time: ?f64 = null,
    prev_project: ?[]const u8 = null,

    pub fn init(self: *ProjectDurations, allocator: std.mem.Allocator) void {
        self.map = std.StringArrayHashMap(std.json.Value).init(allocator);
    }

    pub fn deinit(self: *ProjectDurations) void {
        if (self.map) |*m| m.deinit();
    }

    pub fn add(self: *ProjectDurations, time: f64, project: []const u8) !void {
        const prev_time = self.prev_time orelse time;
        const prev_project = self.prev_project orelse project;
        const diff = time - prev_time;

        if (diff < 300) {
            const prev = self.map.?.get(prev_project) orelse std.json.Value{ .Float = 0 };
            try self.map.?.put(prev_project, std.json.Value{ .Float = prev.Float + diff });
        }

        self.prev_time = time;
        self.prev_project = project;
    }

    pub fn get(self: *ProjectDurations, project: []const u8) ?f64 {
        if (self.map.?.get(project)) |v| {
            return v.Float;
        } else return null;
    }

    pub fn json(self: *ProjectDurations, allocator: std.mem.Allocator) !std.ArrayList(u8) {
        var string = std.ArrayList(u8).init(allocator);
        try (std.json.Value{ .Object = self.map.? }).jsonStringify(.{}, string.writer());
        return string;
    }
};

const testing = std.testing;

test "it works" {
    var durations = ProjectDurations{};
    durations.init(testing.allocator);
    defer durations.deinit();

    var begin: f64 = 1654761539;
    try durations.add(begin, "w1");
    try durations.add(begin + 10, "w1");
    try durations.add(begin + 40, "w1");
    try durations.add(begin + 340, "w1");
    try durations.add(begin + 360, "w2");
    try durations.add(begin + 400, "w2");
    try testing.expectEqual(@as(f64, 60), durations.get("w1").?);
    try testing.expectEqual(@as(f64, 40), durations.get("w2").?);

    const json = try durations.json(testing.allocator);
    try testing.expectEqualStrings(
        \\{"w1":6.0e+01,"w2":4.0e+01}
    , json.items);
    json.deinit();
}
