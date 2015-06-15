package App::ZooKeeper::CLI::Command;
use Getopt::Long qw(GetOptionsFromArray);
use Text::ParseWords qw(shellwords);
use Moo;

has code => (
    is       => "ro",
    required => 1,
);

has name => (
    is       => "ro",
    required => 1,
);

has opts => (
    is      => "ro",
    default => sub { {} },
);

has usage => (
    is      => "ro",
    default => "",
);

sub call {
    my ($self, $line) = @_;
    my (@args) = shellwords($line);
    my @opts = map {
        my $desc = $self->opts->{$_} ? "=".$self->opts->{$_} : "";
        join "", $_, $desc;
    } keys %{$self->opts};

    GetOptionsFromArray(\@args, \my %opts, @opts);
    return $self->code->(\%opts, \@args);
}

1;
