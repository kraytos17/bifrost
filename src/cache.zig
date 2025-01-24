const std = @import("std");
const net = std.net;
const Allocator = std.mem.Allocator;

const Callback = *const fn ([]const u8, []const u8) i32;

pub fn serverLoop(port: u16) !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    const loopback_addr = try net.Ip4Address.parse("127.0.0.1", port);
    const host = net.Address{ .in = loopback_addr };

    var server = try host.listen(.{
        .reuse_port = true,
    });
    defer server.deinit();

    const addr = server.listen_address;
    std.log.info("Listening on {any}\n", .{addr});

    while (true) {
        var client = try server.accept();
        defer client.stream.close();
        std.log.info("Connection received from {any}\n", .{client.address});

        const reader = client.stream.reader();
        var buffer: [1024]u8 = undefined;

        while (true) {
            const bytes_read = reader.read(&buffer) catch |err| {
                if (err == error.EndOfStream) {
                    std.log.info("Client {any} disconnected\n", .{client.address});
                    break;
                }
                return err;
            };

            if (bytes_read == 0) {
                std.log.info("No more data from {any}, closing connection\n", .{client.address});
                break;
            }

            const received_msg = buffer[0..bytes_read];
            const parsed_cmd = parseCommand(received_msg, allocator) catch |err| {
                std.log.err("Error parsing command: {any}\n", .{err});
                continue;
            };
            defer parsed_cmd.deinit(allocator);

            prettyPrintCommand(parsed_cmd);

            if (CmdHandle.getHandler(&Handlers, parsed_cmd.command)) |handler| {
                _ = handler(parsed_cmd.folder, parsed_cmd.args);
            } else {
                std.log.err("Unknown command: {s}. No handlers currently registered for the command\n", .{parsed_cmd.command});
            }
        }
    }
}

pub const ParsedCommand = struct {
    command: []const u8,
    folder: []const u8,
    args: []const u8,

    pub fn deinit(self: ParsedCommand, allocator: std.mem.Allocator) void {
        allocator.free(self.command);
        allocator.free(self.folder);
        if (self.args.len > 0) {
            allocator.free(self.args);
        }
    }
};

pub fn parseCommand(input: []const u8, allocator: Allocator) !ParsedCommand {
    if (input.len == 0) return error.EmptyInput;

    var tokenizer = std.mem.tokenizeAny(u8, std.mem.trim(u8, input, " \t\r\n"), " ");
    const cmd = tokenizer.next() orelse return error.MissingCommand;
    const folder = tokenizer.next() orelse return error.MissingFolder;
    const rest = tokenizer.rest();

    const args = if (rest.len > 0)
        try allocator.dupe(u8, rest)
    else
        try allocator.dupe(u8, "");

    return ParsedCommand{
        .command = try allocator.dupe(u8, cmd),
        .folder = try allocator.dupe(u8, folder),
        .args = args,
    };
}

fn prettyPrintCommand(cmd: ParsedCommand) void {
    std.debug.print(
        \\=== Command Received ===
        \\Command: {s}
        \\Folder:  {s}
        \\Args:    {s}
        \\=======================
        \\
    , .{
        cmd.command,
        cmd.folder,
        cmd.args,
    });
}

pub const CmdType = enum {
    get,
    create,
    select,
    insert,
    update,
    delete,

    pub fn fromString(str: []const u8) ?CmdType {
        inline for (std.meta.fields(CmdType)) |field| {
            if (std.mem.eql(u8, str, field.name)) {
                return @field(CmdType, field.name);
            }
        }
        return null;
    }

    pub fn toString(self: CmdType) []const u8 {
        return switch (self) {
            .get => "get",
            .create => "create",
            .select => "select",
            .insert => "insert",
            .update => "update",
            .delete => "delete",
        };
    }
};

pub const CmdHandle = struct {
    cmd: CmdType,
    handler: Callback,

    pub fn getHandler(handlers: []const CmdHandle, cmd: []const u8) ?Callback {
        if (CmdType.fromString(cmd)) |cmdType| {
            for (handlers) |handle| {
                if (handle.cmd == cmdType) {
                    return handle.handler;
                }
            }
        }

        return null;
    }
};

pub const Handlers = [_]CmdHandle{ .{ .cmd = .get, .handler = handleGet }, .{ .cmd = .create, .handler = handleCreate } };

fn handleGet(folder: []const u8, args: []const u8) i32 {
    _ = folder;
    _ = args;
    std.debug.print("Hello handler\n", .{});
    return 0;
}

fn handleCreate(folder: []const u8, args: []const u8) i32 {
    _ = folder;
    _ = args;
    std.debug.print("Create handler\n", .{});
    return 0;
}
