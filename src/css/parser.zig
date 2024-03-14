// CSS Selector parser
// This file is a rewrite in Zig of Cascadia CSS Selector parser.
// see https://github.com/andybalholm/cascadia
// see https://github.com/andybalholm/cascadia/blob/master/parser.go
const std = @import("std");
const ascii = std.ascii;

pub const AttributeOP = enum {
    eql, // =
    not_eql, // !=
    one_of, // ~=
    prefix_hyphen, // |=
    prefix, // ^=
    suffix, // $=
    contains, // *=
    regexp, // #=

    fn len(op: AttributeOP) u2 {
        if (op == .eql) return 1;
        return 2;
    }
};

pub const PseudoClass = enum {
    not,
    has,
    haschild,
    contains,
    containsown,
    matches,
    matchesown,
    nth_child,
    nth_last_child,
    nth_of_type,
    nth_last_of_type,
    first_child,
    last_child,
    first_of_type,
    last_of_type,
    only_child,
    only_of_type,
    input,
    empty,
    root,
    link,
    lang,
    enabled,
    disabled,
    checked,
    visited,
    hover,
    active,
    focus,
    target,
    after,
    backdrop,
    before,
    cue,
    first_letter,
    first_line,
    grammar_error,
    marker,
    placeholder,
    selection,
    spelling_error,

    fn isPseudoElement(pc: PseudoClass) bool {
        return switch (pc) {
            .after, .backdrop, .before, .cue, .first_letter => true,
            .first_line, .grammar_error, .marker, .placeholder => true,
            .selection, .spelling_error => true,
            else => false,
        };
    }

    fn parse(s: []const u8) ParseError!PseudoClass {
        if (std.ascii.eqlIgnoreCase(s, "not")) return .not;
        if (std.ascii.eqlIgnoreCase(s, "has")) return .has;
        if (std.ascii.eqlIgnoreCase(s, "haschild")) return .haschild;
        if (std.ascii.eqlIgnoreCase(s, "contains")) return .contains;
        if (std.ascii.eqlIgnoreCase(s, "containsown")) return .containsown;
        if (std.ascii.eqlIgnoreCase(s, "matches")) return .matches;
        if (std.ascii.eqlIgnoreCase(s, "matchesown")) return .matchesown;
        if (std.ascii.eqlIgnoreCase(s, "nth-child")) return .nth_child;
        if (std.ascii.eqlIgnoreCase(s, "nth-last-child")) return .nth_last_child;
        if (std.ascii.eqlIgnoreCase(s, "nth-of-type")) return .nth_of_type;
        if (std.ascii.eqlIgnoreCase(s, "nth-last-of-type")) return .nth_last_of_type;
        if (std.ascii.eqlIgnoreCase(s, "first-child")) return .first_child;
        if (std.ascii.eqlIgnoreCase(s, "last-child")) return .last_child;
        if (std.ascii.eqlIgnoreCase(s, "first-of-type")) return .first_of_type;
        if (std.ascii.eqlIgnoreCase(s, "last-of-type")) return .last_of_type;
        if (std.ascii.eqlIgnoreCase(s, "only-child")) return .only_child;
        if (std.ascii.eqlIgnoreCase(s, "only-of-type")) return .only_of_type;
        if (std.ascii.eqlIgnoreCase(s, "input")) return .input;
        if (std.ascii.eqlIgnoreCase(s, "empty")) return .empty;
        if (std.ascii.eqlIgnoreCase(s, "root")) return .root;
        if (std.ascii.eqlIgnoreCase(s, "link")) return .link;
        if (std.ascii.eqlIgnoreCase(s, "lang")) return .lang;
        if (std.ascii.eqlIgnoreCase(s, "enabled")) return .enabled;
        if (std.ascii.eqlIgnoreCase(s, "disabled")) return .disabled;
        if (std.ascii.eqlIgnoreCase(s, "checked")) return .checked;
        if (std.ascii.eqlIgnoreCase(s, "visited")) return .visited;
        if (std.ascii.eqlIgnoreCase(s, "hover")) return .hover;
        if (std.ascii.eqlIgnoreCase(s, "active")) return .active;
        if (std.ascii.eqlIgnoreCase(s, "focus")) return .focus;
        if (std.ascii.eqlIgnoreCase(s, "target")) return .target;
        if (std.ascii.eqlIgnoreCase(s, "after")) return .after;
        if (std.ascii.eqlIgnoreCase(s, "backdrop")) return .backdrop;
        if (std.ascii.eqlIgnoreCase(s, "before")) return .before;
        if (std.ascii.eqlIgnoreCase(s, "cue")) return .cue;
        if (std.ascii.eqlIgnoreCase(s, "first-letter")) return .first_letter;
        if (std.ascii.eqlIgnoreCase(s, "first-line")) return .first_line;
        if (std.ascii.eqlIgnoreCase(s, "grammar-error")) return .grammar_error;
        if (std.ascii.eqlIgnoreCase(s, "marker")) return .marker;
        if (std.ascii.eqlIgnoreCase(s, "placeholder")) return .placeholder;
        if (std.ascii.eqlIgnoreCase(s, "selection")) return .selection;
        if (std.ascii.eqlIgnoreCase(s, "spelling-error")) return .spelling_error;
        return ParseError.InvalidPseudoClass;
    }
};

