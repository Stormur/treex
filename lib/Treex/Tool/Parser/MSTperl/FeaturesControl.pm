package Treex::Tool::Parser::MSTperl::FeaturesControl;

use Moose;
use autodie;
use Carp;

has 'config_file' => (
    is       => 'ro',
    isa      => 'Str',
    required => '1',
);

# training mode or parsing mode
has 'training' => (
    is      => 'ro',
    isa     => 'Bool',
    default => '0',
);

# (default is parsing mode)

# CONFIGURATION

# has 'ord_field_index' => (
#     is => 'rw',
#     isa => 'Int',
# );

has 'parent_ord' => (
    is      => 'rw',
    isa     => 'Str',
    trigger => \&_parent_ord_set,
);

# sets parent_ord_field_index
sub _parent_ord_set {
    my ( $self, $parent_ord ) = @_;

    # set index of parent's ord field
    my $parent_ord_index = $self->field_name2index($parent_ord);
    $self->parent_ord_field_index($parent_ord_index);

    return;    # only technical
}

has 'parent_ord_field_index' => (
    is  => 'rw',
    isa => 'Int',
);

has 'root_field_values' => (
    is      => 'rw',
    isa     => 'ArrayRef[Str]',
    default => sub { [] },
    trigger => \&_root_field_values_set,
);

# checks number of root field values
sub _root_field_values_set {
    my ($self) = @_;

    # check number of fields
    my $root_fields_count = scalar( @{ $self->root_field_values } );
    if ( $root_fields_count != $self->field_names_count ) {
        croak "MSTperl config file error: " .
            "Incorrect number of root field values ($root_fields_count), " .
            "must be same as number of field names (" .
            $self->field_names_count . ")!";
    }

    return;    # only technical
}

has 'number_of_iterations' => (
    isa     => 'Int',
    is      => 'rw',
    default => 10,
);

has 'use_edge_features_cache' => (
    is      => 'rw',
    isa     => 'Bool',
    default => '0',
);

# using cache turned off to fit into RAM by default
# turn on if training with a lot of RAM or on small training data
# turned off when parsing (does not make any sense for parsing)

has 'distance_buckets' => (
    is      => 'rw',
    isa     => 'ArrayRef[Int]',
    default => sub { [] },
    trigger => \&_distance_buckets_set,
);

# sets distance2bucket, maxBucket and minBucket
sub _distance_buckets_set {
    my ( $self, $distance_buckets ) = @_;

    my %distance2bucket;

    # find maximal bucket & partly fill %distance2bucket
    my $maxBucket = 0;
    foreach my $bucket ( @{$distance_buckets} ) {
        if ( $distance2bucket{$bucket} ) {
            warn "Bucket '$bucket' is defined more than once; " .
                "disregarding its later definitions.\n";
        } elsif ( $bucket <= 0 ) {
            croak "MSTperl config file error: " .
                "Error on bucket '$bucket' - " .
                "buckets must be positive integers.";
        } else {
            $distance2bucket{$bucket} = $bucket;
            $distance2bucket{ -$bucket } = -$bucket;
            if ( $bucket > $maxBucket ) {
                $maxBucket = $bucket;
            }
        }
    }

    # set maxBucket and minBucket
    my $minBucket = -$maxBucket;
    $self->maxBucket($maxBucket);
    $self->minBucket($minBucket);

    # fill %distance2bucket from minBucket to maxBucket
    if ( !$distance2bucket{1} ) {
        warn "Bucket '1' is not defined, which does not make any sense; " .
            "adding definition of bucket '1'.\n";
        $distance2bucket{1}  = 1;
        $distance2bucket{-1} = -1;
    }
    my $lastBucket = 1;
    for ( my $distance = 2; $distance < $maxBucket; $distance++ ) {
        if ( $distance2bucket{$distance} ) {

            # the distance defines a bucket
            $lastBucket = $distance2bucket{$distance};
        } else {

            # the distance falls into the highest lower bucket
            $distance2bucket{$distance} = $lastBucket;
            $distance2bucket{ -$distance } = -$lastBucket;
        }
    }
    $self->distance2bucket( \%distance2bucket );

    return;    # only technical
}

has 'distance2bucket' => (
    is      => 'rw',
    isa     => 'HashRef[Int]',
    default => sub { {} },
);

# if mapping is not found in the hash, maxBucket or minBucket is used

has 'maxBucket' => (
    isa     => 'Int',
    is      => 'rw',
    default => '9',
);

# any higher distance falls into this bucket

has 'minBucket' => (
    isa     => 'Int',
    is      => 'rw',
    default => '-9',
);

# any lower distance falls into this bucket, distance is signed (ORD minus ord)

# FIELDS

# field names (for conversion of field index to field name)
has 'field_names' => (
    is      => 'rw',
    isa     => 'ArrayRef[Str]',
    default => sub { [] },
    trigger => \&_field_names_set,
);

