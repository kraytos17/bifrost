const tree = @import("tree.zig");
const std = @import("std");
const cache = @import("cache.zig");
const os = std.os;

const Tree = tree.Tree;
const Node = tree.Node;
const Leaf = tree.Leaf;
const Tag = tree.Tag;
const Handlers = cache.Handlers;
const CmdHandle = cache.CmdHandle;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer {
        const leaked = gpa.deinit();
        if (leaked == .leak) std.log.err("Error: Memory leak detected!\n", .{});
    }

    var root = try Tree.initAlloc(allocator);
    defer root.deinit(allocator);

    const root_node = try root.asNode();
    const node1 = try Node.initAlloc(allocator, root_node, "/users");
    const node2 = try Node.initAlloc(allocator, node1, "/users/login");

    const leaf1 = try Leaf.initAlloc(allocator, node2, "key1", "value1");
    const leaf2 = try Leaf.initAlloc(allocator, node2, "key2", "value2");
    const found_node = tree.nodeLookup(root_node, "/users/login");
    const found_leaf = tree.leafLookup(root_node, "key1");

    std.debug.print("Node found {s}\n", .{found_node.?});
    std.debug.print("Leaf found {s}\n", .{found_leaf.?});

    std.log.info("Tree root: {s}\n", .{root});
    std.log.info("Node1: {s}\n", .{node1});
    std.log.info("Node2: {s}\n", .{node2});
    std.log.info("Leaf1: {s}\n", .{leaf1});
    std.log.info("Leaf2: {s}\n", .{leaf2});

    // const args = try std.process.argsAlloc(allocator);
    // defer std.process.argsFree(allocator, args);

    // var default_port: u16 = 8080;

    // if (args.len > 1) {
    //     const input_port = std.fmt.parseInt(u16, args[1], 10) catch |err| {
    //         std.log.err("Invalid port number '{s}', falling back to default port {d}\n", .{ args[1], default_port });
    //         return err;
    //     };

    //     if (input_port < 1 or input_port > 65535) {
    //         std.log.err("Port number out of range: {d}. Falling back to default port {d}\n", .{ input_port, default_port });
    //     } else {
    //         default_port = input_port;
    //     }
    // }

    // std.log.info("Using port: {d}\n", .{default_port});

    // try cache.serverLoop(default_port);
}
