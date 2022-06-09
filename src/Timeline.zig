const std = @import("std");

const TimelineSegment = struct {
    project: []const u8,
    from: f64,
    to: f64,
};

const Timeline = struct {
    timeline: std.ArrayList(TimelineSegment) = undefined,
    max_idle: f64 = 300,
    prev_time: ?f64 = null,
    prev_from: ?f64 = null,
    prev_project: ?[]const u8 = null,

    pub fn init(self: *Timeline, allocator: std.mem.Allocator) void {
        self.timeline = std.ArrayList(TimelineSegment).init(allocator);
    }

    pub fn deinit(self: *Timeline) void {
        self.timeline.deinit();
    }

    pub fn add(self: *Timeline, time: f64, project: []const u8) !void {
        const prev_time = self.prev_time orelse time;

        if (self.prev_from == null) self.prev_from = time;
        const prev_from = self.prev_from.?;

        const prev_project = self.prev_project orelse project;
        const diff = time - prev_time;

        if (diff < self.max_idle) {
            if (!std.mem.eql(u8, project, prev_project)) {
                const segment = TimelineSegment{ .project = prev_project, .from = prev_from, .to = time };
                try self.timeline.append(segment);
                self.prev_from = time;
            }
        } else {
            const segment = TimelineSegment{ .project = prev_project, .from = prev_from, .to = prev_time };
            try self.timeline.append(segment);
            self.prev_from = time;
        }

        self.prev_time = time;
        self.prev_project = project;
    }

    // or maybe update timeline segment in-place in add?
    pub fn finish(self: *Timeline) !void {
        if (self.prev_project) |prev_project| {
            const prev_time = self.prev_time.?;
            const prev_from = self.prev_from.?;
            const segment = TimelineSegment{ .project = prev_project, .from = prev_from, .to = prev_time };
            try self.timeline.append(segment);
        }
    }

    pub fn json(self: Timeline, allocator: std.mem.Allocator) !std.ArrayList(u8) {
        var string = std.ArrayList(u8).init(allocator);
        try std.json.stringify(self.timeline.items, .{}, string.writer());
        return string;
    }
};

const testing = std.testing;

test "it works" {
    var timeline = Timeline{};
    timeline.init(testing.allocator);
    defer timeline.deinit();

    var begin: f64 = 1654761539;
    try timeline.add(begin, "w1");
    try timeline.add(begin + 10, "w1");
    try timeline.add(begin + 40, "w1");
    try timeline.add(begin + 340, "w1");
    try timeline.add(begin + 360, "w2");
    try timeline.add(begin + 400, "w2");
    try timeline.finish();

    const segments = timeline.timeline.items;
    try testing.expectEqual(@as(usize, 3), segments.len);

    for (segments) |s, i| {
        switch (i) {
            0 => {
                try testing.expectEqualStrings("w1", s.project);
                try testing.expectEqual(begin, s.from);
                try testing.expectEqual(begin + 40, s.to);
            },
            1 => {
                try testing.expectEqualStrings("w1", s.project);
                try testing.expectEqual(begin + 340, s.from);
                try testing.expectEqual(begin + 360, s.to);
            },
            2 => {
                try testing.expectEqualStrings("w2", s.project);
                try testing.expectEqual(begin + 360, s.from);
                try testing.expectEqual(begin + 400, s.to);
            },
            else => unreachable,
        }
    }

    const json = try timeline.json(testing.allocator);
    try testing.expectEqualStrings(
        \\[{"project":"w1","from":1.654761539e+09,"to":1.654761579e+09},{"project":"w1","from":1.654761879e+09,"to":1.654761899e+09},{"project":"w2","from":1.654761899e+09,"to":1.654761939e+09}]
    , json.items);
    json.deinit();
}
