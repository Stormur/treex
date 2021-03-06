package Treex::Block::Filter::CzEng::Train;
use Moose;
use Treex::Core::Common;
use Treex::Block::Filter::CzEng::MaxEnt;
use Treex::Block::Filter::CzEng::NaiveBayes;
use Treex::Block::Filter::CzEng::DecisionTree;

extends 'Treex::Block::Filter::CzEng::Common';

has annotation => (
    isa           => 'Str',
    is            => 'ro',
    required      => 1,
    documentation => 'file with lines containing either "x" or "ok" for each sentence'
);

has outfile => (
    isa           => 'Str',
    is            => 'rw',
    required      => 0,
    default       => "model.maxent",
    documentation => 'output file for the model'
);

has use_for_training => (
    isa           => 'Int',
    is            => 'ro',
    required      => '0',
    documentation => 'how many sentences should be used to train the model (the rest '
                     . 'is used for evaluation)',
    default       => 0
);

has classifier_type => (
    isa           => 'Str',
    is            => 'ro',
    required      => '1',
    documentation => 'classifier type, can be "maxent", "naive_bayes", "decision_tree"'
);

has _classifier_obj => (
    is            => 'rw',
    required      => '0',
    does          => 'Treex::Block::Filter::CzEng::Classifier',
);

sub BUILD {
    my $self = shift;
    if ( $self->{classifier_type} eq "maxent" ) {
        $self->{_classifier_obj} = new Treex::Block::Filter::CzEng::MaxEnt();
    } elsif ( $self->{classifier_type} eq "naive_bayes" ) {
        $self->{_classifier_obj} = new Treex::Block::Filter::CzEng::NaiveBayes();
    } elsif ( $self->{classifier_type} eq "decision_tree" ) {
        $self->{_classifier_obj} = new Treex::Block::Filter::CzEng::DecisionTree();
    } else {
        log_fatal "Unknown classifier type: $self->{classifier_type}";
    }

    $self->{outfile} = "/net/projects/tectomt_shared/data/models/czeng_filter/" . $self->{outfile};
}

sub process_document {
    my ( $self, $document ) = @_;
    $self->{_classifier_obj}->init();

    # train
    open( my $anot_hdl, $self->{annotation} ) or log_fatal $!;
    my @bundles = $document->get_bundles();

    my $count = $self->{use_for_training};
    $count = scalar @bundles if ! $count;
    for ( my $i = 0; $i < $count; $i++ ) {
        log_fatal "Not enough sentences for training" if $i >= scalar @bundles;
        my @features = $self->get_features($bundles[$i]);
        chomp( my $anot = <$anot_hdl> );
        $anot = ( split( "\t", $anot ) )[0];
        log_fatal "Error reading annotation file $self->{annotation}" if ! defined $anot;
        $self->{_classifier_obj}->see( \@features => $anot );
    }
    $self->{_classifier_obj}->learn();
    $self->{_classifier_obj}->save( $self->{outfile} );

    # evaluate
    if ( $self->{use_for_training} ) {
        my ( $x, $p, $tp ) = qw( 0 0 0 );
        for ( my $i = $count; $i < scalar @bundles; $i++ ) {
            my @features = $self->get_features($bundles[$i]);
            chomp( my $anot = <$anot_hdl> );
            $anot = ( split( "\t", $anot ) )[0];
            log_fatal "Error reading annotation file $self->{annotation}" if ! defined $anot;
            my $prediction = $self->{_classifier_obj}->predict( \@features );
            $prediction = 'ok' if ! defined $prediction; # decision trees say nothing unless they know
            if ($anot eq 'x') {
                $x++;
                $tp++ if $prediction eq 'x';
            }
            $p++ if $prediction eq 'x';
        }

        log_info sprintf( "Precision = %.03f, Recall = %.03f", $p ? $tp / $p : 0, $x ? $tp / $x : 0);
    }

    return 1;
}

1;

=over

=item Treex::Block::Filter::CzEng::Train

Given data and a classifier object, train and optionally evaluate a filter model.

=back

=cut

# Copyright 2011 Ales Tamchyna

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