pub const Selector = union(enum) {
    compound: struct {
        selectors: []Selector,
        pseudo_elt: ?PseudoClass,
    },
    group: []Selector,
    tag: []const u8,
    id: []const u8,
    class: []const u8,
    attribute: struct {
        key: []const u8,
        val: ?[]const u8 = null,
        op: ?AttributeOP = null,
        regexp: ?[]const u8 = null,
        ci: bool = false,
    },
    combined: struct {
        first: *Selector,
        second: *Selector,
        combinator: u8,
    },

    never_match: PseudoClass,

    pseudo_class: PseudoClass,
    pseudo_class_only_child: bool,
    pseudo_class_lang: []const u8,
    pseudo_class_relative: struct {
        pseudo_class: PseudoClass,
        match: *Selector,
    },
    pseudo_class_contains: struct {
        own: bool,
        val: []const u8,
    },
    pseudo_class_regexp: struct {
        own: bool,
        regexp: []const u8,
    },
    pseudo_class_nth: struct {
        a: isize,
        b: isize,
        of_type: bool,
        last: bool,
    },
    pseudo_element: PseudoClass,

    fn deinit(sel: Selector, alloc: std.mem.Allocator) void {
        switch (sel) {
            .group => |v| {
                for (v) |vv| vv.deinit(alloc);
                alloc.free(v);
            },
            .compound => |v| {
                for (v.selectors) |vv| vv.deinit(alloc);
                alloc.free(v.selectors);
            },
            .tag, .id, .class, .pseudo_class_lang => |v| alloc.free(v),
            .attribute => |att| {
                alloc.free(att.key);
                if (att.val) |v| alloc.free(v);
                if (att.regexp) |v| alloc.free(v);
            },
            .combined => |c| {
                c.first.deinit(alloc);
                alloc.destroy(c.first);
                c.second.deinit(alloc);
                alloc.destroy(c.second);
            },
            .pseudo_class_relative => |v| {
                v.match.deinit(alloc);
                alloc.destroy(v.match);
            },
            .pseudo_class_contains => |v| alloc.free(v.val),
            .pseudo_class_regexp => |v| alloc.free(v.regexp),
            .pseudo_class, .pseudo_element, .never_match => {},
            .pseudo_class_nth, .pseudo_class_only_child => {},
        }
    }
};

pub const ParseError = error{
    ExpectedSelector,
    ExpectedIdentifier,
    ExpectedName,
    ExpectedIDSelector,
    ExpectedClassSelector,
    ExpectedAttributeSelector,
    ExpectedString,
    ExpectedRegexp,
    ExpectedPseudoClassSelector,
    ExpectedParenthesis,
    ExpectedParenthesisClose,
    ExpectedNthExpression,
    ExpectedInteger,
    InvalidEscape,
    EscapeLineEndingOutsideString,
    InvalidUnicode,
    UnicodeIsNotHandled,
    WriteError,
    PseudoElementNotAtSelectorEnd,
    PseudoElementNotUnique,
    PseudoElementDisabled,
    InvalidAttributeOperator,
    InvalidAttributeSelector,
    InvalidString,
    InvalidRegexp,
    InvalidPseudoClassSelector,
    EmptyPseudoClassSelector,
    InvalidPseudoClass,
    InvalidPseudoElement,
    UnmatchParenthesis,
    NotHandled,
    UnknownPseudoSelector,
    InvalidNthExpression,
} || std.mem.Allocator.Error;

pub const ParseOptions = struct {
    accept_pseudo_elts: bool = true,
};

// Parse parse a selector string and returns the parsed result or an error.
pub fn Parse(alloc: std.mem.Allocator, s: []const u8, opts: ParseOptions) ParseError!Selector {
    var p = Parser{ .s = s, .i = 0, .opts = opts };
    return p.parseSelector(alloc);
}

