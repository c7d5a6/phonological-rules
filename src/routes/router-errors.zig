const web = @import("baz");

/// Errors that map to a client error. Anything else goes through
/// `web.defaultErrorStatus`.
pub const ControllerError = error{
    InvalidUtf8,
    InvalidRule,
    InvalidInput,
    InternalError,
};

pub fn httpStatus(err: anyerror) u16 {
    return switch (err) {
        error.InvalidUtf8, error.InvalidRule, error.InvalidInput, error.BadRequest => 400,
        else => web.defaultErrorStatus(err),
    };
}
