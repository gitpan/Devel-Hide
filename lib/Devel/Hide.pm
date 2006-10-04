
package Devel::Hide;

use 5.006001;
use strict;
use warnings;

our $VERSION = '0.0003';

# TO DO:
# * write Changes, Makefile.PL, README
# * write unimport() sub
# * tweak the instant of emiting the warning message (Devel::Hide hides ...)
# * write decent docs

# maybe I should change the our variables to "use vars qw()"

use vars qw(@HIDDEN $VERBOSE);

# tells whether "Devel::Hide hides ..." was already emitted
my $WARNING;

# $ENV{DEVEL_HIDE_PM} is split in ' '
# as well as @HIDDEN it accepts Module::Module as well as File/Names.pm

# if (m+(/|\.)+) -> filename (has slash or dot)
# if (/::/) -> module         =~ s|::|/|g;    .= '.pm'
# if (/^(\w+::)*\w+$/) -> module

=begin private

=item B<_to_fn>

  $fn = _to_fn($pm)

Turns a Perl module name (like 'A' or 'P::Q') into
a filename ("A.pm", "P/Q.pm").

=end private

=cut

sub _to_fn {
  my $pm = shift;
  $pm =~ s|::|/|g; $pm .= '.pm';
  return $pm
}

=begin private

=item B<_as_fn>

  @fn = _as_fn(@args)
  @fn = _as_fn(qw(A.pm X B/C.pm File::Spec)) # returns qw(A.pm X.pm B/C.pm File/Spec.pm)

Copies the argument list, turning what looks like
a Perl module name to filenames and leaving everything
else as it is. To look like a Perl module name is
to match /^(\w+::)*\w+$/.

=end private

=cut

sub _as_fn {
  my @args = @_;
  my @ans;
  for (@args) {
    push @ans, /^(\w+::)*\w+$/ ? _to_fn($_) : $_;
  }
  return @ans;
}

=begin private

=item B<split_mod>

Splits a list of filenames or module names separated by spaces.
TO DO: The module names are converted to filenames.

=end private

=cut

sub split_mod {
  my @mods = split /\s+/, shift;
  return _as_fn @mods;
}

BEGIN {

  unless (defined $VERBOSE) { # unless user-defined elsewhere, set default
    $VERBOSE = defined $ENV{DEVEL_HIDE_VERBOSE} ? $ENV{DEVEL_HIDE_VERBOSE} : 1;
  }

  unless (defined @HIDDEN) { # unless user-defined elsewhere, set default
    push @HIDDEN, split_mod($ENV{DEVEL_HIDE_PM}) if $ENV{DEVEL_HIDE_PM};
  } else {
    @HIDDEN = _as_fn(@HIDDEN); # just filenames
  }

  if ($] >= 5.008) {
      *_scalar_as_io = \&_scalar_as_io8;
  } else {
      *_scalar_as_io = \&_scalar_as_io6;
  }

}

# works for perl 5.8.0, uses in-core files
sub _scalar_as_io8 {
  open my $io, '<', \$_[0]
    or die $!; # this should not happen (perl 5.8 should support this)
  return $io;
}

# works for perl >= 5.6.1, uses File::Temp
sub _scalar_as_io6 {
  my $scalar = shift;
  require File::Temp;
  my $io = File::Temp::tempfile();
  print $io $scalar;
  seek $io, 0, 0;
  return $io
}

# _scalar_as_io is one of the two sub's above

sub _denial {
  my $filename = shift;
  my $oops;
  my $hidden_by = $VERBOSE ? "hidden" : "hidden by " . __PACKAGE__;
  $oops = qq{die "Can't locate $filename ($hidden_by)\n"};
  return _scalar_as_io($oops);
}

sub _is_hidden {
  my $filename = shift;
  return scalar grep { $_ eq $filename } @HIDDEN
}

sub _carp {
  warn __PACKAGE__, " hides ", join(', ', @HIDDEN), "\n" if $VERBOSE && @HIDDEN;
  $WARNING++;
}

sub _inc_hook {
  my ($coderef, $filename) = @_;

  _carp() unless $WARNING;

  if (_is_hidden($filename)) {
    return _denial($filename);
  } else {
    return undef;
  }
}

use lib (\&_inc_hook);

sub import {
  shift;
  push @HIDDEN, _as_fn(@_) if @_
}

1;

__END__

=head1 NAME

Devel::Hide - Forces the unavailability of specified Perl modules (for testing)

=head1 SYNOPSIS

  use Devel::Hide qw(Module/ToHide.pm);
  require Module::ToHide; # fails 

  use Devel::Hide qw(Test::Pod Test::Pod::Coverage);
  require Test::More; # ok
  require Test::Pod 1.18; # fails

Other common usage patterns:

  $ perl -MDevel::Hide=Module::ToHide Makefile.PL

  bash$ PERL5OPT=MDevel::Hide
  bash$ DEVEL_HIDE_PM='Module::Which Test::Pod'
  bash$ export PERL5OPT DEVEL_HIDE_PM
  bash$ perl Makefile.PL

outputs (like blib)

  Devel::Hide hides Module::Which, Test::Pod, etc.

=head1 DESCRIPTION

Given a list of Perl modules/filenames, this module makes
C<require> and C<use> statements fail (no matter the
specified files/modules are installed or not).

They I<die> with a message like:

  Can't locate Module/ToHide.pm (hidden)

The original intent of this module is to allow Perl developers
to test for alternative behavior when some modules are not
available. In a Perl installation, where many modules are
already installed, there is a chance to screw things up
because you take for granted things that may not be there
in other machines. 

For example, to test if your distribution does the right thing
when a module is missing, you can do

    perl -MDevel::Hide=Test::Pod Makefile.PL

forcing C<Test::Pod> to not be found (whether it is installed
or not).

Another use case is to force a module which can choose between
two requisites to use the one which is not the default.
For example, C<XML::Simple> needs a parser module and may use
C<XML::Parser> or C<XML::SAX> (preferring the latter).
If you have both of them installed, it will always try C<XML::SAX>.
But you can say:

    perl -MDevel::Hide=XML::SAX script_which_uses_xml_simple.pl

    (this needs confirmation)


NOTE. This module does not use L<Carp>. As said before,
denial I<dies>.

This module is pretty trivial. It uses a code reference
in @INC to get rid of specific modules during require -
denying they can be successfully loaded and stopping
the search before they have a chance to be found.


There are three alternative ways to include modules in
the hidden list: 
* setting @Devel::Hide::HIDDEN
* environment variable DEVEL_HIDE_PM
* import()



There is some interaction between C<lib> and this module

   use Devel::Hide qw(Module/ToHide.pm);
   use lib qw(my_lib);

In this case, 'my_lib' enters the include path before
the Devel::Hide hook and if F<Module/ToHide.pm> is found
in 'my_lib', it succeeds.


Also for modules that were loaded before Devel::Hide,
C<require> and C<use> succeeds.


=head2 EXPORTS

Nothing is exported.


=head1 ENVIRONMENT VARIABLES

DEVEL_HIDE_PM - if defined, the list of modules is added
   to the list of hidden modules

DEVEL_HIDE_VERBOSE - on by default. If off, supresses
   the initial message which shows the list of hidden modules
   in effect


=head1 SEE ALSO

L<perldoc -f require> 

L<Test::Without::Module>

=head1 BUGS

Please report bugs via CPAN RT L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Devel-Hide>.

=head1 AUTHOR

Adriano R. Ferreira, E<lt>ferreira@cpan.orgE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2005-2006 by Adriano R. Ferreira

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.


=cut

1;
