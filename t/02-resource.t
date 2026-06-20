use strict;
use warnings;
use Test::More tests => 8;
use lib 'lib';

use_ok('pk9s::Resource');

# Test pod normalization
my $raw_pod = {
    metadata => {
        name => 'nginx-abc123',
        namespace => 'default',
        creationTimestamp => '2024-01-15T10:30:00Z',
    },
    status => {
        phase => 'Running',
        containerStatuses => [
            { ready => 1 },
            { ready => 0 },
        ],
    },
};

my $pod = pk9s::Resource->normalize($raw_pod, 'pod');
isa_ok($pod, 'pk9s::Resource');
is($pod->name, 'nginx-abc123', 'pod name');
is($pod->namespace, 'default', 'pod namespace');
is($pod->status, 'Running', 'pod status');
is($pod->ready, '1/2', 'pod ready count');

# Test deployment normalization
my $raw_deploy = {
    metadata => {
        name => 'nginx-deploy',
        namespace => 'default',
    },
    status => {
        replicas => 3,
        readyReplicas => 2,
        availableReplicas => 2,
    },
};

my $deploy = pk9s::Resource->normalize($raw_deploy, 'deployment');
is($deploy->name, 'nginx-deploy', 'deployment name');
is($deploy->ready, '2/3', 'deployment ready count');
