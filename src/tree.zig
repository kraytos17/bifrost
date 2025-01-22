const std = @import("std");
const Allocator = std.mem.Allocator;

pub const TreeError = error{
    InvalidPath,
    NodeNotFound,
    OutOfMemory,
    InvalidCast,
};

pub const Node = struct {
    tag: Tag,
    north: ?*Node,
    west: ?*Node,
    east: ?*Leaf,
    path: []const u8,

    const Self = @This();

    pub fn init(allocator: Allocator, parent: ?*Node, path: []const u8) !*Self {
        if (path.len == 0) return TreeError.InvalidPath;

        const path_copy = try allocator.dupe(u8, path);
        std.log.debug("Allocated {} bytes for node path '{s}'", .{ path_copy.len, path });
        errdefer allocator.free(path_copy);

        const newNode = try allocator.create(Node);
        std.log.debug("Allocated {} bytes for new node", .{@sizeOf(Node)});
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

        std.log.debug("Freeing {} bytes from node path '{s}'", .{ self.path.len, self.path });
        allocator.free(self.path);

        if (!self.tag.root) {
            std.log.debug("Freeing {} bytes from node", .{@sizeOf(Node)});
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

        try writer.writeAll("\nNode {\n");
        const indent = "    ";

        try writer.print("{s}tag: {{ root: {}, node: {}, leaf: {} }},\n", .{
            indent,
            self.tag.root,
            self.tag.node,
            self.tag.leaf,
        });

        try writer.print("{s}path: '{s}',\n", .{ indent, self.path });
        try writer.print("{s}north: ", .{indent});

        if (self.north) |n| {
            try writer.print("0x{x:0>16}", .{@intFromPtr(n)});
        } else {
            try writer.writeAll("null");
        }

        try writer.writeAll(",\n");
        try writer.print("{s}west:  ", .{indent});

        if (self.west) |w| {
            try writer.print("0x{x:0>16}", .{@intFromPtr(w)});
        } else {
            try writer.writeAll("null");
        }

        try writer.writeAll(",\n");
        try writer.print("{s}east:  ", .{indent});

        if (self.east) |e| {
            try writer.print("0x{x:0>16}", .{@intFromPtr(e)});
        } else {
            try writer.writeAll("null");
        }

        try writer.writeAll("\n}");
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

    pub fn init(allocator: Allocator, parent: ?*Node, key: []const u8, value: []const u8) !*Self {
        const key_copy = try allocator.dupe(u8, key);
        std.log.debug("Allocated {} bytes for leaf key '{s}'", .{ key_copy.len, key });
        errdefer allocator.free(key_copy);

        const value_copy = try allocator.dupe(u8, value);
        std.log.debug("Allocated {} bytes for leaf value", .{value_copy.len});
        errdefer allocator.free(value_copy);

        const newLeaf = try allocator.create(Leaf);
        std.log.debug("Allocated {} bytes for new leaf", .{@sizeOf(Leaf)});
        errdefer allocator.destroy(newLeaf);

        var last: ?*Leaf = null;
        if (parent) |p| {
            last = findLastLinear(p);
            if (!last) {
                p.east = newLeaf;
            } else {
                last.?.east = newLeaf;
            }
        }

        newLeaf.* = .{
            .tag = .{ .node = false, .root = false, .leaf = true },
            .west = if (last) {
                @as(?*Tree, last.?);
            } else {
                @as(?*Tree, parent.?);
            },
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

        std.log.debug("Freeing {} bytes from leaf key '{s}'", .{ self.key.len, self.key });
        allocator.free(self.key);
        std.log.debug("Freeing {} bytes from leaf value", .{self.value.len});
        allocator.free(self.value);
        std.log.debug("Freeing {} bytes from leaf", .{@sizeOf(Leaf)});
        allocator.destroy(self);
    }

    fn findLastLinear(parent: *Node) ?*Self {
        if (!parent.east) {
            return null;
        }

        var l = parent.east;
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

        try writer.writeAll("\nLeaf {\n");
        const indent = "    ";

        try writer.print("{s}tag: {{ root: {}, node: {}, leaf: {} }},\n", .{
            indent,
            self.tag.root,
            self.tag.node,
            self.tag.leaf,
        });

        try writer.print("{s}key:   '{s}',\n", .{ indent, self.key });
        try writer.print("{s}value: '{s}',\n", .{ indent, self.value });
        try writer.print("{s}size:  {d},\n", .{ indent, self.size });
        try writer.print("{s}west: ", .{indent});

        if (self.west) |w| {
            try writer.print("0x{x:0>16}", .{@intFromPtr(w)});
        } else {
            try writer.writeAll("null");
        }

        try writer.writeAll(",\n");
        try writer.print("{s}east: ", .{indent});

        if (self.east) |e| {
            try writer.print("0x{x:0>16}", .{@intFromPtr(e)});
        } else {
            try writer.writeAll("null");
        }

        try writer.writeAll("\n}");
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

    pub fn init(allocator: Allocator) !*Self {
        const tree = try allocator.create(Tree);
        std.log.debug("Allocated {} bytes for new tree", .{@sizeOf(Tree)});
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

        std.log.debug("Freeing {} bytes from tree", .{@sizeOf(Tree)});
        allocator.destroy(self);
    }

    pub fn format(
        self: Self,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        try writer.writeAll("\nTree {");
        switch (self) {
            .node => |*node| {
                try writer.writeAll("\n    Node:");
                try node.format(fmt, options, writer);
            },
            .leaf => |*leaf| {
                try writer.writeAll("\n    Leaf:");
                try leaf.format(fmt, options, writer);
            },
        }

        try writer.writeAll("\n}");
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
