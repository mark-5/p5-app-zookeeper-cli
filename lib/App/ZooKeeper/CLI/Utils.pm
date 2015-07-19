package App::ZooKeeper::CLI::Utils;
use strict;
use warnings;
use List::Util qw(reduce);
use base "Exporter::Tiny";

our @EXPORT = qw(
    collapse_path
    get_parent
    is_empty_path
    join_paths
    qualify_path
);

sub collapse_path {
    my ($path) = @_;
    return "" if is_empty_path($path);
    return $path if $path eq '/';
    my @parts = grep {not is_empty_path($_)} split m|/|, $path;
    unshift @parts, '/' if $path =~ m#^/#;

    for (my $i = 0; $i < @parts; $i++) {
        my $part = $parts[$i];
        if ($part eq '.') {
            splice @parts, $i, 1;
            $i -= 1;
        } elsif ($part eq '..') {
            if ($i >= 2) {
                splice @parts, $i - 1, 2;
                $i -= 2;
            } else {
                # just remove .. if its first or second
                # otherwise it'll try to splice from -1 and die
                splice @parts, $i, 1;
                $i -= 1;
            }
        }
    }

    my $collapsed = reduce {join_paths($a, $b)} @parts;
    return $collapsed // '/';
}

sub get_parent {
    my ($node) = @_;
    return get_parent($node) if $node =~ s#(?<=.)/$##;

    if ($node =~ m#^/#) {
        (my $parent = $node) =~ s#/[^/]+$#/#;
        $parent =~ s#(?<=.)/$##;
        return $parent // '';
    } else {
        return '' unless $node =~ m#/#;
        (my $parent = $node) =~ s#/[^/]+$#/#;
        $parent =~ s#(?<=.)/$##;
        return $parent // '';
    }
}

sub join_paths {
    my ($a, $b) = @_;
    if (is_empty_path($a)) {
        $b =~ s#(?<=.)/$##;
        return $b;
    } elsif (is_empty_path($b)) {
        $a =~ s#(?<=.)/$##;
        return $a;
    } else {
        $a .= '/' unless $a =~ m|/$|;
        $b =~ s|^/||;
        my $joined = $a . $b;
        $joined =~ s#(?<=.)/$##;
        return $joined;
    }
}

sub qualify_path {
    my ($path, $current_node) = @_;
    my $qualified = substr($path, 0, 1) eq '/' ? $path : join_paths($current_node, $path);
    return collapse_path($qualified);
}

sub is_empty_path {
    my ($path) = @_;
    return not(defined $path) || $path eq "";
}

1;
