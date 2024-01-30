const std = @import("std");
const builtin = @import("builtin");
const os = std.os;
const io = std.io;
const assert = std.debug.assert;

const tcp = @import("tcp.zig");

pub const Stream = struct {
    alloc: std.mem.Allocator,
    conn: *tcp.Conn,

    handle: std.os.socket_t,

    pub fn close(self: Stream) void {
        os.closeSocket(self.handle);
        self.alloc.destroy(self.conn);
    }

    pub const ReadError = os.ReadError;
    pub const WriteError = os.WriteError;

    pub const Reader = io.Reader(Stream, ReadError, read);
    pub const Writer = io.Writer(Stream, WriteError, write);

    pub fn reader(self: Stream) Reader {
        return .{ .context = self };
    }

    pub fn writer(self: Stream) Writer {
        return .{ .context = self };
    }

    pub fn read(self: Stream, buffer: []u8) ReadError!usize {
        return self.conn.receive(self.handle, buffer) catch |err| switch (err) {
            else => return error.Unexpected,
        };
    }

    pub fn readv(s: Stream, iovecs: []const os.iovec) ReadError!usize {
        return os.readv(s.handle, iovecs);
    }

    /// Returns the number of bytes read. If the number read is smaller than
    /// `buffer.len`, it means the stream reached the end. Reaching the end of
    /// a stream is not an error condition.
    pub fn readAll(s: Stream, buffer: []u8) ReadError!usize {
        return readAtLeast(s, buffer, buffer.len);
    }

    /// Returns the number of bytes read, calling the underlying read function
    /// the minimal number of times until the buffer has at least `len` bytes
    /// filled. If the number read is less than `len` it means the stream
    /// reached the end. Reaching the end of the stream is not an error
    /// condition.
    pub fn readAtLeast(s: Stream, buffer: []u8, len: usize) ReadError!usize {
        assert(len <= buffer.len);
        var index: usize = 0;
        while (index < len) {
            const amt = try s.read(buffer[index..]);
            if (amt == 0) break;
            index += amt;
        }
        return index;
    }

    /// TODO in evented I/O mode, this implementation incorrectly uses the event loop's
    /// file system thread instead of non-blocking. It needs to be reworked to properly
    /// use non-blocking I/O.
    pub fn write(self: Stream, buffer: []const u8) WriteError!usize {
        return self.conn.send(self.handle, buffer) catch |err| switch (err) {
            error.AccessDenied => error.AccessDenied,
            error.WouldBlock => error.WouldBlock,
            error.ConnectionResetByPeer => error.ConnectionResetByPeer,
            error.MessageTooBig => error.FileTooBig,
            error.BrokenPipe => error.BrokenPipe,
            else => return error.Unexpected,
        };
    }

    pub fn writeAll(self: Stream, bytes: []const u8) WriteError!void {
        var index: usize = 0;
        while (index < bytes.len) {
            index += try self.write(bytes[index..]);
        }
    }

    /// See https://github.com/ziglang/zig/issues/7699
    /// See equivalent function: `std.fs.File.writev`.
    pub fn writev(self: Stream, iovecs: []const os.iovec_const) WriteError!usize {
        if (iovecs.len == 0) return 0;
        const first_buffer = iovecs[0].iov_base[0..iovecs[0].iov_len];
        return try self.write(first_buffer);
    }

    /// The `iovecs` parameter is mutable because this function needs to mutate the fields in
    /// order to handle partial writes from the underlying OS layer.
    /// See https://github.com/ziglang/zig/issues/7699
    /// See equivalent function: `std.fs.File.writevAll`.
    pub fn writevAll(self: Stream, iovecs: []os.iovec_const) WriteError!void {
        if (iovecs.len == 0) return;

        var i: usize = 0;
        while (true) {
            var amt = try self.writev(iovecs[i..]);
            while (amt >= iovecs[i].iov_len) {
                amt -= iovecs[i].iov_len;
                i += 1;
                if (i >= iovecs.len) return;
            }
            iovecs[i].iov_base += amt;
            iovecs[i].iov_len -= amt;
        }
    }
};