# checks field_names, sets field_names_hash and field_indexes
sub _field_names_set {
    my ( $self, $field_names ) = @_;

    my %field_names_hash;
    my %field_indexes;
    for ( my $index = 0; $index < scalar( @{$field_names} ); $index++ ) {
        my $field_name = $field_names->[$index];
        if ( $field_names_hash{$field_name} ) {
            croak "MSTperl config file error: " .
                "Duplicate field name '$field_name'!";
        } elsif ( $field_name ne lc($field_name) ) {
            croak "MSTperl config file error: " .
                "Field name '$field_name' is not lowercase!";
        } elsif ( !$field_name =~ /a-z/ ) {
            croak "MSTperl config file error: " .
                "Field name '$field_name' does not contain " .
                "any character from [a-z]!";
        } else {
            $field_names_hash{$field_name} = 1;
            $field_indexes{$field_name}    = $index;
        }
    }
    $self->field_names_count( scalar( @{$field_names} ) );
    $self->field_names_hash( \%field_names_hash );
    $self->field_indexes( \%field_indexes );

    return;    # only technical
}

has 'field_names_count' => (
    is      => 'rw',
    isa     => 'Int',
    default => '0',
);

# 1 for each field name to easily check if a field name exists
has 'field_names_hash' => (
    is      => 'rw',
    isa     => 'HashRef[Str]',
    default => sub { {} },
);

# index of each field name in field_names
# (for conversion of field name to field index)
has 'field_indexes' => (
    is      => 'rw',
    isa     => 'HashRef[Str]',
    default => sub { {} },
);

# FEATURES

has 'feature_count' => (
    is  => 'rw',
    isa => 'Int',
);

has 'feature_codes' => (
    is      => 'rw',
    isa     => 'ArrayRef[Str]',
    default => sub { [] },
);

has 'feature_codes_hash' => (
    is      => 'rw',
    isa     => 'HashRef[Str]',
    default => sub { {} },
);

has 'feature_indexes' => (
    is      => 'rw',
    isa     => 'HashRef[Str]',
    default => sub { {} },
);

# for each feature contains (a reference to) an array
# which cointains all its subfeature indexes
has 'feature_simple_features_indexes' => (
    is      => 'rw',
    isa     => 'ArrayRef[ArrayRef[Int]]',
    default => sub { [] },
);

# features containing array simple features
has 'array_features' => (
    is      => 'rw',
    isa     => 'HashRef[Int]',
    default => sub { {} },
);

# SIMPLE FEATURES

has 'simple_feature_count' => (
    is  => 'rw',
    isa => 'Int',
);

has 'simple_feature_codes' => (
    is      => 'rw',
    isa     => 'ArrayRef[Str]',
    default => sub { [] },
);

has 'simple_feature_codes_hash' => (
    is      => 'rw',
    isa     => 'HashRef[Str]',
    default => sub { {} },
);

has 'simple_feature_indexes' => (
    is      => 'rw',
    isa     => 'HashRef[Str]',
    default => sub { {} },
);

has 'simple_feature_subs' => (
    is      => 'rw',
    isa     => 'ArrayRef',
    default => sub { [] },
);

has 'simple_feature_field_indexes' => (
    is      => 'rw',
    isa     => 'ArrayRef',
    default => sub { [] },
);

# simple features that return an array of values
has 'array_simple_features' => (
    is      => 'rw',
    isa     => 'HashRef[Int]',
    default => sub { {} },
);

# # simple features that get more than 1 argument as input
# has 'multiarg_simple_features' => (
#     is => 'rw',
#     isa => 'HashRef[Int]',
#     default => sub { {} },
# );

# CACHING

has 'edge_features_cache' => (
    is      => 'rw',
    isa     => 'HashRef[ArrayRef[Str]]',
    default => sub { {} },
);

sub BUILD {
    my ($self) = @_;

    print "Processing config file " . $self->config_file . "...\n";
    use YAML::Tiny;
    my $config = YAML::Tiny->new;
    $config = YAML::Tiny->read( $self->config_file );

    if ($config) {

        # required settings
        my @required_fields = (
            'field_names',
            'root_field_values',
            'parent_ord',
            'distance_buckets',
        );
        foreach my $field (@required_fields) {
            if ( $config->[0]->{$field} ) {
                $self->$field( $config->[0]->{$field} );
            } else {
                croak "MSTperl config file error: Field $field must be set!";
            }
        }

        # optional settings
        my @non_required_fields = (
            'use_edge_features_cache',
            'number_of_iterations',
        );
        foreach my $field (@non_required_fields) {
            if ( $config->[0]->{$field} ) {
                $self->$field( $config->[0]->{$field} );
            }
        }

        # features
        if ( !@{ $config->[0]->{features} } ) {
            croak "MSTperl config file error: Features must be set!";
        }
        foreach my $feature ( @{ $config->[0]->{features} } ) {
            $self->set_feature($feature);
        }
    } else {
        croak "MSTperl config file error: " . YAML::Tiny->errstr;
    }

    # ignore some settings if in parsing-only mode
    if ( !$self->training ) {
        $self->use_edge_features_cache(0);
    }

    $self->feature_count( scalar( @{ $self->feature_codes } ) );
    $self->simple_feature_count( scalar( @{ $self->simple_feature_codes } ) );

    print "Done." . "\n";

    return;    # only technical
}

