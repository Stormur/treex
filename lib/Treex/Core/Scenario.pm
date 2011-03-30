package Treex::Core::Scenario;
use Moose;
use Treex::Common;
use File::Basename;

has loaded_blocks => (
    is      => 'ro',
    isa     => 'ArrayRef[Treex::Core::Block]',
    default => sub { [] }
);

has document_reader => (
    is            => 'rw',
    does          => 'Treex::Core::DocumentReader',
    documentation => 'DocumentReader starts every scenario and reads a stream of documents.'
);

has _global_params => (
    is      => 'ro',
    isa     => 'HashRef[Str]',
    traits  => ['Hash'],
    default => sub { {} },
    handles => {
        get_global_param => 'get',
        set_global_param => 'set',

        #get_global_param_names => 'keys',
        #set_verbose       => [ set => 'verbose' ],
        #get_verbose       => [ get => 'verbose' ],
        #set_language      => [ set => 'language' ],
        #get_language      => [ get => 'language' ],
        #... ?
    },
);

my $TMT_DEBUG_MEMORY = ( defined $ENV{TMT_DEBUG_MEMORY} and $ENV{TMT_DEBUG_MEMORY} );

sub BUILD {
    my ( $self, $arg_ref ) = @_;
    log_info("Initializing an instance of TectoMT::Scenario ...");

    #<<< no perltidy
    my $scen_str = defined $arg_ref->{from_file} ? load_scenario_file($arg_ref->{from_file})
                 :                                 $arg_ref->{from_string};
    #>>>
    log_fatal 'No blocks specified for a scenario!' if !defined $scen_str;

    my @block_items = parse_scenario_string( $scen_str, $arg_ref->{from_file} );
    my $blocks = @block_items;
    log_fatal('Empty block sequence cannot be used for initializing scenario!') if $blocks == 0;

    log_info( "$blocks block" . ( $blocks > 1 ? 's' : '' ) . " to be used in the scenario:\n" );

    # loading (using modules and constructing instances) of the blocks in the sequence
    foreach my $block_item (@block_items) {
        my $block_name = $block_item->{block_name};
        eval "use $block_name; 1;" or log_fatal "Can't use block $block_name !\n$@\n";
    }

    my $i = 0;
    foreach my $block_item (@block_items) {
        $i++;
        my $params = '';
        if ( $block_item->{block_parameters} ) {
            $params = join ' ', @{ $block_item->{block_parameters} };
        }
        log_info("Loading block $block_item->{block_name} ($i/$blocks) $params...");
        my $new_block = $self->_load_block($block_item);

        if ( $new_block->does('Treex::Core::DocumentReader') ) {
            log_fatal("Only one DocumentReader per scenario is permitted ($block_item->{block_name})")
                if $self->document_reader();
            $self->set_document_reader($new_block);
        }
        else {
            push @{ $self->loaded_blocks }, $new_block;
        }
    }

    log_info('');
    log_info('   ALL BLOCKS SUCCESSFULLY LOADED.');
    log_info('');
    return;
}

sub load_scenario_file {
    my ($scenario_filename) = @_;
    log_info "Loading scenario description $scenario_filename";
    open my $SCEN, '<:utf8', $scenario_filename or
        log_fatal "Can't open scenario file $scenario_filename";

    my $scenario_string = do {
        local $/ = undef;
        <$SCEN>;
    };
    $scenario_string =~ s/\n/\n /g;

    #my $scenario_string = join ' ', <$SCEN>; <- puvodni kod, nacetl cely soubor a na zacatek kazdeho krome prvniho radku pridal mezeru. Novy dela to same, jen to je snad videt z kodu
    close $SCEN;
    return $scenario_string;
}

sub _escape {
    my $string = shift;
    $string =~ s/ /%20/g;
    $string =~ s/#/%23/g;
    return $string;
}

