
use 5.006001;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME              => 'Devel::Hide',
    VERSION_FROM      => 'lib/Devel/Hide.pm', # finds $VERSION
    PREREQ_PM         => {
        Test::More               => 0,
      ($] <= 5.008 ? (
        File::Temp               => 0
      ) : ())
    }, 
    ($] >= 5.005 ?
      (ABSTRACT_FROM  => 'lib/Devel/Hide.pm', # retrieve abstract from module
       AUTHOR         => 'A. R. Ferreira <ferreira@cpan.org>',
       NO_META           => 1) : ()),
);
