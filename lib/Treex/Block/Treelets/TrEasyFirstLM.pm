package Treex::Block::Treelets::TrEasyFirstLM;
use Moose;
use Treex::Core::Common;
use Treex::Tool::TranslationModel::Chain;
use Treex::Tool::TranslationModel::Rule;
use Treex::Tool::TranslationModel::Segment;
use Storable;
use List::Pairwise qw(mapp);
use List::Util qw(sum);
use List::MoreUtils qw(all any none first_index);
extends 'Treex::Core::Block';

has model_dir => (
    is            => 'ro',
    isa           => 'Str',
    default       => 'data/models/translation/en2cs',
    documentation => 'Base directory for all models'
);

has model_name => (
    is      => 'ro',
    isa     => 'Str',
    default => 'chain35k.gz',
);

has tm_model => (is => 'rw');

has [qw(wL1 wF1 wL2 wF2 wL3 wF3 wL4 wTM wLogTM)] => (is=>'rw', default=>0);
has [qw(bin0 bin1 bin2 bin3 bin4 bin5)] => (is=>'rw', default=>0);
has [qw(Lg_Fd)] => (is=>'rw', default=>0);

my $MAX_RULE_SIZE = 3;     # max number of nodes in src treelet

my $WEIGHTS;

my (@s_label, @s_parent, @s_children, @t_label, @t_origin, @covered_by);


use LanguageModel::Lemma;
my $ALL = '<ALL>';
my ($cLgFdLd, $cPgFdLd);

sub _load_plsgz {
    my ($filename) = @_;
    open my $PLSGZ, '<:gzip', $filename;
    my $model = Storable::fd_retrieve($PLSGZ);
    log_fatal("Could not parse perl storable model: '$filename'.") if ( !defined $model );
    close $PLSGZ;
    return $model;
}


sub process_start {
    my ($self) = @_;
    my $model = Treex::Tool::TranslationModel::Chain->new();
    $model->load($self->model_dir.'/'.$self->model_name);
    $self->set_tm_model($model->model);
    $WEIGHTS = {
        TM => $self->wTM,
        LogTM => $self->wLogTM,
        L1 => $self->wL1,
        F1 => $self->wF1,
        L2 => $self->wL2,
        F2 => $self->wF2,
        L3 => $self->wL3,
        F3 => $self->wF3,
        bin0 => $self->bin0,
        bin1 => $self->bin1,
        bin2 => $self->bin2,
        bin3 => $self->bin3,
        bin4 => $self->bin4,
        bin5 => $self->bin5,
        Lg_Fd => $self->Lg_Fd,
    };
    
    my $dir = $ENV{TMT_ROOT}.'/share/data/models/language/cs/';
    $cLgFdLd = _load_plsgz( $dir . 'c_LgFdLd.pls.gz' );
    $cPgFdLd = _load_plsgz( $dir . 'c_PgFdLd.pls.gz' );
    LanguageModel::Lemma::init("$dir/lemma_id.pls.gz");
    return;
}

