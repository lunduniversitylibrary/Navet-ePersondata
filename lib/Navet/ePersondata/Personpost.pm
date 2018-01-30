package Navet::ePersondata::Personpost;

use strict;
use warnings;

use Navet::ePersondata;
use Moo;

extends 'Navet::ePersondata';

sub _args_xml {
     my ($self, $arg) = @_;

     my $pnr = $self->_escape_string( $arg->{PersonId} );
     $self->_bestallning_xml .  "<PersonId>$pnr</PersonId>";
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Navet::ePersondata::Personpost - Talks to the Navet Personpost web service

=head1 SYNOPSIS

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


=head1 DESCRIPTION

Navet::ePersondata::Personpost is class for working with the Navet ePersondata
Personpost web service provided by skatteverket.se.

=head1 METHODS

=head2 new( %options )

=head2 find_all( \%query_data )

=head2 find_first( \%query_data )
   
=head2 error()

This class inherits the above methods from L<Navet::ePersondata>. The
C<query_data> parameter should contain C<PersonId>, which stands for a swedish
Personnummer/Samordningsnummer) when using the C<find_all> or C<find_one>
methods. Example:

    $personpost->find_first( {PersonId => '198602212394'} )

=head1 SEE ALSO

L<Navet::ePersondata>

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
