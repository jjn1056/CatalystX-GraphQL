package Catalyst::ActionRole::HandleGraphQL;

use Moose::Role;

requires 'attributes','execute';

has graphql_model => (
  is=>'ro',
  required=>1,
  lazy=>1,
  builder=>'_build_graphql_model');
 
  sub _build_graphql_model {
    my ($self) = @_;
    my ($model) =  @{
      $self->attributes->{GraphQLModel} ||
      ['GraphQL']
    };
    return $model;
  }

around 'execute', sub {
  my ($orig, $self, $controller, $ctx, @args) = @_;
  my ($first, @results) = $self->$orig($controller, $ctx, @args);
  $ctx->forward($ctx->model($self->graphql_model));
  if((ref($first)||'') eq 'CODE') {
    $first->($ctx);
  }
  return ($first, @results);
};

1;

=head1 NAME
 
Catalyst::ActionRole::HandleGraphQL - Easily serve GraphQL from an action

=head1 SYNOPSIS

The following will automatically mount a '/graphql' endpoint with a tiny bit
less boilerplate code than if you call the model directly.

    package Todo::Controller::Root;

    use Moose;
    use MooseX::MethodAttributes;

    extends 'Catalyst::Controller';

    sub graphql :Local :Args(0) Does(HandleGraphQL) {
      my ($self, $c) = @_;
    }

    __PACKAGE__->config(namespace=>'');
    __PACKAGE__->meta->make_immutable;

=head1 DESCRIPTION

Some people will always want less code :)  If you actually put anything into the
action body, it will run first, that way you can do any needed authorization or
other setup (although you can also do that easily enough with action chaining as
well).

By default it assumes your GraphQL model is called 'GraphQL'.   If you name it something
else you can specify that with an attribute 'GraphQLModel', for example:

    sub graphql :Local :Args(0) GraphQLModel(MySpecialName) Does(HandleGraphQL) {
      my ($self, $c) = @_;
    }

Would use C<MyApp::Model::MySpecialName>. However that is starting to not really save 
much code is it...

=head1 AUTHOR
 
John Napiorkowski

=head1 SEE ALSO
 
L<CatalystX::GraphQL>
 
=cut
