package App::ZooKeeper::CLI::Command;
use Getopt::Long::Descriptive ();
use Text::ParseWords qw(shellwords);
use Moo;

has code => (
    is       => "ro",
    required => 1,
);

has long_opts => (
    is      => "ro",
    lazy    => 1,
    builder => "_build_long_opts",
);
sub _build_long_opts {
    my ($self) = @_;
    return [grep {length($_) > 1} @{$self->opts}];
}

has name => (
    is       => "ro",
    required => 1,
);

has opts => (
    is      => "ro",
    lazy    => 1,
    builder => "_build_opts",
);
sub _build_opts {
    my ($self) = @_;
    my @opts = map {$_->[0]} @{$self->opt_spec};
    my @stripped = map {(split /[=:]/, $_, 2)[0]} @opts; 
    return [sort map {split /\|/, $_} @stripped];
}

has opt_spec => (
    is      => "ro",
    default => sub { [] },
);

has short_opts => (
    is      => "ro",
    lazy    => 1,
    builder => "_build_short_opts",
);
sub _build_short_opts {
    my ($self) = @_;
    return [sort grep {length($_) == 1} @{$self->opts}];
}

has usage => (
    is => "ro",
    lazy => 1,
    builder => "_build_usage",
);
sub _build_usage {
    my ($self) = @_;
    local @ARGV;
    my (undef, $usage) = Getopt::Long::Descriptive::describe_options(
        sprintf("%s %%o %s", $self->name, $self->usage_desc),
        @{$self->opt_spec},
    );
    return $usage->text;
}

has usage_desc => (
    is      => "ro",
    default => "",
);

sub call {
    my ($self, $line) = @_;
    local @ARGV = shellwords($line);
    my ($opt) = Getopt::Long::Descriptive::describe_options(
        sprintf("%s %%o %s", $self->name, $self->usage_desc),
        @{$self->opt_spec},
    );
    return $self->code->($opt, \@ARGV);
}

sub BUILD {
    my ($self) = @_;
    for my $spec (@{$self->opt_spec}) {
        push @$spec, "" if @$spec == 1;
    }
}

1;
