package SRS::Utils::PSUtils;
use strict;
use warnings;
use Carp;

our @ISA = qw/Exporter/;
our @EXPORT = qw/pidinfo/;

sub pidinfo {
    my $pid = shift;

    croak "Missing param" unless $pid;

    if ($pid !~ m/^\d+$/s) {
        croak "PID must be a digits sequence";
    }
    
    return SRS::PID->new($pid);
}


1;

package SRS::PID;
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
        return {};
    }

    return $self;
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


sub DESTROY {
    my $self = shift;
    undef $self;
}


1;
__END__;
