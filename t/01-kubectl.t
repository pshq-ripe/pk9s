use strict;
use warnings;
use Test::More tests => 5;
use lib 'lib';

use_ok('pk9s::Kubectl');

my $kubectl = pk9s::Kubectl->new();
isa_ok($kubectl, 'pk9s::Kubectl');

can_ok($kubectl, qw(execute get_pods get_deployments));

# Test with invalid cluster (should fail gracefully)
my $result = $kubectl->execute('get', 'pods', '--output=json');
is(ref $result, 'HASH', 'execute returns hash reference');
ok(exists $result->{items} || exists $result->{error}, 'result has items or error key');