sub set_feature {
    my ( $self, $feature_code ) = @_;

    if ( $self->feature_codes_hash->{$feature_code} ) {
        warn "Feature '$feature_code' is defined more than once; " .
            "disregarding its later definitions.\n";
    } else {

        # get simple features
        my $isArrayFeature = 0;
        my @simple_features_indexes;
        my %simple_features_hash;
        foreach my $simple_feature_code ( split( /\|/, $feature_code ) ) {

            # checks
            if ( $simple_features_hash{$simple_feature_code} ) {
                warn "Simple feature '$simple_feature_code' " .
                    "is used more than once in '$feature_code'; " .
                    "disregarding its later uses.\n";
                next;
            }
            if ( !$self->simple_feature_codes_hash->{$simple_feature_code} ) {

                # this simple feature has not been used at all yet
                $self->set_simple_feature($simple_feature_code);
            }

            # save
            my $simple_feature_index =
                $self->simple_feature_indexes->{$simple_feature_code};
            $simple_features_hash{$simple_feature_code} = 1;
            if ( $self->array_simple_features->{$simple_feature_index} ) {
                $isArrayFeature = 1;
            }
            push @simple_features_indexes, $simple_feature_index;
        }

        # save
        my $feature_index = scalar( @{ $self->feature_codes } );
        $self->feature_codes_hash->{$feature_code} = 1;
        $self->feature_indexes->{$feature_code}    = $feature_index;
        push @{ $self->feature_codes }, $feature_code;
        push @{ $self->feature_simple_features_indexes },
            [@simple_features_indexes];
        if ($isArrayFeature) {
            $self->array_features->{$feature_index} = 1;
        }
    }

    return 1;
}

sub set_simple_feature {
    my ( $self, $simple_feature_code ) = @_;

    # get sub reference and field index
    my $simple_feature_index = scalar @{ $self->simple_feature_codes };
    my $simple_feature_sub;
    my $simple_feature_field;

    # simple parent/child feature
    if ( $simple_feature_code =~ /^([a-zA-Z0-9_]+)$/ ) {

        # child feature
        if ( $simple_feature_code =~ /^([a-z0-9_]+)$/ ) {
            $simple_feature_sub   = \&{feature_child};
            $simple_feature_field = $1;

            # parent feature
        } elsif ( $simple_feature_code =~ /^([A-Z0-9_]+)$/ ) {
            $simple_feature_sub   = \&{feature_parent};
            $simple_feature_field = lc($1);
        } else {
            croak "Incorrect simple feature format '$simple_feature_code'. " .
                "Use lowercase (" . lc($simple_feature_code) .
                ") for child node and UPPERCASE (" . uc($simple_feature_code) .
                ") for parent node.";
        }

        # first/second node feature
    } elsif ( $simple_feature_code =~ /^([12])\.([a-z0-9_]+)$/ ) {

        $simple_feature_field = $2;

        # first node feature
        if ( $1 eq '1' ) {
            $simple_feature_sub = \&{feature_first};

            # second node feature
        } elsif ( $1 eq '2' ) {
            $simple_feature_sub = \&{feature_second};
        } else {
            croak "Assertion failed!";
        }

        # function feature
    } elsif ( $simple_feature_code =~ /^([12\.a-z]+|[A-Z]+)\([a-z0-9_,]+\)$/ ) {
        my $function_name = $1;
        $simple_feature_sub =
            $self->get_simple_feature_sub_reference($function_name);

        # array function?
        if ( $function_name eq 'between' || $function_name eq 'foreach' ) {
            $self->array_simple_features->{$simple_feature_index} = 1;
        }

        # one-arg function feature
        if ( $simple_feature_code =~ /\(([a-z0-9_]+)\)$/ ) {
            $simple_feature_field = $1;

            # two-arg function feature
        } elsif ( $simple_feature_code =~ /\(([a-z0-9_]+),([a-z0-9_]+)\)$/ ) {
            my $simple_feature_field_1 = $1;
            my $simple_feature_field_2 = $2;
            $simple_feature_field =
                [ $simple_feature_field_1, $simple_feature_field_2 ];

        } else {
            croak "Incorrect simple function feature format " .
                "'$simple_feature_code'. " .
                "Only one or two arguments can be used.";
        }
    } else {
        croak "Incorrect simple feature format '$simple_feature_code'.";
    }
    my $simple_feature_field_index =
        $self->field_name2index($simple_feature_field);

    # save
    $self->simple_feature_codes_hash->{$simple_feature_code} = 1;
    $self->simple_feature_indexes->{$simple_feature_code} =
        $simple_feature_index;
    push @{ $self->simple_feature_codes },         $simple_feature_code;
    push @{ $self->simple_feature_subs },          $simple_feature_sub;
    push @{ $self->simple_feature_field_indexes }, $simple_feature_field_index;

    return 1;
}

sub field_name2index {
    my ( $self, $field_name ) = @_;

    if ( ref $field_name eq 'ARRAY' ) {

        # multiarg feature
        my @return;
        foreach my $field ( @{$field_name} ) {
            push @return, $self->field_name2index($field);
        }
        return [@return];
    } else {
        if ( $self->field_names_hash->{$field_name} ) {
            return $self->field_indexes->{$field_name};
        } else {
            croak "Unknown field '$field_name', quiting.";
        }
    }
}

# FEATURES COMPUTATION

