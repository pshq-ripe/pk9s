# pk9s Phase 1: Backend Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use compose:subagent (recommended) or compose:execute to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the Perl backend for kubectl integration, JSON parsing, and resource list normalization.

**Architecture:** Modular Perl project with separate concerns: kubectl execution (fork/pipe), JSON decoding, and resource normalization. Core modules in `lib/pk9s/`, tests in `t/`, entry point in `bin/pk9s`.

**Tech Stack:** Perl 5.30+, JSON::PP (core), IPC::Open3, Test::More, ExtUtils::MakeMaker

---

## File Structure

```
pk9s/
├── bin/
│   └── pk9s                  # Entry point script
├── lib/
│   └── pk9s/
│       ├── Kubectl.pm        # kubectl wrapper (fork/pipe/JSON)
│       ├── Resource.pm       # Resource normalization
│       └── Config.pm         # Configuration management
├── t/
│   ├── 01-kubectl.t          # Kubectl module tests
│   ├── 02-resource.t         # Resource module tests
│   └── 03-config.t           # Config module tests
├── cpanfile                  # Perl dependencies
├── Makefile.PL               # Build system
└── README.md                 # Usage documentation
```

---

### Task 1: Project Scaffolding

**Covers:** [S1, S5]

**Files:**
- Create: `Makefile.PL`
- Create: `cpanfile`
- Create: `lib/pk9s.pm`
- Create: `bin/pk9s`

- [ ] **Step 1: Create Makefile.PL**

```perl
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME         => 'pk9s',
    VERSION_FROM => 'lib/pk9s.pm',
    ABSTRACT     => 'Lightweight Kubernetes TUI in Perl',
    AUTHOR       => 'pk9s contributors',
    LICENSE      => 'perl_5',
    PREREQ_PM    => {
        'JSON::PP'   => 0,
        'IPC::Open3' => 0,
        'File::Temp' => 0,
    },
    TEST_REQUIRES => {
        'Test::More' => 0.96,
    },
    EXE_FILES     => ['bin/pk9s'],
    META_MERGE    => {
        'meta-spec' => { version => 2 },
        resources   => {
            repository => {
                type => 'git',
                url  => 'https://github.com/pshq/pk9s.git',
            },
        },
    },
);
```

- [ ] **Step 2: Create cpanfile**

```perl
requires 'JSON::PP', '0';
requires 'IPC::Open3', '0';
requires 'File::Temp', '0';

on 'test' => sub {
    requires 'Test::More', '0.96';
};
```

- [ ] **Step 3: Create lib/pk9s.pm**

```perl
package pk9s;
use strict;
use warnings;

our $VERSION = '0.01';

1;
```

- [ ] **Step 4: Create bin/pk9s**

```perl
#!/usr/bin/env perl
use strict;
use warnings;
use lib 'lib';
use pk9s;

print "pk9s v$pk9s::VERSION\n";
```

- [ ] **Step 5: Make entry point executable**

Run: `chmod +x bin/pk9s`

- [ ] **Step 6: Verify project loads**

Run: `perl -Ilib bin/pk9s`
Expected: `pk9s v0.01`

- [ ] **Step 7: Commit**

```bash
git add Makefile.PL cpanfile lib/pk9s.pm bin/pk9s
git commit -m "chore: scaffold pk9s project structure"
```

---

### Task 2: Kubectl Module — Interface & Tests

**Covers:** [S1, S4]

**Files:**
- Create: `lib/pk9s/Kubectl.pm`
- Create: `t/01-kubectl.t`

- [ ] **Step 1: Write failing test for Kubectl interface**

```perl
# t/01-kubectl.t
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `prove -Ilib t/01-kubectl.t`
Expected: FAIL with "Can't locate pk9s/Kubectl.pm"

- [ ] **Step 3: Create minimal Kubectl.pm**

```perl
# lib/pk9s/Kubectl.pm
package pk9s::Kubectl;
use strict;
use warnings;
use JSON::PP;
use IPC::Open3;
use Symbol 'gensym';

