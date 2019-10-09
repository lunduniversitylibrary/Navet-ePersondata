use strict;
use warnings FATAL => 'all';
use Test::More;
use Test::Exception;

my $pkg;

my %CONFIG = (  
    pkcs12_file => 't/Kommun A.p12',
    pkcs12_password => '5085873593180405',
    OrgNr => '162021004748',
    BestallningsId => '00000079-FO01-0001',
    soap_options => { proxy => 'https://www2.test.skatteverket.se/na/na_epersondata/V2/personpostXML'}
);


BEGIN {
    $pkg = 'Navet::ePersondata::Personpost';
    use_ok $pkg or BAIL_OUT "Can't load $pkg";
}


throws_ok { $pkg->new()} qr/required/, "required arguments missing";
throws_ok { $pkg->new(%CONFIG, format => 'termdata')}
    qr/^Incompatible values/, "incompatible values 1";
throws_ok {
    $pkg->new( %CONFIG,
               format => 'xml',
               soap_options => {
proxy => 'https://www2.test.skatteverket.se/na/na_epersondata/V2/personpost'
               },
             )
} qr/^Incompatible values/, "incompatible values 2";

throws_ok {
    $pkg->new( %CONFIG, format => 'invalid_format',)
} qr/not a valid format/, "not valid format";

my @recs;
my $node;
my $client;
my $error;

lives_ok {$client= $pkg->new( %CONFIG ) } "construct with correct arguments";
lives_ok {($node) = $client->find_all( {PersonId => '198602212394' } )} "find_all";

$error=$client->error;
is($error, undef, "find_all no error") or BAIL_OUT ("Personpost failed: " .  $error->{message} );

# check  if first value is of type XML::XMLlib::Node.
isa_ok($node, "XML::LibXML::Node", 'find_all first value');
 
my ($namn_node) = $node->findnodes('/Personpost'); 
isa_ok($node, "XML::LibXML::Node", "find_all first Personpost node");

lives_ok {$node = $client->find_first( {PersonId => '198602212394' } )} "find_first";
isa_ok($node, "XML::LibXML::Node", "find_first value");

# format termdata
lives_ok {$client= $pkg->new( %CONFIG, format => 'termdata',
    soap_options => { proxy => 'https://www2.test.skatteverket.se/na/na_epersondata/V2/personpost' },
    ) } "constructor with format termdata";

my $hash;
lives_ok {$hash = $client->find_first( {PersonId => '194106279161' } )} "termdata find_first";
isa_ok($hash, "HASH", 'find_first termdata value');
is( $hash->{'01001'}, '194106279161', 'correct data in formdata result' );

# 0 hits
lives_ok {$hash = $client->find_first( {PersonId => '184106279161' } )} "zero hits lives";
is( $hash, undef, "zero hits with undef results" );
is( $client->error, undef, "zero hits with no error" );

# error conditions

$client= $pkg->new( %CONFIG, BestallningsId => 'BestallningsId not valid');
$hash = $client->find_first( {PersonId => '198602212394' } );
is( $hash, undef, "invalid parameters yield undef results" );
$error = $client->error;
isnt($error, undef, "invalid parameters yields an error");
like($error->{message}, qr/Felaktiga inparametrar/, 'invalid parameters yield correct error message');
is($error->{http_status}, '500', 'invalid parameters yield correct HTTP status');

$client= $pkg->new( %CONFIG, pkcs12_file => 'not_valid');
$hash = $client->find_first( {PersonId => '198602212394' } );
is( $hash, undef, "invalid certificate yields undef results" );
$error = $client->error;
isnt($error, undef, "invalid certificate yields an error");
like($error->{message}, qr/No such file or directory/, 'invalid certificate yields correct error message');
is($error->{http_status}, '500', 'HTTP Status set for invalid certicate');

# Text error
$client= $pkg->new( %CONFIG, soap_options => { proxy => 'http://not_validXML'});
$hash = $client->find_first( {PersonId => '198602212394' } );
is( $hash, undef, "Invalid proxy URL yields undef results" );
$error = $client->error;
isnt($error, undef, "Invalid proxy URL yields an error");
is($error->{http_status}, '500', 'Invalid proxy URL yields correct HTTP status');

#HTML error
$client= $pkg->new( %CONFIG,
    soap_options => { proxy => 'https://www2.test.skatteverket.se/na/na_epersondata/V2/nosuchserviceXML'}
);
$hash = $client->find_first( {PersonId => '198602212394' } );
is( $hash, undef, "wrong proxy URL yields undef results" );
$error = $client->error;
isnt($error, undef, "wrong proxy URL yields an error");
is($error->{http_status}, '404', 'wrong proxy URL yields correct HTTP status');

done_testing;

