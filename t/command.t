use strict; use warnings;
use Test::More;
use App::ZooKeeper::CLI::Command;

my $noopts = App::ZooKeeper::CLI::Command->new(
    name => "noopts",
    code => sub {
        my ($opts, $args) = @_;
        return "done";
    }
);
is $noopts->call, "done";

my $withargv = App::ZooKeeper::CLI::Command->new(
    name => "withargv",
    code => sub {
        my ($opts, $args) = @_;
        return $args;
    }
);
my @args = qw(here be args);
is_deeply $withargv->call(join " ", @args), \@args;

my $withopts = App::ZooKeeper::CLI::Command->new(
    name => "withopts",
    code => sub {
        my ($opts, $args) = @_;
        return $opts;
    },
    opt_spec => [
        [ "noval"     ],
        [ "short|s"   ],
        [ "withval=s" ],
    ],
);
is_deeply $withopts->call("--noval --withval=someval -s"), {
    noval   => 1,
    short   => 1,
    withval => "someval",
};

my $withboth = App::ZooKeeper::CLI::Command->new(
    name => "withboth",
    code => sub {
        my ($opts, $args) = @_;
        return {opts => $opts, args => $args};
    },
    opt_spec => [
        [ "opt1" ],
        [ "opt2" ],
        [ "opt3" ],
    ],
);
is_deeply $withboth->call("--opt1 arg1 --opt2 arg2 --opt3"), {
    args => [qw(arg1 arg2)],
    opts => {
        opt1 => 1,
        opt2 => 1,
        opt3 => 1,
    },
};

done_testing;
