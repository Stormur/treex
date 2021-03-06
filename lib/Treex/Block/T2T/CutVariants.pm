package Treex::Block::T2T::CutVariants;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

has [qw(max_lemma_variants max_formeme_variants)] => (
    is            => 'ro',
    isa           => 'Int',
    default       => 0,
    documentation => 'Retain at most this number of translation variants. 0 means infinity.'
);

has [qw(lemma_prob_sum formeme_prob_sum)] => (
    is            => 'ro',
    isa           => 'Num',
    documentation => 'Retain at most N translation variants,'
        . ' where N is the smallest number so that a sum of N first probabilities'
        . ' is higher than this parameter.'
);

sub BUILD {
    my ( $self, $arg_ref ) = @_;
    my $sum_restriction = defined $self->lemma_prob_sum || defined $self->formeme_prob_sum;
    my $max_restriction = $self->max_lemma_variants     || $self->max_formeme_variants;

    log_fatal(
        'Applying T2T::CutVariants block with no restriction (parameters) does not make sense. '
            . 'Add at least one of: max_lemma_variants, max_formeme_variants, lemma_prob_sum, formeme_prob_sum.'
        )
        if !( $sum_restriction || $max_restriction );

    # TODO check <0,1> interval by a special type within "has"
    #log_fatal("=$l_sum is not in <0,1>")   if defined $l_sum && ( $l_sum < 0 or $l_sum > 1 );
    #log_fatal("FORMEME_PROB_SUM=$f_sum is not in <0,1>") if defined $f_sum && ( $f_sum < 0 or $f_sum > 1 );
    return;
}

sub process_tnode {
    my ( $self, $node ) = @_;

    # t_lemma_variants
    my $lemmas = $self->max_lemma_variants;
    my $l_sum  = $self->lemma_prob_sum;
    my $ls_ref = $node->get_attr('translation_model/t_lemma_variants');
    if ( $l_sum && $ls_ref ) {
        my ( $sum, $variants ) = ( 0, 0 );
        while ( $sum < $l_sum && $variants < @{$ls_ref} ) {
            $sum += 2**$ls_ref->[ $variants++ ]{'logprob'};
        }
        if ( !$lemmas or $variants < $lemmas ) {
            $lemmas = $variants;
        }
    }
    if ( $lemmas && $ls_ref && @{$ls_ref} > $lemmas ) {
        splice @{$ls_ref}, $lemmas;
    }

    # same for formeme_variants
    my $formemes = $self->max_formeme_variants;
    my $f_sum    = $self->formeme_prob_sum;
    my $fs_ref   = $node->get_attr('translation_model/formeme_variants');
    if ( $f_sum && $fs_ref ) {
        my ( $sum, $variants ) = ( 0, 0 );
        while ( $sum < $f_sum && $variants < @{$fs_ref} ) {
            $sum += 2**$fs_ref->[ $variants++ ]{'logprob'};
        }
        if ( !defined $formemes or $variants < $formemes ) {
            $formemes = $variants;
        }
    }
    if ( $formemes && $fs_ref && @{$fs_ref} > $formemes ) {
        splice @{$fs_ref}, $formemes;
    }
}

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::T2T::CutVariants -- prune t_lemma & formeme translations variants

=head1 SYNOPSIS

 T2T::CutVariants max_lemma_variants=7 max_formeme_variants=7 lemma_prob_sum=0.6 formeme_prob_sum=0.6

=head1 DESCRIPTION

Utility block that deletes some translation variants of t-lemmas and formemes.
By parameters (max_[lemma|formeme]_variants and [lemma|formeme]_prob_sum) you can set
the number of variants to be left in the C<translation_model/t_lemma_variants>
and C<translation_model/formeme_variants> attributes.

Conditions are evaluated in conjunction, for example, max_lemma_variants=3 and lemma_prob_sum=0.6
nodeA: prob1=0.5 prob2=0.2 prob3=0.1             ... 2 variants left (sum=0.7)
nodeB: prob1=0.3 prob2=0.1 prob3=0.1 prob4=0.05  ... 3 variants left (sum=0.5)

If the variants were generated by
L<Treex::Block::T2T::TrLAddVariants> or
L<Treex::Block::T2T::TrFAddVariants> block,
you can also use their own C<max_variants> parameter
so superfluous variants are never even saved to the attributes.

=head1 AUTHORS

Martin Popel <popel@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2008,2015 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
