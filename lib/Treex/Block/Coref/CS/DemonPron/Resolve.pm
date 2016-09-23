package Treex::Block::Coref::CS::DemonPron::Resolve;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::Coref::Resolve';
with 'Treex::Block::Coref::CS::DemonPron::Base';

#use Treex::Tool::Coreference::PerceptronRanker;
#use Treex::Tool::Coreference::RuleBasedRanker;
#use Treex::Tool::Coreference::ProbDistrRanker;
use Treex::Tool::ML::VowpalWabbit::Ranker;

has '+model_path' => (
    #default => 'data/models/coreference/CS/vw/perspron.2015-04-29.train.pdt.cs.vw.ranking.model',
    #default => 'data/models/coreference/CS/vw/reflpron.2016-04-24.train.pdt.cs.vw.ranking.model',
    #default => '/home/mnovak/projects/czeng_coref/treex_cr_train/cs/reflpron/tmp/ml/run_2016-04-26_00-56-30_22064.candidates_formeme_or_sempos_must_start_with_n_-_more_candidates/003.5902492061.featset/001.7eb17.mlmethod/model/train.pdt.table.gz.vw.ranking.model',
    default => '/home/mnovak/projects/czeng_coref/treex_cr_train/cs/demonpron/tmp/ml/003_run_2016-09-19_14-46-31_27021.PDT._MonoligualAll_feats._segm_and_exoph_bugfix/001.d48d2d7b1c.featset/004.39acd.mlmethod/model/train.pdt.table.gz.vw.ranking.model',
);

override '_build_ranker' => sub {
    my ($self) = @_;
#    my $ranker = Treex::Tool::Coreference::RuleBasedRanker->new();
#    my $ranker = Treex::Tool::Coreference::ProbDistrRanker->new(
#    my $ranker = Treex::Tool::Coreference::PerceptronRanker->new( 
    my $ranker = Treex::Tool::ML::VowpalWabbit::Ranker->new( 
        { model_path => $self->model_path } 
    );
    return $ranker;
};

override 'actions_for_special_classes' => sub {
    my ($self, $tnode, $ante_idx) = @_;
    # __SELF__: non-anaphoric
    if ($ante_idx == 0) {
        $tnode->wild->{referential} = 0;
    }
    # __SEGM__: referring to a segment
    elsif ($ante_idx == 1) {
        $tnode->set_attr("coref_special", "segm");
        $tnode->wild->{referential} = 1;
    }
    # __EXOPH__: exophora
    else {
        $tnode->set_attr("coref_special", "exoph");
        $tnode->wild->{referential} = 1;
    }
};

1;

#TODO adjust documentation

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::Coref::CS::DemonPron::Resolve

=head1 DESCRIPTION


=head1 AUTHORS

Michal Novák <mnovak@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011-2016 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
