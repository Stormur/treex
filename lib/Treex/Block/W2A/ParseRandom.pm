package Treex::Block::W2A::ParseRandom;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

sub process_atree {
    my ( $self, $root ) = @_;
    my @todo = List::Util::shuffle $root->get_descendants();

    # Flatten the tree first, if there was some topology already.
    foreach my $node (@todo) {
        $node->set_parent($root);
    }

    my @all_nodes = ( $root, @todo );
    while (@todo) {
        my $child    = shift @todo;
        my @possible = grep { $_ != $child && !$_->is_descendant_of($child) } @all_nodes;
        my $parent   = $self->find_parent( $child, @possible );
        $child->set_parent($parent);
    }
    return;
}

sub find_parent {
    my ( $self, $child, @possible ) = @_;
    return $possible[ int( rand( scalar @possible ) ) ];
}

1;

__END__

=head1 NAME

Treex::Block::W2A::ParseRandom random dependency parsing

=head1 DESCRIPTION

The main idea is simple: iterate over all nodes and assign a random parent to
each node.
However, we want a tree as the result, so we make sure
that we don't create cycles in any moment
(using L<Treex::Core::Node::is_descendant_of> check).

If we were iterating over the nodes in a fixed order (left-to-right),
the last node will be most likely hanged on the root,
because other nodes may be its descendants.
So the tree wouldn't be actually random.

Therefore, we iterate over the nodes in a random order (using C<shuffle>).

=head1 COPYRIGHT AND LICENCE

Copyright 2011 Martin Popel

This module is free software;
you can redistribute it and/or modify it under the same terms as Perl itself.
