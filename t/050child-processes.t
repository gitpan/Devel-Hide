
use strict;
use Devel::Hide qw(-from:children Q.pm R);

# Mlib=t is to get around 'use lib' etc being annoying

$ENV{PERL5OPT} = 'Mlib=t '.$ENV{PERL5OPT};

exec($^X, '-e', q{
    use strict;
    use Test::More tests => 4;

    ok($ENV{PERL5OPT} =~ /\bMlib=t\b/, "PERL5OPT is added to, not overwritten: $ENV{PERL5OPT}");
    eval { require P }; 
    ok(!$@, "P was loaded (as it should)");

    eval { require Q }; 
    like($@, qr/^Can't locate Q\.pm/, "Q not found (as it should)");

    eval { require R }; 
    like($@, qr/^Can't locate R\.pm/, "R not found (as it should)");
});
