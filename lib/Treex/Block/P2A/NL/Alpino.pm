package Treex::Block::P2A::NL::Alpino;
use Moose;
use Treex::Core::Common;
use utf8;
extends 'Treex::Core::Block';

my %HEAD_SCORE = ('hd' => 6, 'cmp' => 5, 'crd' => 4, 'dlink' => 3, 'rhd' => 2, 'whd' => 1);

sub create_subtree {
    my ($p_root, $a_root) = @_;
    my @children = sort {($HEAD_SCORE{$b->wild->{rel}} || 0) <=> ($HEAD_SCORE{$a->wild->{rel}} || 0)} grep {!defined $_->form || $_->form !~ /^\*\-/} $p_root->get_children();
    my $head = $children[0];
    foreach my $child (@children) {
        my $new_node;
        if ($child == $head) {
            $new_node = $a_root;
        }
        else {
            $new_node = $a_root->create_child();
        }
        if (defined $child->form) { # the node is termineal
            $new_node->set_form($child->form);
            $new_node->set_lemma($child->lemma);
            $new_node->set_tag($child->tag);
            $new_node->set_attr('ord',$child->wild->{pord});
        }
        elsif (defined $child->phrase) { # the node is nonterminal
            create_subtree($child, $new_node);
        }
    }
}


sub process_zone {
    my ($self, $zone) = @_;
    my $p_root = $zone->get_ptree;
    my $a_root = $zone->create_atree();
    my $a_node = $a_root->create_child();
    create_subtree($p_root, $a_node);
}

1;

=over

=item Treex::Block::P2A::NL::Alpino

Converts phrase-based Dutch Alpino Treebank to dependency format.

=back

=cut

# Copyright 2014 David Mareček <marecek@ufal.mff.cuni.cz>
# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
