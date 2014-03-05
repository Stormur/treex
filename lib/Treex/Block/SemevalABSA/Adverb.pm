package Treex::Block::SemevalABSA::Adverb;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::SemevalABSA::BaseRule';

sub process_ttree {
    my ( $self, $ttree ) = @_;
    my $amapper = get_alayer_mapper( $ttree );
    my @advs = grep { $_->formeme eq 'adv' && is_subjective( $amapper->( $_ ) ) } $ttree->get_descendants;

    for my $adv (@advs) {
        my $pred = find_predicate( $adv );
        next if ! $pred;
        my $polarity = get_polarity( $amapper->( $adv ) );
        my @to_mark = grep { $_->functor eq 'PAT' } get_clause_descendants( $pred );
        if (! @to_mark) {
            @to_mark = grep { $_->functor eq 'ACT' } get_clause_descendants( $pred );
        }
        map { mark_node ( $amapper->( $_ ), "adv_" . $polarity ) } @to_mark;
    }

    return 1;
}

1;

# polaritu adverbia prevezme PAT, existuje-li, jinak ACT
