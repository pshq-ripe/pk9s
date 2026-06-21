use strict;
use warnings;
use Test::More tests => 13;
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

# Test build_regex
my $regex = $search->build_regex("nginx");
isa_ok($regex, 'Regexp', 'build_regex returns regexp');

# Test filter with mock resources
package MockResource {
    sub new { bless { name => $_[1] }, $_[0] }
    sub name { return $_[0]->{name} }
}

package main;

my @resources = (
    MockResource->new("nginx-deploy"),
    MockResource->new("redis-deploy"),
    MockResource->new("nginx-pod"),
);

my $extract = sub { [$_[0]->name] };
my $regex2 = $search->build_regex("nginx");
my @filtered = $search->filter(
    resources => \@resources,
    regex => $regex2,
    extract => $extract,
);

is(scalar @filtered, 2, 'filter returns matching resources');
is($filtered[0]->name, "nginx-deploy", 'filter returns correct first match');
is($filtered[1]->name, "nginx-pod", 'filter returns correct second match');

# Test highlight
my $highlighted = $search->highlight("nginx-deploy", $regex2);
like($highlighted, qr/\e\[1mnginx\e\[0m/, 'highlight wraps match in ANSI bold');
