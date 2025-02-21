const std = @import("std");
const zap = @import("zap");
const builtin = @import("builtin");
const routes = @import("routes/routes.zig");
const DispatchRoutes = routes.DispatchRoutes;
const contextLib = @import("middle/context.zig");
const controller = @import("middle/controller.zig");
const header = @import("middle/header.zig");
const Context = contextLib.Context;
const Session = contextLib.Session;
const SharedAllocator = contextLib.SharedAllocator;

const Handler = zap.Middleware.Handler(Context);

const port = 3003;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = if (builtin.mode == .Debug) gpa.allocator() else std.heap.c_allocator;
    SharedAllocator.init(allocator);
    {
        //
        // --- Routes
        //
        try routes.setup_routes(allocator);
        defer routes.deinit();

        //
        // --- Handlers
        //
        var controllerHandler = controller.ControllerMiddleWare.init(null, routes.dispatch_routes, allocator);
        var headerHandler = header.HeaderMiddleWare.init(controllerHandler.getHandler());

        //
        // --- Listner with first middleware in line
        //
        var listener = try zap.Middleware.Listener(Context).init(
            .{
                .port = port,
                .log = true,
                .max_clients = 100000, // TODO: setup this number
                .on_request = null, // must be null
            },
            headerHandler.getHandler(),
            SharedAllocator.getAllocator,
        );
        listener.listen() catch |err| {
            std.log.debug("\nLISTEN ERROR: {any}\n", .{err});
            return;
        };
        if (builtin.mode == .Debug) zap.enableDebugLog();
        std.log.debug("Listening on 0.0.0.0:{d}\n", .{port});

        //
        // --- Start worker threads
        //
        zap.start(.{
            // if all threads hang, your server will hang
            .threads = 1,
            // workers share memory so do not share states if you have multiple workers
            .workers = 1,
        });
    }

    if (builtin.mode == .Debug) {
        std.log.debug("\n\nSTOPPED!\n\n", .{});
        const leaked = gpa.detectLeaks();
        std.log.debug("Leaks detected: {}\n", .{leaked});
    }
}