sub process_ttree {
    my ($self, $ttree) = @_;

    # Build subnode tree representation
    my @trg_nodes = $ttree->get_descendants({ordered=>1});
    my @src_nodes = map {$_->src_tnode} @trg_nodes;
    @s_label = ('_ROOT', map {escape($_)} map {($_->formeme, $_->t_lemma)} @src_nodes);
    @s_parent = (-1, map {($_->get_parent->ord*2, $_->ord*2 - 1)} @src_nodes);
    @s_children = map {[]} (0..$#s_parent);
    for my $i (1 .. $#s_parent){ push @{$s_children[$s_parent[$i]]}, $i;}

    # Translate subnodes
    @t_label = (); @t_origin = ();
    $self->translate_sentence_subnodes();

    # Convert subnodes back to t-trees
    # TODO de-escape labels
    for my $i (1 .. $#t_label){
        next if !$t_origin[$i]; #skip untranslated (left them as clone)
        my $is_formeme = $i % 2;
        my $t_node = $trg_nodes[($i-2+$is_formeme)/2];
        if ($is_formeme){
            $t_node->set_formeme($t_label[$i]);
            $t_node->set_formeme_origin($t_origin[$i]);
        } else {
            $t_node->set_t_lemma($t_label[$i]);
            $t_node->set_t_lemma_origin($t_origin[$i]);
        }
    }
    return;
}

sub escape {
    my ($string) = $_;
    return '_' if !defined $string;
    $string =~ s/ /&#32;/g;
    $string =~ s/\(/&#40;/g;
    $string =~ s/\(/&#41;/g;
    $string =~ s/=/&#61;/g;
    return $string;
}


sub translate_sentence_subnodes {
    my ($self) = @_;
    my @rules = sort {$b->{score} <=> $a->{score}} $self->retrieve_matching_rules();
    
    while (@rules){
        my $rule = shift @rules;
        $self->apply_rule($rule);
        @rules = sort {$b->{score} <=> $a->{score}} grep {is_valid($_)} @rules;
    }
    return;
}

sub apply_rule {
    my ($self, $rule) = @_;
    my @subnodes = @{$rule->{s_nodes}};
    my @labels   = @{$rule->{t_labels}};
    my $origin = $rule->{src} .' -> '. $rule->{trg} .' = '. $rule->{score};
    my @newly_translated;
    foreach my $i (0..$#subnodes){
        my $subnode = $subnodes[$i];
        
        # if already translated, just log origin
        if ($t_origin[$subnode]){
            $t_origin[$subnode] .= "\n$origin";
        }

        # otherwise, translate an untranslated subnode
        else {
            $t_label[$subnode] = $labels[$i];
            $t_origin[$subnode] = $origin;
            push @newly_translated, $subnode;
        }
    }
    #foreach my $subnode (@newly_translated){
    #    $self->update_lm($subnode);
    #}
    $self->update_lm_scores(@newly_translated);
    return;
}

sub update_lm_scores {
    my ($self, @subnodes) = @_;
    my %affected_rules = map {@{$covered_by[$_]}} @subnodes;
}

sub lm_context {
    my ($subnode) = @_;
    my $parent = $s_parent[$subnode];
}

sub update_lm {
    my ($self, $subnode) = @_;
    my $is_formeme = $subnode % 2;
    my $parent = $s_parent[$subnode];
    if (!$t_origin[$parent]){
        my @rules = grep {is_valid($_)} @{$covered_by[$parent]};
        $covered_by[$parent] = \@rules;
        if (@rules){
            #my @children = grep {$t_origin[$_]} @{$s_children[$subnode]}
            #my @ch_labels = map {$t_label[$_]} @children;
            if ($is_formeme){
                my $Fd  = $t_label[$subnode];
                my $nFd = sum map {$cPgFdLd->{$_}{$Fd}{$ALL}||0} qw(N A P C V D I T);
                
                foreach my $rule (@rules){
                    my $i = first_index {$_==$parent} @{$rule->{s_nodes}};
                    my $uLg = $rule->{t_labels}[$i];
                    $uLg =~ s/#(.)$/ $1/;
                    my $Lg = LanguageModel::Lemma->new($uLg);
                    #my $nLg = $c_LgFdLd->[$$Lg]{$ALL};
                    my $nLgFd = $cLgFdLd->[$$Lg]{$Fd}{$ALL} || 0;
                    my $pLg_Fd = $nLgFd / ($nFd || 1);
#say $Lg, "\tFd=$Fd\tnLgFd=$nLgFd\tnFd=$nFd\tp(Lg|Fd)=$pLg_Fd";
                    $rule->{features}{Lg_Fd} = $pLg_Fd;
                    $self->compute_score($rule);
                }
            }
            else {
            }
        }
    }
    return;
}

# A rule is "valid" if it is compatible with the already translated nodes
# and if it covers some untranslated nodes.
sub is_valid {
    my ($rule) = @_;
    my @subnodes = @{$rule->{s_nodes}};
    my @labels = @{$rule->{t_labels}};
    my $at_least_one_untranslated = 0;
    for my $i (0..$#subnodes){
        my $subnode = $subnodes[$i];
        if ($t_origin[$subnode]){
            return 0 if $labels[$i] ne $t_label[$subnode];
        } else {
            $at_least_one_untranslated = 1;
        }
    }
    return $at_least_one_untranslated;
}

sub retrieve_matching_rules {
    my ($self) =@_;
    my @rules;
    @covered_by = map {[]} @s_label;

    foreach my $s_i (1..$#s_label){
        my @s_side = ($s_i);
        for my $size (1 .. $MAX_RULE_SIZE){
            my $s_str = join ' ', map {$s_label[$_]} @s_side;
            my $entry = $self->tm_model->{$s_str};
            if ($entry){
                mapp {
                    my $rule = {
                        s_nodes => [@s_side],
                        src => $s_str,
                        trg => $a,
                        t_labels => [split / /, $a],
                        TM => $b,
                    };
                    $self->precompute_features($rule);
                    foreach my $s_node (@s_side){
                        push @{$covered_by[$s_node]}, $rule;
                    }
                    $self->compute_score($rule);
                    push @rules, $rule;
                } @$entry;
            }
            my $s_next_i = $s_parent[$s_side[-1]];
            last if $s_next_i == -1; # reached the root
            push @s_side, $s_next_i;
        }
    }
    return @rules;
}

sub compute_score {
    my ($self, $rule) = @_;
    my $score = 0;
    while (my ($name, $value) = each %{$rule->{features}}){
        $score += ($WEIGHTS->{$name} || 0) * $value;
    }
    $rule->{score} = $score;
    return $score;
}

sub precompute_features {
    my ($self, $rule) = @_;
    my @subnodes = map {$s_label[$_]} @{$rule->{s_nodes}};
    my $is_formeme = $subnodes[0] =~ /(.:.|^adv$|^x$)/ ? 'F' : 'L';
    my $size = @subnodes;
    my $TM = $rule->{TM};
    my $logTM = log($TM);
    my $binTM = int(-$logTM);
    
    my %features = (
        $is_formeme => 1,
        $is_formeme.$size => 1,
        TM => $TM,
        LogTM => $logTM,
        #'bin'.$binTM => 1,
    );
    $rule->{features} = \%features;
    return;
}

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::Treelets::TrEasyFirst - translate treelets greedily

=head1 DESCRIPTION

=head1 AUTHOR

Martin Popel <popel@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2013 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

=cut