const Parser = struct {
    s: []const u8, // string to parse
    i: usize = 0, // current position

    opts: ParseOptions,

    // skipWhitespace consumes whitespace characters and comments.
    // It returns true if there was actually anything to skip.
    fn skipWhitespace(p: *Parser) bool {
        var i = p.i;
        while (i < p.s.len) {
            const c = p.s[i];
            // Whitespaces.
            if (ascii.isWhitespace(c)) {
                i += 1;
                continue;
            }

            // Comments.
            if (c == '/') {
                if (std.mem.startsWith(u8, p.s[i..], "/*")) {
                    if (std.mem.indexOf(u8, p.s[i..], "*/")) |end| {
                        i += end + "*/".len;
                        continue;
                    }
                }
            }
            break;
        }

        if (i > p.i) {
            p.i = i;
            return true;
        }

        return false;
    }

    // parseSimpleSelectorSequence parses a selector sequence that applies to
    // a single element.
    fn parseSimpleSelectorSequence(p: *Parser, alloc: std.mem.Allocator) ParseError!Selector {
        if (p.i >= p.s.len) {
            return ParseError.ExpectedSelector;
        }

        var buf = std.ArrayList(Selector).init(alloc);
        defer buf.deinit();

        switch (p.s[p.i]) {
            '*' => {
                // It's the universal selector. Just skip over it, since it
                // doesn't affect the meaning.
                p.i += 1;

                // other version of universal selector
                if (p.i + 2 < p.s.len and std.mem.eql(u8, "|*", p.s[p.i .. p.i + 2])) {
                    p.i += 2;
                }
            },
            '#', '.', '[', ':' => {
                // There's no type selector. Wait to process the other till the
                // main loop.
            },
            else => try buf.append(try p.parseTypeSelector(alloc)),
        }

        var pseudo_elt: ?PseudoClass = null;

        loop: while (p.i < p.s.len) {
            var ns: Selector = switch (p.s[p.i]) {
                '#' => try p.parseIDSelector(alloc),
                '.' => try p.parseClassSelector(alloc),
                '[' => try p.parseAttributeSelector(alloc),
                ':' => try p.parsePseudoclassSelector(alloc),
                else => break :loop,
            };
            errdefer ns.deinit(alloc);

            // From https://drafts.csswg.org/selectors-3/#pseudo-elements :
            // "Only one pseudo-element may appear per selector, and if present
            // it must appear after the sequence of simple selectors that
            // represents the subjects of the selector.""
            switch (ns) {
                .pseudo_element => |e| {
                    //  We found a pseudo-element.
                    //  Only one pseudo-element is accepted per selector.
                    if (pseudo_elt != null) return ParseError.PseudoElementNotUnique;
                    if (!p.opts.accept_pseudo_elts) return ParseError.PseudoElementDisabled;

                    pseudo_elt = e;
                    ns.deinit(alloc);
                },
                else => {
                    if (pseudo_elt != null) return ParseError.PseudoElementNotAtSelectorEnd;
                    try buf.append(ns);
                },
            }
        }

        // no need wrap the selectors in compoundSelector
        if (buf.items.len == 1 and pseudo_elt == null) return buf.items[0];

        return .{ .compound = .{ .selectors = try buf.toOwnedSlice(), .pseudo_elt = pseudo_elt } };
    }

    // parseTypeSelector parses a type selector (one that matches by tag name).
    fn parseTypeSelector(p: *Parser, alloc: std.mem.Allocator) ParseError!Selector {
        var buf = std.ArrayList(u8).init(alloc);
        defer buf.deinit();
        try p.parseIdentifier(buf.writer());

        return .{ .tag = try buf.toOwnedSlice() };
    }

    // parseIdentifier parses an identifier.
    fn parseIdentifier(p: *Parser, w: anytype) ParseError!void {
        const prefix = '-';
        var numPrefix: usize = 0;

        while (p.s.len > p.i and p.s[p.i] == prefix) {
            p.i += 1;
            numPrefix += 1;
        }

        if (p.s.len <= p.i) {
            return ParseError.ExpectedSelector;
        }

        const c = p.s[p.i];
        if (!nameStart(c) or c == '\\') {
            return ParseError.ExpectedSelector;
        }

        var ii: usize = 0;
        while (ii < numPrefix) {
            w.writeByte(prefix) catch return ParseError.WriteError;
            ii += 1;
        }
        try parseName(p, w);
    }

    // parseName parses a name (which is like an identifier, but doesn't have
    // extra restrictions on the first character).
    fn parseName(p: *Parser, w: anytype) ParseError!void {
        var i = p.i;
        var ok = false;

        while (i < p.s.len) {
            const c = p.s[i];

            if (nameChar(c)) {
                const start = i;
                while (i < p.s.len and nameChar(p.s[i])) i += 1;
                w.writeAll(p.s[start..i]) catch return ParseError.WriteError;
                ok = true;
            } else if (c == '\\') {
                p.i = i;
                try p.parseEscape(w);
                i = p.i;
                ok = true;
            } else {
                // default:
                break;
            }
        }

        if (!ok) return ParseError.ExpectedName;
        p.i = i;
    }

    // parseEscape parses a backslash escape.
    // The returned string is owned by the caller.
    fn parseEscape(p: *Parser, w: anytype) ParseError!void {
        if (p.s.len < p.i + 2 or p.s[p.i] != '\\') {
            return ParseError.InvalidEscape;
        }

        const start = p.i + 1;
        const c = p.s[start];
        if (ascii.isWhitespace(c)) return ParseError.EscapeLineEndingOutsideString;

        // unicode escape (hex)
        if (ascii.isHex(c)) {
            var i: usize = start;
            while (i < start + 6 and i < p.s.len and ascii.isHex(p.s[i])) {
                i += 1;
            }
            const v = std.fmt.parseUnsigned(u21, p.s[start..i], 16) catch return ParseError.InvalidUnicode;
            if (p.s.len > i) {
                switch (p.s[i]) {
                    '\r' => {
                        i += 1;
                        if (p.s.len > i and p.s[i] == '\n') i += 1;
                    },
                    ' ', '\t', '\n', std.ascii.control_code.ff => i += 1,
                    else => {},
                }
                p.i = i;
                var buf: [4]u8 = undefined;
                const ln = std.unicode.utf8Encode(v, &buf) catch return ParseError.InvalidUnicode;
                w.writeAll(buf[0..ln]) catch return ParseError.WriteError;
                return;
            }
        }

        // Return the literal character after the backslash.
        p.i += 2;
        w.writeAll(p.s[start .. start + 1]) catch return ParseError.WriteError;
    }

    // parseIDSelector parses a selector that matches by id attribute.
    fn parseIDSelector(p: *Parser, alloc: std.mem.Allocator) ParseError!Selector {
        if (p.i >= p.s.len) return ParseError.ExpectedIDSelector;
        if (p.s[p.i] != '#') return ParseError.ExpectedIDSelector;

        p.i += 1;

        var buf = std.ArrayList(u8).init(alloc);
        defer buf.deinit();

        try p.parseName(buf.writer());
        return .{ .id = try buf.toOwnedSlice() };
    }

    // parseClassSelector parses a selector that matches by class attribute.
    fn parseClassSelector(p: *Parser, alloc: std.mem.Allocator) ParseError!Selector {
        if (p.i >= p.s.len) return ParseError.ExpectedClassSelector;
        if (p.s[p.i] != '.') return ParseError.ExpectedClassSelector;

        p.i += 1;

        var buf = std.ArrayList(u8).init(alloc);
        defer buf.deinit();

        try p.parseIdentifier(buf.writer());
        return .{ .class = try buf.toOwnedSlice() };
    }

    // parseAttributeSelector parses a selector that matches by attribute value.
    fn parseAttributeSelector(p: *Parser, alloc: std.mem.Allocator) ParseError!Selector {
        if (p.i >= p.s.len) return ParseError.ExpectedAttributeSelector;
        if (p.s[p.i] != '[') return ParseError.ExpectedAttributeSelector;

        p.i += 1;
        _ = p.skipWhitespace();

        var buf = std.ArrayList(u8).init(alloc);
        defer buf.deinit();

        try p.parseIdentifier(buf.writer());
        const key = try buf.toOwnedSlice();
        errdefer alloc.free(key);

        lowerstr(key);

        _ = p.skipWhitespace();
        if (p.i >= p.s.len) return ParseError.ExpectedAttributeSelector;
        if (p.s[p.i] == ']') {
            p.i += 1;
            return .{ .attribute = .{ .key = key } };
        }

        if (p.i + 2 >= p.s.len) return ParseError.ExpectedAttributeSelector;

        const op = try parseAttributeOP(p.s[p.i .. p.i + 2]);
        p.i += op.len();

        _ = p.skipWhitespace();
        if (p.i >= p.s.len) return ParseError.ExpectedAttributeSelector;

        buf.clearRetainingCapacity();
        var is_val: bool = undefined;
        if (op == .regexp) {
            is_val = false;
            try p.parseRegex(buf.writer());
        } else {
            is_val = true;
            switch (p.s[p.i]) {
                '\'', '"' => try p.parseString(buf.writer()),
                else => try p.parseIdentifier(buf.writer()),
            }
        }

        _ = p.skipWhitespace();
        if (p.i >= p.s.len) return ParseError.ExpectedAttributeSelector;

        // check if the attribute contains an ignore case flag
        var ci = false;
        if (p.s[p.i] == 'i' or p.s[p.i] == 'I') {
            ci = true;
            p.i += 1;
        }

        _ = p.skipWhitespace();
        if (p.i >= p.s.len) return ParseError.ExpectedAttributeSelector;

        if (p.s[p.i] != ']') return ParseError.InvalidAttributeSelector;
        p.i += 1;

        return .{ .attribute = .{
            .key = key,
            .val = if (is_val) try buf.toOwnedSlice() else null,
            .regexp = if (!is_val) try buf.toOwnedSlice() else null,
            .op = op,
            .ci = ci,
        } };
    }

    // parseString parses a single- or double-quoted string.
    fn parseString(p: *Parser, writer: anytype) ParseError!void {
        var i = p.i;
        if (p.s.len < i + 2) return ParseError.ExpectedString;

        const quote = p.s[i];
        i += 1;

        loop: while (i < p.s.len) {
            switch (p.s[i]) {
                '\\' => {
                    if (p.s.len > i + 1) {
                        const c = p.s[i + 1];
                        switch (c) {
                            '\r' => {
                                if (p.s.len > i + 2 and p.s[i + 2] == '\n') {
                                    i += 3;
                                    continue :loop;
                                }
                                i += 2;
                                continue :loop;
                            },
                            '\n', std.ascii.control_code.ff => {
                                i += 2;
                                continue :loop;
                            },
                            else => {},
                        }
                    }
                    p.i = i;
                    try p.parseEscape(writer);
                    i = p.i;
                },
                '\r', '\n', std.ascii.control_code.ff => return ParseError.InvalidString,
                else => |c| {
                    if (c == quote) break :loop;
                    const start = i;
                    while (i < p.s.len) {
                        const cc = p.s[i];
                        if (cc == quote or cc == '\\' or c == '\r' or c == '\n' or c == std.ascii.control_code.ff) break;
                        i += 1;
                    }
                    writer.writeAll(p.s[start..i]) catch return ParseError.WriteError;
                },
            }
        }

        if (i >= p.s.len) return ParseError.InvalidString;

        // Consume the final quote.
        i += 1;
        p.i = i;
    }

    // parseRegex parses a regular expression; the end is defined by encountering an
    // unmatched closing ')' or ']' which is not consumed
    fn parseRegex(p: *Parser, writer: anytype) ParseError!void {
        var i = p.i;
        if (p.s.len < i + 2) return ParseError.ExpectedRegexp;

        // number of open parens or brackets;
        // when it becomes negative, finished parsing regex
        var open: isize = 0;

        loop: while (i < p.s.len) {
            switch (p.s[i]) {
                '(', '[' => open += 1,
                ')', ']' => {
                    open -= 1;
                    if (open < 0) break :loop;
                },
                else => {},
            }
            i += 1;
        }

        if (i >= p.s.len) return ParseError.InvalidRegexp;
        writer.writeAll(p.s[p.i..i]) catch return ParseError.WriteError;
        p.i = i;
    }

    // parsePseudoclassSelector parses a pseudoclass selector like :not(p) or a pseudo-element
    // For backwards compatibility, both ':' and '::' prefix are allowed for pseudo-elements.
    // https://drafts.csswg.org/selectors-3/#pseudo-elements
    fn parsePseudoclassSelector(p: *Parser, alloc: std.mem.Allocator) ParseError!Selector {
        if (p.i >= p.s.len) return ParseError.ExpectedPseudoClassSelector;
        if (p.s[p.i] != ':') return ParseError.ExpectedPseudoClassSelector;

        p.i += 1;

        var must_pseudo_elt: bool = false;
        if (p.i >= p.s.len) return ParseError.EmptyPseudoClassSelector;
        if (p.s[p.i] == ':') { // we found a pseudo-element
            must_pseudo_elt = true;
            p.i += 1;
        }

        var buf = std.ArrayList(u8).init(alloc);
        defer buf.deinit();

        try p.parseIdentifier(buf.writer());

        const pseudo_class = try PseudoClass.parse(buf.items);

        // reset the buffer to reuse it.
        buf.clearRetainingCapacity();

        if (must_pseudo_elt and !pseudo_class.isPseudoElement()) return ParseError.InvalidPseudoElement;

        switch (pseudo_class) {
            .not, .has, .haschild => {
                if (!p.consumeParenthesis()) return ParseError.ExpectedParenthesis;

                const sel = try p.parseSelectorGroup(alloc);
                if (!p.consumeClosingParenthesis()) return ParseError.ExpectedParenthesisClose;

                const s = try alloc.create(Selector);
                errdefer alloc.destroy(s);
                s.* = sel;

                return .{ .pseudo_class_relative = .{ .pseudo_class = pseudo_class, .match = s } };
            },
            .contains, .containsown => {
                if (!p.consumeParenthesis()) return ParseError.ExpectedParenthesis;
                if (p.i == p.s.len) return ParseError.UnmatchParenthesis;

                switch (p.s[p.i]) {
                    '\'', '"' => try p.parseString(buf.writer()),
                    else => try p.parseString(buf.writer()),
                }

                _ = p.skipWhitespace();
                if (p.i >= p.s.len) return ParseError.InvalidPseudoClass;
                if (!p.consumeClosingParenthesis()) return ParseError.ExpectedParenthesisClose;

                const val = try buf.toOwnedSlice();
                errdefer alloc.free(val);

                lowerstr(val);

                return .{ .pseudo_class_contains = .{ .own = pseudo_class == .containsown, .val = val } };
            },
            .matches, .matchesown => {
                if (!p.consumeParenthesis()) return ParseError.ExpectedParenthesis;

                try p.parseRegex(buf.writer());
                if (p.i >= p.s.len) return ParseError.InvalidPseudoClassSelector;
                if (!p.consumeClosingParenthesis()) return ParseError.ExpectedParenthesisClose;

                return .{ .pseudo_class_regexp = .{ .own = pseudo_class == .matchesown, .regexp = try buf.toOwnedSlice() } };
            },
            .nth_child, .nth_last_child, .nth_of_type, .nth_last_of_type => {
                if (!p.consumeParenthesis()) return ParseError.ExpectedParenthesis;
                const nth = try p.parseNth(alloc);
                if (!p.consumeClosingParenthesis()) return ParseError.ExpectedParenthesisClose;

                const last = pseudo_class == .nth_last_child or pseudo_class == .nth_last_of_type;
                const of_type = pseudo_class == .nth_of_type or pseudo_class == .nth_last_of_type;
                return .{ .pseudo_class_nth = .{ .a = nth[0], .b = nth[1], .of_type = of_type, .last = last } };
            },
            .first_child => return .{ .pseudo_class_nth = .{ .a = 0, .b = 1, .of_type = false, .last = false } },
            .last_child => return .{ .pseudo_class_nth = .{ .a = 0, .b = 1, .of_type = false, .last = true } },
            .first_of_type => return .{ .pseudo_class_nth = .{ .a = 0, .b = 1, .of_type = true, .last = false } },
            .last_of_type => return .{ .pseudo_class_nth = .{ .a = 0, .b = 1, .of_type = true, .last = true } },
            .only_child => return .{ .pseudo_class_only_child = false },
            .only_of_type => return .{ .pseudo_class_only_child = true },
            .input, .empty, .root, .link => return .{ .pseudo_class = pseudo_class },
            .enabled, .disabled, .checked => return .{ .pseudo_class = pseudo_class },
            .lang => {
                if (!p.consumeParenthesis()) return ParseError.ExpectedParenthesis;
                if (p.i == p.s.len) return ParseError.UnmatchParenthesis;

                try p.parseIdentifier(buf.writer());

                _ = p.skipWhitespace();
                if (p.i >= p.s.len) return ParseError.InvalidPseudoClass;
                if (!p.consumeClosingParenthesis()) return ParseError.ExpectedParenthesisClose;

                const val = try buf.toOwnedSlice();
                errdefer alloc.free(val);
                lowerstr(val);

                return .{ .pseudo_class_lang = val };
            },
            .visited, .hover, .active, .focus, .target => {
                // Not applicable in a static context: never match.
                return .{ .never_match = pseudo_class };
            },
            .after, .backdrop, .before, .cue, .first_letter => return .{ .pseudo_element = pseudo_class },
            .first_line, .grammar_error, .marker, .placeholder => return .{ .pseudo_element = pseudo_class },
            .selection, .spelling_error => return .{ .pseudo_element = pseudo_class },
        }
    }

    // consumeParenthesis consumes an opening parenthesis and any following
    // whitespace. It returns true if there was actually a parenthesis to skip.
    fn consumeParenthesis(p: *Parser) bool {
        if (p.i < p.s.len and p.s[p.i] == '(') {
            p.i += 1;
            _ = p.skipWhitespace();
            return true;
        }
        return false;
    }

    // parseSelectorGroup parses a group of selectors, separated by commas.
    fn parseSelectorGroup(p: *Parser, alloc: std.mem.Allocator) ParseError!Selector {
        const s = try p.parseSelector(alloc);

        var buf = std.ArrayList(Selector).init(alloc);
        defer buf.deinit();

        try buf.append(s);

        while (p.i < p.s.len) {
            if (p.s[p.i] != ',') break;
            p.i += 1;
            const ss = try p.parseSelector(alloc);
            try buf.append(ss);
        }

        return .{ .group = try buf.toOwnedSlice() };
    }

    // parseSelector parses a selector that may include combinators.
    fn parseSelector(p: *Parser, alloc: std.mem.Allocator) ParseError!Selector {
        _ = p.skipWhitespace();
        var s = try p.parseSimpleSelectorSequence(alloc);

        while (true) {
            var combinator: u8 = undefined;
            if (p.skipWhitespace()) {
                combinator = ' ';
            }
            if (p.i >= p.s.len) {
                return s;
            }

            switch (p.s[p.i]) {
                '+', '>', '~' => {
                    combinator = p.s[p.i];
                    p.i += 1;
                    _ = p.skipWhitespace();
                },
                // These characters can't begin a selector, but they can legally occur after one.
                ',', ')' => return s,
                else => {},
            }

            if (combinator == 0) {
                return s;
            }

            const c = try p.parseSimpleSelectorSequence(alloc);

            const first = try alloc.create(Selector);
            errdefer alloc.destroy(first);
            first.* = s;

            const second = try alloc.create(Selector);
            errdefer alloc.destroy(second);
            second.* = c;

            s = Selector{ .combined = .{ .first = first, .second = second, .combinator = combinator } };
        }

        return s;
    }

    // consumeClosingParenthesis consumes a closing parenthesis and any preceding
    // whitespace. It returns true if there was actually a parenthesis to skip.
    fn consumeClosingParenthesis(p: *Parser) bool {
        const i = p.i;
        _ = p.skipWhitespace();
        if (p.i < p.s.len and p.s[p.i] == ')') {
            p.i += 1;
            return true;
        }
        p.i = i;
        return false;
    }

    // parseInteger parses a  decimal integer.
    fn parseInteger(p: *Parser) ParseError!isize {
        var i = p.i;
        const start = i;
        while (i < p.s.len and '0' <= p.s[i] and p.s[i] <= '9') i += 1;
        if (i == start) return ParseError.ExpectedInteger;
        p.i = i;

        return std.fmt.parseUnsigned(isize, p.s[start..i], 10) catch ParseError.ExpectedInteger;
    }

    fn parseNthReadN(p: *Parser, a: isize) ParseError![2]isize {
        _ = p.skipWhitespace();
        if (p.i >= p.s.len) return ParseError.ExpectedNthExpression;

        return switch (p.s[p.i]) {
            '+' => {
                p.i += 1;
                _ = p.skipWhitespace();
                const b = try p.parseInteger();
                return .{ a, b };
            },
            '-' => {
                p.i += 1;
                _ = p.skipWhitespace();
                const b = try p.parseInteger();
                return .{ a, -b };
            },
            else => .{ a, 0 },
        };
    }

    fn parseNthReadA(p: *Parser, a: isize) ParseError![2]isize {
        if (p.i >= p.s.len) return ParseError.ExpectedNthExpression;
        return switch (p.s[p.i]) {
            'n', 'N' => {
                p.i += 1;
                return p.parseNthReadN(a);
            },
            else => .{ 0, a },
        };
    }

    fn parseNthNegativeA(p: *Parser) ParseError![2]isize {
        if (p.i >= p.s.len) return ParseError.ExpectedNthExpression;
        const c = p.s[p.i];
        if (std.ascii.isDigit(c)) {
            const a = try p.parseInteger() * -1;
            return p.parseNthReadA(a);
        }
        if (c == 'n' or c == 'N') {
            p.i += 1;
            return p.parseNthReadN(-1);
        }

        return ParseError.InvalidNthExpression;
    }

    fn parseNthPositiveA(p: *Parser) ParseError![2]isize {
        if (p.i >= p.s.len) return ParseError.ExpectedNthExpression;
        const c = p.s[p.i];
        if (std.ascii.isDigit(c)) {
            const a = try p.parseInteger() * -1;
            return p.parseNthReadA(a);
        }
        if (c == 'n' or c == 'N') {
            p.i += 1;
            return p.parseNthReadN(1);
        }

        return ParseError.InvalidNthExpression;
    }

    // parseNth parses the argument for :nth-child (normally of the form an+b).
    fn parseNth(p: *Parser, alloc: std.mem.Allocator) ParseError![2]isize {
        // initial state
        if (p.i >= p.s.len) return ParseError.ExpectedNthExpression;
        return switch (p.s[p.i]) {
            '-' => {
                p.i += 1;
                return p.parseNthNegativeA();
            },
            '+' => {
                p.i += 1;
                return p.parseNthPositiveA();
            },
            '0', '1', '2', '3', '4', '5', '6', '7', '8', '9' => p.parseNthPositiveA(),
            'n', 'N' => {
                p.i += 1;
                return p.parseNthReadN(1);
            },
            'o', 'O', 'e', 'E' => {
                var buf = std.ArrayList(u8).init(alloc);
                defer buf.deinit();

                try p.parseName(buf.writer());

                if (std.ascii.eqlIgnoreCase("odd", buf.items)) return .{ 2, 1 };
                if (std.ascii.eqlIgnoreCase("even", buf.items)) return .{ 2, 0 };

                return ParseError.InvalidNthExpression;
            },
            else => ParseError.InvalidNthExpression,
        };
    }
};

