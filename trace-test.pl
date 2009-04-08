#!/usr/bin/perl

sub foo {
    my $i;
    $i = 1_000_000;
    $i-- while $i > 0;
    return;
}

sub bar {
    my $a = "foobar";
    return \$a;
}

sub baz {
    sleep $_[0];
}

while(1) {
    foo();
    bar();
    baz(1);
}
