requires 'IO::Socket::SSL';
requires 'Moo';
requires 'SOAP::XML::Client::Generic';
requires 'XML::LibXML';

on configure => sub {
    requires 'Module::Build::Tiny', '0.034';
    requires 'perl', '5.008005';
};

on test => sub {
    requires 'Test::Exception';
    requires 'Test::More';
};
