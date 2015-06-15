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
use AE;
use Moo::Role;

has term => (
    is      => "ro",
    lazy    => 1,
    builder => "_build_term",
);
sub _build_term {
    my ($self) = @_;
    my $term   = Term::ReadLine->new("App::ZooKeeper CLI");
    $self->_attach_event_loop($term);
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

    my ($name) = shellwords($stripped);
    (my $args = $line) =~ s/^\s*$name\s*//;
    if (my $cmd = $self->commands->{$name}) {
        my $results = try {
            return $cmd->call($args);
        } catch {
            my $err = $_;
            $err   .= "\n" unless $err =~ /\n$/;
            warn $err;
            return undef;
        };
        $results .= "\n" if $results and $results !~ /\n$/;
        print $results if $results;
    } else {
        print "Unrecognized command: $name\n";
    }

    $term->addhistory($line);
}

sub _attach_autocomplete {
    my ($self, $term) = @_;
    my $attr = $self->_autocomplete_attr($term);
    return unless $attr;

    weaken(my $wself = $self);
    $term->Attribs->{$attr} = sub { $wself->_autocomplete(@_) };
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

        my $i = 0;
        return $term->completion_matches($text, sub { $matches[$i++] });
    }
}

sub autocomplete {
    my ($self, $line) = @_;
    return $self->match_commands($line) unless $line =~ /\s+/;

    my ($cmd, @args) = shellwords($line);
    my $in_match = $line !~ /\s$/;
    my $last_arg = $args[-1] // "";
    if ($in_match and $last_arg =~ /^-/) {
        return $self->match_options($cmd, $last_arg);
    } else {
        return $self->match_nodes($in_match ? $last_arg : "");
    }
}

sub match_commands {
    my ($self, $cmd) = @_;
    $cmd ||= "";
    return grep /^$cmd/, sort keys %{$self->commands};
}

sub match_options {
    my ($self, $cmd, $opt) = @_;
    my @all_opts    = sort keys %{$self->commands->{$cmd}->opts||{}};
    my @with_dashes = map "--$_", @all_opts;
    return grep {/^$opt/} @with_dashes;
}

sub match_nodes {
    my ($self, $node) = @_;
    my $collapsed = collapse_path($node || "");
    $collapsed .= "/" if $node =~ m#(?<=.)/$#;

    my $parent = get_parent($collapsed);
    my @children  = $self->list_children($parent);
    my @qualified = map join_paths($parent, $_), @children;

    my @matches = grep /^$collapsed/, @qualified;
    if (@matches == 1) {
        push @matches, map {
            join_paths($matches[0], $_)
        } $self->list_children($matches[0]);
    }
    return @matches;
}

sub list_children {
    my ($self, $node) = @_;
    return shellwords($self->commands->{ls}->call($node));
}

sub _attach_event_loop {
    my ($self, $term) = @_;
    $term->event_loop(sub {
        my ($data) = @_;
        $data->[1] = AE::cv;
        $data->[1]->recv;
    }, sub {
        my ($fh) = @_;
        my $data = [];
        $data->[0] = AE::io($fh, 0, sub { $data->[1]->send });
        $data;
    });
}

with qw(
    App::ZooKeeper::CLI::Role::HasSession
    App::ZooKeeper::CLI::Role::HasCommands
);

1;
