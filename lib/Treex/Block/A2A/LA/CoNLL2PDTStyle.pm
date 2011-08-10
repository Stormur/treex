package Treex::Block::A2A::LA::CoNLL2PDTStyle;
use Moose;
use Treex::Core::Common;
use utf8;
extends 'Treex::Block::A2A::CoNLL2PDTStyle';

sub deprel_to_afun
{
    my $self  = shift;
    my $root  = shift;
    my @nodes = $root->get_descendants();
    foreach my $node (@nodes)
    {
        my $deprel = $node->conll_deprel();
        my $parent = $node->parent();
        my $ppos   = $parent->tag();

        #convert into PDT style
        if ( $deprel =~ 'PNOM' )
        {
            $node->set_afun('Pnom');
        }
        elsif ( $deprel =~ 'OBJ' )
        {
            $node->set_afun('Obj');
        }
        elsif ( $deprel =~ 'ATR' )
        {
            $node->set_afun('Atr');
        }
        elsif ( $deprel =~ 'SBJ' )
        {
            $node->set_afun('Sb');
        }
        elsif ( $deprel =~ 'COORD' )
        {
            $node->set_afun('Coord');
        }
        elsif ( $deprel =~ 'AUXC' )
        {
            $node->set_afun('AuxC');
        }
        elsif ( $deprel =~ 'AuxC' )
        {
            $node->set_afun('AuxC');
        }
        elsif ( $deprel =~ 'AuxY' )
        {
            $node->set_afun('AuxY');
        }
        elsif ( $deprel =~ 'AUXP' )
        {
            $node->set_afun('AuxP');
        }
        elsif ( $deprel =~ 'AuxP' )
        {
            $node->set_afun('AuxP');
        }
        elsif ( $deprel =~ 'PRED' )
        {
            $node->set_afun('Pred');
        }
        elsif ( $deprel =~ 'ExD' )
        {
            $node->set_afun('ExD');
        }
        elsif ( $deprel =~ 'ADV' )
        {
            $node->set_afun('Adv');
        }
        elsif ( $deprel =~ 'ATV' )
        {
            $node->set_afun('Atv');
        }
        elsif ( $deprel =~ 'ATVV' )
        {
            $node->set_afun('AtvV');
        }
        elsif ( $deprel =~ 'AtvV' )
        {
            $node->set_afun('AtvV');
        }
        elsif ( $deprel =~ 'APOS' )
        {
            $node->set_afun('Apos');
        }

        #Object compliment
        elsif ( $deprel =~ 'OCOMP' )
        {
            $node->set_afun('Obj');
        }

        #not sure what XSEG is/can't find documentation on it'
        elsif ( $deprel =~ 'XSEG' )
        {
            $node->set_afun('Atr');
        }

        #undefined tags=atr?
        elsif ( $deprel =~ 'UNDEFINED' )
        {
            $node->set_afun('Apos');
        }
        else {
            $node->set_afun($deprel);
        }

    }
}

