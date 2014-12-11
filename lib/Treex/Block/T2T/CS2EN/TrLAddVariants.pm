package Treex::Block::T2T::CS2EN::TrLAddVariants;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::T2T::TrLAddVariants';

has '+model_dir' => ( default => 'data/models/translation/cs2en' );
has '+discr_model' => ( default => '20141209_lemma.maxent.gz' );
has '+static_model' => ( default => '20141209_lemma.static.gz' );

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::T2T::CS2EN::TrLAddVariants -- add t-lemma translation variants from translation models (cs2en)

=head1 DESCRIPTION

Adding t-lemma translation variants for the cs2en translation.

=back

=head1 AUTHOR

Martin Popel <popel@ufal.mff.cuni.cz>

Michal Novák <mnovak@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