// nameStart returns whether c can be the first character of an identifier
// (not counting an initial hyphen, or an escape sequence).
fn nameStart(c: u8) bool {
    return 'a' <= c and c <= 'z' or 'A' <= c and c <= 'Z' or c == '_' or c > 127;
}

// nameChar returns whether c can be a character within an identifier
// (not counting an escape sequence).
fn nameChar(c: u8) bool {
    return 'a' <= c and c <= 'z' or 'A' <= c and c <= 'Z' or c == '_' or c > 127 or
        c == '-' or '0' <= c and c <= '9';
}

fn lowerstr(str: []u8) void {
    for (str, 0..) |c, i| {
        str[i] = std.ascii.toLower(c);
    }
}

// parseAttributeOP parses an AttributeOP from a string of 1 or 2 bytes.
fn parseAttributeOP(s: []const u8) ParseError!AttributeOP {
    if (s.len < 1 or s.len > 2) return ParseError.InvalidAttributeOperator;

    // if the first sign is equal, we don't check anything else.
    if (s[0] == '=') return .eql;

    if (s.len != 2 or s[1] != '=') return ParseError.InvalidAttributeOperator;

    return switch (s[0]) {
        '=' => .eql,
        '!' => .not_eql,
        '~' => .one_of,
        '|' => .prefix_hyphen,
        '^' => .prefix,
        '$' => .suffix,
        '*' => .contains,
        '#' => .regexp,
        else => ParseError.InvalidAttributeOperator,
    };
}

