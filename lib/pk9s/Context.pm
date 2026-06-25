package pk9s::Context;
use strict;
use warnings;
use DBI;
use File::Path 'mkpath';

sub new {
    my ($class, %args) = @_;
    my $dir = $args{dir} // "$ENV{HOME}/.pk9s";
    mkpath($dir) unless -d $dir;

    my $db_path = "$dir/context.db";
    my $dbh = DBI->connect("dbi:SQLite:dbname=$db_path", '', '', {
        RaiseError => 1,
        PrintError => 0,
        AutoCommit => 1,
    });

    $dbh->do('PRAGMA journal_mode=WAL');

    $dbh->do(<<'SQL');
        CREATE TABLE IF NOT EXISTS context (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            timestamp INTEGER NOT NULL,
            type TEXT NOT NULL,
            namespace TEXT,
            resource_type TEXT,
            resource_name TEXT,
            data TEXT NOT NULL
        )
SQL

    $dbh->do(<<'SQL');
        CREATE TABLE IF NOT EXISTS commands (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            timestamp INTEGER NOT NULL,
            command TEXT NOT NULL,
            stdout TEXT,
            stderr TEXT,
            exit_code INTEGER,
            duration_ms INTEGER
        )
SQL

    $dbh->do('CREATE INDEX IF NOT EXISTS idx_context_type ON context(type)');
    $dbh->do('CREATE INDEX IF NOT EXISTS idx_context_resource ON context(resource_name)');
    $dbh->do('CREATE INDEX IF NOT EXISTS idx_context_timestamp ON context(timestamp)');
    $dbh->do('CREATE INDEX IF NOT EXISTS idx_commands_timestamp ON commands(timestamp)');

    return bless { dbh => $dbh, dir => $dir }, $class;
}

sub log_command {
    my ($self, $cmd, $stdout, $stderr, $exit_code, $duration) = @_;

    $self->{dbh}->do(
        'INSERT INTO commands (timestamp, command, stdout, stderr, exit_code, duration_ms) VALUES (?, ?, ?, ?, ?, ?)',
        undef,
        time(),
        $cmd,
        substr($stdout // '', 0, 10000),
        substr($stderr // '', 0, 5000),
        $exit_code,
        $duration,
    );
}

sub log_event {
    my ($self, $type, $namespace, $resource_type, $resource_name, $data) = @_;

    $self->{dbh}->do(
        'INSERT INTO context (timestamp, type, namespace, resource_type, resource_name, data) VALUES (?, ?, ?, ?, ?, ?)',
        undef,
        time(),
        $type,
        $namespace // '',
        $resource_type // '',
        $resource_name // '',
        substr($data // '', 0, 5000),
    );
}

sub get_context {
    my ($self, %args) = @_;
    my $limit = $args{limit} // 20;
    my $type = $args{type};
    my $resource = $args{resource};

    my $sql = 'SELECT * FROM context WHERE 1=1';
    my @params;

    if ($type) {
        $sql .= ' AND type = ?';
        push @params, $type;
    }
    if ($resource) {
        $sql .= ' AND (resource_name = ? OR resource_type = ?)';
        push @params, $resource, $resource;
    }

    $sql .= ' ORDER BY timestamp DESC LIMIT ?';
    push @params, $limit;

    my $sth = $self->{dbh}->prepare($sql);
    $sth->execute(@params);

    my @results;
    while (my $row = $sth->fetchrow_hashref) {
        push @results, $row;
    }

    return [reverse @results];
}

sub get_history {
    my ($self, %args) = @_;
    my $limit = $args{limit} // 10;

    my $sth = $self->{dbh}->prepare('SELECT * FROM commands ORDER BY timestamp DESC LIMIT ?');
    $sth->execute($limit);

    my @results;
    while (my $row = $sth->fetchrow_hashref) {
        push @results, $row;
    }

    return [reverse @results];
}

sub clear_old {
    my ($self, $days) = @_;
    $days //= 7;
    my $cutoff = time() - ($days * 86400);

    $self->{dbh}->do('DELETE FROM context WHERE timestamp < ?', undef, $cutoff);
    $self->{dbh}->do('DELETE FROM commands WHERE timestamp < ?', undef, $cutoff);
}

sub DESTROY {
    my ($self) = @_;
    $self->{dbh}->disconnect if $self->{dbh};
}

1;
