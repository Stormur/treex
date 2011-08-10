package Treex::Block::A2A::EL::CoNLL2PDTStyle;
use Moose;
use Treex::Core::Common;
use utf8;
extends 'Treex::Block::A2A::CoNLL2PDTStyle';

#------------------------------------------------------------------------------
# Reads the Italian CoNLL trees, converts morphosyntactic tags to the positional
# tagset and transforms the tree to adhere to PDT guidelines.
#------------------------------------------------------------------------------
sub process_zone
{
    my $self   = shift;
    my $zone   = shift;
    my $a_root = $self->SUPER::process_zone($zone);
}

#------------------------------------------------------------------------------
# Convert dependency relation tags to analytical functions.
# http://ufal.mff.cuni.cz/pdt2.0/doc/manuals/cz/a-layer/html/ch03s02.html
#------------------------------------------------------------------------------
sub deprel_to_afun
{
    my $self  = shift;
    my $root  = shift;
    my @nodes = $root->get_descendants();
    foreach my $node (@nodes)
    {
        my $deprel = $node->conll_deprel();
        my $form   = $node->form();
        my $pos    = $node->conll_pos();

        # default assignment
        my $afun = $deprel;

        $afun =~ s/^IObj/Obj/;
        $afun =~ s/_Ap$//;
        $afun =~ s/_Pa$//;

        if ( $deprel eq '---' ) {
            $afun = "Atr";
        }

        if ( $afun =~ /_Co$/ ) {
            $afun =~ s/_Co$//;
            $node->set_is_member(1);
        }

        $node->set_afun($afun);
    }
}

1;

=over

=item Treex::Block::A2A::EL::CoNLL2PDTStyle

Converts Modern Greek dependency treebank into PDT style treebank.

1. Morphological conversion             -> Yes 

2. DEPREL conversion                    -> Yes

3. Structural conversion to match PDT   -> Yes



=back

=cut

# Copyright 2011 Dan Zeman <zeman@ufal.mff.cuni.cz>, Loganathan Ramasamy <ramasamy@ufal.mff.cuni.cz>

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