sub new {
    my ($class, %args) = @_;
    my $self = {
        kubectl => $args{kubectl} || 'kubectl',
        context => $args{context} || undef,
    };
    return bless $self, $class;
}

sub execute {
    my ($self, @args) = @_;
    
    my @cmd = ($self->{kubectl});
    push @cmd, '--context', $self->{context} if $self->{context};
    push @cmd, @args;
    
    my ($stdout, $stderr) = $self->_run(@cmd);
    
    if ($stderr && $stderr =~ /error/i) {
        return { error => $stderr };
    }
    
    my $data = eval { decode_json($stdout) };
    if ($@) {
        return { error => "JSON decode failed: $@" };
    }
    
    return $data;
}

sub get_pods {
    my ($self, %args) = @_;
    my @cmd = ('get', 'pods', '--output=json');
    push @cmd, '--namespace', $args{namespace} if $args{namespace};
    return $self->execute(@cmd);
}

sub get_deployments {
    my ($self, %args) = @_;
    my @cmd = ('get', 'deployments', '--output=json');
    push @cmd, '--namespace', $args{namespace} if $args{namespace};
    return $self->execute(@cmd);
}

sub _run {
    my ($self, @cmd) = @_;
    
    my $err = gensym;
    my $pid = open3(my $stdout, my $stderr, @cmd);
    
    my $out = do { local $/; <$stdout> };
    my $err_out = do { local $/; <$stderr> };
    
    waitpid($pid, 0);
    
    return ($out, $err_out);
}

1;
```

- [ ] **Step 4: Run test to verify it passes**

Run: `prove -Ilib t/01-kubectl.t`
Expected: PASS (tests may fail due to no cluster, but module loads)

- [ ] **Step 5: Commit**

```bash
git add lib/pk9s/Kubectl.pm t/01-kubectl.t
git commit -m "feat: add Kubectl module with execute, get_pods, get_deployments"
```

---

### Task 3: Kubectl Module — Unit Tests with Mocking

**Covers:** [S1, S4]

**Files:**
- Create: `t/01-kubectl-mock.t`

- [ ] **Step 1: Write mocked tests**

```perl
# t/01-kubectl-mock.t
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
```

- [ ] **Step 2: Run mock tests**

Run: `prove -Ilib t/01-kubectl-mock.t`
Expected: PASS

- [ ] **Step 3: Commit**

```bash
git add t/01-kubectl-mock.t
git commit -m "test: add mocked Kubectl unit tests"
```

---

### Task 4: Resource Normalization Module

**Covers:** [S2, S4]

**Files:**
- Create: `lib/pk9s/Resource.pm`
- Create: `t/02-resource.t`

- [ ] **Step 1: Write failing test for Resource module**

```perl
# t/02-resource.t
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `prove -Ilib t/02-resource.t`
Expected: FAIL with "Can't locate pk9s/Resource.pm"

- [ ] **Step 3: Implement Resource.pm**