test "parser.skipWhitespace" {
    const testcases = [_]struct {
        s: []const u8,
        i: usize,
        r: bool,
    }{
        .{ .s = "", .i = 0, .r = false },
        .{ .s = "foo", .i = 0, .r = false },
        .{ .s = " ", .i = 1, .r = true },
        .{ .s = " foo", .i = 1, .r = true },
        .{ .s = "/* foo */ bar", .i = 10, .r = true },
        .{ .s = "/* foo", .i = 0, .r = false },
    };

    for (testcases) |tc| {
        var p = Parser{ .s = tc.s, .opts = .{} };
        const res = p.skipWhitespace();
        try std.testing.expectEqual(tc.r, res);
        try std.testing.expectEqual(tc.i, p.i);
    }
}

test "parser.parseIdentifier" {
    const alloc = std.testing.allocator;

    const testcases = [_]struct {
        s: []const u8, // given value
        exp: []const u8, // expected value
        err: bool = false,
    }{
        .{ .s = "x", .exp = "x" },
        .{ .s = "96", .exp = "", .err = true },
        .{ .s = "-x", .exp = "-x" },
        .{ .s = "r\\e9 sumé", .exp = "résumé" },
        .{ .s = "r\\0000e9 sumé", .exp = "résumé" },
        .{ .s = "r\\0000e9sumé", .exp = "résumé" },
        .{ .s = "a\\\"b", .exp = "a\"b" },
    };

    var buf = std.ArrayList(u8).init(alloc);
    defer buf.deinit();

    for (testcases) |tc| {
        buf.clearRetainingCapacity();

        var p = Parser{ .s = tc.s, .opts = .{} };
        p.parseIdentifier(buf.writer()) catch |e| {
            // if error was expected, continue.
            if (tc.err) continue;

            std.debug.print("test case {s}\n", .{tc.s});
            return e;
        };
        std.testing.expectEqualDeep(tc.exp, buf.items) catch |e| {
            std.debug.print("test case {s} : {s}\n", .{ tc.s, buf.items });
            return e;
        };
    }
}

