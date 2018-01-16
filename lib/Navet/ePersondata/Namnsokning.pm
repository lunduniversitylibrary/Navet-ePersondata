package Navet::ePersondata::Namnsokning;

use strict;
use warnings;

use Moo;
use Navet::ePersondata;

our $VERSION = '0.01';

extends 'Navet::ePersondata';

my @REQUEST_ELEMENTS = qw(
Adress
EfterMellanNamn
FodelsetidFrom
FodelsetidTom
Fornamn
Kon
PostnummerFrom
PostnummerTom
Postort
Kategori
);


sub _args_xml {
    my ($self, $arg) = @_;

    my $xml =
        $self->_bestallning_xml . 
        '<SokvillkorNamn xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">' .
            join ('', map {
                my $val = $self->_escape_string($arg->{$_} // '');
                my $nil = length $val
                        ? ''
                        : ' xsi:nil="true"';  
                "<$_$nil>$val</$_>"
            } @REQUEST_ELEMENTS) .
            '</SokvillkorNamn>';
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Navet::ePersondata::Namsokning - Talks to the Namsokning web service that is provided by skattaverket.se

=head1 SYNOPSIS

    use Navet::ePersondata::Namnsokning;
    
    my $ep = Navet::ePersondata::Namnsokning->new(
        pkcs12_file => '/path/to/certificate.p12',
        pkcs12_password => '4309734529556524',
        OrgNr => '162021004748',
        BestallningsId => '00000079-FO01-0001',
    );
    
    my $query = {
        Kon => 'K',
        Fornamn => 'sar*',
        Postort => 'Boden'            
    };
    
    my ($namn_node) = $node->findnodes('/Personpost/Namn');
    print "The name is ", join ' ', $namn_node->findvalue('./Fornamn'),
        $namn_node->findvalue('./Efternamn'), "\n";

=head1 DESCRIPTION

Navet::ePersondata::Namnsokning is class for working with the Navet ePersondata
Namnsökning web service provided by skatteverket.se.

=head1 METHODS

=head2 new( %options )

=head2 find_all( \%query_data )

=head2 find_first( \%query_data )
   
=head2 error()

This class inherits the above methods from L<Navet::ePersondata>. The
C<query_data> parameter should contain a combination (with some restrictions) of the following search
fields: C<Adress>, C<EfterMellanNamn>, C<FodelsetidFrom>, C<FodelsetidTom>,
C<Fornamn>, C<Kon>, C<PostnummerFrom>, C<PostnummerTom>, C<Postort>,
C<Kategori>. Example:

    my @hits = $ep->get_data({
        Kon => 'K',
        Fornamn => 'sar*',
        Postort => 'Boden'
    });

=head1 SEE ALSO

L<Navet::ePersondata>

L<Navet::ePersondata::Personpost>

L<SOAP::XML::Client>

L<https://skatteverket.se/foretagochorganisationer/myndigheter/informationsutbytemellanmyndigheter/navethamtauppgifteromfolkbokforing.html>  

=head1 AUTHOR

Snorri Briem E<lt>snorri.briem@ub.lu.seE<gt>

=head1 COPYRIGHT

Copyright 2018- Lund University Library

=head1 LICENSE

This is free software; you can redistribute it and/or modify it under the same terms as the Perl 5 programming language system itself.

=cut
