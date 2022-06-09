const std = @import("std");

const ProjectDurations = struct {
    map: std.StringHashMap(f64) = undefined,
    max_idle: f64 = 300,
    prev_time: ?f64 = null,
    prev_project: ?[]const u8 = null,

    pub fn init(self: *ProjectDurations, allocator: std.mem.Allocator) void {
        self.map = std.StringHashMap(f64).init(allocator);
    }

    pub fn deinit(self: *ProjectDurations) void {
        self.map.deinit();
    }

    pub fn add(self: *ProjectDurations, time: f64, project: []const u8) !void {
        const prev_time = self.prev_time orelse time;
        const prev_project = self.prev_project orelse project;
        const diff = time - prev_time;

        if (diff < self.max_idle) {
            const prev = self.map.get(prev_project) orelse 0;
            try self.map.put(prev_project, prev + diff);
        }

        self.prev_time = time;
        self.prev_project = project;
    }

    pub fn get(self: *ProjectDurations, project: []const u8) ?f64 {
        return self.map.get(project);
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

    // TODO durations.json()
}