```perl
# lib/pk9s/Resource.pm
package pk9s::Resource;
use strict;
use warnings;

sub new {
    my ($class, %args) = @_;
    my $self = {
        name      => $args{name}      || '',
        namespace => $args{namespace} || 'default',
        type      => $args{type}      || 'unknown',
        status    => $args{status}    || 'Unknown',
        ready     => $args{ready}     || '-',
        age       => $args{age}       || '-',
        raw       => $args{raw}       || {},
    };
    return bless $self, $class;
}

sub name      { return $_[0]->{name} }
sub namespace { return $_[0]->{namespace} }
sub type      { return $_[0]->{type} }
sub status    { return $_[0]->{status} }
sub ready     { return $_[0]->{ready} }
sub age       { return $_[0]->{age} }
sub raw       { return $_[0]->{raw} }

sub normalize {
    my ($class, $raw, $type) = @_;
    
    my %args = (
        raw  => $raw,
        type => $type,
    );
    
    if ($type eq 'pod') {
        $args{name}      = $raw->{metadata}{name} // '';
        $args{namespace} = $raw->{metadata}{namespace} // 'default';
        $args{status}    = $raw->{status}{phase} // 'Unknown';
        $args{age}       = $class->_calc_age($raw->{metadata}{creationTimestamp});
        
        my @containers = @{$raw->{status}{containerStatuses} // []};
        my $ready = grep { $_->{ready} } @containers;
        $args{ready} = "$ready/" . scalar(@containers) if @containers;
    }
    elsif ($type eq 'deployment') {
        $args{name}      = $raw->{metadata}{name} // '';
        $args{namespace} = $raw->{metadata}{namespace} // 'default';
        $args{status}    = 'Running';
        $args{age}       = $class->_calc_age($raw->{metadata}{creationTimestamp});
        
        my $replicas = $raw->{status}{replicas} // 0;
        my $ready    = $raw->{status}{readyReplicas} // 0;
        $args{ready} = "$ready/$replicas" if $replicas;
    }
    elsif ($type eq 'service') {
        $args{name}      = $raw->{metadata}{name} // '';
        $args{namespace} = $raw->{metadata}{namespace} // 'default';
        $args{status}    = 'Active';
        $args{ready}     = '-';
    }
    
    return $class->new(%args);
}

sub _calc_age {
    my ($class, $timestamp) = @_;
    return '-' unless $timestamp;
    
    # Simple age calculation (days)
    my $then = Time::Local::timelocal(
        reverse split /[-T:]/, $timestamp
    );
    my $now = time();
    my $days = int(($now - $then) / 86400);
    
    return "${days}d" if $days > 0;
    my $hours = int(($now - $then) / 3600);
    return "${hours}h" if $hours > 0;
    return '<1h';
}

1;
```

- [ ] **Step 4: Run test to verify it passes**

Run: `prove -Ilib t/02-resource.t`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/pk9s/Resource.pm t/02-resource.t
git commit -m "feat: add Resource normalization module"
```

---

### Task 5: Configuration Module

**Covers:** [S3, S5]

**Files:**
- Create: `lib/pk9s/Config.pm`
- Create: `t/03-config.t`

- [ ] **Step 1: Write failing test for Config module**

```perl
# t/03-config.t
use strict;
use warnings;
use Test::More tests => 5;
use lib 'lib';
use File::Temp qw(tempfile);

use_ok('pk9s::Config');

# Test default config
my $config = pk9s::Config->new();
isa_ok($config, 'pk9s::Config');
is($config->get('kubectl'), 'kubectl', 'default kubectl path');
is($config->get('context'), undef, 'default context is undef');

# Test loading from file
my ($fh, $filename) = tempfile(SUFFIX => '.json', UNLINK => 1);
print $fh '{"kubectl":"/usr/local/bin/kubectl","context":"production"}';
close $fh;

my $file_config = pk9s::Config->new(file => $filename);
is($file_config->get('kubectl'), '/usr/local/bin/kubectl', 'loaded kubectl from file');
```

- [ ] **Step 2: Run test to verify it fails**

Run: `prove -Ilib t/03-config.t`
Expected: FAIL with "Can't locate pk9s/Config.pm"

- [ ] **Step 3: Implement Config.pm**

```perl
# lib/pk9s/Config.pm
package pk9s::Config;
use strict;
use warnings;
use JSON::PP;

my %DEFAULTS = (
    kubectl   => 'kubectl',
    context   => undef,
    namespace => 'default',
    editor    => $ENV{EDITOR} || 'vim',
    log_level => 'info',
);

sub new {
    my ($class, %args) = @_;
    my $self = { %DEFAULTS };
    
    if ($args{file} && -f $args{file}) {
        open my $fh, '<', $args{file} or die "Cannot open $args{file}: $!";
        my $json = do { local $/; <$fh> };
        close $fh;
        
        my $data = eval { decode_json($json) };
        if ($data && ref $data eq 'HASH') {
            @$self{keys %$data} = values %$data;
        }
    }
    
    return bless $self, $class;
}

sub get {
    my ($self, $key) = @_;
    return $self->{$key};
}

sub set {
    my ($self, $key, $value) = @_;
    $self->{$key} = $value;
}

sub all {
    my ($self) = @_;
    return %$self;
}

