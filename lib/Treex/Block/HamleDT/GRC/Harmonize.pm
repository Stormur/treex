package Treex::Block::HamleDT::GRC::Harmonize;
use Moose;
use Treex::Core::Common;
use utf8;
extends 'Treex::Block::HamleDT::HarmonizePDT';

my %agdt2pdt =
(
    'ADV'       => 'Adv',
    'APOS'      => 'Apos',
    'ATR'       => 'Atr',
    'ATV'       => 'Atv',
    'COORD'     => 'Coord',
    'OBJ'       => 'Obj',
    'OCOMP'     => 'Obj', ###!!!
    'PNOM'      => 'Pnom',
    'PRED'      => 'Pred',
    'SBJ'       => 'Sb',
    'UNDEFINED' => 'NR',
    # XSEG is assigned to initial parts of a broken word, e.g. "Achai - on": on ( Achai/XSEG , -/XSEG )
    'XSEG'      => 'Atr' ###!!! Should we add XSeg to the set of HamleDT labels?
);

#------------------------------------------------------------------------------
# Reads the Ancient Greek CoNLL trees, converts morphosyntactic tags to the positional
# tagset and transforms the tree to adhere to PDT guidelines.
#------------------------------------------------------------------------------
sub process_zone
{
    my $self = shift;
    my $zone = shift;
    my $root = $self->SUPER::process_zone($zone);
    $self->fix_undefined_nodes($root);
    ###!!! TODO: grc trees sometimes have conjunct1, coordination, conjunct2 as siblings. We should fix it, but meanwhile we just delete afun=Coord from the coordination.
    $self->check_coord_membership($root);
    $self->check_afuns($root);
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
    # First loop: copy deprel to afun and convert _CO and _AP to is_member.
    # Leave everything else untouched until we know that is_member is set correctly for all nodes.
    foreach my $node (@nodes)
    {
        my $deprel = $node->conll_deprel();
        my $afun = $deprel;
        # There were occasional cycles in the source data. They were removed before importing the trees to Treex
        # but a mark was left in the dependency label where the cycle was broken.
        # Example: AuxP-CYCLE:12-CYCLE:16-CYCLE:15-CYCLE:14
        # We have no means of repairing the structure but we have to remove the mark in order to get a valid afun.
        $afun =~ s/-CYCLE.*//;
        # The _CO suffix signals conjuncts.
        # The _AP suffix signals members of apposition.
        # We will later reshape appositions but the routine will expect is_member set.
        if($afun =~ s/_(CO|AP)$//)
        {
            $node->set_is_member(1);
            # There are nodes that have both _AP and _CO but we have no means of representing that.
            # Remove the other suffix if present.
            $afun =~ s/_(CO|AP)$//;
        }
        # Convert the _PA suffix to the is_parenthesis_root flag.
        if($afun =~ s/_PA$//)
        {
            $node->set_is_parenthesis_root(1);
        }
    }
    # Second loop: we still cannot rely on is_member because it is not guaranteed that it is always set directly under COORD or APOS.
    # The source data follow the PDT convention that AuxP and AuxC nodes do not have it (and thus it is marked at a lower level).
    # In contrast, Treex marks is_member directly under Coord or Apos. We cannot convert it later because we need reliable is_member
    # for afun conversion. And we cannot use the Pdt2TreexIsMemberConversion block because it relies on the afuns Coord and Apos
    # and these are not yet ready.
    foreach my $node (@nodes)
    {
        if($node->is_member())
        {
            my $new_member = _climb_up_below_coap($node);
            if($new_member && $new_member != $node)
            {
                $new_member->set_is_member(1);
                $node->set_is_member(undef);
            }
        }
    }
    # Third loop: now that we can rely on the is_member flags, we can recognize even interacting coordination and elipsis.
    # Let's convert the rest of afuns.
    foreach my $node (@nodes)
    {
        my $afun = $node->afun();
        # There are chained dependency labels that describe situation around elipsis.
        # They ought to contain an ExD, which may be indexed.
        # The tag before ExD describes the dependency of the node on its elided parent.
        # The tag after ExD describes the dependency of the elided parent on the grandparent.
        # Example: ADV_ExD0_PRED_CO
        # Similar cases in PDT get just ExD.
        if($afun =~ m/ExD/)
        {
            # If the chained label is something like COORD_ExD0_OBJ_CO_ExD1_PRED,
            # this node should be Coord and the conjuncts should get ExD.
            if($afun =~ m/^COORD/)
            {
                my @members = grep {$_->is_member()} ($node->children());
                if(@members)
                {
                    foreach my $member (@members)
                    {
                        $member->set_real_afun('ExD');
                    }
                    $afun = 'Coord';
                }
                else
                {
                    $afun = 'ExD';
                }
            }
            elsif($afun =~ m/^APOS/)
            {
                my @members = grep {$_->is_member()} ($node->children());
                if(@members)
                {
                    foreach my $member (@members)
                    {
                        $member->set_real_afun('ExD');
                    }
                    $afun = 'Apos';
                }
                else
                {
                    $afun = 'ExD';
                }
            }
            else
            {
                $afun = 'ExD';
            }
        }
        # Most AGDT afuns are all uppercase but we typically want only the first letter uppercase.
        if(exists($agdt2pdt{$afun}))
        {
            $afun = $agdt2pdt{$afun};
        }
        $node->set_afun($afun);
    }
    foreach my $node (@nodes)
    {
        # "and" and "but" have often deprel PRED
        if ($node->form =~ /^(και|αλλ’|,)$/ and grep {$_->is_member} $node->get_children)
        {
            $node->set_afun('Coord');
        }
        # no is_member allowed directly below root
        if ($node->is_member and $node->get_parent->is_root)
        {
            $node->set_is_member(0);
        }
    }
}

#------------------------------------------------------------------------------
# Searches for the head of coordination or apposition in AGDT. Adapted from
# Pdt2TreexIsMemberConversion by Zdenek Zabokrtsky (but different because of
# slightly different afuns in this treebank). Used for moving the is_member
# flag directly under the head (even if it is AuxP, in which case PDT would not
# put the flag there).
#------------------------------------------------------------------------------
sub _climb_up_below_coap
{
    my ($node) = @_;
    if ($node->parent()->is_root())
    {
        log_warn('No co/ap node between a co/ap member and the tree root');
        return;
    }
    elsif ($node->parent()->afun() =~ m/(COORD|APOS)/i)
    {
        return $node;
    }
    else
    {
        return _climb_up_below_coap($node->parent());
    }
}

#------------------------------------------------------------------------------
# A few punctuation nodes (commas and dashes) are attached non-projectively to
# the root, ignoring their neighboring tokens. They are labeled with the
# UNDEFINED afun (which we temporarily converted to NR). Attach them to the
# preceding token and give them a better afun.
#------------------------------------------------------------------------------
sub fix_undefined_nodes
{
    my $self  = shift;
    my $root  = shift;
    my @nodes = $root->get_descendants({ordered => 1});
    for(my $i = 0; $i<=$#nodes; $i++)
    {
        my $node = $nodes[$i];
        # If this is the last punctuation in the sentence, chances are that it was already recognized as AuxK.
        # In that case the problem is already fixed.
        if($node->conll_deprel() eq 'UNDEFINED' && $node->afun() ne 'AuxK')
        {
            if($node->parent()->is_root() && $node->is_leaf())
            {
                # Attach the node to the preceding token if there is a preceding token.
                if($i>0)
                {
                    $node->set_parent($nodes[$i-1]);
                }
                # If there is no preceding token but there is a following token, attach the node there.
                elsif($i<$#nodes && $nodes[$i+1]->afun() ne 'AuxK')
                {
                    $node->set_parent($nodes[$i+1]);
                }
                # If this is the only token in the sentence, it remained attached to the root.
                # Pick the right afun for the node.
                my $form = $node->form();
                if($form eq ',')
                {
                    $node->set_afun('AuxX');
                }
                # Besides punctuation there are also separated diacritics that should never appear alone in a node but they do:
                # 768 \x{300} COMBINING GRAVE ACCENT
                # 769 \x{301} COMBINING ACUTE ACCENT
                # 787 \x{313} COMBINING COMMA ABOVE
                # 788 \x{314} COMBINING REVERSED COMMA ABOVE
                # 803 \x{323} COMBINING DOT BELOW
                # 834 \x{342} COMBINING GREEK PERISPOMENI
                # All these characters belong to the class M (marks).
                elsif($form =~ m/^[\pP\pM]+$/)
                {
                    $node->set_afun('AuxG');
                }
                else # neither punctuation nor diacritics
                {
                    $node->set_afun('AuxY');
                }
            }
            # Other UNDEFINED nodes.
            elsif($node->parent()->is_root() && $node->get_iset('pos') eq 'verb')
            {
                $node->set_afun('Pred');
            }
            elsif($node->parent()->is_root())
            {
                $node->set_afun('ExD');
            }
            elsif(grep {$_->conll_deprel() eq 'XSEG'} ($node->get_siblings()))
            {
                # UNDEFINED nodes that are siblings of XSEG nodes should have been also XSEG nodes.
                $node->set_afun('Atr');
            }
            elsif($node->parent()->get_iset('pos') eq 'noun')
            {
                $node->set_afun('Atr');
            }
            elsif($node->parent()->get_iset('pos') eq 'verb' && $node->match_iset('pos' => 'noun', 'case' => 'acc'))
            {
                $node->set_afun('Obj');
            }
            else
            {
                $node->set_afun('ExD');
            }
        }
    }
}

#------------------------------------------------------------------------------
# Catches possible annotation inconsistencies. If there are no conjuncts under
# a Coord node, let's try to find them. (We do not care about apposition
# because it has been restructured.)
#------------------------------------------------------------------------------
sub check_coord_membership
{
    my $self  = shift;
    my $root  = shift;
    my @nodes = $root->get_descendants();
    foreach my $node (@nodes)
    {
        my $afun = $node->afun();
        if($afun eq 'Coord')
        {
            my @children = $node->children();
            # Are there any children?
            if(scalar(@children)==0)
            {
                # There are a few annotation errors where a leaf node is labeled Coord.
                # In some cases, the node is rightly Coord but it ought not to be leaf.
                my $parent = $node->parent();
                my $sibling = $node->get_left_neighbor();
                my $uncle = $parent->get_left_neighbor();
                ###!!! TODO
            }
            # If there are children, are there conjuncts among them?
            elsif(scalar(grep {$_->is_member()} (@children))==0)
            {
                $self->identify_coap_members($node);
            }
        }
    }
}

1;

=over

=item Treex::Block::HamleDT::GRC::Harmonize

Converts Ancient Greek dependency treebank to the HamleDT (Prague) style.
Most of the deprel tags follow PDT conventions but they are very elaborated
so we have shortened them.

=back

=cut

# Copyright 2011, 2014 Dan Zeman <zeman@ufal.mff.cuni.cz>
# Copyright 2011 Loganathan Ramasamy <ramasamy@ufal.mff.cuni.cz>

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