sub get_all_features {
    my ( $self, $edge ) = @_;

    # try to get featres from cache
    my $edge_signature;
    if ( $self->use_edge_features_cache ) {
        $edge_signature = $edge->signature();

        my $cache_features = $self->edge_features_cache->{$edge_signature};
        if ($cache_features) {
            return $cache_features;
        }
    }

    # double else: if cache not used or if edge features not found in cache
    my $simple_feature_values = $self->get_simple_feature_values_array($edge);
    my @features;
    my $features_count = $self->feature_count;
    for (
        my $feature_index = 0;
        $feature_index < $features_count;
        $feature_index++
        )
    {
        my $feature_value =
            $self->get_feature_value( $feature_index, $simple_feature_values );
        if ( $self->array_features->{$feature_index} ) {

            #it is an array feature, the returned value is an array reference
            foreach my $value ( @{$feature_value} ) {
                push @features, "$feature_index:$value";
            }
        } else {

            #it is not an array feature, the returned value is a string
            if ( $feature_value ne '' ) {
                push @features, "$feature_index:$feature_value";
            }
        }
    }

    # save result in cache
    if ( $self->use_edge_features_cache ) {
        $self->edge_features_cache->{$edge_signature} = \@features;
    }

    return \@features;
}

sub get_feature_value {
    my ( $self, $feature_index, $simple_feature_values ) = @_;

    my $simple_features_indexes =
        $self->feature_simple_features_indexes->[$feature_index];

    if ( $self->array_features->{$feature_index} ) {
        my $feature_value =
            $self->get_array_feature_value(
            $simple_features_indexes,
            $simple_feature_values, 0
            );
        if ($feature_value) {
            return $feature_value;
        } else {
            return [];
        }
    } else {
        my @values;
        foreach my $simple_feature_index ( @{$simple_features_indexes} ) {
            my $value = $simple_feature_values->[$simple_feature_index];
            if ( $value ne '' ) {
                push @values, $value;
            } else {
                return '';
            }
        }

        my $feature_value = join '|', @values;
        return $feature_value;
    }
}

# for features containing subfeatures that return an array of values
sub get_array_feature_value {
    my (
        $self,
        $simple_features_indexes,
        $simple_feature_values,
        $start_from
    ) = @_;

    # get value at this position (position = $start_from)
    my $simple_feature_index = $simple_features_indexes->[$start_from];
    my $value                = $simple_feature_values->[$simple_feature_index];
    if ( !$self->array_simple_features->{$simple_feature_index} ) {

        # if not an array reference
        $value = [ ($value) ];    # make it an array reference
    }

    my $simple_features_count = scalar @{$simple_features_indexes};
    if ( $start_from < $simple_features_count - 1 ) {

        # not the last simple feature => have to recurse
        my $append =
            $self->get_array_feature_value(
            $simple_features_indexes,
            $simple_feature_values, $start_from + 1
            );
        my @values;
        foreach my $my_value ( @{$value} ) {
            foreach my $append_value ( @{$append} ) {
                my $add_value = "$my_value|$append_value";
                push @values, $add_value;
            }
        }
        return [@values];
    } else {    # else bottom of recursion
        return $value;
    }
}

# SIMPLE FEATURES

sub get_simple_feature_values_array {
    my ( $self, $edge ) = @_;

    my @simple_feature_values;
    my $simple_feature_count = $self->simple_feature_count;
    for (
        my $simple_feature_index = 0;
        $simple_feature_index < $simple_feature_count;
        $simple_feature_index++
        )
    {
        my $sub = $self->simple_feature_subs->[$simple_feature_index];

        # if the simple feature takes more than one argment,
        # then $field_index is an array reference
        my $field_index =
            $self->simple_feature_field_indexes->[$simple_feature_index];
        my $value = &$sub( $self, $edge, $field_index );
        push @simple_feature_values, $value;
    }

    return [@simple_feature_values];
}

my %simple_feature_sub_references = (
    'distance'    => \&{feature_distance},
    'preceding'   => \&{feature_preceding_child},
    'PRECEDING'   => \&{feature_preceding_parent},
    '1.preceding' => \&{feature_preceding_first},
    '2.preceding' => \&{feature_preceding_second},
    'following'   => \&{feature_following_child},
    'FOLLOWING'   => \&{feature_following_parent},
    '1.following' => \&{feature_following_first},
    '2.following' => \&{feature_following_second},
    'between'     => \&{feature_between},
    'foreach'     => \&{feature_foreach},
    'equals'      => \&{feature_equals},
    'equalspc'    => \&{feature_equalspc},
);

sub get_simple_feature_sub_reference {
    my ( $self, $simple_feature_function ) = @_;

    if ( $simple_feature_sub_references{$simple_feature_function} ) {
        return $simple_feature_sub_references{$simple_feature_function};
    } else {
        croak "Unknown feature function '$simple_feature_function'!";
    }
}

sub feature_distance {
    my ( $self, $edge, $field_index ) = @_;

    my $distance =
        $edge->parent->fields->[$field_index]
        - $edge->child->fields->[$field_index];

    my $bucket = $self->distance2bucket->{$distance};
    if ($bucket) {
        return $bucket;
    } else {
        if ( $distance <= $self->minBucket ) {
            return $self->minBucket;
        } else {    # $distance >= $self->maxBucket
            return $self->maxBucket;
        }
    }
}

sub feature_child {
    my ( $self, $edge, $field_index ) = @_;
    return ( $edge->child->fields->[$field_index] );
}

sub feature_parent {
    my ( $self, $edge, $field_index ) = @_;
    return ( $edge->parent->fields->[$field_index] );
}

sub feature_first {
    my ( $self, $edge, $field_index ) = @_;
    return ( $edge->first->fields->[$field_index] );
}

