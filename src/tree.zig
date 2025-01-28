const std = @import("std");
const Allocator = std.mem.Allocator;

pub const TreeError = error{
    InvalidPath,
    NodeNotFound,
    OutOfMemory,
    InvalidCast,
} || Allocator.Error;

pub const Node = struct {
    tag: Tag,
    north: ?*Node,
    west: ?*Node,
    east: ?*Leaf,
    path: []const u8,

    const Self = @This();

    pub fn initAlloc(allocator: Allocator, parent: ?*Node, path: []const u8) TreeError!*Self {
        if (path.len == 0) return TreeError.InvalidPath;

        const path_copy = try allocator.dupe(u8, path);
        errdefer allocator.free(path_copy);

        const newNode = try allocator.create(Node);
        errdefer allocator.destroy(newNode);

        newNode.* = .{
            .tag = .{ .node = true, .root = false, .leaf = false },
            .north = parent,
            .west = null,
            .east = null,
            .path = path_copy,
        };

        if (parent) |p| {
            if (p.west != null) return TreeError.NodeNotFound;
            p.west = newNode;
        }

        return newNode;
    }

    pub fn deinit(self: *Self, allocator: Allocator) void {
        if (self.west) |w| {
            w.deinit(allocator);
            self.west = null;
        }

        if (self.east) |e| {
            e.deinit(allocator);
            self.east = null;
        }

        allocator.free(self.path);
        if (!self.tag.root) {
            allocator.destroy(self);
        }
    }

    pub fn format(
        self: Self,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt;
        _ = options;
        const indent = "    ";

        try writer.print("\nNode {{\n{s}tag: {{ root: {}, node: {}, leaf: {} }},\n{s}path: '{s}',\n{s}north: ", .{
            indent,
            self.tag.root,
            self.tag.node,
            self.tag.leaf,
            indent,
            self.path,
            indent,
        });

        if (self.north) |n| {
            try writer.print("0x{x:0>16},\n", .{@intFromPtr(n)});
        } else {
            try writer.print("null,\n", .{});
        }

        try writer.print("{s}west:  ", .{indent});
        if (self.west) |w| {
            try writer.print("0x{x:0>16},\n", .{@intFromPtr(w)});
        } else {
            try writer.print("null,\n", .{});
        }

        try writer.print("{s}east:  ", .{indent});
        if (self.east) |e| {
            try writer.print("0x{x:0>16}\n}}", .{@intFromPtr(e)});
        } else {
            try writer.print("null\n}}", .{});
        }
    }
};

pub const Leaf = struct {
    tag: Tag,
    west: ?*Tree,
    east: ?*Leaf,
    key: []const u8,
    value: []const u8,
    size: u16,

    const Self = @This();

    pub fn initAlloc(allocator: Allocator, parent: ?*Node, key: []const u8, value: []const u8) TreeError!*Self {
        const key_copy = try allocator.dupe(u8, key);
        errdefer allocator.free(key_copy);

        const value_copy = try allocator.dupe(u8, value);
        errdefer allocator.free(value_copy);

        const newLeaf = try allocator.create(Leaf);
        errdefer allocator.destroy(newLeaf);

        var last: ?*Leaf = null;
        if (parent) |p| {
            last = findLastLinear(p);
            if (last == null) {
                p.east = newLeaf;
            } else {
                last.?.east = newLeaf;
            }
        }

        newLeaf.* = .{
            .tag = .{ .node = false, .root = false, .leaf = true },
            .west = if (last) |l| @ptrCast(l) else @ptrCast(parent),
            .east = null,
            .key = key_copy,
            .value = value_copy,
            .size = @intCast(value.len),
        };

        return newLeaf;
    }

    pub fn deinit(self: *Self, allocator: Allocator) void {
        if (self.east) |e| {
            e.deinit(allocator);
        }

        allocator.free(self.key);
        allocator.free(self.value);
        allocator.destroy(self);
    }

    fn findLastLinear(parent: *Node) ?*Self {
        if (parent.east == null) {
            return null;
        }

        var l = parent.east.?;
        while (l.east) |next| {
            l = next;
        }

        return l;
    }

    pub fn format(
        self: Self,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt;
        _ = options;
        const indent = "    ";

        try writer.print("\nLeaf {{\n{s}tag: {{ root: {}, node: {}, leaf: {} }},\n{s}key:   '{s}',\n{s}value: '{s}',\n{s}size:  {d},\n{s}west: ", .{
            indent,
            self.tag.root,
            self.tag.node,
            self.tag.leaf,
            indent,
            self.key,
            indent,
            self.value,
            indent,
            self.size,
            indent,
        });

        if (self.west) |w| {
            try writer.print("0x{x:0>16},\n", .{@intFromPtr(w)});
        } else {
            try writer.print("null,\n", .{});
        }

        try writer.print("{s}east: ", .{indent});
        if (self.east) |e| {
            try writer.print("0x{x:0>16}\n}}", .{@intFromPtr(e)});
        } else {
            try writer.print("null\n}}", .{});
        }
    }
};

const TreeTypes = enum {
    node,
    leaf,
};

pub const Tree = union(TreeTypes) {
    node: Node,
    leaf: Leaf,

    const Self = @This();

    pub fn initAlloc(allocator: Allocator) TreeError!*Self {
        const tree = try allocator.create(Tree);
        errdefer allocator.destroy(tree);

        const path_copy = try allocator.dupe(u8, "/");
        errdefer allocator.free(path_copy);

        tree.* = .{ .node = .{
            .tag = .{ .node = true, .root = true, .leaf = false },
            .north = null,
            .west = null,
            .east = null,
            .path = path_copy,
        } };

        return tree;
    }

    pub fn deinit(self: *Self, allocator: Allocator) void {
        switch (self.*) {
            .node => |*n| {
                if (n.west) |w| {
                    w.deinit(allocator);
                    n.west = null;
                }

                if (n.east) |e| {
                    e.deinit(allocator);
                    n.east = null;
                }

                allocator.free(n.path);
            },
            .leaf => |*l| {
                if (l.east) |e| {
                    e.deinit(allocator);
                }
                allocator.free(l.key);
                allocator.free(l.value);
            },
        }

        allocator.destroy(self);
    }

    pub fn format(
        self: Self,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        switch (self) {
            .node => |*node| {
                try writer.print("\nTree {{\n    Node:", .{});
                try node.format(fmt, options, writer);
            },
            .leaf => |*leaf| {
                try writer.print("\nTree {{\n    Leaf:", .{});
                try leaf.format(fmt, options, writer);
            },
        }

        try writer.print("\n}}", .{});
    }

    pub fn asNode(self: *Self) !*Node {
        return switch (self.*) {
            .node => |*n| n,
            .leaf => error.ExpectedNode,
        };
    }
};

pub const Tag = packed struct {
    root: bool,
    node: bool,
    leaf: bool,
};

pub fn nodeLookup(root: ?*Node, path: []const u8) ?*Node {
    var current_node = root;
    while (current_node) |node| {
        if (std.mem.eql(u8, node.path, path)) {
            return node;
        }

        current_node = node.west;
    }

    return null;
}

pub fn leafLookup(root: ?*Node, key: []const u8) ?*Leaf {
    var current_node = root;
    while (current_node) |node| {
        var current_leaf = node.east;
        while (current_leaf) |leaf| {
            if (std.mem.eql(u8, leaf.key, key)) {
                return leaf;
            }

            current_leaf = leaf.east;
        }
        current_node = node.west;
    }

    return null;
}