sub parse_scenario_string {
    my ( $scenario_string, $from_file ) = @_;

    # Preserve escaped quotes
    $scenario_string =~ s{\\"}{%22}g;
    $scenario_string =~ s{\\'}{%27}g;

    # Preserve spaces inside quotes and backticks in block parameters
    # Quotes are deleted, whereas backticks are preserved.
    $scenario_string =~ s/="([^"]*)"/'='._escape($1)/eg;
    $scenario_string =~ s/='([^']*)'/'='._escape($1)/eg;
    $scenario_string =~ s/(=`[^`]*`)/_escape($1)/eg;

    $scenario_string =~ s/#.*\n//g;    # delete comments ended by a newline
    $scenario_string =~ s/#.+$//;      # and a comment on the last line
    $scenario_string =~ s/\s+/ /g;
    $scenario_string =~ s/^ //g;
    $scenario_string =~ s/ $//g;

    my @tokens = split / /, $scenario_string;
    my @block_items;
    foreach my $token (@tokens) {

        # include of another scenario file
        if ( $token =~ /\.scen/ ) {
            my $scenario_filename = $token;
            $scenario_filename =~ s/\$\{?TMT_ROOT\}?/$ENV{TMT_ROOT}/;

            my $included_scen_path;
            if ( $scenario_filename =~ m|^/| ) {    # absolute path
                $included_scen_path = $scenario_filename
            }
            elsif ( defined $from_file ) {          # relative to the "parent" scenario file
                $included_scen_path = dirname($from_file) . "/$scenario_filename";
            }
            else {                                  # relative to the cwd
                $included_scen_path = "./$scenario_filename";
            }

            my $included_scen_str = load_scenario_file($included_scen_path);
            push @block_items, parse_scenario_string( $included_scen_str, $included_scen_path );
        }

        # parameter definition
        elsif ( $token =~ /(\S+)=(\S+)/ ) {

            # "de-escape"
            $token =~ s/%20/ /g;
            $token =~ s/%23/#/g;
            $token =~ s/%22/"/g;
            $token =~ s/%27/'/g;

            if ( not @block_items ) {
                log_fatal "Specification of block arguments before the first block name: $token\n";
            }
            push @{ $block_items[-1]->{block_parameters} }, $token;
        }

        # block definition
        else {
            my $block_filename = $token;
            $block_filename =~ s/::/\//g;
            $block_filename .= '.pm';
            if ( -e $ENV{TMT_ROOT} . "/treex/lib/Treex/Block/$block_filename" ) {    # new Treex blocks
                $token = "Treex::Block::$token";
            }
            elsif ( -e $ENV{TMT_ROOT} . "/libs/blocks/$block_filename" ) {           # old TectoMT blocks
            }
            else {

                # TODO allow user-made blocks not-starting with Treex::Block?
                log_fatal("Block $token (file $block_filename) does not exist!");
            }
            push @block_items, { 'block_name' => $token, 'block_parameters' => [] };
        }
    }

    return @block_items;
}

# reverse of parse_scenario_string, used in tools/tests/auto_diagnose.pl
sub construct_scenario_string {
    my ( $block_items, $multiline ) = @_;
    return join(
        $multiline ? "\n" : ' ',
        map {
            $_->{block_name} . " " . join( " ", @{ $_->{block_parameters} } )
            } @$block_items
    );
}

sub _load_block {
    my ( $self, $block_item ) = @_;
    my $block_name = $block_item->{block_name};
    my $new_block;

    # Initialize with global (scenario) parameters
    my %params = ( %{ $self->_global_params }, scenario => $self );

    # which can be overriden by (local) block parameters.
    foreach ( @{ $block_item->{block_parameters} } ) {
        my ( $name, $value ) = split /=/;
        $params{$name} = $value;
    }

    my $string_to_eval = '$new_block = ' . $block_name . '->new(\%params);1';
    eval $string_to_eval or log_fatal "Treex::Core::Scenario->new: error when initializing block $block_name by evaluating '$string_to_eval'\n";

    return $new_block;
}

sub run {
    my ($self) = @_;
    my $reader              = $self->document_reader or log_fatal('No DocumentReader supplied');
    my $number_of_blocks    = @{ $self->loaded_blocks };
    my $number_of_documents = $reader->number_of_documents_per_this_job() || '?';
    my $document_number     = 0;

    while ( my $document = $reader->next_document_for_this_job() ) {
        $document_number++;
        my $doc_name = $document->full_filename;
        my $doc_from = $document->loaded_from;
        log_info "Document $document_number/$number_of_documents $doc_name loaded from $doc_from";
        my $block_number = 0;
        foreach my $block ( @{ $self->loaded_blocks } ) {
            $block_number++;
            log_info "Applying block $block_number/$number_of_blocks " . ref($block);
            $block->process_document($document);
        }
    }
    log_info "Processed $document_number document"
        . ( $document_number == 1 ? '' : 's' );
    return 1;
}

use Module::Reload;

sub reset {
    my ($self) = @_;
    my $changed_modules = Module::Reload->check;
    log_info "Number of reloaded modules = $changed_modules";
    log_info "reseting the document reader\n";
    $self->document_reader->reset();

    # TODO rebuild the reloaded blocks
    return;
}

1;

__END__


=for Pod::Coverage BUILD

=head1 NAME

Treex::Core::Scenario

=head1 SYNOPSIS

 use Treex::Core::Scenario;
 ??? ??? ??? ???



=head1 DESCRIPTION


?? ?? ?? ?? ?? ???? ?? ???? ?? ???? ?? ?? needs to be updated


=head1 METHODS

=head2 Constructor

=over 4

=item my $scenario = Treex::Core::Scenario->new(scen => 'W2A::Tokenize language=en  W2A::Lemmatize' );

Constructor parameter 'scen' specifies
the names of blocks which are to be executed (in the specified order)
when the scenario is applied on a Treex::Core::Document object.

=back


=head2 Running the scenario

=over 4

=item $scenario->apply_on_stream($stream);

It applies the blocks on a stream of treex documents.

=back

=head2 Rather internal methods for loading scenarios

=over 4

=item construct_scenario_string

=item load_scenario_file

=item parse_scenario_string

=back


=head1 SEE ALSO

L<TectoMT::Node|TectoMT::Node>,
L<TectoMT::Bundle|TectoMT::Bundle>,
L<Treex::Core::Document|Treex::Core::Document>,
L<TectoMT::Block|TectoMT::Block>,


=head1 AUTHORS

Zdenek Zabokrtsky <zabokrtsky@ufal.mff.cuni.cz>
Martin Popel <popel@ufal.mff.cuni.cz>

=head1 COPYRIGHT

Copyright 2006-2010 Zdenek Zabokrtsky, Martin Popel.
This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README

