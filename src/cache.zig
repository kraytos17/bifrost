const std = @import("std");
const net = std.net;

pub fn serverLoop(port: u16) !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const allocator = gpa.allocator();
    const loopback_addr = try net.Ip4Address.parse("127.0.0.1", port);
    const host = net.Address{ .in = loopback_addr };
    
    var server = try host.listen(.{
        .reuse_port = true,
    });
    defer server.deinit();

    const addr = server.listen_address;
    std.log.debug("Listening on {any}\n", .{addr});

    while (true) {
        var client = try server.accept();
        defer client.stream.close();
        std.log.debug("Connection received, {any} is sending data\n", .{client.address});

        while (true) {
            const msg = client.stream.reader().readAllAlloc(allocator, 1024) catch |err| {
                if (err == error.EndOfStream) {
                    std.log.debug("Client {any} disconnected\n", .{client.address});
                    break;
                }
                return err;
            };

            defer allocator.free(msg);

            if (msg.len == 0) {
                std.log.debug("No more data from {any}, closing connection\n", .{client.address});
                break;
            }

            std.log.debug("{any} says {s}\n", .{ client.address, msg });
        }
    }
}
