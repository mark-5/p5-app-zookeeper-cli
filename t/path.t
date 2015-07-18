use strict; use warnings;
use Test::More;
use App::ZooKeeper::CLI::Utils qw(
    collapse_path
    get_parent
    join_paths
    qualify_path
);

is collapse_path(undef), "";
is collapse_path('/'), '/';
is collapse_path('/foo/bar'), '/foo/bar';
is collapse_path('/foo/.'), '/foo';
is collapse_path('/foo/..'), '/';
is collapse_path('/foo/./bar'), '/foo/bar';
is collapse_path('/foo/bar/baz/..'), '/foo/bar';
is collapse_path('/foo/bar/baz/../boz'), '/foo/bar/boz';

is collapse_path('foo/bar'), 'foo/bar';
is collapse_path('foo/.'), 'foo';
is collapse_path('foo/./bar'), 'foo/bar';
is collapse_path('foo/bar/baz/..'), 'foo/bar';
is collapse_path('foo/bar/baz/../boz'), 'foo/bar/boz';

is collapse_path('foo/'), 'foo';
is collapse_path('foo/bar/./'), 'foo/bar';
is collapse_path('foo/bar/../'), 'foo';

is get_parent('/foo'), '/';
is get_parent('/foo/'), '/';
is get_parent('/foo/bar'), '/foo';
is get_parent('/foo/bar/'), '/foo';
is get_parent('foo'), '';
is get_parent('foo/'), '';
is get_parent('foo/bar'), 'foo';
is get_parent('foo/bar/'), 'foo';

is join_paths(undef, "foo"), "foo";
is join_paths(undef, "/foo"), "/foo";
is join_paths("foo", undef), "foo";
is join_paths("foo/", undef), "foo";
is join_paths("foo", "bar"), "foo/bar";
is join_paths("/foo", "bar"), "/foo/bar";
is join_paths("/foo", "/bar"), "/foo/bar";

done_testing;
