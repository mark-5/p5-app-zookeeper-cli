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

our %_COMMANDS;
sub add_cmd {
    my ($name, @args) = @_;
    $_COMMANDS{$name} = {
        name   => $name,
        method => "cmd_$name",
        @args,
    };
}

sub _setup_cmds {
    my ($self) = @_;
    weaken($self);

    while (my ($cmd, $args) = each %_COMMANDS) {
        my $method = $self->can($args->{method});
        $self->commands->{$cmd} = App::ZooKeeper::CLI::Command->new(
            code => sub { $self->$method(@_) },
            %$args,
        );
    }
}

add_cmd add_auth => (
    opt_spec => [
        [ "encoded|e" ]
    ],
    usage_desc => "<scheme> <credentials>",
);
sub cmd_add_auth {
    my ($self, $opts, $args) = @_;
    my ($scheme, $creds) = @$args;
    $self->handle->add_auth($scheme, $creds, %$opts);
    return;
}

add_cmd cd => (
    usage_desc => "<path>",
);
sub cmd_cd {
    my ($self, $opts, $args) = @_;
    my $path = $args->[0] // "/";
    $path = $self->previous_node if $path eq '-';
    $path = qualify_path($path => $self->current_node);
    die "Node $path does not exist\n" unless $self->handle->exists($path);

    $self->previous_node($self->current_node);
    $self->current_node($path);
    return;
}

add_cmd create => (
    opt_spec => [
        [ "persistent|p" ],
        [ "sequential|s" ],
    ],
    usage_desc => "<path> <value>",
);
sub cmd_create {
    my ($self, $opts, $args) = @_;
    my $path = qualify_path($args->[0] => $self->current_node);
    $opts->{value} = defined $args->[1] ? $args->[1] : "";
    $self->handle->create($path, persistent => 1, %$opts);
    return;
}

add_cmd delete => (
    usage_desc => "<path>",
);
sub cmd_delete {
    my ($self, $opts, $args) = @_;
    my $path = qualify_path($args->[0] => $self->current_node);
    $self->handle->delete($path);
    return;
}

add_cmd exit => (code => sub { exit 0 });

add_cmd get => (
    usage_desc => "<path>",
);
sub cmd_get {
    my ($self, $opts, $args) = @_;
    my $path = qualify_path($args->[0] => $self->current_node);
    return scalar $self->handle->get($path);
}

add_cmd get_acl => (
    usage_desc => "<path>",
);
sub cmd_get_acl {
    my ($self, $opts, $args) = @_;
    my $path = qualify_path($args->[0] => $self->current_node);
    return $self->dump_acl($self->handle->get_acl($path));
}

add_cmd help => ();
sub cmd_help {
    my ($self) = @_;
    my @commands = sort {$a->name cmp $b->name} values %{$self->commands};
    my $output = "\n";
    $output .= $_->usage for @commands;
    return $output;
}

add_cmd ls => (
    usage_desc => "<path>",
);
sub cmd_ls {
    my ($self, $opts, $args) = @_;
    my $path = qualify_path($args->[0]//"" => $self->current_node);
    return join ' ', $self->handle->get_children($path);
}

add_cmd set => (
    opt_spec => [
        [ "version|v=i" ],
    ],
    usage_desc => "<path> <value>",
);
sub cmd_set {
    my ($self, $opts, $args) = @_;
    my $path  = qualify_path($args->[0] => $self->current_node);
    my $value = $args->[1];
    $self->handle->set($path, $value, %$opts);
    return;
}

add_cmd set_acl => (
    opt_spec => [
        [ "append|a"    ],
        [ "id|i=s",     ],
        [ "perms|p=s",  ],
        [ "scheme|s=s"  ],
        [ "version|v=i" ],
    ],
    usage_desc => "<path>",
);
sub cmd_set_acl {
    my ($self, $opts, $args) = @_;
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
}

add_cmd stat => (
    usage_desc => "<path>",
);
sub cmd_stat {
    my ($self, $opts, $args) = @_;
    my $path = qualify_path($args->[0] => $self->current_node);
    return $self->dump_hash(($self->handle->get($path))[1]);
}

our @watch_opts = qw(child data exists all);
add_cmd watch => (
    opt_spec => [
        map {
            my $short = substr($_, 0, 1);
            [ "$_|$short" ];
        } @watch_opts
    ],
    usage_desc => "<path>",
);
sub cmd_watch {
    my ($self, $opts, $args) = @_;
    if ($opts->{all}) { $opts->{$_}++ for @watch_opts };
    my $path = qualify_path($args->[0] => $self->current_node);

    my $watch  = sub { print "\n", $self->dump_event($_[0]) };
    my $handle = $self->handle;
    $handle->get($path, watcher => $watch) if $opts->{data};
    $handle->exists($path, watcher => $watch) if $opts->{exists};
    $handle->get_children($path, watcher => $watch) if $opts->{child};

    return;
}


sub BUILD {}
after BUILD => sub {
    my ($self) = @_;
    $self->_setup_cmds

};

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
