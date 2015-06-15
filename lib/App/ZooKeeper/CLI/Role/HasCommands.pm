package App::ZooKeeper::CLI::Role::HasCommands;
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

    $self->add_command("cd", code => sub {
        my ($opts, $args) = @_;
        my $path = $args->[0] // "/";
        $path = $self->previous_node if $path eq '-';
        $path = qualify_path($path => $self->current_node);
        die "Node $path does not exist\n" unless $self->handle->exists($path);

        $self->previous_node($self->current_node);
        $self->current_node($path);
        return;
    }, usage => "<path>");

    $self->add_command("create", code => sub {
        my ($opts, $args) = @_;
        my $path = qualify_path($args->[0] => $self->current_node);
        $opts->{value} = defined $args->[1] ? $args->[1] : "";
        $self->handle->create($path, persistent => 1, %$opts);
        return;
    }, opts => {
        persistent => undef,
        sequential => undef,
    }, usage => "[--persistent|--sequential] <path> <value>");

    $self->add_command("delete", code => sub {
        my ($opts, $args) = @_;
        my $path = qualify_path($args->[0] => $self->current_node);
        $self->handle->delete($path);
        return;
    }, usage => "<path>");

    $self->add_command("exit", code => sub { exit 0 });

    $self->add_command("get", code => sub {
        my ($opts, $args) = @_;
        my $path = qualify_path($args->[0] => $self->current_node);
        return scalar $self->handle->get($path);
    }, usage => "<path>");

    $self->add_command("help", code => sub {
        my $output = "\n";
        my @commands = sort {$a->name cmp $b->name} values %{$self->commands};
        for my $cmd (@commands) {
            $output .= sprintf("%s %s\n", $cmd->name, $cmd->usage);
        }
        return $output;
    });

    $self->add_command("ls", code => sub {
        my ($opts, $args) = @_;
        my $path = qualify_path($args->[0]//"" => $self->current_node);
        $path = qualify_path($path => $self->current_node);
        return join ' ', $self->handle->get_children($path);
    }, usage => "<path>");

    $self->add_command("set", code => sub {
        my ($opts, $args) = @_;
        my $path  = qualify_path($args->[0] => $self->current_node);
        my $value = $args->[1];
        $self->handle->set($path, $value, %$opts);
        return;
    }, opts => {
        version => "i"
    }, usage => "[--version=<version>] <path> <value>");

    $self->add_command("stat", code => sub {
        my ($opts, $args) = @_;
        my $path = qualify_path($args->[0] => $self->current_node);
        return $self->dump_hash(($self->handle->get($path))[1]);
    }, usage => "<path>");

    my @watch_opts = qw(data child data exists all);
    $self->add_command("watch", code => sub {
        my ($opts, $args) = @_;
        if ($opts->{all}) { $opts->{$_}++ for @watch_opts };
        my $path = qualify_path($args->[0] => $self->current_node);

        my $watch  = sub { print "\n", $self->dump_event($_[0]) };
        my $handle = $self->handle;
        $handle->get($path, watcher => $watch) if $opts->{data};
        $handle->exists($path, watcher => $watch) if $opts->{exists};
        $handle->get_children($path, watcher => $watch) if $opts->{child};
        return;
    }, opts => {
        map {($_ => undef)} @watch_opts
    }, usage => "[--child|--data|--exists|--all] <path>");
}

sub dump_event {
    my ($self, $event) = @_;
    my $clone = {%$event};
    $clone->{state} = zstate($clone->{state});
    $clone->{type}  = zevent($clone->{type});
    return $self->dump_hash($clone);
}

sub dump_hash {
    my ($self, $hash) = @_;
    my $dump = "";
    $dump .= "\t$_ = $hash->{$_}\n" for sort keys %$hash;
    return $dump;
}

with qw(App::ZooKeeper::CLI::Role::HasSession);
requires qw(handle);

1;