sub feature_second {
    my ( $self, $edge, $field_index ) = @_;
    return ( $edge->second->fields->[$field_index] );
}

sub feature_preceding_child {
    my ( $self, $edge, $field_index ) = @_;

    my $node = $edge->sentence->getNodeByOrd( $edge->child->ord - 1 );

    # $node may be undef
    if ($node) {
        if ( $edge->parent->ord == $node->ord ) {

            # no gap between nodes
            return '#mid#';
        } else {
            return $node->fields->[$field_index];
        }
    } else {
        return '#start#';
    }
}

sub feature_preceding_parent {
    my ( $self, $edge, $field_index ) = @_;

    my $node = $edge->sentence->getNodeByOrd( $edge->parent->ord - 1 );

    # $node may be undef
    if ($node) {
        if ( $edge->child->ord == $node->ord ) {

            # no gap between nodes
            return '#mid#';
        } else {
            return $node->fields->[$field_index];
        }
    } else {
        return '#start#';
    }
}

sub feature_following_child {
    my ( $self, $edge, $field_index ) = @_;

    my $node = $edge->sentence->getNodeByOrd( $edge->child->ord + 1 );

    # $node may be undef
    if ($node) {
        if ( $edge->parent->ord == $node->ord ) {

            # no gap between nodes
            return '#mid#';
        } else {
            return $node->fields->[$field_index];
        }
    } else {
        return '#end#';
    }
}

sub feature_following_parent {
    my ( $self, $edge, $field_index ) = @_;

    my $node = $edge->sentence->getNodeByOrd( $edge->parent->ord + 1 );

    # $node may be undef
    if ($node) {
        if ( $edge->child->ord == $node->ord ) {

            # no gap between nodes
            return '#mid#';
        } else {
            return $node->fields->[$field_index];
        }
    } else {
        return '#end#';
    }
}

sub feature_preceding_first {
    my ( $self, $edge, $field_index ) = @_;

    my $node = $edge->sentence->getNodeByOrd( $edge->first->ord - 1 );

    # $node may be undef
    if ($node) {
        return $node->fields->[$field_index];
    } else {
        return '#start#';
    }
}

sub feature_preceding_second {
    my ( $self, $edge, $field_index ) = @_;

    my $node = $edge->sentence->getNodeByOrd( $edge->second->ord - 1 );

    # $node may be undef
    if ($node) {
        if ( $edge->first->ord == $node->ord ) {

            # node preceding second node is first node
            return '#mid#';
        } else {
            return $node->fields->[$field_index];
        }
    } else {
        return '#start#';
    }
}

sub feature_following_first {
    my ( $self, $edge, $field_index ) = @_;

    my $node = $edge->sentence->getNodeByOrd( $edge->first->ord + 1 );

    # $node may be undef
    if ($node) {
        if ( $edge->second->ord == $node->ord ) {

            # node following first node is second node
            return '#mid#';
        } else {
            return $node->fields->[$field_index];
        }
    } else {
        return '#end#';
    }
}

sub feature_following_second {
    my ( $self, $edge, $field_index ) = @_;

    my $node = $edge->sentence->getNodeByOrd( $edge->second->ord + 1 );

    # $node may be undef
    if ($node) {
        return $node->fields->[$field_index];
    } else {
        return '#end#';
    }
}

sub feature_between {
    my ( $self, $edge, $field_index ) = @_;

    my @values;
    my $from;
    my $to;
    if ( $edge->parent->ord < $edge->child->ord ) {
        $from = $edge->parent->ord + 1;
        $to   = $edge->child->ord - 1;
    } else {
        $from = $edge->child->ord + 1;
        $to   = $edge->parent->ord - 1;
    }
    for ( my $ord = $from; $ord <= $to; $ord++ ) {
        push @values,
            $edge->sentence->getNodeByOrd($ord)->fields->[$field_index];
    }

    return [@values];
}

sub feature_foreach {
    my ( $self, $edge, $field_index ) = @_;

    my $values = $edge->child->fields->[$field_index];
    if ($values) {
        my @values = split / /, $edge->child->fields->[$field_index];
        return [@values];
    } else {
        return '';
    }
}

sub feature_equals {
    my ( $self, $edge, $field_indexes ) = @_;

    # equals takes two arguments
    if ( @{$field_indexes} == 2 ) {
        my ( $field_index_1, $field_index_2 ) = @{$field_indexes};
        my $values_1 = $edge->child->fields->[$field_index_1];
        my $values_2 = $edge->child->fields->[$field_index_2];

        # we handle undefines and empties specially
        if (
            defined $values_1
            && $values_1 ne ''
            && defined $values_2
            && $values_2 ne ''
            )
        {
            my $result   = 0;                      # default not equal
            my @values_1 = split / /, $values_1;
            my @values_2 = split / /, $values_2;

            # try to find a match
            foreach my $value_1 (@values_1) {
                foreach my $value_2 (@values_2) {
                    if ( $value_1 eq $value_2 ) {
                        $result = 1;               # one match is enough
                    }
                }
            }
            return $result;
        } else {
            return -1;                             # undef
        }
    } else {
        croak "equals() takes TWO arguments!!!";
    }
}

