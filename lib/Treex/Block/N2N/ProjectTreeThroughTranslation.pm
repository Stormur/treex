package Treex::Block::N2N::ProjectTreeThroughTranslation;

use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';
use List::MoreUtils qw(uniq);

has '+language' => ( required => 1 );

sub process_zone {
    my ( $self, $zone ) = @_;

    # get the n-trees from the source zone and the current zone (here, create if it doesn't exist)
    my $troot     = $zone->get_ttree();
    my $troot_src = $troot->src_tnode() or return;
    my $src_zone  = $troot_src->get_zone();    
    return if ( !$src_zone->has_ntree() );
    my $nroot_src = $src_zone->get_ntree() or return;
    my $nroot = $zone->has_ntree() ? $zone->get_ntree() : $zone->create_ntree();

    $self->project_nsubtree( $nroot_src, $nroot );
}

sub project_nsubtree {
    my ( $self, $nnode_src, $nnode ) = @_;

    # Leaf nodes: project the source a-nodes onto target a-nodes over t-nodes
    if ( $nnode_src->is_leaf and not $nnode_src->is_root ) {

        # getting source anodes
        my @anodes_src = $nnode_src->get_anodes();

        # getting source t-nodes for the a-nodes (through both aux.rf and lex.rf, removing duplicates)
        my @tnodes_src = uniq map { ( $_->get_referencing_nodes('a/lex.rf'), $_->get_referencing_nodes('a/aux.rf') ) } @anodes_src;

        # getting target t-nodes (storing them in a hash for fast membership checks)
        my @tnodes = map { $_->get_referencing_nodes('src_tnode.rf') } @tnodes_src;
        my %tnodes_hash = map { $_->id => 1 } @tnodes;

        # getting target a-nodes: always add lexical node, use heuristics for auxiliaries
        my @anodes = ();
        foreach my $tnode (@tnodes) {
            push @anodes, $tnode->get_lex_anode();
            my @aauxs = $tnode->get_aux_anodes();
            foreach my $aaux (@aauxs) {
                push @anodes, $aaux if ( $self->should_include_aux( $tnode, $aaux, \%tnodes_hash ) );
            }
        }

        # deduplicate and sort the target a-nodes and let the n-node refer to them,
        # assign their concatenated forms/lemmas as the normalized NE name
        @anodes = uniq sort { $a->ord <=> $b->ord } @anodes;
        $nnode->set_anodes(@anodes);
        $nnode->set_normalized_name( join ' ', map { $_->form // $_->lemma // '' } @anodes );
        return;
    }

    # Internal nodes: first recurse down to the whole subtree, projecting names and references
    foreach my $nchild_src ( $nnode_src->get_children() ) {
        my $nchild = $nnode->create_child( { ne_type => $nchild_src->ne_type } );
        $self->project_nsubtree( $nchild_src, $nchild );
    }

    # Return if we're at the root (we don't need to copy references and normalized names)
    return if ( $nnode->is_root );

    my @anodes = uniq map { $_->get_anodes } $nnode->get_children();
    @anodes = sort { $a->ord <=> $b->ord } @anodes;
    $nnode->set_anodes(@anodes);
    $nnode->set_normalized_name( join ' ', map { $_->form // $_->lemma // '' } @anodes );

    return;
}

# Check if the given aux a-node should be included in the n-tree
sub should_include_aux {
    my ( $self, $tnode, $aaux, $tnodes_hash ) = @_;

    my $afun = $aaux->afun // '';

    # always add Aux[VTR] anodes
    return 1 if ( $afun =~ /Aux[VTR]/ );

    if ( $afun =~ /Aux[CP]/ ) {

        # add Aux[CP] anodes if the parent of the t-node is also within the NE...
        my $tparent = $tnode->get_parent();
        return 1 if ( $tnodes_hash->{ $tparent->id } );

        # ...or if they are a part of the t-lemma + hanging under the lexical a-node
        my $form = $aaux->form // '';
        my $anode = $tnode->get_lex_anode();
        return 1 if ( $aaux->get_parent() == $anode and $tnode->t_lemma =~ /(_|^)$form(_|$)/ );
    }
    return 0;
}

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::N2N::ProjectTreeThroughTranslation

=head1 DESCRIPTION

Projecting an n-tree through translation on the t-layer. 

Given a zone, this finds the source zone (through t-tree root's C<tnode_src.rf> attribute).
It then tries to copy the n-tree from the source zone into the target zone.

For a given source n-tree leaf, the block projects the referenced a-nodes onto source t-nodes,
then proceeds to target t-nodes through the C<tnode_src.rf> attribute. Finally, using a simple
heuristic, it maps the t-node onto its lexical a-node and some of the auxiliary a-nodes.

The references to a-layer for internal n-tree nodes are then built bottom-up as the union of
all nodes referenced by their children.

The C<normalized_name> attributes are filled by whatever is found in the a-nodes: C<form>s or
C<lemma>s. 

=head1 AUTHOR

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2015 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