test "parser.parseString" {
    const alloc = std.testing.allocator;

    const testcases = [_]struct {
        s: []const u8, // given value
        exp: []const u8, // expected value
        err: bool = false,
    }{
        .{ .s = "\"x\"", .exp = "x" },
        .{ .s = "'x'", .exp = "x" },
        .{ .s = "'x", .exp = "", .err = true },
        .{ .s = "'x\\\r\nx'", .exp = "xx" },
        .{ .s = "\"r\\e9 sumé\"", .exp = "résumé" },
        .{ .s = "\"r\\0000e9 sumé\"", .exp = "résumé" },
        .{ .s = "\"r\\0000e9sumé\"", .exp = "résumé" },
        .{ .s = "\"a\\\"b\"", .exp = "a\"b" },
        .{ .s = "\"\\\n\"", .exp = "" },
        .{ .s = "\"hello world\"", .exp = "hello world" },
    };

    var buf = std.ArrayList(u8).init(alloc);
    defer buf.deinit();

    for (testcases) |tc| {
        buf.clearRetainingCapacity();

        var p = Parser{ .s = tc.s, .opts = .{} };
        p.parseString(buf.writer()) catch |e| {
            // if error was expected, continue.
            if (tc.err) continue;

            std.debug.print("test case {s}\n", .{tc.s});
            return e;
        };
        std.testing.expectEqualDeep(tc.exp, buf.items) catch |e| {
            std.debug.print("test case {s} : {s}\n", .{ tc.s, buf.items });
            return e;
        };
    }
}

