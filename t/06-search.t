use strict;
use warnings;
use Test::More tests => 8;
use lib 'lib';

use_ok('pk9s::Search');

my $search = pk9s::Search->new();
isa_ok($search, 'pk9s::Search');

can_ok($search, qw(parse_query build_regex filter highlight));

# Test parse_query with scoped mode
my ($term, $scope) = $search->parse_query("nginx");
is($term, "nginx", 'parse_query returns term');
is($scope, "current", 'parse_query returns current scope');

# Test parse_query with all: prefix
($term, $scope) = $search->parse_query("all:nginx");
is($term, "nginx", 'parse_query strips all: prefix');
is($scope, "all", 'parse_query returns all scope');

# Test empty query
($term, $scope) = $search->parse_query("");
is($term, "", 'parse_query handles empty query');
