package App::ZooKeeper::CLI::Role::HasSession;
use Moo::Role;

has current_node => (
    is      => 'rw',
    default => '/',
);

has previous_node => (
    is      => 'rw',
    default => '/',
);

1;
