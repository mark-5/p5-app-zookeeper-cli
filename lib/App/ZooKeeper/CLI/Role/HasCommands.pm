package App::ZooKeeper::CLI::Role::HasCommands;
use Data::Dumper;
$Data::Dumper::Sortkeys = 1;
use App::ZooKeeper::CLI::Command;
use App::ZooKeeper::CLI::Utils qw(qualify_path);
use Scalar::Util qw(weaken);
use ZooKeeper::Constants qw(:all);
use Moo::Role;

has commands => (
    is      => "ro",
    default => sub { {} },
);

sub add_command {
    my ($self, $name, @args) = @_;
    $self->commands->{$name} = App::ZooKeeper::CLI::Command->new(
        name => $name,
        @args,
    );
}

sub BUILD {
    my ($self) = @_;
    weaken($self);

    $self->add_command("cat", code => sub {
        my ($opts, $args) = @_;
        my $path = qualify_path($args->[0] => $self->current_node);
        return scalar $self->handle->get($path);
    });

    $self->add_command("cd", code => sub {
        my ($opts, $args) = @_;
        my $path = $args->[0] // "/";
        $path = $self->previous_node if $path eq '-';
        $path = qualify_path($path => $self->current_node);
        die "Node $path does not exist\n" unless $self->handle->exists($path);

        $self->previous_node($self->current_node);
        $self->current_node($path);
        return undef;
    });

    $self->add_command("exit", code => sub { exit 0 });

    $self->add_command("ls", code => sub {
        my ($opts, $args) = @_;
        my $path = qualify_path($args->[0]//"" => $self->current_node);
        $path = qualify_path($path => $self->current_node);
        return join ' ', $self->handle->get_children($path);
    });

    $self->add_command("rm", code => sub {
        my ($opts, $args) = @_;
        my $path = qualify_path($args->[0] => $self->current_node);
        $self->handle->delete($path);
        return undef;
    });

    $self->add_command("stat", code => sub {
        my ($opts, $args) = @_;
        my $path = qualify_path($args->[0] => $self->current_node);
        return Dumper +($self->handle->get($path))[1];
    });

    $self->add_command("touch", code => sub {
        my ($opts, $args) = @_;
        my $path = qualify_path($args->[0] => $self->current_node);
        return $self->handle->create($path, persistent => 1, %$opts);
    }, opts => {
        persistent => undef,
        sequential => undef,
        value      => "s",
    });

    my @watch_opts = qw(all data exists child);
    $self->add_command("watch", code => sub {
        my ($opts, $args) = @_;
        if ($opts->{all}) { $opts->{$_}++ for @watch_opts };
        my $path = qualify_path($args->[0] => $self->current_node);

        my $watch  = sub { warn "\n", $self->dump_event($_[0]) };
        my $handle = $self->handle;
        $handle->get($path, watcher => $watch) if $opts->{data};
        $handle->exists($path, watcher => $watch) if $opts->{exists};
        $handle->get_children($path, watcher => $watch) if $opts->{child};
        return;
    }, opts => {
        map {($_ => undef)} @watch_opts
    });
}

sub dump_event {
    my ($self, $event) = @_;
    my $clone = {%$event};
    $clone->{event} = zevent($clone->{event});
    $clone->{state} = zstate($clone->{state});
    return Dumper($clone);
}

with qw(App::ZooKeeper::CLI::Role::HasSession);
requires qw(handle);

1;
