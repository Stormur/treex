package Treex::Block::A2T::CS::SetDiathesis;
use Moose;
use Treex::Core::Common;

extends 'Treex::Core::Block';

sub process_tnode {
    my ( $self, $t_node ) = @_;

    if ( $t_node->gram_sempos and $t_node->gram_sempos eq 'v' ) {

        my $lex_a_node = $t_node->get_lex_anode;
        return unless $lex_a_node;

        my $diathesis;

        if ( $lex_a_node->tag =~ /^Vs/ ) {
            $diathesis = 'pas';
        }
        elsif ( grep { $_->afun eq "AuxR" } $lex_a_node->get_children ) {    # TODO shouldn't these be aux_nodes of the t_node ?
            $diathesis = 'deagent';
        }
        else {
            $diathesis = 'act';
        }

        $t_node->set_gram_diathesis($diathesis);
    }
    return;
}

1;

__END__

=encoding utf-8
=head1 NAME

Treex::Block::A2T::CS::SetDiathesis

=head1 DESCRIPTION

The attribute C<gram/diathesis> of Czech verb t-nodes is filled
with one of the following values:
  act - active diathesis
  pas - passive diathesis
  deagent - deagentive diathesis

=head1 AUTHORS

Zdeněk Žabokrtský <zabokrtsky@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2008-2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