1;
```

- [ ] **Step 4: Run test to verify it passes**

Run: `prove -Ilib t/03-config.t`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/pk9s/Config.pm t/03-config.t
git commit -m "feat: add Config module for settings management"
```

---

### Task 6: Integration Test — Kubectl + Resource

**Covers:** [S2, S4, S7]

**Files:**
- Create: `t/04-integration.t`

- [ ] **Step 1: Write integration test**

```perl
# t/04-integration.t
use strict;
use warnings;
use Test::More tests => 4;
use lib 'lib';

# Mock for integration testing
package MockKubectl {
    use parent 'pk9s::Kubectl';
    
    sub _run {
        my ($self, @cmd) = @_;
        
        if ($cmd[-1] eq 'pods') {
            return ('{
                "apiVersion": "v1",
                "items": [
                    {"metadata": {"name": "pod-1", "namespace": "default"}, "status": {"phase": "Running", "containerStatuses": [{"ready": 1}]}},
                    {"metadata": {"name": "pod-2", "namespace": "kube-system"}, "status": {"phase": "Pending", "containerStatuses": []}}
                ]
            }', '');
        }
        
        return ('{}', '');
    }
}

package main;

use_ok('pk9s::Kubectl');
use_ok('pk9s::Resource');

my $kubectl = MockKubectl->new();
my $data = $kubectl->get_pods();

my @resources = map { 
    pk9s::Resource->normalize($_, 'pod') 
} @{$data->{items}};

is(scalar @resources, 2, 'normalized 2 pods');
is($resources[0]->status, 'Running', 'first pod is Running');
```

- [ ] **Step 2: Run integration test**

Run: `prove -Ilib t/04-integration.t`
Expected: PASS

- [ ] **Step 3: Commit**

```bash
git add t/04-integration.t
git commit -m "test: add integration test for Kubectl + Resource"
```

---

### Task 7: Update Entry Point

**Covers:** [S1, S2]

**Files:**
- Modify: `bin/pk9s`

- [ ] **Step 1: Update bin/pk9s with backend usage**

```perl
#!/usr/bin/env perl
use strict;
use warnings;
use lib 'lib';
use pk9s::Kubectl;
use pk9s::Resource;
use pk9s::Config;

my $config = pk9s::Config->new();
my $kubectl = pk9s::Kubectl->new(
    kubectl => $config->get('kubectl'),
    context => $config->get('context'),
);

my $data = $kubectl->get_pods(namespace => $config->get('namespace'));

if ($data->{error}) {
    print STDERR "Error: $data->{error}\n";
    exit 1;
}

my @pods = map { pk9s::Resource->normalize($_, 'pod') } @{$data->{items}};

printf "%-40s %-15s %-10s\n", 'NAME', 'STATUS', 'READY';
printf "%-40s %-15s %-10s\n", '-' x 40, '-' x 15, '-' x 10;

for my $pod (@pods) {
    printf "%-40s %-15s %-10s\n", $pod->name, $pod->status, $pod->ready;
}
```

- [ ] **Step 2: Verify entry point works**

Run: `perl -Ilib bin/pk9s 2>&1 | head -5`
Expected: Table output (or error if no cluster configured)

- [ ] **Step 3: Commit**

```bash
git add bin/pk9s
git commit -m "feat: update entry point to use backend modules"
```

---

## Self-Review Checklist

- [ ] **Spec coverage:** S1 (problem) ✓, S2 (solution) ✓, S3 (architecture) ✓, S4 (roadmap phase 1) ✓, S5 (decisions) ✓, S7 (success criteria partial) ✓
- [ ] **Placeholder scan:** No TBD/TODO found
- [ ] **Type consistency:** Kubectl.pm interface matches tests, Resource.pm normalization matches test expectations
- [ ] **File structure:** All files defined in structure section exist in tasks

## Execution Handoff

This plan has 7 tasks with clear dependencies. Recommendation:

- **Tasks 1-2:** Sequential (scaffolding must come first)
- **Tasks 3-5:** Can be parallel (independent modules)
- **Tasks 6-7:** Sequential (integration depends on modules)
