# NAME

Navet::ePersondata - Simple framework for the Navet ePersondata web services

# SYNOPSIS

      use Navet::ePersondata::Personpost;

      my $ep = Navet::ePersondata::Personpost->new(    
          # Set proxy to test service instead of production 
          soap_options => {
              proxy => 'https://ppx4.skatteverket.se/nawa15/na_epersondata/V2/personpostXML'
          },
          pkcs12_file => '/path/to/certificate.p12',
          pkcs12_password => '4309734529556524',
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
          pkcs12_password => '4309734529556524',
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
    

# DESCRIPTION

This package is the base class for talking with  Web Services - ePersondata
provided by skatteverket.se. The specific modules to use are
[Navet::ePersondata::PersonPost](https://metacpan.org/pod/Navet::ePersondata::PersonPost) and  [Navet::ePersondata:Namsokning](https://metacpan.org/pod/Navet::ePersondata:Namsokning) corresponding
to Web Service Personpost and Namnsökning. Using these services requires agreement
and access graneted by Skatteverket in Sweden and also a special certificate. 

# METHODS

## new( %options )

    my $personpost_client = Navet::ePersondata::Personpost->new(
       pkcs12_file => '/path/to/certificate_file',
       pkcs12_password  => 'secret', 
       OrgNr => '162021004748',  
       BestallningsId => '00000079-FO01-0001',
       format => 'termdata', # ('termdata' or 'xml') default 'xml'
       soap_options => { proxy => 'https..', ...}  
    );

This constructor requires `pkcs12_file`, `pkcs12_password`, `OrgNr` and
`BestallningsId` or it will croak.

See information from Skatteverket in how to optain these. See
[SOAP::XML::Client](https://metacpan.org/pod/SOAP::XML::Client) for `soap_options` if they are needed.

## find\_all( \\%query\_data )

    my @hits = $personpost_client->find_all( {PersonId => '196601010101'} )
    

query\_data should contain the query parameters to the service.

Performs a SOAP call to the service and returns a list of objects that match the query.
The format of the objects is determined by what format was specified in the constructor:
[XML::LibXML::Node](https://metacpan.org/pod/XML::LibXML::Node) if it was 'xml', references to a flat hash of termcodes, termdata
if it was 'termdata'. Returns empty list if there was an error or if no record was found.

## find\_first( \\%query\_data )

Like find\_all except returns a single entry (first found) instead of a list.
If not found or an error occurred it returns `undef`.

## error()

    if (my $err = $client->error) {
        die "Error: message=", $err->{message}, "\n";
    }

Returns a reference to a hash of the error information if the last call resulted in an error.
Returns `undef` if there was no error. The hash can contain the following fields:

    message          - error text
    soap_faultcode   - SOAP faultcode from /Envelope/Body/Fault/faultscode
    soap_faultstring - SOAP faultstring from /Envelope/BodyFault/faultstring
    sv_Felkod        - Extra error code provided by Skatteverket
    sv_Beskrivning   - Extra description provided by Skatteverket
    raw_error        - Unparsed error text (can be XML, HTML or plain text)
    https_status     - HTTP status code

Only `message` and `raw_error` are garanteed to be set.

# SEE ALSO

[Navet::ePersondata::Personpost](https://metacpan.org/pod/Navet::ePersondata::Personpost)

[Navet::ePersondata::Namnsokning](https://metacpan.org/pod/Navet::ePersondata::Namnsokning)

[SOAP::XML::Client](https://metacpan.org/pod/SOAP::XML::Client)

[https://skatteverket.se/foretagochorganisationer/myndigheter/informationsutbytemellanmyndigheter/navethamtauppgifteromfolkbokforing.html](https://skatteverket.se/foretagochorganisationer/myndigheter/informationsutbytemellanmyndigheter/navethamtauppgifteromfolkbokforing.html)  

# AUTHOR

Snorri Briem <snorri.briem@ub.lu.se>

# COPYRIGHT

Copyright 2018- Lund University Library

# LICENSE

This is free software; you can redistribute it and/or modify it under the same terms as the Perl 5 programming language system itself.
