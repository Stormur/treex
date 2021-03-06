package Treex::Block::Coref::MarkMentionsForScorer;
use Moose;
use Treex::Core::Common;

use Treex::Tool::Coreference::Utils;
use Treex::Tool::Coreference::NodeFilter;

extends 'Treex::Core::Block';

has 'layer' => ( is => 'ro', isa => enum([qw/a t/]), default => 'a' );
has 'only_heads' => ( is => 'ro', isa => 'Bool', default => 1 );
has 'clear' => ( is => 'ro', isa => 'Bool', default => 1 );

has '_entities' => ( is => 'rw', isa => 'HashRef[Str]', default => sub {{}} );

# project only nodes that are not anaphors of grammatical coreference
#sub _is_coref_text_mention {
#    my ($tnode) = @_;
#    my @is_ante = ($tnode->get_referencing_nodes('coref_gram.rf'), $tnode->get_referencing_nodes('coref_text.rf'));
#    my @is_text_anaph = $tnode->get_coref_text_nodes();
#    my @is_gram_anaph = $tnode->get_coref_gram_nodes();
#    return ((@is_ante || @is_text_anaph) && !@is_gram_anaph);
#}

before 'process_document' => sub {
    my ($self, $doc) = @_;

    if ($self->clear) {
        my @trees = map { $_->get_tree($self->language, $self->layer, $self->selector) } $doc->get_bundles;
        foreach my $tree (@trees) {
            foreach my $node ($tree->get_descendants) {
                delete $node->wild->{coref_mention_start};
                delete $node->wild->{coref_mention_end};
            }
        }
    }

    $self->_set_entities({});

    my @ttrees = map { $_->get_tree($self->language,'t',$self->selector) } $doc->get_bundles;
    my @chains = Treex::Tool::Coreference::Utils::get_coreference_entities(\@ttrees);
    my $entity_idx = 1;
    foreach my $chain (@chains) {
        foreach my $node (@$chain) {
            $self->_entities->{$node->id} = $entity_idx;
        }
        $entity_idx++;
    }
};

sub process_tnode {
    my ($self, $tnode) = @_;

#    return if (!_is_coref_text_mention($tnode));
    my $entity_idx = $self->_entities->{$tnode->id};
    return if (!defined $entity_idx);
    
    my @mention_nodes;
    if ($self->layer eq 'a') {
        @mention_nodes = $self->surface_mention_by_t_expansion($tnode);
        #$self->surface_mention_by_a_expansion;
    }
    # if asked for a mention on the t-layer, heads_only format is the only possible
    else {
        @mention_nodes = ( $tnode );
    }

    return if (!@mention_nodes);
    
    # the beginning of the mention
    push @{$mention_nodes[0]->wild->{coref_mention_start}}, $entity_idx;
    # the end of the mention
    push @{$mention_nodes[-1]->wild->{coref_mention_end}}, $entity_idx;
}

sub surface_mention_by_t_expansion {
    my ($self, $tnode) = @_;
    
    my @mention_t_nodes = get_desc_no_verbal_subtree($tnode);
    my $t_head_mention = $mention_t_nodes[0];
    my $a_head_mention = $t_head_mention->get_lex_anode;
    #return if (!defined $a_head_mention);
    
    my @mention_a_nodes = grep {defined $_ && (!defined $a_head_mention || $_ == $a_head_mention || $_->is_descendant_of($a_head_mention))}
        map { $self->only_heads ? $_->get_lex_anode : $_->get_anodes } @mention_t_nodes;
    
    @mention_a_nodes = sort {$a->ord <=> $b->ord} @mention_a_nodes;

    if (@mention_a_nodes > 0 && $mention_a_nodes[-1]->form =~ /^[.,:]$/) {
        pop @mention_a_nodes;
    }
    return @mention_a_nodes;
}

sub get_desc_no_verbal_subtree {
    my ($tnode) = @_;
    my @desc = ( $tnode );
    foreach my $kid ($tnode->get_children) {
        next if ((defined $kid->formeme && $kid->formeme =~ /^v/) || (defined $kid->gram_sempos && $kid->gram_sempos =~ /^v/));
        my @subdesc = get_desc_no_verbal_subtree($kid);
        push @desc, @subdesc;
    }
    return @desc;
}

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::Coref::MarkMentionsForScorer

=head1 DESCRIPTION

This block marks the coreference mentions by setting the wild attributes
"coref_mention_start" and "coref_mention_end".

This block is usually followed by Treex::Block::Write::SemEval2010, which prints out
the data in the format consumed by CoNLL coreference resolution scorer.

=head1 PARAMETERS

=over

=item C<layer>

Which layer is taken as a basis (default "a").

=back

=head1 AUTHOR

Michal Novák <mnovak@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2013, 2015 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