# only difference to equals is the line:
# my $values_1 = $edge->PARENT->fields->[$field_index_1];
sub feature_equalspc {
    my ( $self, $edge, $field_indexes ) = @_;

    # equals takes two arguments
    if ( @{$field_indexes} == 2 ) {
        my ( $field_index_1, $field_index_2 ) = @{$field_indexes};
        my $values_1 = $edge->parent->fields->[$field_index_1];
        my $values_2 = $edge->child->fields->[$field_index_2];

        # we handle undefines and empties specially
        if (
            defined $values_1
            && $values_1 ne ''
            && defined $values_2
            && $values_2 ne ''
            )
        {
            my $result   = 0;                      # default not equal
            my @values_1 = split / /, $values_1;
            my @values_2 = split / /, $values_2;

            # try to find a match
            foreach my $value_1 (@values_1) {
                foreach my $value_2 (@values_2) {
                    if ( $value_1 eq $value_2 ) {
                        $result = 1;               # one match is enough
                    }
                }
            }
            return $result;
        } else {
            return -1;                             # undef
        }
    } else {
        croak "equals() takes TWO arguments!!!";
    }
}

1;

__END__

=pod

=for Pod::Coverage BUILD

=encoding utf-8

=head1 NAME

Treex::Tool::Parser::MSTperl::FeaturesControl

=head1 DESCRIPTION

Controls the features used in the model.
Also handles the configuration.

=head2 Features

TODO: outdated, superceded by use of config file -> rewrite

Each feature has a form C<code:value>. The code desribes the information which
is relevant for the feature, and the value is the information retained from
the dependency edge (and possibly other parts of the sentence
(L<Treex::Tool::Parser::MSTperl::Sentence>) stored in C<sentence> field).

For example, the feature C<L|l:být|pes> means that the lemma of the parent node
(the governing word) is "být" and the lemma of its child node (the dependent
node) is "pes".

Each (proper) feature is composed of several simple features. In the
aforementioned example, the simple feature codes were C<L> and C<l> and their
values "být" and "pes", respectively. Each simple feature code is a string
(case sensitive) and its value is also a string. The simple feature codes are
joined together by the C<|> sign to form the code of the proper feature, and
similarly, the simple feature values joined by C<|> form the proper feature
value. Then, the proper feature code and value are joined together by C<:>.
(Therefore, the codes and values of the simple features must not contain the
C<|> and the C<:> signs.)

By a naming convention,
if the same simple feature can be computed for both the parent node and its
child node, their codes are the same but for the case, which is upper for the
parent and lower for the child. If this is not applicable, an uppercase
code is used.

For higher effectiveness the simple feature codes are translated to integers
(see C<simple_feature_codes>).

In reality the feature codes are translated to integers as well (see
C<feature_codes>), but this is only an internal issue. You can see these
numbers in the model file if you use the default L<Data::Dumper> format (see
C<load> and C<store>). However, if you use the tsv format (see C<load_tsv>,
C<store_tsv>), you will see the real string feature codes.

Currently the following simple features are available. Any subset of them can
be used to form a proper feature, but their order should follow their order of
appearance in this list (still, this is only a cleanliness and readability
thing, it does not affect the function of the parser in any way).

=over 4

=item Distance (D)

Distance of the two nodes in the sentence, computed as order of the parent
minus the order of the child. Eg. for the sentence "To je prima pes ." and the
feature D computed on nodes "je" and "pes" (parent and child respectively),
the order of "je" is 2 and the order of "pes" is 4, yielding the feature value
of 2 - 4 = -2. This leads to a feature C<D:-2>.

=item Form (F, f)

The form of the node, i.e. the word exactly as it appears in the sentence text.

Currently not used as it has not lead to any improvement in the parsing.

=item Lemma (L, l)

The morphological lemma of the node.

=item preceding tag (S, s)

The morphological tag (or POS tag if you like) of the node preceding (ord-wise)
the node.

=item Tag (T, t)

The morphological tag of the node.

=item following tag (U, u)

The morphological tag of the node following (ord-wise) the node.

=item between tag (B)

The morphological tag of each node between (ord-wise) the parent node and the
child node. This simple feature returns (a reference to) an array of values.

=back

Some of the simple features can return an empty string in case they are not
applicable (eg. C<U> for the last node in the sentence), then the whole
feature is not present for the edge.

Some of the simple features return an array of values (eg. the C<B> simple
feature). This can result in several instances of the feature with the same
code for one edge to appear in the result.

=head1 FIELDS

=head2 Fields

=over 4

=item field_names (ArrayRef[Str])

Field names (for conversion of field index to field name)

=item field_names_hash (HashRef[Str])

1 for each field name to easily check if a field name exists

=item field_indexes (HashRef[Str])

Index of each field name in field_names (for conversion of field name to field
index)

=back

=head2 Features

TODO: slightly outdated

The examples used here are consistent throughout this part of documentation,
i.e. if several simple features are listed in C<simple_feature_codes> and
then simple feature with index 9 is referred to in C<array_simple_features>,
it really means the C<B> simple feature which is on the 9th position in
C<simple_feature_codes>.

=over 4

=item feature_count (Int)

Alias of C<scalar @{feature_codes}> (but the integer is really
stored in the field for faster access).

=item feature_codes (ArrayRef[Str])

Codes of all features to be computed. Their
indexes in this array are used to refer to them in the code. Eg.:

 feature_codes ( [( 'L|T', 'l|t', 'L|T|l|t', 'T|B|t')] )

=item feature_codes_hash (HashRef[Str])

1 for each feature code to easily check if a feature exists

