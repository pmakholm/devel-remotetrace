# $Id:$
package Devel::RemoteTrace;

use warnings;
use strict;

our $VERSION = '0.2';

sub import {
    $DB::trace = 1 if grep { $_ eq ':trace' } @_;
}

package DB;

our $sub;
our @args;
our $trace;

use Socket;
my ($socket, $sin);
my $depth;

BEGIN {
    # Force use of debuging:
    $INC{'perl5db.pl'} = 1;
    $^P = 0x33f;

    # Initialize socket:
    my $port  = $ENV{DEBUG_PORT} || 9999;
    my $host  = $ENV{DEBUG_ADDR} || 'localhost';
    my $proto = getprotobyname('udp');

    $sin      = sockaddr_in($port, INADDR_LOOPBACK);
    socket( $socket, PF_INET, SOCK_DGRAM, $proto);

    # Initialize pretty printing:
    $depth = '';
}

sub dblog {
    send($socket, $_[0], 0, $sin);
}

$SIG{USR2} = sub { $trace = !$trace; };

sub DB {
    return unless $trace;

    my %Caller;
    @Caller{ qw( package filename line subroutine) } = caller(0);

    no strict 'refs';
    dblog( "[$$]$depth $Caller{filename}:$Caller{line}: " .  ${$main::{"_<$Caller{filename}"}}[$Caller{line}] );
}

sub sub {
    unless ($trace) {
        no strict 'refs';
        return &{ $sub };
    }

    my %dbCalled;
    my %realCalled;

    # A call frame contains where the call happened and the name of the called
    # subroutine. To log the complete description we need the subroutine name from the
    # callers frame and the filename and line numer form the callees
    # frame.
    @dbCalled{   qw(package filename line subroutine) } = caller(-1);
    @realCalled{ qw(package filename line subroutine) } = caller( 0);

    $realCalled{subroutine} ||= "<main>";

    dblog( "[$$]$depth $sub called in $realCalled{subroutine} "
         . "at $dbCalled{filename}:$dbCalled{line}\n" );


    $depth .= "  ";
    
    my ($ret, @ret);
    {
        # Call the function in the correct context:

        no strict 'refs';
        if (wantarray) {
            @ret = &{ $sub };
        } elsif (defined wantarray) {
            $ret = &{ $sub };
        } else {
            &{ $sub };
        }
    }

    substr($depth,0,2,'');

    # and return the correct context
    return (wantarray) ? @ret : defined(wantarray) ? $ret : undef;
}

sub postponed {
    return unless $trace;

    my $arg = shift;
    if (ref \$arg eq 'GLOB') {
        dblog( "[$$] Loaded file ${ *$arg{SCALAR} }\n" );
    } else {
        dblog( "[$$] Compiled function $arg\n" );
    }
}


1;

__END__

=head1 NAME

Devel::RemoteTrace - Attachable call trace of perl scripts

=head1 SYNOPSIS

  $ perl -d:RemoteTrace your-script

or

  $ perl -d:RemoteTrace=:trace your-script

or

  use Devel::RemoteTrace;

=head1 DESCRIPTION

This module implements a perl debugger that sends a call trace of the debugged
perl script to a remote destination via UDP. The default is to send to
localhost:9999.

By using UDP the debug process doesn't have to care aboput if any body is
listening. It just sends the trace messages.

Tracing is enabled and disabled bysending the traced process ans SIGUSR2. If 
the module is called with ':trace' as argument tracing is enabled from the
beginning

=head1 ENVIRONMENT

RemoteTrace uses the followin environment variables:

=over 4

=item DEBUG_ADDR

=item DEBUG_PORT

The hostname and port to send the call trace to.

=back

=head1 BUGS, FEATURES, AND OTHER ISSUES

Using this on untrusted networks might leak security related information

Due to the nature of UDP there is no guarantee that the receiver gets all
function calls. This could be "fixed" by adding a sequence number.

=head1 AUTHOR

Peter Makholm, C<< <peter at makholm.net> >>

=head1 COPYRIGHT & LICENSE

Copyright 2009 Peter Makholm, all rights reserved.

This software is released under the MIT license cited below.

=head1 The "MIT" License

Permission is hereby granted, free of charge, to any person obtaining
a copy of this software and associated documentation files (the
"Software"), to deal in the Software without restriction, including
without limitation the rights to use, copy, modify, merge, publish,
distribute, sublicense, and/or sell copies of the Software, and to
permit persons to whom the Software is furnished to do so, subject
to the following conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR
ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF
CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.


