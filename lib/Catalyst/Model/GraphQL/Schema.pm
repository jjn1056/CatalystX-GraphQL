package Catalyst::Model::GraphQL::Schema;

use Plack::Util;
use GraphQL::Schema;

use base 'Catalyst::Model';

sub COMPONENT {
  my ( $class, $c ) = @_;
  my $arguments = ( ref( $_[-1] ) eq 'HASH' ) ? $_[-1] : {};

  if(my $from = $arguments->{from}) {
    return $class->coerce_schema($from);
  } else {
    return GraphQL::Schema->new($arguments);
  }
}

sub coerce_schema {
  my $class = shift;
  my $from = Plack::Util::is_real_fh($_[0]) ?
    do { local $/ = undef; <$_[0]> } : 
      $_[0];
  return GraphQL::Schema->from_doc($from);
}

1;

=head1 NAME
 
Catalyst::Model::GraphQL::Schema - Catalyst Proxy for GraphQL::Schema
 
=head1 SYNOPSIS
 
=head1 DESCRIPTION
 

=head1 CONFIGURATION
 
This L<Catalyst::Model> applications supports the following configuration arguments:


=head1 METHODS

    TBD
 
=head1 AUTHOR
 
John Napiorkowski <jnapiork@cpan.org>

=head1 SEE ALSO
 
L<GraphQL>, L<Catalyst>, L<CatalystX::GraphQL>

=head1 COPYRIGHT

Copyright (c) 2019 by "AUTHOR" as listed above.

=head1 LICENSE

This library is free software and may be distributed under the same terms as perl itself.
 
=cut

