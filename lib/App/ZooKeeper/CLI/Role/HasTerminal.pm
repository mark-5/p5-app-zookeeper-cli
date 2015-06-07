package App::ZooKeeper::CLI::Role::HasTerminal;
use Scalar::Util qw(weaken);
use Term::ReadLine;
use Text::ParseWords qw(shellwords);
use Try::Tiny;
use App::ZooKeeper::CLI::Utils qw(
    collapse_path
    get_parent
    join_paths
);
use Moo::Role;

has term => (
    is      => "ro",
    lazy    => 1,
    builder => "_build_term",
);
sub _build_term {
    my ($self) = @_;
    my $term   = Term::ReadLine->new("App::ZooKeeper CLI");
    $self->_attach_autocomplete($term);
    return $term;
}

sub _autocomplete_attr {
    my ($self, $term) = @_;
    return $term->isa("Term::ReadLine::Gnu")  ? "attempted_completion_function"
         : $term->isa("Term::ReadLine::Perl") ? "completion_function"
         : undef;
}

sub readline {
    my ($self) = @_;
    my $term   = $self->term;
    return $term->readline(sprintf "%s: ", $self->current_node);
}

sub execute {
    my ($self, $line) = @_;
    return unless $line =~ /\S+/;
    (my $stripped = $line) =~ s/^\s+|\s+$//g;
    my $term = $self->term;

    my ($cmd, @args) = shellwords($stripped);
    if (my $method = $self->can($cmd)) {
        my $results = try {
            return $self->$method(@args)
        } catch {
            my $err = $_;
            $err   .= "\n" unless $err =~ /\n$/;
            warn $err;
            return undef;
        };
        print "$results\n" if $results;
    } else {
        print "Unrecognized command: $cmd\n";
    }

    $term->addhistory($line);
}

sub _attach_autocomplete {
    my ($self, $term) = @_;
    my $attr = $self->_autocomplete_attr($term);
    return unless $attr;

    my $wself = $self;
    $term->Attribs->{$attr} = sub { $wself->_autocomplete(@_) };
    weaken($wself);
}

sub _autocomplete {
    my $is_trp = scalar(@_) == 4;
    my ($self, $text, $line, $start, $end) = @_;
    $end = $start + length($text) if $is_trp;
    substr($line, $end) = "";

    my @matches = $self->autocomplete($line);
    return unless @matches;

    if ($is_trp) {
        return @matches;
    } else {
        my $term = $self->term;
        $term->Attribs->{attempted_completion_over} = 1;
        return $term->completion_matches($text, sub { @matches });
    }
}

sub autocomplete {
    my ($self, $line) = @_;
    return $self->match_commands($line) unless $line =~ /\s+/;

    my ($cmd, $args) = split /\s+/, $line, 2;
    return $self->match_nodes($args);
}

sub match_commands {
    my ($self, $cmd) = @_;
    $cmd ||= "";
    return grep /^$cmd/, @{$self->commands};
}

sub match_nodes {
    my ($self, $node) = @_;
    my $collapsed = collapse_path($node || "");
    $collapsed .= "/" if $node =~ m#(?<=.)/$#;

    my $parent = get_parent($collapsed);
    my @children  = split /\s+/, $self->ls($parent);
    my @qualified = map join_paths($parent, $_), @children;
    my @with_slashes = map {
        $self->ls($_) ? ($_, "$_/") : $_
    } @qualified;
    return grep /^$collapsed/, @with_slashes;
}


with qw(
    App::ZooKeeper::CLI::Role::HasSession
    App::ZooKeeper::CLI::Role::HasCommands
);

1;
