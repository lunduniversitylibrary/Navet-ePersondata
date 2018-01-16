use strict;
use warnings FATAL => 'all';
use Test::More;
use Test::Exception;

my $pkg;

my %CONFIG = (  
    pkcs12_file => 't/notarealhost.kommun-a.se.p12',
    pkcs12_password => '4309734529556524',
    OrgNr => '162021004748',
    BestallningsId => '00000079-FO01-0001',
    soap_options => { proxy => 'https://ppx4.skatteverket.se/nawa15/na_epersondata/V2/namnsokningXML'}
);


BEGIN {
    $pkg = 'Navet::ePersondata::Namnsokning';
    use_ok $pkg or BAIL_OUT "Can't load $pkg";
}


throws_ok { $pkg->new()} qr/required/, "Required arguments missing";
throws_ok { $pkg->new(%CONFIG, format => 'termdata')}
    qr/^Incompatible values/, "incompatible values 1";
throws_ok {
    $pkg->new( %CONFIG,
               format => 'xml',
               soap_options => {
proxy => 'https://ppx4.skatteverket.se/nawa15/na_epersondata/V2/namnsokning'
               },
             )
} qr/^Incompatible values/, "incompatible values 2";

throws_ok {
    $pkg->new( %CONFIG, format => 'invalid_format',)
} qr/not a valid format/, "invalid format";

# find_records
#TODO: SKIP following if no network


my @recs;
my $node;
my $client;
my $error;

lives_ok {$client= $pkg->new( %CONFIG ) } "new works";

lives_ok {($node) = $client->find_all( {Kon => 'K', Fornamn => 'sar*', Postort => 'Boden'} )} "find_all namnsokning";

#check  if first value is of type XML::XMLlib::Node.
isa_ok($node, "XML::LibXML::Node", "find_all first value");
 

my ($namn_node) = $node->findnodes('/Personpost');
isa_ok($node, "XML::LibXML::Node", "find_all first Personpost node");

lives_ok {$node = $client->find_first(  {Kon => 'K', Fornamn => 'sar*', Postort => 'Boden'} )} "find_first";
isa_ok($node, "XML::LibXML::Node", "find_first value");

# format termdata
lives_ok {$client= $pkg->new( %CONFIG, format => 'termdata',
    soap_options => { proxy => 'https://ppx4.skatteverket.se/nawa15/na_epersondata/V2/namnsokning' },
    ) } "constructor with format termdata";

my $hash;
lives_ok {$hash = $client->find_first( {Kon => 'K', Fornamn => 'sar*', Postort => 'Boden'} )} "termdata find_first";
isa_ok($hash, "HASH", "find_first termdata value");
like( $hash->{'01012'}, qr/\bsar/i, 'correct data in formdata result' );

# 0 hits
lives_ok {$hash = $client->find_first( {Kon => 'K', Fornamn => 'zorglubb*', Postort => 'Boden'} )} "zero hits lives";
is( $hash, undef, "zero hits with undef results" );
is( $client->error, undef, "zero hits with no error" );

# error conditions

$client= $pkg->new( %CONFIG, BestallningsId => 'BestallningsId not valid');
$hash = $client->find_first(  {Kon => 'K', Fornamn => 'sar*', Postort => 'Boden'} );
is( $hash, undef, "invalid parameters yield undef results" );
$error = $client->error;
isnt($error, undef, "invalid parameters yields an error");
like($error->{message}, qr/Felaktiga inparametrar/, 'invalid parameters yield correct error message');
is($error->{http_status}, '500', 'invalid parameters yield correct HTTP status');

$client= $pkg->new( %CONFIG, pkcs12_file => 'not_valid');
$hash = $client->find_first({Kon => 'K', Fornamn => 'sar*', Postort => 'Boden'} );
is( $hash, undef, "uinvalid certificate yields undef results" );
$error = $client->error;
isnt($error, undef, "invalid certificate yields an error");
like($error->{message}, qr/No such file or directory/, 'invalid certificate yields correct error message');
is($error->{http_status}, '500', 'HTTP Status set for invalid certicate');

# Text error
$client= $pkg->new( %CONFIG, soap_options => { proxy => 'http://not_validXML'});
$hash = $client->find_first( {Kon => 'K', Fornamn => 'sar*', Postort => 'Boden'} );
is( $hash, undef, "Invalid proxy URL yields undef results" );
$error = $client->error;
isnt($error, undef, "Invalid proxy URL yields an error");
like($error->{message}, qr/Name or service not known/, 'Invalid proxy URL yields correct error message');
is($error->{http_status}, '500', 'Invalid proxy URL yields correct HTTP status');

#HTML error
$client= $pkg->new( %CONFIG,
    soap_options => { proxy => 'https://ppx4.skatteverket.se/nawa15/na_epersondata/V2/nosuchserviceXML'}
);
$hash = $client->find_first( {Kon => 'K', Fornamn => 'sar*', Postort => 'Boden'} );
is( $hash, undef, "wrong proxy URL yields undef results" );
$error = $client->error;
isnt($error, undef, "Invalid proxy URL yields an error");
like($error->{message}, qr/Not Found/, 'wrong proxy URL yields correct error message');
is($error->{http_status}, '404', 'wrong proxy URL yields correct HTTP status');

done_testing;

