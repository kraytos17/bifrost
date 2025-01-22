const tree = @import("tree.zig");
const std = @import("std");
const cache = @import("cache.zig");
const os = std.os;

const Tree = tree.Tree;
const Node = tree.Node;
const Leaf = tree.Leaf;
const Tag = tree.Tag;

pub fn main() !void {
    // var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    // const allocator = gpa.allocator();
    // defer {
    //     const leaked = gpa.deinit();
    //     if (leaked == .leak) std.log.err("Warning: Memory leak detected!\n", .{});
    // }

    // var root = try Tree.init(allocator);
    // defer root.deinit(allocator);

    // const root_node = try root.asNode();
    // const node1 = try Node.init(allocator, root_node, "/users");
    // const node2 = try Node.init(allocator, node1, "/users/login");

    // std.log.info("Tree root: {any}\n", .{root});
    // std.log.info("Node1: {any}\n", .{node1});
    // std.log.info("Node2: {any}\n", .{node2});

    const args = std.os.argv;
    var default_port: u16 = 8080;

    if (args.len > 1) {
        const input_port = std.fmt.parseInt(u16, std.mem.span(args[1]), 10) catch |err| {
            std.log.err("Invalid port number '{s}', falling back to default port {d}\n", .{ args[1], default_port });
            return err;
        };

        if (input_port < 1 or input_port > 65535) {
            std.log.err("Port number out of range: {d}. Falling back to default port {d}\n", .{ input_port, default_port });
        } else {
            default_port = input_port;
        }
    }

    std.log.info("Using port: {d}\n", .{default_port});

    try cache.serverLoop(default_port);
}
