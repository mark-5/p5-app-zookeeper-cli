package ZooKeeper::CLI;
use ZooKeeper;
use Data::Dumper;
$Data::Dumper::Sortkeys = 1;
use Moo;

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

has current_node => (
    is      => 'rw',
    default => '/',
);

has previous_node => (
    is      => 'rw',
    default => '/',
);

sub ls {
    my ($self, $path) = @_;
    $path ||= $self->current_node;
    $path = $self->qualify_path($path);
    return join ' ', $self->handle->get_children($path);
}

sub cd {
    my ($self, $path) = @_;
    $path ||= '/';
    $path = $self->previous_node if $path eq '-';
    $path = $self->qualify_path($path);
    die "Node $path does not exist\n" unless $self->handle->exists($path);

    $self->previous_node($self->current_node);
    $self->current_node($path);
    return undef;
}

sub rm {
    my ($self, $path) = @_;
    $path = $self->qualify_path($path);
    $self->handle->delete($path);
    return undef;
}

sub touch {
    my ($self, $path) = @_;
    $path = $self->qualify_path($path);
    return $self->handle->create($path, persistent => 1);
}

sub cat {
    my ($self, $path) = @_;
    $path = $self->qualify_path($path);
    return scalar $self->handle->get($path);
}

sub stat {
    my ($self, $path) = @_;
    $path = $self->qualify_path($path);
    return Dumper +($self->handle->get($path))[1];
}

sub qualify_path {
    my ($self, $path) = @_;
    my $qualified = substr($path, 0, 1) eq '/' ? $path : $self->join_paths($self->current_node, $path);
    my $collapsed = $self->collapse_path($qualified);
    return $collapsed;
}

sub join_paths {
    my ($self, $a, $b) = @_;
    $a .= '/' unless $a =~ m|/$|;
    $b =~ s|^/||;
    return $a . $b;
}

sub collapse_path {
    my ($self, $path) = @_;
    return $path if $path eq '/';
    my @parts = split m|/|, $path;

    for (my $i = 0; $i < @parts; $i++) {
        my $part = $parts[$i] or next;
        if ($part eq '.') {
            splice @parts, $i, 1;
            $i -= 1;
        } elsif ($part eq '..') {
            splice @parts, $i - 1, 2;
            $i -= 2;
        }
    }

    my $collapsed = join '/', @parts;
    return $collapsed || '/';
}

sub BUILD { shift->handle }

1;
