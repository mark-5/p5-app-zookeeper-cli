use strict; use warnings;
use Test::More;
use ZooKeeper::CLI;

my $collapse = sub { ZooKeeper::CLI->collapse_path(@_) };
is $collapse->('/'), '/';
is $collapse->('/foo/bar'), '/foo/bar';
is $collapse->('/foo/.'), '/foo';
is $collapse->('/foo/./bar'), '/foo/bar';
is $collapse->('/foo/bar/baz/..'), '/foo/bar';
is $collapse->('/foo/bar/baz/../boz'), '/foo/bar/boz';

done_testing;
