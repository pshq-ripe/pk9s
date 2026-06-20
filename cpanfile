requires 'JSON::PP', '0';
requires 'IPC::Open3', '0';
requires 'File::Temp', '0';
requires 'Tickit', '0';
requires 'Term::ANSIColor', '0';

on 'test' => sub {
    requires 'Test::More', '0.96';
};
