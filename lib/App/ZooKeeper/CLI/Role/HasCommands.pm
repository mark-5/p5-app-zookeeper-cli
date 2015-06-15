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

    $self->add_command("add_auth", code => sub {
        my ($opts, $args) = @_;
        my ($scheme, $creds) = @$args;
        $self->handle->add_auth($scheme, $creds, %$opts);
        return;
    }, opt_spec => [
        [ "encoded|e" ]
    ], usage_desc => "<scheme> <credentials>");

    $self->add_command("cd", code => sub {
        my ($opts, $args) = @_;
        my $path = $args->[0] // "/";
        $path = $self->previous_node if $path eq '-';
        $path = qualify_path($path => $self->current_node);
        die "Node $path does not exist\n" unless $self->handle->exists($path);

        $self->previous_node($self->current_node);
        $self->current_node($path);
        return;
    }, usage_desc => "<path>");

    $self->add_command("create", code => sub {
        my ($opts, $args) = @_;
        my $path = qualify_path($args->[0] => $self->current_node);
        $opts->{value} = defined $args->[1] ? $args->[1] : "";
        $self->handle->create($path, persistent => 1, %$opts);
        return;
    }, opt_spec => [
        [ "persistent|p" ],
        [ "sequential|s" ]
    ], usage_desc => "<path> <value>");

    $self->add_command("delete", code => sub {
        my ($opts, $args) = @_;
        my $path = qualify_path($args->[0] => $self->current_node);
        $self->handle->delete($path);
        return;
    }, usage_desc => "<path>");

    $self->add_command("exit", code => sub { exit 0 });

    $self->add_command("get", code => sub {
        my ($opts, $args) = @_;
        my $path = qualify_path($args->[0] => $self->current_node);
        return scalar $self->handle->get($path);
    }, usage_desc => "<path>");

    $self->add_command("get_acl", code => sub {
        my ($opts, $args) = @_;
        my $path = qualify_path($args->[0] => $self->current_node);
        return $self->dump_acl($self->handle->get_acl($path));
    }, usage_desc => "<path>");

    $self->add_command("help", code => sub {
        my @commands = sort {$a->name cmp $b->name} values %{$self->commands};
        my $output = "\n";
        $output .= $_->usage for @commands;
        return $output;
    });

    $self->add_command("ls", code => sub {
        my ($opts, $args) = @_;
        my $path = qualify_path($args->[0]//"" => $self->current_node);
        $path = qualify_path($path => $self->current_node);
        return join ' ', $self->handle->get_children($path);
    }, usage_desc => "<path>");

    $self->add_command("set", code => sub {
        my ($opts, $args) = @_;
        my $path  = qualify_path($args->[0] => $self->current_node);
        my $value = $args->[1];
        $self->handle->set($path, $value, %$opts);
        return;
    }, opt_spec => [
        [ "version|v=i" ],
    ], usage_desc => "<path> <value>");

    $self->add_command("set_acl", code => sub {
        my ($opts, $args) = @_;
        my $path = qualify_path($args->[0] => $self->current_node);
        my $append  = delete $opts->{append};
        my $version = delete $opts->{version};
        my $acls    = [$self->as_acl($opts)];
        if ($append) {
            my $existing = $self->handle->get_acl($path);
            $acls = [@$acls, @$existing];
        }
        $self->handle->set_acl($path => $acls, version => $version);
        return;
    }, opt_spec => [
        [ "append|a"                    ],
        [ "id|i=s",     {required => 1} ],
        [ "perms|p=s",  {required => 1} ],
        [ "scheme|s=s", {required => 1} ],
        [ "version|v=i"                 ],
    ], usage_desc => "<path>");

    $self->add_command("stat", code => sub {
        my ($opts, $args) = @_;
        my $path = qualify_path($args->[0] => $self->current_node);
        return $self->dump_hash(($self->handle->get($path))[1]);
    }, usage_desc => "<path>");

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
    }, opt_spec => [
        map {
            my $short = substr($_, 0, 1);
            [ "$_|$short" ];
        } @watch_opts
    ], usage_desc => "<path>");
}

sub as_acl {
    my ($self, $opt) = @_;
    my @acl_strings = split /\|/, delete $opt->{perms};
    for my $acl_str (@acl_strings) {
        $acl_str = uc $acl_str;
        $opt->{perms} |= __PACKAGE__->can("ZOO_PERM_$acl_str")->();
    }
    return $opt;
}

sub dump_acl {
    my ($self, $acls) = @_;
    my @dumps;
    for my $acl (@$acls) {
        my $clone = {%$acl};
        $clone->{perms} = zperm($clone->{perms});
        push @dumps, $self->dump_hash($clone);
    }
    return join "\n", @dumps;
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
