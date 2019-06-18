package Todo::Controller::Root;

use Moose;
use MooseX::MethodAttributes;

extends 'Catalyst::Controller';

sub graphql :Local :Args(0) Does(HandleGraphQL) {
  my ($self, $c) = @_;
}

__PACKAGE__->config(namespace=>'');
__PACKAGE__->meta->make_immutable;

