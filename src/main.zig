const tree = @import("tree.zig");
const std = @import("std");

const Tree = tree.Tree;
const Node = tree.Node;
const Leaf = tree.Leaf;
const Tag = tree.Tag;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer {
        const leaked = gpa.deinit();
        if (leaked == .leak) std.log.err("Warning: Memory leak detected!\n", .{});
    }

    var root = try Tree.init(allocator);
    defer root.deinit(allocator);

    const root_node = try root.asNode();
    const node1 = try Node.init(allocator, root_node, "/users");
    const node2 = try Node.init(allocator, node1, "/users/login");

    std.log.info("Tree root: {any}\n", .{root});
    std.log.info("Node1: {any}\n", .{node1});
    std.log.info("Node2: {any}\n", .{node2});
}
