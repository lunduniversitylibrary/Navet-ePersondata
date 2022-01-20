package Navet::ePersondata;

use strict;
use warnings;

use Carp;
use SOAP::XML::Client::Generic;
use IO::Socket::SSL;
use XML::LibXML;
use Moo;

our $VERSION = '0.02';

has OrgNr => ( is => 'ro', required => 1);
has BestallningsId => (is => 'ro', required => 1);
has pkcs12_file => ( is => 'ro', required => 1);
has pkcs12_password => ( is => 'ro', required => 1);

has format => (
    is => 'ro',
    default => sub {'xml'},
    isa => sub { croak "$_[0] is not a valid format" unless $_[0] =~ m/^(?:xml|termdata)$/ } 
);
has soap_options => ( is => 'ro', default => sub {{}});
has soap => (is  => 'ro', lazy => 1, builder => 1);
has error => ( is => 'ro', clearer => 1, lazy =>1, builder =>1);

my %SOAP_DEFAULT_OPTIONS = (
    uri   => 'http://xmls.skatteverket.se/se/skatteverket/folkbokforing/na/epersondata/V1',
    xmlns => 'http://xmls.skatteverket.se/se/skatteverket/folkbokforing/na/epersondata/V1',
    strip_default_xmlns => 1,
);

sub BUILD {
    my ($self, $args) = @_;
    
    if ( my $proxy = $self->soap_options->{proxy} ) {
        if ( ($self->format eq 'xml' && $proxy !~ m/XML$/) ||
             ($self->format eq 'termdata' && $proxy =~ m/XML$/)
           ) {
            croak "Incompatible values for format and soap proxy";
        }
    }
}


sub _build_soap {
    my $self = shift;

    my %arg = %SOAP_DEFAULT_OPTIONS;
    
    my $xml = $self->format  eq 'xml' ? 'XML' : '';
    my $name = $self->_service_name;
    $arg{proxy} = "https://www2.skatteverket.se/na/na_epersondata/V3/$name$xml";

    SOAP::XML::Client::Generic->new({
        %arg,
        %{$self->soap_options},
      });  
}


sub _service_name  {
    my $self = shift;
    my $name = ref $self;
    $name =~ s/^.+:://;
    return "\l$name";
}

sub _set_ssl_env {
    my $self = shift;

    IO::Socket::SSL::set_defaults(cert_file => $self->pkcs12_file, passwd_cb => sub { $self->pkcs12_password; });
}

sub _escape_string {
    my ($self, $text) = @_;
    $text =~ s/&/&amp;/go;
    $text =~ s/</&lt;/go;
    $text =~ s/>/&gt;/go;
    $text =~ s/'/&apos;/go;
    $text =~ s/"/&quot;/go;
    return $text;
}


sub _bestallning_xml {
    my ($self) = @_;
    my $BestallningsId = $self->_escape_string($self->BestallningsId);
    my $OrgNr = $self->_escape_string($self->OrgNr);
"<Bestallning>
<OrgNr>$OrgNr</OrgNr><BestallningsId>$BestallningsId</BestallningsId>
</Bestallning>
";
}

sub _find_records {
    my ($self, $arg, $xpath) = @_;

    my $soap = $self->soap;
    $self->_set_ssl_env();
    
    $self->clear_error();
    
    if ( $soap->fetch({
        method => (ucfirst($self->_service_name) . "Request"),
        xml => ($self->_bestallning_xml . $self->_args_xml($arg)),
    }) ) {
        return $soap->results_xml->findnodes($xpath);
    }

    return; #failed     
}



sub _parse_termdata {
    my ($self, $data, $only_first) = @_;
    my @records;
    my $temp_record;
    
    
    for (split /\n/, $data) {
        my ($a, $c, $d) = split / /, $_, 3;
        next unless $a;
    
        if ($a eq '#POST_START') {
            $temp_record={};
        }
    
        if ($a eq '#UP') {
            $temp_record->{$c}=$d;
        }
    
        if ($a eq '#POST_SLUT') {
            push @records, $temp_record;
            last if $only_first
        }       
    }

    return \@records;
    
}

sub _find_records_termdata {
    my ($self, $arg, $only_first) = @_;
    
    my $response_ele = ucfirst($self->_service_name) . 'Response';
    my ($result) = $self->_find_records($arg, "//*\[local-name()='$response_ele'\]");
    return unless $result;
    return @{$self->_parse_termdata($result->to_literal, $only_first)}; #check
}



# Public Methods. --------------------------------------------------------------

sub find_all {
    my ($self, $arg) = @_;

    if ($self->format eq 'xml' ) {    
        return $self->_find_records($arg, '//Folkbokforingspost');
    }
    
    #format = termdata
    return $self->_find_records_termdata($arg);
}


sub find_first {
    my ($self, $arg) = @_;

    my $found;
    
    if ($self->format eq 'xml') {
        ($found) = $self->_find_records($arg, '//Folkbokforingspost[1]');
        return $found;
    } else {
        #format = termdata
        ($found) = $self->_find_records_termdata($arg,1);
    }
    return $found;
}


