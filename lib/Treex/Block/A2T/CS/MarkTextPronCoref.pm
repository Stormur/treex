package Treex::Block::A2T::CS::MarkTextPronCoref;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::A2T::BaseMarkCoref';

use Treex::Tool::Coreference::PerceptronRanker;
#use Treex::Tool::Coreference::RuleBasedRanker;
#use Treex::Tool::Coreference::ProbDistrRanker;
use Treex::Tool::ML::VowpalWabbit::Ranker;
use Treex::Tool::Coreference::CS::PronCorefFeatures;
use Treex::Tool::Coreference::NounAnteCandsGetter;
use Treex::Tool::Coreference::CS::PronAnaphFilter;

has '+model_path' => (
    default => '/home/mnovak/projects/czeng_coref/tmp/ml/tte_feats_2013-11-17_13-35-54/4e224b442c/model/pdt.cs.analysed.vw.ranking.8411a.model',
#    default => 'data/models/coreference/CS/perceptron/text.perspron.analysed',
#    default => 'data/models/coreference/CS/gibbs/text.perspron.analysed',
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

override '_build_feature_extractor' => sub {
    my ($self) = @_;
    #my $fe = Treex::Tool::Coreference::CS::PronCorefFeatures->new();
    my $fe = Treex::Tool::Coreference::CS::PronCorefFeatures->new({
    #    format => 'unsup'
    });
    return $fe;
};

override '_build_ante_cands_selector' => sub {
    my ($self) = @_;
    my $acs = Treex::Tool::Coreference::NounAnteCandsGetter->new({
        prev_sents_num => 1,
        anaphor_as_candidate => 1,
        cands_within_czeng_blocks => 1,
    });
    return $acs;
};

override '_build_anaph_cands_filter' => sub {
    my ($self) = @_;
    my $acf = Treex::Tool::Coreference::CS::PronAnaphFilter->new();
    return $acf;
};

1;

=over

=item Treex::Block::A2T::CS::MarkTextPronCoref


=back

=cut

# Copyright 2008-2011 Michal Novak

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
