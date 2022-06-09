const std = @import("std");

pub const TotalDuration = struct {
    total: f64 = 0,
    prev: ?f64 = null,
    max_idle: f64 = 300,

    fn add(self: *TotalDuration, time: f64) void {
        const prev = self.prev orelse time;
        const diff = time - prev;
        if (diff < self.max_idle) self.total += diff;
        self.prev = time;
    }
};

const testing = std.testing;

test "it works" {
    var total = TotalDuration{};
    var begin: f64 = 1654761539;

    total.add(begin);
    try testing.expectEqual(total.prev.?, begin);
    try testing.expectEqual(total.total, 0);

    total.add(begin + 10);
    try testing.expectEqual(total.prev.?, begin + 10);
    try testing.expectEqual(total.total, 10);

    total.add(begin + 310);
    try testing.expectEqual(total.prev.?, begin + 310);
    try testing.expectEqual(total.total, 10);

    total.add(begin + 340);
    try testing.expectEqual(total.prev.?, begin + 340);
    try testing.expectEqual(total.total, 40);
}
