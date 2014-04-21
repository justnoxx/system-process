package System::Process;

# TODO: add pod

use strict;
use warnings;
use Carp;

our $VERSION = 0.05;

sub import {
    *{main::pidinfo} = \&pidinfo;
}

sub pidinfo {
    my (%params, $pid);

    if (scalar @_ & 1) {
        %params = (
            pid  =>  shift
        );
    }
    else {
        %params = @_;    
    }
    
    if ($params{pid} && $params{file}) {
        croak 'Choose one';
    }

    if (!$params{pid} && !$params{file}) {
        croak 'Missing pid or file param';
    }

    if ($params{file}) {
        return undef unless -r $params{file};

        open PID, $params{file};
        $pid = <PID>;
        close PID;
        return undef unless $pid;
        chomp $pid;
    }
    else {
        $pid = $params{pid};
    }
    

    if ($pid !~ m/^\d+$/s) {
        croak "PID must be a digits sequence";
    }
    
    return System::Process::Unit->new($pid);
}


1;

package System::Process::Unit;
use strict;
use warnings;
use Carp;

our $AUTOLOAD;

my @allowed_subs = qw/
    cpu
    time
    stat
    tty
    user
    mem
    rss
    vsz
    command
    start
/;

my $hal;
%$hal = map {(__PACKAGE__ . '::' . $_, 1)} @allowed_subs;


sub AUTOLOAD {
    my $program = $AUTOLOAD;

    croak "Undefined subroutine $program" unless $hal->{$program};

    my $sub = sub {
        my $self = shift;
        return $self->internal_info($program);
    };
    no strict 'refs';
    *{$program} = $sub;
    use strict 'refs';
    goto &$sub;
}


sub new {
    my ($class, $pid) = @_;

    my $self = {};
    bless $self, $class;
    $self->pid($pid);
    unless ($self->process_info()) {
        return undef;
    }

    return $self;
}


sub refresh {
    my $self = shift;
    my $pid = $self->pid();

    $self = System::Process::pidinfo(pid     =>  $pid);
    return 1;
}

sub process_info {
    my $self = shift;

    my $command = 'ps u ' . $self->pid();
    my @res = `$command`;
    return $self->parse_output(@res);
}


sub parse_output {
    my ($self, @out) = @_;

    # если нет второй строки, значит процесса не было
    return 0 unless $out[1];

    my @header = split /\s+/, $out[0];
    my @values = split /\s+/, $out[1];
    my $res;

    my $last_key;

    for (0 .. $#values) {
        unless (@header) {
            unshift @values, $res->{$last_key};
            $res->{$last_key} = join ' ', @values;
            last;
        }
        else {
            my $k = $last_key = shift @header;
            my $v = shift @values;
            $res->{$k} = $v;
        }
    }

    for my $key (keys %$res) {
        my $k2 = lc $key;
        $k2 =~ s/[^A-Za-z]//gs;
        $res->{$k2} = $res->{$key};
        delete $res->{$key};
    }
    
    $self->internal_info($res);

    return 1;
}


sub pid {
    my ($self, $pid) = @_;

    if ($pid) {
        $self->{pid} = $pid;
    }
    return $self->{pid};
}


sub internal_info {
    my ($self, $param) = @_;

    if (ref $param eq 'HASH') {
        $self->{_procinfo} = $param;
        return 1;
    }
    else {
        $param =~ s|^.+::||;
        return $self->{_procinfo}->{$param};
    }
}


sub cankill {
    my $self = shift;

    my $pid = $self->pid();

    if (kill 0, $pid) {
        return 1;
    }
    return 0;
}


sub kill {
    my ($self, $signal) = @_;

    if (!defined $signal) {
        croak 'Signal must be specified';
    }
    # printf "Gonna kill %s with signal: %s\n", $self->pid(), $signal;
    return kill $signal, $self->pid();
}


sub DESTROY {
    my $self = shift;
    undef $self;
}


1;
__END__;
