// Integration tests derived from paths.star (bazelbuild/starlark test suite).
// Verifies that the interpreter correctly handles the Skylib paths library,
// a pure-Starlark path-manipulation module ported to the core dialect.

///|
let paths_star_src : String =
  #|load("assert.star", "assert")
  #|load("struct.star", "struct")
  #|
  #|def _basename(p):
  #|    return p.rpartition("/")[-1]
  #|
  #|def _dirname(p):
  #|    prefix, sep, _ = p.rpartition("/")
  #|    if not prefix:
  #|        return sep
  #|    else:
  #|        return prefix.rstrip("/")
  #|
  #|def _is_absolute(path):
  #|    return path.startswith("/") or (len(path) > 2 and path[1] == ":")
  #|
  #|def _join(path, *others):
  #|    result = path
  #|    for p in others:
  #|        if _is_absolute(p):
  #|            result = p
  #|        elif not result or result.endswith("/"):
  #|            result += p
  #|        else:
  #|            result += "/" + p
  #|    return result
  #|
  #|def _normalize(path):
  #|    if not path:
  #|        return "."
  #|    if path.startswith("//") and not path.startswith("///"):
  #|        initial_slashes = 2
  #|    elif path.startswith("/"):
  #|        initial_slashes = 1
  #|    else:
  #|        initial_slashes = 0
  #|    is_relative = (initial_slashes == 0)
  #|    components = path.split("/")
  #|    new_components = []
  #|    for component in components:
  #|        if component in ("", "."):
  #|            continue
  #|        if component == "..":
  #|            if new_components and new_components[-1] != "..":
  #|                new_components.pop()
  #|            elif is_relative:
  #|                new_components.append(component)
  #|        else:
  #|            new_components.append(component)
  #|    path = "/".join(new_components)
  #|    if not is_relative:
  #|        path = ("/" * initial_slashes) + path
  #|    return path or "."
  #|
  #|def _relativize(path, start):
  #|    segments = _normalize(path).split("/")
  #|    start_segments = _normalize(start).split("/")
  #|    if start_segments == ["."]:
  #|        start_segments = []
  #|    start_length = len(start_segments)
  #|    if (path.startswith("/") != start.startswith("/") or
  #|        len(segments) < start_length):
  #|        fail("Path '%s' is not beneath '%s'" % (path, start))
  #|    for ancestor_segment, segment in zip(start_segments, segments):
  #|        if ancestor_segment != segment:
  #|            fail("Path '%s' is not beneath '%s'" % (path, start))
  #|    length = len(segments) - start_length
  #|    result_segments = segments[-length:]
  #|    return "/".join(result_segments)
  #|
  #|def _split_extension(p):
  #|    b = _basename(p)
  #|    last_dot_in_basename = b.rfind(".")
  #|    if last_dot_in_basename <= 0:
  #|        return (p, "")
  #|    dot_distance_from_end = len(b) - last_dot_in_basename
  #|    return (p[:-dot_distance_from_end], p[-dot_distance_from_end:])
  #|
  #|def _replace_extension(p, new_extension):
  #|    return _split_extension(p)[0] + new_extension
  #|
  #|paths = struct(
  #|    basename = _basename,
  #|    dirname = _dirname,
  #|    is_absolute = _is_absolute,
  #|    join = _join,
  #|    normalize = _normalize,
  #|    relativize = _relativize,
  #|    replace_extension = _replace_extension,
  #|    split_extension = _split_extension,
  #|)
  #|
  #|# basename
  #|assert.eq(paths.basename("foo/bar.baz"), "bar.baz")
  #|assert.eq(paths.basename("foo/"), "")
  #|assert.eq(paths.basename("foo"), "foo")
  #|assert.eq(paths.basename(""), "")
  #|assert.eq(paths.basename("/"), "")
  #|
  #|# dirname
  #|assert.eq(paths.dirname("foo/bar"), "foo")
  #|assert.eq(paths.dirname("foo/bar/baz"), "foo/bar")
  #|assert.eq(paths.dirname("foo"), "")
  #|assert.eq(paths.dirname("/foo"), "/")
  #|assert.eq(paths.dirname("foo///bar"), "foo")
  #|
  #|# is_absolute
  #|assert.true(paths.is_absolute("/foo"))
  #|assert.true(not paths.is_absolute("foo"))
  #|assert.true(not paths.is_absolute("foo/bar"))
  #|
  #|# join
  #|assert.eq(paths.join("a", "b", "c"), "a/b/c")
  #|assert.eq(paths.join("a/b", "c"), "a/b/c")
  #|assert.eq(paths.join("a/b/", "c"), "a/b/c")
  #|assert.eq(paths.join("", "b"), "b")
  #|assert.eq(paths.join("a", "/b"), "/b")
  #|
  #|# normalize
  #|assert.eq(paths.normalize(""), ".")
  #|assert.eq(paths.normalize("."), ".")
  #|assert.eq(paths.normalize("foo/./bar"), "foo/bar")
  #|assert.eq(paths.normalize("foo//bar"), "foo/bar")
  #|assert.eq(paths.normalize("foo/bar/.."), "foo")
  #|assert.eq(paths.normalize("/foo/bar/.."), "/foo")
  #|assert.eq(paths.normalize("//foo"), "//foo")
  #|assert.eq(paths.normalize("///foo"), "/foo")
  #|
  #|# relativize
  #|assert.eq(paths.relativize("foo/bar/baz", "foo/bar"), "baz")
  #|assert.eq(paths.relativize("foo/bar", "foo"), "bar")
  #|assert.eq(paths.relativize("foo", ""), "foo")
  #|
  #|# split_extension
  #|assert.eq(paths.split_extension("foo.txt"), ("foo", ".txt"))
  #|assert.eq(paths.split_extension("foo"), ("foo", ""))
  #|assert.eq(paths.split_extension(".bashrc"), (".bashrc", ""))
  #|assert.eq(paths.split_extension("foo.tar.gz"), ("foo.tar", ".gz"))
  #|
  #|# replace_extension
  #|assert.eq(paths.replace_extension("foo.txt", ".md"), "foo.md")
  #|assert.eq(paths.replace_extension("foo", ".txt"), "foo.txt")

///|
test "paths.star: pure-Starlark path manipulation library" {
  let errs = run_star_string(paths_star_src)
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}
