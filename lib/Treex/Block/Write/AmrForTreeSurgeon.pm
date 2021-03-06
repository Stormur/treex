package Treex::Block::Write::AmrForTreeSurgeon;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::Write::Amr';

# Returns the t-node's lemma/label
sub _get_lemma {
    my ( $self, $tnode ) = @_;
    
    return undef if ( !defined $tnode->t_lemma );
    my @data = ( $tnode->t_lemma );

    # skip NE generated nodes
    if ( $tnode->src_tnode ) {
        push @data, 'formeme=' . ( $tnode->src_tnode->formeme // '' );

        my @anodes;
        # add surface information from whole NEs to NE head, otherwise just from the linked a-node
        if ( $tnode->wild->{is_ne_head} ) {
            my $nnode = $tnode->get_document()->get_node_by_id( $tnode->wild->{src_nnode} );
            @anodes = sort { $a->ord <=> $b->ord } $nnode->get_anodes();
        }
        else {
            @anodes = $tnode->src_tnode->get_anodes( { ordered => 1 } );
        }
        push @data, 'lemma=' . join( ' ', map { $_->lemma } @anodes );
        push @data, 'form=' . join( ' ', map { $_->form } @anodes );

        # add BBN information
        if ( $tnode->src_tnode->wild->{bbn} ) {
            push @data, 'bbn=' . lc( $tnode->src_tnode->wild->{bbn} );
        }
    }

    # use shortened IDs (without language and selector)
    my $id = $tnode->id;
    $id =~ s/.*([ps][0-9])/$1/;
    push @data, 'id=' . $id;

    return join( '_', map { $_ =~ s/ /_/g; $_ } @data );
}

1;

__END__

=head1 NAME

Treex::Block::Write::AmrForTreeSurgeon

=head1 DESCRIPTION

Produces a Penman (AMR)-like format for the Tsurgeon tool, containing
additional attributes (formemes, BBN Ne types, surface) in comparison to normal AMR.

=head1 ATTRIBUTES

=over

=item language

Language of the trees to be printed.

=item selector

Selector of the trees to be printed.

=back

=head1 AUTHORS

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