test "parser." {
    const alloc = std.testing.allocator;

    const testcases = [_][]const u8{
        "address",
        "*",
        "#foo",
        "li#t1",
        "*#t4",
        ".t1",
        "p.t1",
        "div.teST",
        ".t1.fail",
        "p.t1.t2",
        "p.--t1",
        "p.--t1.--t2",
        "p[title]",
        "div[class=\"red\" i]",
        "address[title=\"foo\"]",
        "address[title=\"FoOIgnoRECaSe\" i]",
        "address[title!=\"foo\"]",
        "address[title!=\"foo\" i]",
        "p[title!=\"FooBarUFoo\" i]",
        "[  \t title        ~=       foo    ]",
        "p[title~=\"FOO\" i]",
        "p[title~=toofoo i]",
        "[title~=\"hello world\"]",
        "[title~=\"hello\" i]",
        "[title~=\"hello\"          I]",
        "[lang|=\"en\"]",
        "[lang|=\"EN\" i]",
        "[lang|=\"EN\"     i]",
        "[title^=\"foo\"]",
        "[title^=\"foo\" i]",
        "[title$=\"bar\"]",
        "[title$=\"BAR\" i]",
        "[title*=\"bar\"]",
        "[title*=\"BaRu\" i]",
        "[title*=\"BaRu\" I]",
        "p[class$=\" \"]",
        "p[class$=\"\"]",
        "p[class^=\" \"]",
        "p[class^=\"\"]",
        "p[class*=\" \"]",
        "p[class*=\"\"]",
        "input[name=Sex][value=F]",
        "table[border=\"0\"][cellpadding=\"0\"][cellspacing=\"0\"]",
        ".t1:not(.t2)",
        "div:not(.t1)",
        "div:not([class=\"t2\"])",
        "li:nth-child(odd)",
        "li:nth-child(even)",
        "li:nth-child(-n+2)",
        "li:nth-child(3n+1)",
        "li:nth-last-child(odd)",
        "li:nth-last-child(even)",
        "li:nth-last-child(-n+2)",
        "li:nth-last-child(3n+1)",
        "span:first-child",
        "span:last-child",
        "p:nth-of-type(2)",
        "p:nth-last-of-type(2)",
        "p:last-of-type",
        "p:first-of-type",
        "p:only-child",
        "p:only-of-type",
        ":empty",
        "div p",
        "div table p",
        "div > p",
        "p ~ p",
        "p + p",
        "li, p",
        "p +/*This is a comment*/ p",
        "p:contains(\"that wraps\")",
        "p:containsOwn(\"that wraps\")",
        ":containsOwn(\"inner\")",
        "p:containsOwn(\"block\")",
        "div:has(#p1)",
        "div:has(:containsOwn(\"2\"))",
        "body :has(:containsOwn(\"2\"))",
        "body :haschild(:containsOwn(\"2\"))",
        "p:matches([\\d])",
        "p:matches([a-z])",
        "p:matches([a-zA-Z])",
        "p:matches([^\\d])",
        "p:matches(^(0|a))",
        "p:matches(^\\d+$)",
        "p:not(:matches(^\\d+$))",
        "div :matchesOwn(^\\d+$)",
        "[href#=(fina)]:not([href#=(\\/\\/[^\\/]+untrusted)])",
        "[href#=(^https:\\/\\/[^\\/]*\\/?news)]",
        ":input",
        ":root",
        "*:root",
        "html:nth-child(1)",
        "*:root:first-child",
        "*:root:nth-child(1)",
        "a:not(:root)",
        "body > *:nth-child(3n+2)",
        "input:disabled",
        ":disabled",
        ":enabled",
        "div.class1, div.class2",
    };

    for (testcases) |tc| {
        const s = Parse(alloc, tc, .{}) catch |e| {
            std.debug.print("query {s}", .{tc});
            return e;
        };
        defer s.deinit(alloc);
    }
}
