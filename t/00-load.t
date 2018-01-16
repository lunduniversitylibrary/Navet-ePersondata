#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;

my $pkg;
BEGIN {
    use_ok 'Navet::ePersondata';
    use_ok 'Navet::ePersondata::Personpost';
    use_ok 'Navet::ePersondata::Namnsokning';  
}

require_ok 'Navet::ePersondata';
require_ok 'Navet::ePersondata::Personpost';
require_ok 'Navet::ePersondata::Namnsokning';  

done_testing 6;
