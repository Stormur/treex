package Treex::Tool::Coreference::CS::PronAnaphFilter;

use Moose;
use Treex::Core::Common;

with 'Treex::Tool::Coreference::AnaphFilter';

# according to rule presented in Nguy et al. (2009)
# nodes with the t_lemma #PersPron and third person in gram/person
sub is_candidate {
    my ($self, $node) = @_;
    return ( $node->t_lemma eq '#PersPron' && $node->gram_person eq '3' );
}

# TODO doc

1;
