package App::ZooKeeper::CLI;
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
    App::ZooKeeper::CLI::Role::HasCommands
    App::ZooKeeper::CLI::Role::HasTerminal
);

1;