=item feature_indexes (HashRef[Str])

Index of each feature code in feature_codes (for conversion of feature code to
feature index)

=item feature_simple_features_indexes (ArrayRef[ArrayRef[Int]])

For each feature contains (a reference to) an array which contains all its
simple feature indexes (corresponding to positions in C<simple_feature_codes>
). Eg. for the 4 features (0 to 3) listed in C<feature_codes> and the 10
simple features listed in C<simple_feature_codes> (0 to 9):

 feature_simple_features_indexes ( [(
   [ (1, 5) ],
   [ (2, 6) ],
   [ (1, 5, 2, 6) ],
   [ (5, 9, 6) ],
 )] )


=item array_features (HashRef)

Indexes of features containing array simple features (see
C<array_simple_features>). Eg.:

 array_features( { 3 => 1} )

as the feature with index 3 (C<'T|B|t'>) contains the C<B> simple feature
which is an array simple feature.

=back

=head2 Simple features

=over 4

=item simple_feature_count (Int)

Alias of C<scalar @{simple_feature_codes}> (but the integer is really
stored in the field for faster access).

=item simple_feature_codes (ArrayRef[Str])

Codes of all simple features to be computed. Their order is important as their
indexes in this array are used to refer to them in the code, especially in the
C<get_simple_feature> method. Eg.:

 simple_feature_codes ( [('D', 'L', 'l', 'S', 's', 'T', 't', 'U', 'u', 'B')])

=item simple_feature_codes_hash (HashRef[Str])

1 for each simple feature code to easily check if a simple feature exists

=item simple_feature_indexes (HashRef[Str])

Index of each simple feature code in simple_feature_codes (for conversion of
simple feature code to simple feature index)

=item simple_feature_field_indexes (ArrayRef)

For each simple feature (on the corresponsing index) contains the index of the
field (in C<field_names>), which is used to compute the simple feature value
(together with a subroutine from C<simple_feature_subs>).

If the simple feature takes more than one argument (called a multiarg feature
here), then instead of a single field index there is a reference to an array
of field indexes.

=item simple_feature_subs (ArrayRef)

For faster run, the simple features are internally not represented by their
string codes, which would have to be parsed repeatedly. Instead their codes
are parsed once only (in C<set_simple_feature>) and they are represented as
an integer index of the field which is used to compute the feature (it is the
actual index of the field in the input file line, accessible through
L<Treex::Tool::Parser::MSTperl::Node/fields>) and a reference to a subroutine
(one of the C<feature_*> subs, see below) which computes the feature value
based on the field index and the edge (L<Treex::Tool::Parser::MSTperl::Edge>).
The references subroutine is then invoked in C<get_simple_feature_values_array>.

=item array_simple_features (HashRef[Int])

Indexes of simple features that return an array of values instead of a single
string value. Eg.:

 array_simple_features( { 9 => 1} )

because in the aforementioned example the C<B> simple feature returns an array
of values and has the index C<9>.


=back

=head2 Other

=over 4