sub _build_error {
    my $self = shift;
    
    my $soap_error = $self->soap->error
        or return;

    my $http_status_line = $self->soap->status
        or return {
            message => $soap_error,
            raw_error => $soap_error,
        };
    
    my $error = { raw_error => $soap_error};
    ($error->{http_status},$error->{message}) = split / /, $http_status_line, 2;
    
    $error->{message} ||= $error->{http_status};
    
    my $edom;
    
    eval {
        $edom = XML::LibXML->load_xml(
            string => \$soap_error,
        );
    };
    
    if ($edom) {
        if (my ($fnode) = $edom->documentElement->findnodes('/S:Envelope/S:Body/S:Fault')) {
            my $faultcode = $fnode->findvalue('./faultcode'),
            my $faultstring = $fnode->findvalue('./faultstring'),
            
            my $Felkod = $fnode->findvalue("//*\[local-name()='Felkod'\]");
            my $Beskrivning = $fnode->findvalue("//*\[local-name()='Beskrivning'\]");
            
            $error->{message} = $Beskrivning || $faultstring;
            $error->{soap_faultcode} = $faultcode if $faultcode;
            $error->{soap_faultstring} = $faultstring if $faultstring;
            $error->{sv_Felkod} = $Felkod if $Felkod;
            $error->{sv_Beskrivning} = $Beskrivning if $Beskrivning;
        }
    } else {
        
    }
    return $error;
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Navet::ePersondata - Simple framework for the Navet ePersondata web services

=head1 SYNOPSIS

    use Navet::ePersondata::Personpost;

    my $ep = Navet::ePersondata::Personpost->new(    
        # Set proxy to test service instead of production 
        soap_options => {
            proxy => 'https://www2.test.skatteverket.se/na/na_epersondata/V2/personpostXML'
        },
        pkcs12_file => '/path/to/certificate.p12',
        pkcs12_password => '5085873593180405',
        OrgNr => '162021004748',
        BestallningsId => '00000079-FO01-0001',
    );

    my $node = $ep->find_first({PersonId => '198602212394'})
        or die "Failed: ", $ep->error->{message};
    
    my ($namn_node) = $node->findnodes('./Personpost/Namn');
    print "The name is ", join ' ', $namn_node->findvalue('./Fornamn'),
        $namn_node->findvalue('./Efternamn'), "\n";
    
    # Using Namsokning and termdata format:
    
    use Navet::ePersondata::Namnsokning;
    
    my $ep = Navet::ePersondata::Namnsokning->new(
        pkcs12_file => '/path/to/certificate.p12',
        pkcs12_password => '5085873593180405',
        OrgNr => '162021004748',
        BestallningsId => '00000079-FO01-0001',
        format => 'termdata'
    );
    
    my $query = {
        Kon => 'K',
        Fornamn => 'sar*',
        Postort => 'Boden'            
    };
    
    foreach my $termdata ( $ep->find_all($query) ) {
        my ($first_name, $middle_name, $last_name) =
            ($termdata->{'01012'}, $termdata->{'01013'}, $termdata->{'01014'});
            
        $full_name = $first_name
            . ($middle_name ? " $middle_name" : '') . " $last_name";
        print "$full_name\n";
    }
  

=head1 DESCRIPTION

This package is the base class for talking with  Web Services - ePersondata
provided by skatteverket.se. The specific modules to use are
L<Navet::ePersondata::PersonPost> and  L<Navet::ePersondata:Namsokning> corresponding
to Web Service Personpost and Namnsökning. Using these services requires agreement
and access granted by Skatteverket in Sweden and also a special certificate. 

=head1 METHODS

=head2 new( %options )

    my $personpost_client = Navet::ePersondata::Personpost->new(
       pkcs12_file => '/path/to/certificate_file',
       pkcs12_password  => 'secret', 
       OrgNr => '162021004748',  
       BestallningsId => '00000079-FO01-0001',
       format => 'termdata', # ('termdata' or 'xml') default 'xml'
       soap_options => { proxy => 'https..', ...}  
    );

This constructor requires C<pkcs12_file>, C<pkcs12_password>, C<OrgNr> and
C<BestallningsId> or it will croak.

See information from Skatteverket in how to optain these. See
L<SOAP::XML::Client> for C<soap_options> if they are needed.

=head2 find_all( \%query_data )

    my @hits = $personpost_client->find_all( {PersonId => '196601010101'} )
    
query_data should contain the query parameters to the service.

Performs a SOAP call to the service and returns a list of objects that match the query.
The format of the objects is determined by what format was specified in the constructor:
L<XML::LibXML::Node> if it was 'xml', references to a flat hash of termcodes, termdata
if it was 'termdata'. Returns empty list if there was an error or if no record was found.

=head2 find_first( \%query_data )
   
Like find_all except returns a single entry (first found) instead of a list.
If not found or an error occurred it returns C<undef>.

=head2 error()

    if (my $err = $client->error) {
        die "Error: message=", $err->{message}, "\n";
    }

Returns a reference to a hash of the error information if the last call resulted in an error.
Returns C<undef> if there was no error. The hash can contain the following fields:

    message          - error text
    soap_faultcode   - SOAP faultcode from /Envelope/Body/Fault/faultscode
    soap_faultstring - SOAP faultstring from /Envelope/BodyFault/faultstring
    sv_Felkod        - Extra error code provided by Skatteverket
    sv_Beskrivning   - Extra description provided by Skatteverket
    raw_error        - Unparsed error text (can be XML, HTML or plain text)
    https_status     - HTTP status code

Only C<message> and C<raw_error> are garanteed to be set.

=head1 SEE ALSO

L<Navet::ePersondata::Personpost>

L<Navet::ePersondata::Namnsokning>

L<SOAP::XML::Client>

L<https://skatteverket.se/foretagochorganisationer/myndigheter/informationsutbytemellanmyndigheter/navethamtauppgifteromfolkbokforing.html>  

=head1 AUTHOR

Snorri Briem E<lt>snorri.briem@ub.lu.seE<gt>

=head1 COPYRIGHT

Copyright 2018- Lund University Library

=head1 LICENSE

This is free software; you can redistribute it and/or modify it under the same terms as the Perl 5 programming language system itself.

=cut
