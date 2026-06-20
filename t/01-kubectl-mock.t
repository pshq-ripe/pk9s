use strict;
use warnings;
use Test::More tests => 6;
use lib 'lib';

# Mock module that overrides _run
package MockKubectl {
    use parent 'pk9s::Kubectl';
    
    sub _run {
        my ($self, @cmd) = @_;
        
        # Return mock JSON based on command
        my $json = '{
            "apiVersion": "v1",
            "items": [
                {
                    "metadata": {"name": "test-pod"},
                    "status": {"phase": "Running"}
                }
            ]
        }';
        
        return ($json, '');
    }
}

package main;

use_ok('pk9s::Kubectl');

my $kubectl = MockKubectl->new();
isa_ok($kubectl, 'MockKubectl');

# Test execute with mock
my $result = $kubectl->execute('get', 'pods', '--output=json');
is(ref $result, 'HASH', 'execute returns hash');
is(exists $result->{items}, 1, 'result has items');
is(scalar @{$result->{items}}, 1, 'items has one element');
is($result->{items}[0]{metadata}{name}, 'test-pod', 'pod name correct');
