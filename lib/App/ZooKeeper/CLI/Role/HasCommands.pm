package App::ZooKeeper::CLI::Role::HasCommands;
use Data::Dumper;
$Data::Dumper::Sortkeys = 1;
use App::ZooKeeper::CLI::Utils qw(qualify_path);
use Moo::Role;

our @COMMANDS = qw(
    cat
    cd
    ls
    rm
    stat
    touch
);

has commands => (
    is      => "ro",
    default => sub { \@COMMANDS },
);

sub ls {
    my ($self, $path) = @_;
    $path //= $self->current_node;
    $path = qualify_path($path => $self->current_node);
    return join ' ', $self->handle->get_children($path);
}

sub cd {
    my ($self, $path) = @_;
    $path //= '/';
    $path = $self->previous_node if $path eq '-';
    $path = qualify_path($path => $self->current_node);
    die "Node $path does not exist\n" unless $self->handle->exists($path);

    $self->previous_node($self->current_node);
    $self->current_node($path);
    return undef;
}

sub rm {
    my ($self, $path) = @_;
    $path = qualify_path($path => $self->current_node);
    $self->handle->delete($path);
    return undef;
}

sub touch {
    my ($self, $path) = @_;
    $path = qualify_path($path => $self->current_node);
    return $self->handle->create($path, persistent => 1);
}

sub cat {
    my ($self, $path) = @_;
    $path = qualify_path($path => $self->current_node);
    return scalar $self->handle->get($path);
}

sub stat {
    my ($self, $path) = @_;
    $path = qualify_path($path => $self->current_node);
    return Dumper +($self->handle->get($path))[1];
}


with qw(App::ZooKeeper::CLI::Role::HasSession);
requires qw(handle);

1;