=item edge_features_cache (HashRef[ArrayRef[Str])

If caching is turned on (see below), all features of any edge computed by the
C<get_feature_simple_features_indexes> method are computed once only, stored
in this cache and then retrieved when needed.

The key of the hash is the edge signature (see
L<Treex::Tool::Parser::MSTperl::Edge/signature>), the value is
(a reference to) an array of fetures and their values.

=back

=head2 Settings

The the config file (usually C<config.txt>) is in YAML format.

Some of the settings are ignored when in parsing mode (i.e. not training).
These are use_edge_features_cache (turned off) and number_of_iterations
(irrelevant).

These are settings which are acquired from the configuration file (see also
its contents, the options are also richly commented there):

=head3 Basic Settings

=over 4

=item field_names

Lowercase names of fields in the input file
(the data fields are to be separated by tabs in the input file).
Use [a-z0-9_] only, using always at least one letter.
Use unique names, i.e. devise some names even for unused fields.

=item root_field_values

Field values to set for the (technical) root node.

=item parent_ord

Name of field containing ord of the parent of the node
(also called "head" or "governing node").

=item number_of_iterations

How many times the trainer (Tagger::MSTperl::Trainer) should go through
all the training data (default is C<10>).

=item use_edge_features_cache

Turns on and off using the C<edge_features_cache>. Default is C<0>.

Using cache should be turned on (C<1>) if training with a lot of RAM or on small
training data, as it uses a lot of memory but speeds up the training greatly
(approx. by 30% to 50%). If you need to save RAM, turn it off (C<0>).

=back

=head3 Features Settings

In the C<features> field of the config file all features to be used by the model
are set. Use the input file field names to use the field of the (child) node,
uppercase them to use the field of the parent, prefix them by C<1.> or C<2.>
to use the field on the first or second node in the sentence (i.e. based on
order in sentence, regardless of which is parent and which is child).

You can also make use of several functions. Again, you can usually (i.e. when
it makes sense) write their names in lowercase to invoke them on the child
field, uppercase for parent, or prefixed by C<1.> or C<2.> for first or second
node. The argument of a function must always be a (child) field name.

=over 4

=item distance(ord_field)

Bucketed ord-wise distance of child and parent (ORD minus ord)

=item preceding(field)

Value of the specified field on the ord-wise preceding node

=item following(field)

The same for ord-wise following node

=item between(field)

Value of the specified field for each node which is ord-wise between the child
node and the parent node

=item equals(field1,field2), equalspc(field1,field2)

Returns C<1> if the values of the fields equal
(if they have multiple values, returns 1 if at least for one pair of
their values the values equal),
C<0> if they don't and C<-1> if at least one of the values is undefined.

C<equalspc> uses C<field1> of the parent node and C<field2> of the child node.

=back

Lines beginning with # are comments and are ignored. Lines that contain
only whitespace chars or are empty are ignored as well.

=head1 METHODS

=head2 Settings

The best source of information about all the possible settings is the
configuration file itself (usually called C<config.txt>), as it is richly
commented and accompanied by real examples at the same time.

=over 4

=item my $featuresControl =
Treex::Tool::Parser::MSTperl::FeaturesControl->new(config_file => 'file.config')

Reads the configuration file (in YAML format) and applies the settings.

See file C<samples/sample.config>.

=item set_feature ($feature_code)

Parses the feature code and (if no errors are encountered) creates its
representation in the fields of this package (all C<feature_>* fields and
possibly also the C<array_features> field).

=item set_simple_feature ($simple_feature_code)

Parses the simple feature code and creates its representation in the fields of
this package (all C<simple_feature_>* fields and possibly also the
C<array_simple_features> field).

=item field_name2index ($field_name)

Fields are referred to by names in the config files but by indexes in the
code. Therefore this conversion function is necessary; the other direction of
the conversion is ensured by the C<field_names> field.

=back

=head2 Computing (proper) features

=over 4

=item my $features_array_rf = $model->get_all_features($edge)

Returns (a reference to) an array which contains all features of the edge
(according to settings).

If caching is turned on, tries to look the features up in the cache before
computing them. If they are not cached yet, they are computed and stored into
the cache.

The value of a feature is computed by C<get_feature_value>. Values of simple
features are precomputed (by calling C<get_simple_feature_values_array>) and
passed to the C<get_feature_value> method.

=item my $feature_value = get_feature_value(3, $simple_feature_values)

Returns the value of the feature with the given index.

If it is an array feature (see C<array_features>), its value is (a reference
to) an array of all (string) values of the feature (a reference to an empty
array if there are no values).

If it is not an array feature, its value is composed from the simple feature
values. If some of the simple features do not have a value defined, an empty
string (C<''>) is returned.

=item my $feature_value = get_array_feature_value ($simple_features_indexes,
    $simple_feature_values, $start_from)

Recursively calls itself to compose an array of all values of the feature
(composed of the simple features given in C<$simple_features_indexes> array
reference), which is a cartesian product on all values of the simple features.
The C<$start_from> variable should be C<0> when this method is called and is
incremented in the recursive calls.

=back

=head2 Computing simple features

=over 4

=item my $simple_feature_values = get_simple_feature_values_array($edge)

Returns (a reference to) an array of values of all simple features (see
C<simple_feature_codes>). For each simple feature, its value can be found
on the position in the returned array corresponding to its position in
C<simple_feature_codes>.

=item my $sub = get_simple_feature_sub_reference ('distance')

Translates the feature funtion string name (eg. C<distance>) to its reference
(eg. C<\&feature_distance>).

=item my $value = get_simple_feature_value ($edge, 9)

Returns the value of the simple feature with the given index by calling an
appropriate C<feature_*> method on the edge
(see L<Treex::Tool::Parser::MSTperl::Edge>). If
the feature cannot be computed, an empty string (C<''>) is returned (or a
reference to an empty array for array simple features - see
C<array_simple_features>).

=item feature_distance

=item feature_child

=item feature_parent

=item feature_first

=item feature_second

=item feature_preceding_child

=item feature_preceding_parent

=item feature_following_child

=item feature_following_parent

=item feature_preceding_first

=item feature_preceding_second

=item feature_following_first

=item feature_following_second

=item feature_between

=item feature_foreach

=item feature_equals, feature_equalspc

# from config:

  equals(field1,field2) - returns 1 if the value of field1 is the same as
      the value of field2; for fields with multiple values (eg. with
      aligned nodes), it has the meaning of an "exists" operator: it returns
      1 if there is at least one pair of values of each field that are
      the same.
      returns 0 if no values match, -1 if (at least) one of the fields is
      undef (may be also represented by an empty string)

  equalspc(field1,field2) - like equals but first field is taken from parent
      and second from child

- a simple feature function equals(field_1,field_2)
with xquery-like "at least once" semantics for multiple values
(there can be multiple alignments)
with a special output value if one of the fields is unknown
(maybe it suffices to emmit an undef, as this would occur iff at least
one of the arguments is undef; but maybe not and eg. "-1" should be given)


This makes it possible to have a simple feature which behaves like this:

=over 4

=item returns 1 if the edge between child and parent is also present in the
English tree

=item returns 0 if not

=item returns -1 if cannot decide (alignment info is missing for some of the
nodes)

=back

Because if the parser has (the ord of the en child node and)
the ord of en child's parent and the ord of the en parent node
(and the ord of the en parent's parent), the feature can check whether
en_parent->ord = en_child->parentOrd

C<equalspc(en->ord, en->parent->ord)>

=back

=head1 AUTHORS

Rudolf Rosa <rosa@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by Institute of Formal and Applied Linguistics,
Charles University in Prague

This module is free software;
you can redistribute it and/or modify it under the same terms as Perl itself.
