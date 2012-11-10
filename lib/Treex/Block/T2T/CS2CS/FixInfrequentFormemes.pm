package Treex::Block::T2T::CS2CS::FixInfrequentFormemes;
use Moose;
use Treex::Core::Common;
use utf8;
extends 'Treex::Block::T2T::CS2CS::Deepfix';

# model
has 'model'            => ( is => 'rw', isa => 'Maybe[Str]', default => undef );
has 'model_from_share' => ( is => 'ro', isa => 'Maybe[Str]', default => undef );
has 'model_format'     => ( is => 'ro', isa => 'Str', default => 'tlemma_ptlemma_pos_formeme' );

# exclusive thresholds
has 'lower_threshold' => ( is => 'ro', isa => 'Num', default => 0.2 );
has 'upper_threshold' => ( is => 'ro', isa => 'Num', default => 0.85 );

has 'lower_threshold_en' => ( is => 'ro', isa => 'Num', default => 0.1 );
has 'upper_threshold_en' => ( is => 'ro', isa => 'Num', default => 0.6 );

has 'magic' => ( is => 'ro', isa => 'Str', default => '' );

my $model_data;

sub process_start {
    my $self = shift;

    # find the model file
    if ( defined $self->model_from_share ) {
        my $model = require_file_from_share(
	    'data/models/deepfix/' . $self->model_from_share );
        $self->set_model($model);
    }
    if ( !defined $self->model ) {
        log_fatal("Either model or model_from_share parameter must be set!");
    }

    # load the model file
    $model_data = do $self->model;

    # handle errors
    if ( !$model_data ) {
        if ($@) {
            log_fatal "Cannot parse file " . $self->model . ": $@";
        }
        elsif ( !defined $model_data ) {
            log_fatal "Cannot read file " . $self->model . ": $!";
        }
        else {
            log_fatal "Cannot load data from file " . $self->model;
        }
    }

    return;
}

sub fill_node_info {
    my ( $self, $node_info ) = @_;
    
    $self->fill_info_from_tree($node_info);
    $self->fill_info_from_model($node_info);

    return;
}

# fills in info that is provided by the model
sub fill_info_from_model {
    my ( $self, $node_info ) = @_;

    # get info from model
    $node_info->{'original_score'} =
        $self->get_formeme_score($node_info);
    ( $node_info->{'best_formeme'}, $node_info->{'best_score'} ) =
        $self->get_best_formeme($node_info);
    ( $node_info->{'bpos'}, $node_info->{'bpreps'}, $node_info->{'bcase'} )
	= Treex::Tool::Depfix::CS::FormemeSplitter::splitFormeme(
        $node_info->{'best_formeme'} );

    return $node_info;
}

# uses the model to compute the score of the given formeme
# (or the original formeme if no formeme is given)
# NB: this is *it*, this is what actually decides the fix
# Now this is simply MLE with +1 smoothing, but backoff could be provided
# and eventually there should be some "real" machine learning here
sub get_formeme_score {
    my ( $self, $node_info, $formeme ) = @_;
    if ( !defined $formeme ) {
        $formeme = $node_info->{'formeme'};
    }
    
    # default values (used if the model does not tell us anything)
    my $formeme_count = 0;
    my $all_count = 0;

    # get the numbers from the model
    # (depends on the format of the model)
    if ($self->model_format eq 'tlemma_ptlemma_pos_formeme') {

	$formeme_count = $model_data->{'tlemma_ptlemma_pos_formeme'}
        ->{ $node_info->{'tlemma'} }->{ $node_info->{'ptlemma'} }->{ $node_info->{'syntpos'} }->{$formeme}
        || 0;

	$all_count = $model_data->{'tlemma_ptlemma_pos'}
        ->{ $node_info->{'tlemma'} }->{ $node_info->{'ptlemma'} }->{ $node_info->{'syntpos'} }
        || 0;
    }
    elsif ($self->model_format eq 'tlemma_ptlemma_pos_attdir_formeme') {

	$formeme_count = $model_data->{'tlemma_ptlemma_pos_attdir_formeme'}
        ->{ $node_info->{'tlemma'} }->{ $node_info->{'ptlemma'} }->{ $node_info->{'syntpos'} }->{ $node_info->{'attdir'} }->{$formeme}
        || 0;

	$all_count = $model_data->{'tlemma_ptlemma_pos_attdir'}
        ->{ $node_info->{'tlemma'} }->{ $node_info->{'ptlemma'} }->{ $node_info->{'syntpos'} }->{ $node_info->{'attdir'} }
        || 0;
    }
    elsif ($self->model_format eq 'tlemma_ptlemma_syntpos_enformeme_formeme') {

	$formeme_count = $model_data->{'tlemma_ptlemma_syntpos_enformeme_formeme'}
        ->{ $node_info->{'tlemma'} }->{ $node_info->{'ptlemma'} }->{ $node_info->{'syntpos'} }->{ $node_info->{'enformeme'} }->{$formeme}
        || 0;

	$all_count = $model_data->{'tlemma_ptlemma_syntpos_enformeme'}
        ->{ $node_info->{'tlemma'} }->{ $node_info->{'ptlemma'} }->{ $node_info->{'syntpos'} }->{ $node_info->{'enformeme'} }
        || 0;
    }

    my $score = ( $formeme_count + 1 ) / ( $all_count + 2 );

    return $score;
}

