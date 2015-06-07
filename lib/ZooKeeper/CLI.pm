package ZooKeeper::CLI;
use ZooKeeper;
use Moo;
use 5.10.1;

our $VERSION = '0.0.1';

has hosts => (
    is       => 'ro',
    required => 1,
);

has handle => (
    is      => 'ro',
    lazy    => 1,
    builder => '_build_handle',
);
sub _build_handle {
    my ($self) = @_;
    return ZooKeeper->new(hosts => $self->hosts);
}

with qw(
    ZooKeeper::CLI::Role::HasCommands
    ZooKeeper::CLI::Role::HasTerminal
);

1;