# find highest scoring formeme
# (assumes that the upper threshold is > 0.5
# and therefore it is not necessary to handle cases
# where there are two top scoring formemes --
# a random one is chosen in such case)
sub get_best_formeme {
    my ( $self, $node_info ) = @_;

    my @candidates = ();
    if ($self->model_format eq 'tlemma_ptlemma_pos_formeme') {
	@candidates = keys %{
	    $model_data->{'tlemma_ptlemma_pos_formeme'}
            ->{ $node_info->{'tlemma'} }->{ $node_info->{'ptlemma'} }->{ $node_info->{'syntpos'} }
	    };
    }
    elsif ($self->model_format eq 'tlemma_ptlemma_pos_attdir_formeme') {
	@candidates = keys %{
	    $model_data->{'tlemma_ptlemma_pos_attdir_formeme'}
            ->{ $node_info->{'tlemma'} }->{ $node_info->{'ptlemma'} }->{ $node_info->{'syntpos'} }->{ $node_info->{'attdir'} }
	    };
    }
    elsif ($self->model_format eq 'tlemma_ptlemma_syntpos_enformeme_formeme') {
	@candidates = keys %{
	    $model_data->{'tlemma_ptlemma_syntpos_enformeme_formeme'}
            ->{ $node_info->{'tlemma'} }->{ $node_info->{'ptlemma'} }->{ $node_info->{'syntpos'} }->{ $node_info->{'enformeme'} }
	    };
    }

    my $top_score   = 0;
    my $top_formeme = '';    # returned if no usable formemes in model

    foreach my $candidate (@candidates) {
        my $score = $self->get_formeme_score( $node_info, $candidate );
        if ( $score > $top_score ) {
            $top_score   = $score;
            $top_formeme = $candidate;
        }
    }

    return ( $top_formeme, $top_score );
}

1;

__END__

=pod

=encoding utf-8

=head1 NAME

Treex::Block::T2T::CS2CS::FixInfrequentFormemes -
An attempt to replace infrequent formemes by some more frequent ones.
(A Deepfix block.)

=head1 DESCRIPTION

An attempt to replace infrequent formemes by some more frequent ones.

Each node's formeme is checked against certain conditions --
currently, we attempt to fix only formemes of syntactical nouns
that are not morphological pronouns and that have no or one preposition.
Each such formeme is scored against the C<model> -- currently this is
a +1 smoothed MLE on CzEng data; the node's formeme is conditioned by
the t-lemma of the node and the t-lemma of its effective parent.
If the score of the current formeme is below C<lower_threshold>
and the score of the best scoring alternative formeme
is above C<upper_threshold>, the change is performed.

=head1 PARAMETERS

=over

=item C<lower_threshold>

Only formemes with a score below C<lower_threshold> are fixed.
Default is 0.2.

=item C<upper_threshold>

Formemes are only changed to formemes with a score above C<upper_threshold>.
Default is 0.85.

=item C<model>

Absolute path to the model file.
Can be overridden by C<model_from_share>.

=item C<model_from_share>

Path to the model file, relative to C<share/data/models/deepfix/>.
The model file is automatically downloaded if missing locally but available online.
Overrides C<model>.
Default is undef.

=item C<orig_alignment_type>

Type of alignment between the CS t-trees.
Default is C<orig>.
The alignment must lead from this zone to the other zone.

=item C<src_alignment_type>

Type of alignment between the cs_Tfix t-tree and the en t-tree.
Default is C<src>.
The alignemt must lead from cs_Tfix to en.

=item C<log_to_console>

Set to C<1> to log details about the changes performed, using C<log_info()>.
Default is C<0>.

=back

=head1 AUTHORS

Rudolf Rosa <rosa@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2012 by Institute of Formal and Applied Linguistics, Charles
University in Prague

This module is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.
